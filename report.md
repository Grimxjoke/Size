# H1 Liquidate & Self Liquidate should have a 100% up time

## Impact
Lender can lose funds if the borrower's collateral is dropping when the protocol is Paused.  

## Proof of Concept

Alice deposit 4000 USDC into the size protocol<br>
Bob deposit 1 ETH of collateral so around 4000$ (assuming the ETH price is 4000$/ETH)<br>
Bob borrow up to 2666 USDC with a Collateral Ration of 150% <br>
> BorrowAmount = Collateral Value / crOpening  <br>
> Collateral Value = 4000 USD woth of ETH <br>
> CrOpening = 1,5 <br>

ETH price is dropping to 3467$/ETH
Collateral Ratio now is just above the liquidation threshold of 130% <br>
> Collateral Value = 3464 USD worth of ETH <br>
> BorrowAmount = 2666 USDC <br> 
> Collateral Ratio =  Collateral Value / Borrow Amount = 1.3004 <br>
> crLiquidation = 1,3 <br>

Protocol pause the Size Contract for any reasons

Bob collateral is now dropping more and it's open for liquidation (liquidate) but can't be liquidate due to the modifier.

If the ETH's price is still dropping and reach the price of 2665$/ETH, the borrower is now undercollaterized and can't call the Self-Liquidation function either. <br>
Therefore the borrower has no incetives to repay the loan and keep the USDC value. 



## Tools Used

Manual Review

## Recommended Mitigation Steps

Remove the whenNotPaused modifier in the Liquidate & SelfLiquidate functions.
Create a different modifier to pause the liquidate and self iquidate functions (for emergencies). This way if the protocol is paused, creditors can still self liquidate. 



### Links to affected code -> To include directly in the Code4rena Submit page
https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L210
https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L223





# M1 APR calculation is favoring the borrower instead of the lender

The loan APR affects how much the borrower is expected to pay to the lender. In the following examples, the APR is calculated using the mulDivDown function. This favors the borrower instead of the lender.

First Example: 
Liquidate.sol::executeLiquidate

https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/libraries/actions/Liquidate.sol#L112
```solidity
    protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
    ...
    state.data.collateralToken.transferFrom(debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken);
```

Second Example: 

YieldCurveLibrary::getAPR 

getApr will return this value if y0 > y1 : 
```solidity
return y0 + Math.mulDivDown(y1 - y0, tenor - x0, x1 - x0);
```

However as this is APR calculation, a lower APR will be beneficial for the Borrower. 

## Tools Used

Manual Review

## Recommended Mitigation Steps

Use mulDivUp when calculation the APR

First Example: 
Set the protocolProfitCollateralToken to:

```diff
- protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
+ protocolProfitCollateralToken = Math.mulDivUp(collateralRemainder, collateralProtocolPercent, PERCENT);  
```



Second Example: 
Set the return value to:    
```diff

- return y0 + Math.mulDivDown(y1 - y0, tenor - x0, x1 - x0);
+ return y0 + Math.mulDivUp(y1 - y0, tenor - x0, x1 - x0);

``` 


# M1 User can place offer which are never collateralized leading to many dirty orders in the order book.
The protocol allows users to add limit orders uncollateralized. A bad actor, using multiple wallets, can create fake and appealing lending/borrowing offers. This will create many highly appealing orders in the orders book which will fail during fulfillment time when calling the Create sell/buy market orders functions. This will lead to a very bad user experience and created a semi-DOS effect on the system. 

## POC
```
function test_limit_order_not_backed_by_collateral_failing() public{
      
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
```

## Tools Used

Manual Review

## Recommended Mitigation Steps
There are a few options to mitigate:
- Remove bad offers (limit orders) from the order book
- Mechanism to blacklist bad acttors
- Allow collateralized limit orders only


# M1 loan and borrow offers are not being reset after the user deposit has been used for lending/borrowing leaving stake orders on the order book
Once a legitimate user adds a loan or borrow offer to the order book, other users can user the market order functions to fulfill that order. Once a user deposit has been consumed to fulfill other orders, the offer still reamins in the order book, creating stale orders which cannot be fulfilled. 

## POC
```
 function test_orders_not_being_cleared_after_fulfillment_failing()public{
      _deposit(alice, usdc, 150e6);
      _deposit(bob, weth, 200e18);
      _deposit(candy, weth, 200e18);

      assertEq(_state().alice.user.loanOffer.isNull(),true);

      console.log("Alice places a lending offer in the order book.");
      _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
      
      assertEq(_state().alice.user.loanOffer.isNull(),false);

      uint256 amount = 100e6;
      uint256 tenor = 365 days;

      uint256 futureValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);

      bool result = false;
      console.log("Bob tries to fulfill Alice's order, operation should complete successfully");
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
      catch Error(string memory reason){
         console.log(reason);
         result=false;
      }
      assertEq(result,true);
      console.log("Order is still in Alice's state reflecting in the order book");
      assertEq(_state().alice.user.loanOffer.isNull(),false);


      console.log("Candy tries to fulfill Alice's order as he sees it in the order book. Operation should fail with insufficient amount error");
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
      catch Error(string memory reason){
         console.log(reason);
         result=false;
      }
      assertEq(result,false);



   }
```

## Tools Used

Manual Review

## Recommended Mitigation Steps
There are different mitigation options:
- update the order book to remove stale orders
- Use the UI to show how much a user can lend/borrow based on their deposited collateral