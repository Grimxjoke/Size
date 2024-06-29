SpearBit 
Some of the findings aren't rally in-scope but are part of the report.
eg: 5.1.2 Potential reverse market where USDC -> Collateral & WETH -> Borrow Token 

## Criticals 

5.1.1 : 
Make sure that all borrowing and exiting functions enforce the repayment of fees, particularly focusing on any mechanisms for exiting debt positions or creating market orders.
Make sure  that fees are calculated based on the faceValue rather than issuanceValue to prevent manipulation.
Make sure that the system correctly handles multiple accounts and collateral transfers, preventing borrowers from using secondary accounts to reduce or avoid fees.

5.1.2 : 
Make sure that all functions handle decimals correctly, especially when converting between different USDC and WETH with different decimal places.
Make sure that all configuration values, such as crOpening and crLiquidation, are appropriately set for the reverse market scenario. Ensure that these values are escalated correctly to prevent calculation errors.
Make sure Ensure that key functions like debtTokenAmountToCollateralTokenAmount and collateralRatio work correctly in both normal and reverse market configurations. 

## HIGHS

5.2.1 : 
Make sure the calculation of assignedCollateral properly accounts for repay fees and does not include future fees that other creditors will pay.
Make sure that that the LoanLibrary.getCreditPositionProRataAssignedCollateral() function is modified to deduct repay fees from the debt position's collateral amount, adjusting for unpaid fees.

5.2.3 : Resolved By SIZE I think 
Make sure that the BuyMarketCredit function correctly checks that the APR does not fall below the minimum acceptable rate (minAPR).

## MEDIUM 

5.3.1 : 
Make sure that the calculation of debtInCollateralToken uses debtPosition.faceValue instead of the total debt. This ensures that self-liquidations are only eligible when the position is undercollateralized.

5.3.3 : Based their Issue because it's different from the Doc
Make sure ensure no fees are deducted during self-liquidation.
Make sure the simple Recommendations has been followed. 

5.3.4 : 
Make sure that the protocol only controls the amount of emitted debt tokens and removes the restrictive caps on collateral and borrow tokens.
