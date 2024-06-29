// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserView} from "@src/SizeView.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {BaseTest} from "@test/BaseTest.sol";
import "forge-std/console.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";

import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";

contract LimitOrderNotBackedByCollateral is BaseTest {
   using OfferLibrary for LoanOffer;
   
   function test_limit_order_not_backed_by_collateral() public{

        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        Vars memory _before = _state();

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        uint256 futureValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);

        uint256 futureValueOpening = Math.mulDivUp(futureValue, size.riskConfig().crOpening, PERCENT);
        uint256 minimumCollateral = size.debtTokenAmountToCollateralTokenAmount(futureValueOpening);
        uint256 swapFee = size.getSwapFee(amount, tenor);

        Vars memory _after = _state();

        assertGt(_before.bob.collateralTokenBalance, minimumCollateral);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance - amount - swapFee);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, size.getDebtPosition(debtPositionId).futureValue);

   }
}