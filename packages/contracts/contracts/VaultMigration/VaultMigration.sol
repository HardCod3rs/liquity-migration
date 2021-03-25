pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./uniswap/UniswapFlashSwapper.sol";
import "./uniswap/IUniswapRouter.sol";
import "./Maker/DSProxyActions.sol";
import "./IProxy.sol";

contract VaultMigration is UniswapFlashSwapper, DssProxyActions {
    // Uniswap
    IUniswapRouter UniswapInterface;

    // Registers
    address ProxyRegisteryAddress;
    address ProxyGuardRegisteryAddress;

    // Maker
    address MakerProxyActions;
    address ETHGemJoin;

    struct MakerVaultData {
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

    /*struct LiquityTroveData {
        uint64;
    }*/

    constructor(
        address _UniswapFactory,
        address _UniswapInterface,
        address _MakerProxyActions,
        address _LiquityProxyBorrowerOperations,
        address _ETHGemJoin,
        address _ProxyRegisteryAddress,
        address _ProxyGuardRegisteryAddress,
        address _DAI,
        address _WETH,
        address _LUSD
    ) public UniswapFlashSwapper(_UniswapFactory, _DAI, _WETH) {
        UniswapInterface = IUniswapRouter(_UniswapInterface);
        MakerProxyActions = _MakerProxyActions;
        LiquityProxyBorrowerOperations = _LiquityProxyBorrowerOperations;
        ETHGemJoin = _ETHGemJoin;
        ProxyRegisteryAddress = _ProxyRegisteryAddress;
        ProxyGuardRegisteryAddress = _ProxyGuardRegisteryAddress;
        LUSD = _LUSD;
    }

    function _newLiquityTrove(
        address owner,
        uint256 _maxFee,
        uint256 _CollateralAmount,
        uint256 _LUSDAmount
    ) private {
        DSProxy proxy = IProxyRegistery(ProxyRegisteryAddress).build(address(this));
        DSGuard proxyAuth = IGuardRegistery(ProxyGuardRegisteryAddress).newGuard(address(this));

        proxy.setAuthority(DSAuthority(address(proxyAuth)));
        proxyAuth.permit(address(this), address(proxy), bytes32(uint256(-1)));

        proxy.setOwner(owner);
        proxyAuth.setOwner(owner);

        proxy.execute.value(_CollateralAmount)(
            LiquityProxyBorrowerOperations,
            abi.encodeWithSignature(
                "openTrove(uint, uint, address, address)",
                _maxFee,
                _LUSDAmount,
                address(proxy),
                address(proxy)
            )
        );
    }

    // @notice Flash-borrows _amount of _tokenBorrow from a Uniswap V2 pair and repays using _tokenPay
    // @param _tokenBorrow The address of the token you want to flash-borrow, use 0x0 for ETH
    // @param _amount The amount of _tokenBorrow you will borrow
    // @param _tokenPay The address of the token you want to use to payback the flash-borrow, use 0x0 for ETH
    // @param _userData Data that will be passed to the `execute` function for the user
    // @dev Depending on your use case, you may want to add access controls to this function
    function migratetoLiquity(MakerVaultData calldata _vaultData) external {
        // cdpallow
        //  amount is debt amount * rate
        startSwap(DAI, _vaultData.debtAmount, LUSD, abi.encode(_vaultData));
    }

    /* function mgigratetoMaker(
        address _tokenBorrow,
        uint256 _amount,
        address _tokenPay
    ) external {
        startSwap(_tokenBorrow, _amount, _tokenPay, _userData);
    }*/

    function _migrateVault(
        address _tokenBorrow,
        uint256 _amount,
        address _tokenPay,
        uint256 _amountToRepay,
        bytes memory _userData
    ) internal {
        // Migration to Liquity
        if (_tokenBorrow == DAI) {
            MakerVaultData memory vaultData = abi.decode(_userData, (MakerVaultData));
            if (vaultData.gemjoin == ETHGemJoin) {
                wipeAllAndFreeETH(
                    vaultData.manager,
                    vaultData.gemjoin,
                    vaultData.daiJoin,
                    vaultData.cdpID,
                    vaultData.collateralAmount
                );
                _newLiquityTrove(vaultData.owner, 1e17, _amount, _amountToRepay);
            } else {
                wipeAllAndFreeGem(
                    vaultData.manager,
                    vaultData.gemjoin,
                    vaultData.daiJoin,
                    vaultData.cdpID,
                    vaultData.collateralAmount
                );
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
                _newLiquityTrove(vaultData.owner, 1e17, amounts[amounts.length - 1], _amountToRepay);
            }
        }

        // Migration to Maker
        //else if (_tokenborrow == LUSD) {}
    }

    function swapToETH(
        address[] memory path,
        uint256 amount,
        uint256 minReturn
    ) internal returns (uint256[] memory amounts) {
        IERC20(path[0]).approve(address(UniswapInterface), amount);
        amounts = UniswapInterface.swapExactTokensForTokens(amount, minReturn, path, address(this), (now + 30 minutes));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    }

    function getBalanceOf(address _input) private returns (uint256) {
        if (_input == address(0)) {
            return address(this).balance;
        }
        return IERC20(_input).balanceOf(address(this));
    }
}
