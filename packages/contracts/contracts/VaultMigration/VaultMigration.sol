pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./uniswap/UniswapFlashSwapper.sol";
import "./uniswap/IUniswapRouter.sol";
import "./IProxy.sol";

contract VaultMigration is UniswapFlashSwapper {
    // Uniswap
    IUniswapRouter UniswapRouter;

    // Registers
    address ProxyRegisteryAddress;
    address ProxyGuardRegisteryAddress;

    // Maker
    address MakerProxyActions;
    address ETHAGemJoin;
    address ETHBGemJoin;

    struct NewVaultData {
        address owner;
        uint256 _CollateralAmount;
        uint256 _DAIAmount;
        address _DAIReceiver;
        address _manager;
        address _jug;
        address _ethJoin;
        address _daiJoin;
        bytes32 _ilk;
    }

    struct MakertoLiquityData {
        address owner;
        address manager;
        address gemToken;
        address gemjoin;
        address daiJoin;
        uint256 cdpID;
        uint256 debtAmount;
        uint256 collateralAmount;
        uint256 maxSlippage;
    }

    // Liquity
    address LiquityProxyBorrowerOperations;
    address LUSD;

    struct LiquitytoMakerData {
        address owner;
        uint256 _CollateralAmount;
        uint256 _DebtAmount;
        address _manager;
        address _jug;
        address _ethJoin;
        address _daiJoin;
        bytes32 _ilk;
    }

    constructor(
        address _UniswapFactory,
        address _UniswapRouter,
        address _MakerProxyActions,
        address _LiquityProxyBorrowerOperations,
        address _ETHAGemJoin,
        address _ETHBGemJoin,
        address _ProxyRegisteryAddress,
        address _ProxyGuardRegisteryAddress,
        address _DAI,
        address _WETH,
        address _LUSD
    ) public UniswapFlashSwapper(_UniswapFactory, _DAI, _WETH) {
        UniswapRouter = IUniswapRouter(_UniswapRouter);
        MakerProxyActions = _MakerProxyActions;
        LiquityProxyBorrowerOperations = _LiquityProxyBorrowerOperations;
        ETHAGemJoin = _ETHAGemJoin;
        ETHBGemJoin = _ETHBGemJoin;
        ProxyRegisteryAddress = _ProxyRegisteryAddress;
        ProxyGuardRegisteryAddress = _ProxyGuardRegisteryAddress;
        LUSD = _LUSD;
    }

    function newMakerVault(NewVaultData memory newVaultData) public payable returns (uint256 cdpID) {
        DSProxy proxy = IProxyRegistery(ProxyRegisteryAddress).build(address(this));
        DSGuard proxyAuth = IGuardRegistery(ProxyGuardRegisteryAddress).newGuard(address(this));

        proxy.setAuthority(DSAuthority(address(proxyAuth)));
        proxyAuth.permit(address(this), address(proxy), bytes32(uint256(-1)));

        proxy.setOwner(newVaultData.owner);
        proxyAuth.setOwner(newVaultData.owner);

        if (msg.sender != permissionedPairAddress)
            require(msg.value == newVaultData._CollateralAmount, "Insufficient Value");

        bytes32 result =
            proxy.execute.value(newVaultData._CollateralAmount)(
                LiquityProxyBorrowerOperations,
                abi.encodeWithSignature(
                    "openLockETHAndDraw(address,address,address,address,byte32,uint256)",
                    newVaultData._manager,
                    newVaultData._jug,
                    newVaultData._ethJoin,
                    newVaultData._daiJoin,
                    newVaultData._ilk,
                    newVaultData._DAIAmount
                )
            );
        cdpID = abi.decode(abi.encodePacked(result), (uint256));

        if (newVaultData._DAIReceiver != address(this))
            IERC20(DAI).transfer(newVaultData._DAIReceiver, newVaultData._DAIAmount);
    }

    function newLiquityTrove(
        address owner,
        uint256 _maxFee,
        uint256 _CollateralAmount,
        uint256 _LUSDAmount,
        address _LUSDReceiver
    ) public payable {
        DSProxy proxy = IProxyRegistery(ProxyRegisteryAddress).build(address(this));
        DSGuard proxyAuth = IGuardRegistery(ProxyGuardRegisteryAddress).newGuard(address(this));

        proxy.setAuthority(DSAuthority(address(proxyAuth)));
        proxyAuth.permit(address(this), address(proxy), bytes32(uint256(-1)));

        proxy.setOwner(owner);
        proxyAuth.setOwner(owner);

        if (msg.sender != permissionedPairAddress) require(msg.value == _CollateralAmount, "Insufficient Value");

        proxy.execute.value(_CollateralAmount)(
            LiquityProxyBorrowerOperations,
            abi.encodeWithSignature(
                "openTrove(uint,uint,address,address)",
                _maxFee,
                _LUSDAmount,
                address(proxy),
                address(proxy)
            )
        );

        if (_LUSDReceiver != address(this)) IERC20(LUSD).transfer(_LUSDReceiver, _LUSDAmount);
    }

    // @notice Flash-borrows _amount of _tokenBorrow from a Uniswap V2 pair and repays using _tokenPay
    // @param _tokenBorrow The address of the token you want to flash-borrow, use 0x0 for ETH
    // @param _amount The amount of _tokenBorrow you will borrow
    // @param _tokenPay The address of the token you want to use to payback the flash-borrow, use 0x0 for ETH
    // @param _userData Data that will be passed to the `execute` function for the user
    // @dev Depending on your use case, you may want to add access controls to this function
    function migratetoLiquity(MakertoLiquityData calldata _vaultData) external {
        // User have to approve this contract through CDPAllow
        // Debt is debt amount * rate
        require(msg.sender == _vaultData.owner, "You are not the owner!");
        startSwap(DAI, _vaultData.debtAmount, LUSD, abi.encode(_vaultData));
    }

    //
    function mgigratetoMaker(address ProxyAddress, LiquitytoMakerData calldata _vaultData) external {
        require(msg.sender == _vaultData.owner, "You are not the owner!");
        startSwap(LUSD, _vaultData._DebtAmount, DAI, abi.encode(ProxyAddress, _vaultData));
    }

    function _migrateVault(
        address _tokenBorrow,
        uint256 _amount,
        address _tokenPay,
        uint256 _amountToRepay,
        bytes memory _userData
    ) internal {
        // Migration to Liquity
        if (_tokenBorrow == DAI) {
            MakertoLiquityData memory vaultData = abi.decode(_userData, (MakertoLiquityData));
            if (vaultData.gemjoin == ETHAGemJoin || vaultData.gemjoin == ETHBGemJoin) {
                (bool success, bytes memory data) =
                    MakerProxyActions.delegatecall(
                        abi.encodeWithSignature(
                            "wipeAllAndFreeETH(address,address,address,uint,uint,address)",
                            vaultData.manager,
                            vaultData.gemjoin,
                            vaultData.daiJoin,
                            vaultData.cdpID,
                            vaultData.collateralAmount,
                            address(this)
                        )
                    );
                require(success, "Clearing Debt Failed!");
                newLiquityTrove(vaultData.owner, 1e17, _amount, _amountToRepay, address(this));
            } else {
                (bool success, bytes memory data) =
                    MakerProxyActions.delegatecall(
                        abi.encodeWithSignature(
                            "wipeAllAndFreeGem(address,address,address,uint,uint,address)",
                            vaultData.manager,
                            vaultData.gemjoin,
                            vaultData.daiJoin,
                            vaultData.cdpID,
                            vaultData.collateralAmount,
                            address(this)
                        )
                    );
                require(success, "Clearing Debt Failed!");
                // Swap
                address[] memory swapPath = new address[](2);
                swapPath[0] = vaultData.gemToken;
                swapPath[1] = WETH;
                uint256[] memory amounts =
                    swapToETH(
                        swapPath,
                        vaultData.collateralAmount,
                        (vaultData.collateralAmount * vaultData.maxSlippage) / 100
                    );
                newLiquityTrove(vaultData.owner, 1e17, amounts[amounts.length - 1], _amountToRepay, address(this));
            }
        }
        // Migration to Maker
        else if (_tokenBorrow == LUSD) {
            (address ProxyAddress, LiquitytoMakerData memory vaultData) =
                abi.decode(_userData, (address, LiquitytoMakerData));
            (bool status, bytes memory data) =
                ProxyAddress.call(
                    abi.encodeWithSignature(
                        "execute(address,bytes)",
                        address(LiquityProxyBorrowerOperations),
                        abi.encodeWithSignature(
                            "closeTrove(uint256,uint256,address)",
                            vaultData._DebtAmount,
                            vaultData._CollateralAmount,
                            address(this)
                        )
                    )
                );
            require(status, "Failed to Close Trove!");
            newMakerVault(
                NewVaultData({
                    owner: vaultData.owner,
                    _CollateralAmount: vaultData._CollateralAmount,
                    _DAIAmount: _amountToRepay,
                    _DAIReceiver: address(this),
                    _manager: vaultData._manager,
                    _jug: vaultData._jug,
                    _ethJoin: vaultData._ethJoin,
                    _daiJoin: vaultData._daiJoin,
                    _ilk: vaultData._ilk
                })
            );
        }
    }

    function swapToETH(
        address[] memory path,
        uint256 amount,
        uint256 minReturn
    ) internal returns (uint256[] memory amounts) {
        IERC20(path[0]).approve(address(UniswapRouter), amount);
        amounts = UniswapRouter.swapExactTokensForTokens(amount, minReturn, path, address(this), (now + 30 minutes));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    }

    function getBalanceOf(address _input) private returns (uint256) {
        if (_input == address(0)) {
            return address(this).balance;
        }
        return IERC20(_input).balanceOf(address(this));
    }
}
