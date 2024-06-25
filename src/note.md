
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

Collateral ratio calculation
```solidity
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



How does a borrower give his position to another one? Is LiquidableWithTransfer the only solution or there are other ways ? 



Does both the ETH and the sizeETH get locked until repaid or liquidation when the lender gives a loan to a borrower ? In that case, the borrower has to deposit ETH also before as collateral, what about the borrower sizeETH, what about the USDC the sizeUSDC(ST) and it's sizeDebt(debtToken) ? What it locked by the system, what is distributed to who ? 


I've read many time that the size protocol used a 130% liquidation Collateral Ratio, meaning that (let's say that 1ETH = 2000$) if the user is deposit 1ETH, he can borrow up to 2000*(70/100) = 1400 USDC ? if the ETH value is dropping and the user has a loan of 1400usdc , therefore the Collateral ratio will get higher that 130% and the position will be able to be liquidabte. 


Also if the calculation is right, how do you make sence of it ? What I mean is that the LCR is c = 130% = a+B so b=30% more than a= 100%. So for a collateral value of d = 100$ =  I can borrow up to d*((a - b)/100) , is that right ?




## Main functions to Diagram from Size.sol: 
    - Multicall
    - Deposit
    - Withdraw
    - BuyCreditLimit
    - SellCreditLimit
    - BuyCreditMarket
    - SellCreditMarket
    - Repay
    - Claim
    - Liquidate
    - SelfLiquidate
    - LiquidateWithReplacement
    - Compensate
    - SetUserConfiguration

How can the market Multiplier can change ? 
    - Is that the Hook Rate ?
    - Yes it is  

Max Due date vs Tenors vs Deadline ?  
    - I think that maxDueDate is like the tenor for all the position, maybe the max tenor ?  

getRatePerTenor vs getAPRPerTenor ? 

Where is the borrower get match with the best loan (lowest rate ) in the code ? 

Where is the Insurrance Reserve ? 
    

https://docs.size.credit/non-technical/reducing-debt-with-credit

If Bob lends future value of 105USDC -> Position 1
Borrow 85USDC -> Position 2

Get back (after maturity without lender replacement) 105USDC -> Position 1
105-85 = 20 . Get back 20 USDC as 85USDC are locked as collateral to his Loan -> position 2
However his Loan is 85USDC + interest and collateral is 85USDC, so Bob is directly underwater on position 2 when he claims all is credit out of his position as a lenders

Bob get's undercollaterized (collaretal < position collateral + swapfees + interests rate ) and never repay his Loan -> position 2. 

From the docs : https://docs.size.credit/non-technical/reducing-debt-with-credit
""Positions are liquidated one at a time, and the liquidation threshold may rise back above the liquidation threshold if the liquidation is not unprofitable, giving the user another chance to supply more collateral.""

But if 1 position is liquidate, the collareral is reduce, therefore the Positions are still liquidable ?
Make sure that the actual liquidable position is liquidate first and not a random one or the first one, if the liquidable position isn't the lower one, the user is still subject to liquidation ....  
eg: p1(130) + p2(120) + p3(130) < 130% meaning that at least 1 position is lower than 130%, if position p1 is to be liquidate, all Position are still liquidable 



Questions : 
YieldCurveLibrary::L140
AccountingLibrary::L307 + BuyCreditMarket::L178 why PERCENT + ratePerTenor ? 
AccountingLibrary::L309 Fees calculated Twice
What is the "faceValue" ? 
    - Face Value is the sum of all the future Value. Future Value is the amount to be pay to 1 Lender. 
    - If the Debt Position has 2 Credit Positions (2 lenders) the faceValue = futureValue(lender1) + futureValue(lender2) 


In SelfLiquidation, the new Assigned Collateral is : AC = oldAC * (1 - (x / D))
x = amount of credit to cancel
D = Total Loan (w/o interest)  




What does it mean ? 
Liquidation should prioritize the lowest LTV asset


Liquidation Rule:
Liquidation should prioritize the liquidator fees
Liquidation should not loose the reward the user has made so far, or use them as part of collateral



To verify with Mody : 

Assigned Value Decimals Checks <br>
Collateral Ratio Decimals Checks <br>
Check Liquidation page : https://docs.size.credit/technical-docs/contracts/3.5-liquidations#id-3.5.2-eligibility-for-liquidation <br>

The initial values are set to:
- 𝜌𝑜 = 150%
- 𝜌𝑙 = 130%
