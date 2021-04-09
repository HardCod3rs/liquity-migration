// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Interfaces/IBorrowerOperations.sol";
import "./Interfaces/IERC20.sol";

contract BorrowerOperationsScript {
    IBorrowerOperations immutable borrowerOperations;
    address immutable LUSD;

    function LUSD_Join(address _From, uint256 _Amount) private {
        // Gets LUSD from the user's wallet
        IERC20(LUSD).transferFrom(_From, address(this), _Amount);
        // Approves Operations to take the LUSD amount
        IERC20(LUSD).approve(address(borrowerOperations), _Amount);
    }

    constructor(IBorrowerOperations _borrowerOperations, address _LUSD) public {
        borrowerOperations = _borrowerOperations;
        LUSD = _LUSD;
    }

    function openTrove(
        uint256 _maxFee,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.openTrove{ value: msg.value }(_maxFee, _LUSDAmount, _upperHint, _lowerHint);
    }

    function openTroveAndDraw(
        uint256 _maxFee,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.openTrove{ value: msg.value }(_maxFee, _LUSDAmount, _upperHint, _lowerHint);

        IERC20(LUSD).transfer(msg.sender, _LUSDAmount);
    }

    function addColl(address _upperHint, address _lowerHint) external payable {
        borrowerOperations.addColl{ value: msg.value }(_upperHint, _lowerHint);
    }

    function withdrawColl(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperations.withdrawColl(_amount, _upperHint, _lowerHint);
    }

    function withdrawLUSD(
        uint256 _maxFee,
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperations.withdrawLUSD(_maxFee, _amount, _upperHint, _lowerHint);
    }

    function repayLUSD(
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperations.repayLUSD(_amount, _upperHint, _lowerHint);
    }

    function closeTrove() external {
        borrowerOperations.closeTrove();
    }

    function closeTroveAndFreeETH(uint256 _debtAmount, uint256 _collAmount) external {
        LUSD_Join(msg.sender, _debtAmount);
        borrowerOperations.closeTrove();
        msg.sender.transfer(_collAmount);
    }

    function adjustTrove(
        uint256 _maxFee,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.adjustTrove{ value: msg.value }(
            _maxFee,
            _collWithdrawal,
            _debtChange,
            isDebtIncrease,
            _upperHint,
            _lowerHint
        );
    }

    function adjustTroveAndDraw(
        uint256 _maxFee,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        borrowerOperations.adjustTrove{ value: msg.value }(
            _maxFee,
            _collWithdrawal,
            _debtChange,
            isDebtIncrease,
            _upperHint,
            _lowerHint
        );
        if (isDebtIncrease) IERC20(LUSD).transfer(msg.sender, _debtChange);
    }

    function claimCollateral() external {
        borrowerOperations.claimCollateral();
    }
}
