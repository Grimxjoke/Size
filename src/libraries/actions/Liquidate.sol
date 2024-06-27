// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateParams {
    // The debt position ID to liquidate
    uint256 debtPositionId;
    // The minimum profit in collateral tokens expected by the liquidator
    uint256 minimumCollateralProfit;
}

/// @title Liquidate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for liquidating a debt position
library Liquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    /// @notice Validates the input parameters for liquidating a debt position
    /// @param state The state
    function validateLiquidate(State storage state, LiquidateParams calldata params) external view {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate msg.sender
        // N/A

        // validate debtPositionId
        if (!state.isDebtPositionLiquidatable(params.debtPositionId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.debtPositionId,
                state.collateralRatio(debtPosition.borrower),
                state.getLoanStatus(params.debtPositionId)
            );
        }

        // validate minimumCollateralProfit
        // N/A
    }


    /// @notice Executes the liquidation of a debt position
    /// @param state The state
    /// @param params The input parameters for liquidating a debt position
    /// @return liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(params.debtPositionId, params.minimumCollateralProfit, collateralRatio, loanStatus);

        // if the loan is both underwater and overdue, the protocol fee related to underwater liquidations takes precedence
        uint256 collateralProtocolPercent = state.isUserUnderwater(debtPosition.borrower)
            ? state.feeConfig.collateralProtocolPercent
            : state.feeConfig.overdueCollateralProtocolPercent;

        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPosition);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPosition.futureValue);
        uint256 protocolProfitCollateralToken = 0;

        // profitable liquidation
        if (assignedCollateral > debtInCollateralToken) {
            
            //audit Will probably always choose the second value at it's in 1e6.
            uint256 liquidatorReward = Math.min(
                //audit First is in 1e18
                assignedCollateral - debtInCollateralToken,
                //audit Second is in 1e6
                Math.mulDivUp(debtPosition.futureValue, state.feeConfig.liquidationRewardPercent, PERCENT)
                // liquidationRewardPercent set to 5% in script/deploy.sol -> 0.05e18
            );
            liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

            // split the remaining collateral between the protocol and the borrower, capped by the crLiquidation
            //audit-ok  @paul No Underflow possible here ? The wost that can happen is to be 0 but cannot get lower  
            uint256 collateralRemainder = assignedCollateral - liquidatorProfitCollateralToken;

            // cap the collateral remainder to the liquidation collateral ratio
            //   otherwise, the split for non-underwater overdue loans could be too much
            uint256 collateralRemainderCap =
                Math.mulDivDown(debtInCollateralToken, state.riskConfig.crLiquidation, PERCENT);

            collateralRemainder = Math.min(collateralRemainder, collateralRemainderCap);
            //audit-issue @paul Should be mulDivUp as it's from the borrower to the Size protocol. In favor of the protocol
            protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        //note The Liquidator repay the Borrower debt to Size
        state.data.borrowAToken.transferFrom(msg.sender, address(this), debtPosition.futureValue);
        //note The Borrower send part of his collateral to the liquidator 
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, liquidatorProfitCollateralToken);
        //audit-ok @mody. sometimes, this will be 0 amount, will it revert? doesn't seem like it https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
        state.data.collateralToken.transferFrom(
            debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken
        );

        debtPosition.liquidityIndexAtRepayment = state.data.borrowAToken.liquidityIndex();
        state.repayDebt(params.debtPositionId, debtPosition.futureValue);
    }

    /// @notice Validates the minimum profit in collateral tokens expected by the liquidator
    /// @param params The input parameters for liquidating a debt position
    /// @param liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    function validateMinimumCollateralProfit(
        State storage,
        LiquidateParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        if (liquidatorProfitCollateralToken < params.minimumCollateralProfit) {
            revert Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT(
                liquidatorProfitCollateralToken, params.minimumCollateralProfit
            );
        }
    }
}
