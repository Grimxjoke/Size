// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {SellCreditLimit, SellCreditLimitParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarket, SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";

import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";

import {BuyCreditMarket, BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {SetUserConfiguration, SetUserConfigurationParams} from "@src/libraries/actions/SetUserConfiguration.sol";

import {BuyCreditLimit, BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";
import {Liquidate, LiquidateParams} from "@src/libraries/actions/Liquidate.sol";

import {Multicall} from "@src/libraries/Multicall.sol";
import {Compensate, CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {
    LiquidateWithReplacement,
    LiquidateWithReplacementParams
} from "@src/libraries/actions/LiquidateWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
//note  What would be the Self Liquidate ?
import {SelfLiquidate, SelfLiquidateParams} from "@src/libraries/actions/SelfLiquidate.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {State} from "@src/SizeStorage.sol";

import {CapsLibrary} from "@src/libraries/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {SizeView} from "@src/SizeView.sol";
import {Events} from "@src/libraries/Events.sol";

import {IMulticall} from "@src/interfaces/IMulticall.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeAdmin} from "@src/interfaces/ISizeAdmin.sol";

//note Probably the Bot address
bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
//note Probably Owner Address
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant BORROW_RATE_UPDATER_ROLE = keccak256("BORROW_RATE_UPDATER_ROLE");

/// @title Size
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISize}.
contract Size is ISize, SizeView, Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    //note They use a lot of Library to only change the State 
    using Initialize for State;
    using UpdateConfig for State;
    using Deposit for State;
    using Withdraw for State;
    using SellCreditMarket for State;
    using SellCreditLimit for State;
    using BuyCreditMarket for State;
    using BuyCreditLimit for State;
    using Repay for State;
    using Claim for State;
    using Liquidate for State;
    using SelfLiquidate for State;
    using LiquidateWithReplacement for State;
    using Compensate for State;
    using SetUserConfiguration for State;
    using RiskLibrary for State;
    using CapsLibrary for State;
    using Multicall for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        InitializeFeeConfigParams calldata f,
        InitializeRiskConfigParams calldata r,
        InitializeOracleParams calldata o,
        InitializeDataParams calldata d
    ) external initializer {
        state.validateInitialize(owner, f, r, o, d);
        //audit-info Need to check for Upgradeability features and secure implementations 
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(f, r, o, d);
        //note All Role given to Owner
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(KEEPER_ROLE, owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Updates the configuration of the protocol
    ///         Only callabe by the DEFAULT_ADMIN_ROLE
    /// @dev For `address` parameters, the `value` is converted to `uint160` and then to `address`
    /// @param params UpdateConfigParams struct containing the following fields:
    ///     - string key: The configuration parameter to update
    ///     - uint256 value: The value to update
    function updateConfig(UpdateConfigParams calldata params)
        external
        override(ISizeAdmin)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    /// @notice Sets the variable borrow rate
    ///         Only callabe by the BORROW_RATE_UPDATER_ROLE
    /// @dev The variable pool borrow rate cannot be used if the variablePoolBorrowRateStaleRateInterval is set to zero
    /// @param borrowRate The new borrow rate
    function setVariablePoolBorrowRate(uint128 borrowRate)
        external
        override(ISizeAdmin)
        onlyRole(BORROW_RATE_UPDATER_ROLE)
    {
        uint128 oldBorrowRate = state.oracle.variablePoolBorrowRate;
        state.oracle.variablePoolBorrowRate = borrowRate;
        state.oracle.variablePoolBorrowRateUpdatedAt = uint64(block.timestamp);
        emit Events.VariablePoolBorrowRateUpdated(oldBorrowRate, borrowRate);
    }

    /// @inheritdoc ISizeAdmin
    function pause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ISizeAdmin
    function unpause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Executes multiple calls in a single transaction
    /// @dev This function allows for batch processing of multiple interactions with the protocol in a single transaction.
    ///      This allows users to take actions that would otherwise be denied due to deposit limits.
    /// @param _data An array of bytes encoded function calls to be executed in sequence.
    /// @return results An array of bytes representing the return data from each function call executed.
    function multicall(bytes[] calldata _data)
        public
        payable
        override(IMulticall)
        whenNotPaused
        returns (bytes[] memory results)
    {
        results = state.multicall(_data);
    }
        
    /// @notice Deposit underlying borrow/collateral tokens to the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always deposited into the Variable Pool,
    ///         Collateral tokens are deposited into the Size contract through the DepositTokenLibrary
    /// @dev The caller must approve the transfer of the token to the protocol.
    ///      This function mints 1:1 Size Tokens (e.g. aUSDC, szETH) in exchange of the deposited tokens
    /// @param params DepositParams struct containing the following fields:
    ///     - address token: The address of the token to deposit
    ///     - uint256 amount: The amount of tokens to deposit
    ///     - uint256 to: The recipient of the deposit
    function deposit(DepositParams calldata params) public payable override(ISize) whenNotPaused {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @notice Withdraw underlying borrow/collateral tokens from the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always withdrawn from the Variable Pool
    ///         Collateral tokens are withdrawn from the Size contract through the DepositTokenLibrary
    /// @dev This function burns 1:1 Size Tokens (e.g. aUSDC, szETH) in exchange of the withdrawn tokens
    /// @param params WithdrawParams struct containing the following fields:
    ///     - address token: The address of the token to withdraw
    ///     - uint256 amount: The amount of tokens to withdraw (in decimals, e.g. 1_000e6 for 1000 USDC or 10e18 for 10 WETH)
    ///     - uint256 to: The recipient of the withdrawal
    function withdraw(WithdrawParams calldata params) external payable override(ISize) whenNotPaused {
        //note Same pattern
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        //audit-info Execute withdraw and then validate something -> Reentrancy ? CEI respected ? 
        //@mody-reply this is a different pattern where at the end of the function is checks for invariants. 
        state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
    }

    /// @notice Places a new loan offer in the orderbook
    /// @param params BuyCreditLimitParams struct containing the following fields:
    ///     - uint256 maxDueDate: The maximum due date of the loan (e.g., 1712188800 for April 4th, 2024)
    ///     - YieldCurve curveRelativeTime: The yield curve for the loan offer, a struct containing the following fields:
    ///         - uint256[] tenors: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] aprs: The aprs of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5% APR, 7% APR, and 8% APR, linear interest, respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [1e18, 1.2e18, 1.3e18] to represent 100%, 120%, and 130% of the market borrow rate, respectively)
    function buyCreditLimit(BuyCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditLimit(params);
        state.executeBuyCreditLimit(params);
    }

    /// @notice Places a new borrow offer in the orderbook
    /// @param params SellCreditLimitParams struct containing the following fields:
    ///     - YieldCurve curveRelativeTime: The yield curve for the borrow offer, a struct containing the following fields:
    ///         - uint256[] tenors: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] aprs: The aprs of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5% APR, 7% APR, and 8% APR, linear interest, respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [0.99e18, 1e18, 1.1e18] to represent 99%, 100%, and 110% of the market borrow rate, respectively)
    function sellCreditLimit(SellCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateSellCreditLimit(params);
        state.executeSellCreditLimit(params);
    }

    /// @notice Obtains credit via lending or buying existing credit
    /// @param params BuyCreditMarketParams struct containing the following fields:
    ///     - address borrower: The address of the borrower (optional, for lending)
    ///     - uint256 creditPositionId: The id of the credit position to buy (optional, for buying credit)
    ///     - uint256 tenor: The tenor of the loan
    ///     - uint256 amount: The amount of tokens to lend or credit to buy
    ///     - bool exactAmountIn: Indicates if the amount is the value to be transferred or used to calculate the transfer amount
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 minAPR: The minimum APR the caller is willing to accept
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditMarket(params);
        uint256 amount = state.executeBuyCreditMarket(params);
        if (params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @notice Sells credit via borrowing or exiting an existing credit position
    ///         This function can be used both for selling an existing credit or to borrow by creating a DebtPosition/CreditPosition pair
    /// @dev Order "takers" are the ones who pay the rounding, since "makers" are the ones passively waiting for an order to be matched
    ///       The caller may pass type(uint256).max as the creditPositionId in order to represent "mint a new DebtPosition/CreditPosition pair"
    /// @param params SellCreditMarketParams struct containing the following fields:
    ///     - address lender: The address of the lender
    ///     - uint256 creditPositionId: The id of a credit position to be sold
    ///     - uint256 amount: The amount of tokens to borrow (in decimals, e.g. 1_000e6 for 1000 aUSDC)
    ///     - uint256 tenor: The tenor of the loan
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 maxAPR: The maximum APR the caller is willing to accept
    ///     - bool exactAmountIn: this flag indicates if the amount argument represents either credit (true) or cash (false)
    function sellCreditMarket(SellCreditMarketParams memory params) external payable override(ISize) whenNotPaused {
        state.validateSellCreditMarket(params);
        uint256 amount = state.executeSellCreditMarket(params);
        if (params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @notice Repay a debt position by transferring the amount due of borrow tokens to the protocol, which are deposited to the Variable Pool for the lenders to claim
    ///         Partial repayment are currently unsupported
    /// @dev The Variable Pool liquidity index is snapshotted at the time of the repayment in order to calculate the accrued interest for lenders to claim
    ///      The liquidator overdue reward is cleared from the borrower debt upon repayment
    /// @param params RepayParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to repay
    function repay(RepayParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @notice Claim the repayment of a loan with accrued interest from the Variable Pool
    /// @dev Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet.
    ///      CLAIMED loans can't be claimed either because its credit has already been consumed entirely either by a previous claim or by exiting before
    /// @param params ClaimParams struct containing the following fields:
    ///     - uint256 creditPositionId: The id of the credit position to claim
    function claim(ClaimParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    /// @notice Liquidate a debt position
    ///         In case of a protifable liquidation, part of the collateral remainder is split between the protocol and the liquidator
    ///         The split is capped by the crLiquidation parameter (otherwise, the split for overdue loans could be too much)
    ///         If the loan is overdue, a liquidator is charged from the borrower
    /// @param params LiquidateParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    /// @return liquidatorProfitCollateralToken The amount of collateral tokens the liquidator received from the liquidation
    //audit @mody liquidate function should provide a 100% uptime, even when contract is paused. debatable though. 
    //audit @mody does the protocol allow for a gap between max credit selling (borrowing) and liquidation threshold? if not, then a user can get liquidation immediately after taking a loan. 
    function liquidate(LiquidateParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralToken)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralToken = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
    }

    /// @notice Self liquidate a credit position that is undercollateralized
    ///         The lender cancels an amount of debt equivalent to their credit and a percentage of the protocol fees
    /// @dev The user is prevented to self liquidate if a regular liquidation would be profitable
    /// @param params SelfLiquidateParams struct containing the following fields:
    ///     - uint256 creditPositionId: The id of the credit position to self-liquidate
    function selfLiquidate(SelfLiquidateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateSelfLiquidate(params);
        state.executeSelfLiquidate(params);
    }

  
    /// @notice Liquidate a debt position with a replacement borrower
    /// @dev This function works exactly like `liquidate`, with an added logic of replacing the borrower on the storage
    ///         When liquidating with replacement, nothing changes from the lender's perspective, but a spread is created between the previous borrower rate and the new borrower rate.
    ///         As a result of the spread of these borrow aprs, the protocol is able to profit from the liquidation. Since the choice of the borrower impacts on the protocol's profit, this method is permissioned
    /// @param params LiquidateWithReplacementParams struct containing the following fields:
    ///     - uint256 debtPositionId: The id of the debt position to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    ///     - address borrower: The address of the replacement borrower
    ///     - uint256 deadline: The maximum timestamp for the transaction to be executed
    ///     - uint256 minAPR: The minimum APR the caller is willing to accept
    /// @return liquidatorProfitCollateralToken The amount of collateral tokens liquidator received from the liquidation
    /// @return liquidatorProfitBorrowToken The amount of borrow tokens liquidator received from the liquidation
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken)
    {
        state.validateLiquidateWithReplacement(params);
        uint256 amount;
        (amount, liquidatorProfitCollateralToken, liquidatorProfitBorrowToken) =
            state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @notice Compensate a borrower's debt with his credit in another loan
    ///         The compensation can not exceed both 1) the credit the lender of `debtPositionToRepayId` to the borrower and 2) the credit the lender of `creditPositionToCompensateId`
    /// @dev The caller may pass type(uint256).max as the creditPositionId in order to represent "mint a new DebtPosition/CreditPosition pair"
    /// @param params CompensateParams struct containing the following fields:
    ///     - uint256 debtPositionToRepayId: The id of the debt position to repay
    ///     - uint256 creditPositionToCompensateId: The id of the credit position to compensate
    ///     - uint256 amount: The amount of tokens to compensate (in decimals, e.g. 1_000e6 for 1000 aUSDC)
    function compensate(CompensateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateCompensate(params);
        state.executeCompensate(params);
        state.validateUserIsNotUnderwater(msg.sender);
    }

    /// @inheritdoc ISize
    function setUserConfiguration(SetUserConfigurationParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
    {
        state.validateSetUserConfiguration(params);
        state.executeSetUserConfiguration(params);
    }
}
