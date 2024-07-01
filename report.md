# H1 Liquidate & Self Liquidate should not be Paused

## Impact
Lender can loose funds if the borrower's collateral is dropping when the protocol is Paused.  

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



### Links to affected code -> To include directly in the Code4rena Submit page
https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L210
https://github.com/code-423n4/2024-06-size/blob/8850e25fb088898e9cf86f9be1c401ad155bea86/src/Size.sol#L223





# M1 Wrong Use of Rounding

Rounding should be in favor of Protocol and then Lender, but never the Borrower. 

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