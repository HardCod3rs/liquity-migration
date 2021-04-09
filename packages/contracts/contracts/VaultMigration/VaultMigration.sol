pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./uniswap/UniswapFlashSwapper.sol";
import "./uniswap/IUniswapRouter.sol";
import "./IProxy.sol";

// Development
import "hardhat/console.sol";

contract VaultMigration is UniswapFlashSwapper {
    // Uniswap
    IUniswapRouter UniswapRouter;

    // Proxy
    address public ProxyGuardAddress;

    // Maker
    address MakerProxyActions;
    address ETHAGemJoin;
    address ETHBGemJoin;

    struct NewVaultData {
        uint256 _CollateralAmount;
        uint256 _DAIAmount;
        address _manager;
        address _jug;
        address _ethJoin;
        address _daiJoin;
        bytes32 _ilk;
    }

    struct MakertoLiquityData {
        address manager;
        address gemToken;
        address gemjoin;
        address daiJoin;
        uint256 cdpID;
        uint256 debtAmount;
        uint256 collateralAmount;
        uint256 minCollateralPercentage;
    }

    // Liquity
    address LiquityProxyBorrowerOperations;
    address LUSD;

    struct NewTroveData {
        uint256 _maxFee;
        uint256 _CollateralAmount;
        uint256 _LUSDAmount;
    }

    struct LiquitytoMakerData {
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
        address _ProxyGuardRegisteryAddress,
        address _DAI,
        address _WETH,
        address _LUSD
    ) public UniswapFlashSwapper(_UniswapFactory, _DAI, _WETH) {
        // Contracts
        UniswapRouter = IUniswapRouter(_UniswapRouter);
        MakerProxyActions = _MakerProxyActions;
        LiquityProxyBorrowerOperations = _LiquityProxyBorrowerOperations;
        // Addresses
        ETHAGemJoin = _ETHAGemJoin;
        ETHBGemJoin = _ETHBGemJoin;
        LUSD = _LUSD;
        // Construct Functions
        ProxyGuardAddress = address(_MigrationDSAuth(_ProxyGuardRegisteryAddress));
    }

    function _MigrationDSAuth(address ProxyGuardRegisteryAddress) internal returns (DSGuard proxyAuth) {
        proxyAuth = IGuardRegistery(ProxyGuardRegisteryAddress).newGuard(address(this));
    }

    function _newMakerVault(DSProxy Proxy, NewVaultData memory newVaultData) internal {
        Proxy.execute.value(newVaultData._CollateralAmount)(
            MakerProxyActions,
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
    }

    function _newLiquityTrove(DSProxy Proxy, NewTroveData memory newTroveData) internal {
        Proxy.execute.value(newTroveData._CollateralAmount)(
            LiquityProxyBorrowerOperations,
            abi.encodeWithSignature(
                "openTroveAndDraw(uint256,uint256,address,address)",
                newTroveData._maxFee,
                newTroveData._LUSDAmount,
                address(Proxy),
                address(Proxy)
            )
        );

        console.log(getBalanceOf(LUSD));
    }

    // @notice Flash-borrows _amount of _tokenBorrow from a Uniswap V2 pair and repays using _tokenPay
    // @param _tokenBorrow The address of the token you want to flash-borrow, use 0x0 for ETH
    // @param _amount The amount of _tokenBorrow you will borrow
    // @param _tokenPay The address of the token you want to use to payback the flash-borrow, use 0x0 for ETH
    // @param _userData Data that will be passed to the `execute` function for the user
    // @dev Depending on your use case, you may want to add access controls to this function
    function migratetoLiquity(address ProxyAddress, MakertoLiquityData calldata _vaultData) external {
        require(msg.sender == DSProxy(ProxyAddress).owner(), "You are not the Vault Owner");
        startSwap(DAI, _vaultData.debtAmount, LUSD, abi.encode(ProxyAddress, _vaultData));
    }

    //
    function mgigratetoMaker(address ProxyAddress, LiquitytoMakerData calldata _vaultData) external {
        require(msg.sender == DSProxy(ProxyAddress).owner(), "You are not the Trove Owner");
        startSwap(LUSD, _vaultData._DebtAmount, DAI, abi.encode(ProxyAddress, _vaultData));
    }

    function _migrateVault(
        address _tokenBorrow,
        uint256 _amount,
        address _tokenPay,
        uint256 _amountToRepay,
        bytes memory _userData
    ) internal {
        console.log("WTF");
        // Migration to Liquity
        if (_tokenBorrow == DAI) {
            console.log("pay amount: %s repay amount: %s", _amount, _amountToRepay);
            (address ProxyAddress, MakertoLiquityData memory vaultData) =
                abi.decode(_userData, (address, MakertoLiquityData));
            IERC20(_tokenBorrow).approve(ProxyAddress, _amount);
            if (vaultData.gemjoin == ETHAGemJoin || vaultData.gemjoin == ETHBGemJoin) {
                console.log("passed");
                DSProxy(ProxyAddress).execute(
                    MakerProxyActions,
                    abi.encodeWithSignature(
                        "wipeAllAndFreeETH(address,address,address,uint256,uint256)",
                        vaultData.manager,
                        vaultData.gemjoin,
                        vaultData.daiJoin,
                        vaultData.cdpID,
                        vaultData.collateralAmount
                    )
                );
                console.log("Balance: %s Collateral: %s", getBalanceOf(address(0)), vaultData.collateralAmount);
                _newLiquityTrove(
                    DSProxy(ProxyAddress),
                    NewTroveData({
                        _maxFee: 1e17,
                        _CollateralAmount: vaultData.collateralAmount,
                        _LUSDAmount: _amountToRepay
                    })
                );
            } else {
                DSProxy(ProxyAddress).execute(
                    MakerProxyActions,
                    abi.encodeWithSignature(
                        "wipeAllAndFreeGem(address,address,address,uint256,uint256)",
                        vaultData.manager,
                        vaultData.gemjoin,
                        vaultData.daiJoin,
                        vaultData.cdpID,
                        vaultData.collateralAmount
                    )
                );
                // Swap
                uint256[] memory amounts =
                    swapToETH(vaultData.gemToken, vaultData.collateralAmount, vaultData.minCollateralPercentage);

                console.log("Balance: %s Collateral: %s", getBalanceOf(address(0)), vaultData.collateralAmount);

                _newLiquityTrove(
                    DSProxy(ProxyAddress),
                    NewTroveData({
                        _maxFee: 1e17,
                        _CollateralAmount: amounts[amounts.length - 1],
                        _LUSDAmount: _amountToRepay
                    })
                );
            }
        }
        // Migration to Maker
        else if (_tokenBorrow == LUSD) {
            (address ProxyAddress, LiquitytoMakerData memory vaultData) =
                abi.decode(_userData, (address, LiquitytoMakerData));
            IERC20(_tokenBorrow).approve(ProxyAddress, _amount);
            DSProxy(ProxyAddress).execute(
                LiquityProxyBorrowerOperations,
                abi.encodeWithSignature(
                    "closeTroveAndFreeETH(uint256,uint256)",
                    vaultData._DebtAmount,
                    vaultData._CollateralAmount
                )
            );

            _newMakerVault(
                DSProxy(ProxyAddress),
                NewVaultData({
                    _CollateralAmount: vaultData._CollateralAmount,
                    _DAIAmount: _amountToRepay,
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
        address token,
        uint256 amount,
        uint256 minReturnPercent
    ) internal returns (uint256[] memory amounts) {
        address[] memory swapPath = new address[](2);
        swapPath[0] = token;
        swapPath[1] = WETH;
        uint256[] memory estimatedOuts = UniswapRouter.getAmountsOut(amount, swapPath);
        IERC20(swapPath[0]).approve(address(UniswapRouter), amount);
        amounts = UniswapRouter.swapExactTokensForTokens(
            amount,
            (estimatedOuts[estimatedOuts.length - 1] * minReturnPercent) / 100,
            swapPath,
            address(this),
            (now + 30 minutes)
        );
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    }

    function getBalanceOf(address _input) public view returns (uint256) {
        if (_input == address(0)) {
            return address(this).balance;
        }
        return IERC20(_input).balanceOf(address(this));
    }
}
