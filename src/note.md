
AccountingLibrary: 

Loan active status ? 
explain that : ""It guarantees that the sum of credit positions keeps equal to the debt position future value.""
So lender cannot take Reduce their crdit if it's in Active status
What's Tenor again ? -> tenor == maturity ? 



LoanLibrary: 
why ""CREDIT_POSITION_ID_START"" starts at mid uint range ? 
non transferable (scaled) tokens

RiskLibrary: 
debtWAD -> amountToWAD(debtAmount, Underlying Borrow token Decimals ) 

```solidity Collateral ratio calculation
 if (debt != 0) {
            return Math.mulDivDown(collateral, price, debtWad);
        } else {
            return type(uint256).max;
        }

```



Error.sol
What the compensator ? 

CapsLibrary:
What it the borrowAtoken anyway ?
What is the Variale Pool ? 

OfferLibrary: 

Check again AprBytenor -> YiedCurveLibrary
What's the absolute rate per tenor ? 



PriceFeed.sol:

What's GRACE_PERIOD_TIME ?
What's base;
What's quote;
What's sequencerUptimeFeed;
Check Chainlink -> latestRoundData() return values ;





Overall Question : 

Get to understand a bit more the aToken from aave 
What is Self Liquidate ? 
What is ""LiquidateWithReplacement"" again ? 
What is "Compensate" vs "Claim" ?

what are scaled amount/balance ? 
What is the variable pool and what's it's use case ? 
How is the variable Pool interact in any way with the token scaled contract ? 
What exactly is the debt token ? Is a non-trasferable (non scaled) token based on the underlying Borrow token (USDC)

So a BorrowAToken (scaled ) is created base on the USDC and the debt token (non scaled ) is also created based on USDC ? 
Why one is scaled where the other is not scaled ? 
What's the diff between Credit or Cash ? 
What's the matter with RESERVED_ID, and who can set a position ID (credit position or debt position) to RESERVED_ID == type(uint).max ?

What's Claiming a position ? Need the Loan to be repaid first ? Credit should be > 0  
What's Compensate ? Who is the compensator in size protocol ? 
Why taking the min value between amount, creditPositionWithDebtToRepay.credit and creditPositionToCompensate.credit to Compensate
What is the diff between isUnderWater and isPositionLiquidable ? 

What is the collateral token as a non-transferabel token? ther's a lot a differents tokens , ETH as collateral, USDC as borrow token, sizeETH as collateral non-transferable token, sizeBorrowAtoken is non-transferable scaled token, and also the debt token which is non-transferable token?
Liquidate vs LiquidateWithReplacement vs SelfLiquidate ? 
What is "setUserConfiguration" contract ? 
What is 150% liquidation collateral ratio ? 



How does a borrower give his position to another one? Is LiquidableWithTransfer the only solution or there are other ways ? 












Attacks Ideas: 

Can the Borrower self liquidate and save/earn money even when the health factor is < 1 ? 






Does both the ETH and the sizeETH get locked until repaid or liquidation when the lender gives a loan to a borrower ? In that case, the borrower has to deposit ETH also before as collateral, what about the borrower sizeETH, what about the USDC the sizeUSDC(ST) and it's sizeDebt(debtToken) ? What it locked by the system, what is distributed to who ? 


In self liquidate , i assume that the borrower is still loosing money but not as much as Liquidate
Also the borrower that gets replace in LiquidateWithReplacment, Does the borrower loose more in the regular Liquidate or does he loose the same amount in both Liquidate and LiqidateWithReplacment ? 


I've read many time that the size protocol used a 130% liquidation Collateral Ratio, meaning that (let's say that 1ETH = 2000$) if the user is deposit 1ETH, he can borrow up to 2000*(70/100) = 1400 USDC ? if the ETH value is dropping and the user has a loan of 1400usdc , therefore the Collateral ration will get higherr that 130% and the position will be able to be liquidabte. 


Also if the calculation is right, how do oyu make sence of it ? What I mean is that the LCR is c = 130% = a+B so b=30% more than a= 100%. So for a collateral value of d = 100$ =  I can borrow up to d*((a - b)/100) , is that right ?





How can the market Multiplier can change