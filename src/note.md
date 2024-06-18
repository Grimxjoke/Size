
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

So a BorrowAToken (scaled ) is created base on the USDC and the debt token (non scaled ) is also created based on USDC
Why one is scaled where the other is not scaled ? 
What's the diff between Credit or Cash ? 
What's the matter with RESERVED_ID, and who can set a position ID (credit position or debt position) to RESERVED_ID == type(uint).max ?

What's Claiming a position ? Need the Loan to be reapid first ? Credit should be > 0 -> Already Claimed 
What's Compensate ? Compensator should be the borrower ? 
Why taking the min value between amount, creditPositionWithDebtToRepay.credit and creditPositionToCompensate.credit to Compensate
What is the diff between isUnderWater and isPositionLiquidable ? 

Liquidate vs LiquidateWithReplacement vs SelfLiquidate ? 
What is "setUserConfiguration" contract ? 
What is 150% liquidation collateral ratio ? 












Attacks Ideas: 

Can the Borrower self liquidate and save/earn money even when the health factor is < 1 ? 



