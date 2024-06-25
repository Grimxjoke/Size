// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/libraries/YieldCurveLibrary.sol";

struct BuyCreditMarketParams {
    // The borrower
    // If creditPositionId is not RESERVED_ID, this value is ignored and the owner of the existing credit is used
    address borrower;
    // The credit position ID to buy
    // If RESERVED_ID, a new credit position will be created
    uint256 creditPositionId;
    // The amount of credit to buy
    uint256 amount;
    // The tenor of the loan
    // If creditPositionId is not RESERVED_ID, this value is ignored and the tenor of the existing loan is used
    uint256 tenor;
    // The deadline for the transaction
    uint256 deadline;
    // The minimum APR for the loan
    uint256 minAPR;
    // Whether amount means cash or credit
    bool exactAmountIn;
}

/// @title BuyCreditMarket
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for buying credit (lending) as a market order
library BuyCreditMarket {
    using OfferLibrary for BorrowOffer;
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using RiskLibrary for State;

    /// @notice Validates the input parameters for buying credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    function validateBuyCreditMarket(
        State storage state,
        BuyCreditMarketParams calldata params
    ) external view {
        address borrower;
        uint256 tenor;

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {
            borrower = params.borrower;
            tenor = params.tenor;

            // validate tenor
            if (
                tenor < state.riskConfig.minTenor ||
                tenor > state.riskConfig.maxTenor
            ) {
                revert Errors.TENOR_OUT_OF_RANGE(
                    tenor,
                    state.riskConfig.minTenor,
                    state.riskConfig.maxTenor
                );
            }
        } else {
            // Get a CreditPosition from a creditPositionId
            CreditPosition storage creditPosition = state.getCreditPosition(
                params.creditPositionId
            );

            // Get a DebtPosition from a CreditPosition id
            DebtPosition storage debtPosition = state
                .getDebtPositionByCreditPositionId(params.creditPositionId);
            //True if the credit position is transferrable, false otherwise
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    state.getLoanStatus(params.creditPositionId),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            User storage user = state.data.users[creditPosition.lender];
            if (
                user.allCreditPositionsForSaleDisabled ||
                !creditPosition.forSale
            ) {
                revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
            }

            borrower = creditPosition.lender;
            tenor = debtPosition.dueDate - block.timestamp; // positive since the credit position is transferrable, so the loan must be ACTIVE
        }

        BorrowOffer memory borrowOffer = state.data.users[borrower].borrowOffer;

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(borrower);
        }

        // validate amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(
                params.amount,
                state.riskConfig.minimumCreditBorrowAToken
            );
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        // Get the APR by tenor of a Borrow Offer
        uint256 apr = borrowOffer.getAPRByTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state
                    .oracle
                    .variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state
                    .oracle
                    .variablePoolBorrowRateStaleRateInterval
            }),
            tenor
        );
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    /// @notice Executes the buying of credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    /// @return cashAmountIn The amount of cash paid for the credit
    //audit-issue @mody buy and sell credit market does not remove the loan or borrow offer from the order book, this means users will keep trying to match orders which cannot be fulfilled.
    function executeBuyCreditMarket(
        State storage state,
        BuyCreditMarketParams memory params
    ) external returns (uint256 cashAmountIn) {
        emit Events.BuyCreditMarket(
            params.borrower,
            params.creditPositionId,
            params.tenor,
            params.amount,
            params.exactAmountIn
        );

        CreditPosition memory creditPosition;
        uint256 tenor;
        address borrower;
        if (params.creditPositionId == RESERVED_ID) {
            borrower = params.borrower;
            tenor = params.tenor;
        } else {
            // Get a DebtPosition from a CreditPosition id
            DebtPosition storage debtPosition = state
                .getDebtPositionByCreditPositionId(params.creditPositionId);

            // Get a CreditPosition from a creditPositionId
            creditPosition = state.getCreditPosition(params.creditPositionId);

            //audit-issue It's meant to be debtPosition.borrower instead as lender is msg.sender
            borrower = creditPosition.lender;
            tenor = debtPosition.dueDate - block.timestamp;
        }
        // Give the APR only for the duration of the tenor instead of an annual interest rate
        // Example a APR of 5% with a tenor of 1month will be : 5*30/365 = 0.4% interest after 1 month
        uint256 ratePerTenor = state.data.users[borrower].borrowOffer.getRatePerTenor(
                VariablePoolBorrowRateParams({
                    variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                    variablePoolBorrowRateUpdatedAt: state
                        .oracle
                        .variablePoolBorrowRateUpdatedAt,
                    variablePoolBorrowRateStaleRateInterval: state
                        .oracle
                        .variablePoolBorrowRateStaleRateInterval
                }),
                tenor
            );

        uint256 creditAmountOut;
        uint256 fees;

        if (params.exactAmountIn) {
            cashAmountIn = params.amount;

            
            // Get the credit amount out for a given cash amount in
            (creditAmountOut, fees) = state.getCreditAmountOut({
                cashAmountIn: cashAmountIn,
                maxCashAmountIn: params.creditPositionId == RESERVED_ID
                    ? cashAmountIn
                    : Math.mulDivUp(creditPosition.credit, PERCENT, PERCENT + ratePerTenor ),
                maxCredit: params.creditPositionId == RESERVED_ID
                    //audit Why (Percent + ratePerTenor)
                    ? Math.mulDivDown(cashAmountIn, PERCENT + ratePerTenor, PERCENT)
                    : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: tenor
            });
        } else {
            creditAmountOut = params.amount;

            // Get the cash amount in for a given credit amount out
            (cashAmountIn, fees) = state.getCashAmountIn({
                creditAmountOut: creditAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? creditAmountOut
                    : creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: tenor
            });
        }

        if (params.creditPositionId == RESERVED_ID) {
            /// @notice Creates a debt and credit position
            /// @dev Updates the borrower's total debt tracker.
            ///      The debt position future value and the credit position amount are created with the same value.

            state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: borrower,
                futureValue: creditAmountOut,
                dueDate: block.timestamp + tenor
            });
        } else {
            /// @notice Creates a credit position by exiting an existing credit position
            /// @dev If the credit amount is the same, the existing credit position is updated with the new lender.
            ///      If the credit amount is different, the existing credit position is reduced and a new credit position is created.
            ///      The exit process can only be done with loans in the ACTIVE status.
            ///        It guarantees that the sum of credit positions keeps equal to the debt position future value.
            state.createCreditPosition({
                exitCreditPositionId: params.creditPositionId,
                lender: msg.sender,
                credit: creditAmountOut
            });
        }

        state.data.borrowAToken.transferFrom(
            msg.sender,
            borrower,
            cashAmountIn - fees
        );
        //audit-ok @paul So Lender has to pay swapfees for lending his money ?
        //mody reply. I don't believe so. If the total a lender pays is 1000 and fee is 200, the borrower only gets 800 but the loan value is still 1000+interest
        state.data.borrowAToken.transferFrom(
            msg.sender,
            state.feeConfig.feeRecipient,
            fees
        );
    }
}
