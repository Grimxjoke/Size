# Liquidate & Self-Liquidate Should Have 100% Uptime

## Impact
Lenders can lose funds if the borrower's collateral is dropping when the protocol is paused.

## Proof of Concept

* Alice deposits 4000 USDC into the Size protocol.
* Bob deposits 1 ETH as collateral, worth approximately 4000 USD (assuming the ETH price is 4000 USD/ETH).
* Bob borrows up to 2666 USDC with a Collateral Ratio of 150%.
    * BorrowAmount = Collateral Value / crOpening
    * Collateral Value = 4000 USD worth of ETH
    * crOpening = 1.5

* ETH price drops to 3467 USD/ETH.
* Collateral Ratio is now just above the liquidation threshold of 130%.
    * Collateral Value = 3467 USD worth of ETH
    * BorrowAmount = 2666 USDC
    * Collateral Ratio = Collateral Value / Borrow Amount = 1.3004
    * crLiquidation = 1.3

* Protocol pauses the Size contract for any reason.
* Bob's collateral drops further and is open for liquidation but his position can't be liquidated due to the modifier.

If the ETH price continues to drop and reaches 2665 USD/ETH, Bob is now undercollateralized and Alice can't call the Self-Liquidation function either.

Therefore, Bob has no incentive to repay the loan and keep the USDC value, leading to a loss of funds for Alice.

## Tools Used

Manual Review

## Recommended Mitigation Steps

* Remove the `whenNotPaused` modifier in the `Liquidate` and `SelfLiquidate` functions.
* Create a different modifier to pause the liquidate and self-liquidate functions (for emergencies). This way, if the protocol is paused, creditors can still self-liquidate.

### Links to Affected Code (to include directly in the Code4rena Submit page)
* https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L210
* https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L223





# APR Calculation is Favoring the Borrower Instead of the Lender

The loan APR affects how much the borrower is expected to pay to the lender. In the following examples, the APR is calculated using the `mulDivDown` function. This favors the borrower instead of the lender.

## First Example
`Liquidate.sol::executeLiquidate`
- [Liquidate.sol#L112](https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/libraries/actions/Liquidate.sol#L112)

```solidity
    protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
    ...
    state.data.collateralToken.transferFrom(debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken);
```

## Second Example
`YieldCurveLibrary::getAPR`
- `getApr` will return this value if `y0 > y1`:
```solidity
    protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
    ...
    state.data.collateralToken.transferFrom(debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken);
```
- `return y0 + Math.mulDivDown(y1 - y0, tenor - x0, x1 - x0);`

However, as this is an APR calculation, a lower APR will be beneficial for the borrower.

## Tools Used
Manual Review

## Recommended Mitigation Steps
Use `mulDivUp` when calculating the APR.

### First Example
Set the `protocolProfitCollateralToken` to:
- `protocolProfitCollateralToken = Math.mulDivUp(collateralRemainder, collateralProtocolPercent, PERCENT);`

### Second Example
Set the return value to:
- `return y0 + Math.mulDivUp(y1 - y0, tenor - x0, x1 - x0);`





# M1 Users Can Place Offers That Are Never Collateralized, Leading to Many Dirty Orders in the Order Book
The protocol allows users to add limit orders without collateral. A bad actor, using multiple wallets, can create fake and appealing lending/borrowing offers. This will create many highly appealing orders in the order book which will fail during fulfillment when calling the create sell/buy market orders functions. This will lead to a very bad user experience and create a semi-DOS effect on the system.


## POC

<details><summary>  See tests </summary>
  
```solidity
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
</details>


## Tools Used

Manual Review

## Recommended Mitigation Steps
There are a few options to mitigate:
- Remove bad offers (limit orders) from the order book.
- Implement a mechanism to blacklist bad actors.
- Allow collateralized limit orders only.


# Loan and Borrow Offers Are Not Being Reset After the User Deposit Has Been Used, Leaving Stale Orders on the Order Book

Once a legitimate user adds a loan or borrow offer to the order book, other users can use the market order functions to fulfill that order. Once a user's deposit has been consumed to fulfill other orders, the offer still remains in the order book, creating stale orders which cannot be fulfilled.

## POC

<details><summary>  See tests </summary>

```solidity
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
</details>

## Tools Used

Manual Review

## Recommended Mitigation Steps
There are different mitigation options:
- Update the order book to remove stale orders.
- Use the UI to show how much a user can lend/borrow based on their deposited collateral.





















