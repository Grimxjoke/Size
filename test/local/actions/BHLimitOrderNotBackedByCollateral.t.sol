// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserView} from "@src/SizeView.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
<<<<<<< HEAD
import {BaseTest, Vars} from "@test/BaseTest.sol";
=======
import {Vars, BaseTest} from "@test/BaseTest.sol";
>>>>>>> 333f5076f7ae0852aa9dca28a8f5f4fe4b805801
import "forge-std/console.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";

import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";
import {Math, PERCENT, YEAR} from "@src/libraries/Math.sol";

contract LimitOrderNotBackedByCollateral is BaseTest {
   using OfferLibrary for LoanOffer;
   
   function test_limit_order_not_backed_by_collateral() public{
      
      // _deposit(alice, usdc, 200e6);
      _deposit(bob, weth, 100e18);
      _deposit(candy, weth, 100e18);
      console.log("Alice places an order in the order book. Uncollateralized.");
      _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

      uint256 amount = 100e6;
      uint256 tenor = 365 days;

      uint256 futureValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);


      bool result = false;
      console.log("Bob tries to fulfill Alice's order, operation fails dues to lack of deposit from Alice.");
      vm.prank(bob);
      try size.sellCreditMarket(
         SellCreditMarketParams({
               lender: alice,
               creditPositionId: RESERVED_ID,
               amount: amount,
               tenor: tenor,
               deadline: block.timestamp,
               maxAPR: type(uint256).max,
               exactAmountIn: false
         })
      ){
         result=true;
      }
      catch{
         result=false;
      }
      assertEq(result,false);

      console.log("Candy tries to fulfill the order. fails as well. ");
      vm.prank(candy);
      try size.sellCreditMarket(
         SellCreditMarketParams({
               lender: alice,
               creditPositionId: RESERVED_ID,
               amount: amount,
               tenor: tenor,
               deadline: block.timestamp,
               maxAPR: type(uint256).max,
               exactAmountIn: false
         })
      ){
         result=true;
      }
      catch{
         result=false;
      }
      assertEq(result,false);



   }
}