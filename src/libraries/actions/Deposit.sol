// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";
import {CapsLibrary} from "@src/libraries/CapsLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {DepositTokenLibrary} from "@src/libraries/DepositTokenLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositParams {
    // The token to deposit
    address token;
    // The amount to deposit
    uint256 amount;
    // The account to deposit the tokens to
    address to;
}

/// @title Deposit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for depositing tokens into the protocol
library Deposit {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IWETH;

    using DepositTokenLibrary for State;
    using CapsLibrary for State;

    function validateDeposit(
        State storage state,
        DepositParams calldata params
    ) external view {
        // validate msg.sender
        // N/A

        // validate msg.value
        //audit-ok
        if (
            msg.value != 0 &&
            (msg.value != params.amount ||
                params.token != address(state.data.weth))
        ) {
            revert Errors.INVALID_MSG_VALUE(msg.value);
        }

        // validate token
        //audit-ok The token should be either the collateral or the Borrow
        //note To check if both token have only one entry point (should be) check this solodit issue : 
        //note  https://solodit.xyz/issues/anyone-can-steal-money-from-other-suppliers-in-tusd-market-by-creating-negative-interest-rates-openzeppelin-compound-comprehensive-protocol-audit-markdown
        if (
            params.token != address(state.data.underlyingCollateralToken) &&
            params.token != address(state.data.underlyingBorrowToken)
        ) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate to
        if (params.to == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function executeDeposit(
        State storage state,
        DepositParams calldata params
    ) public {
        address from = msg.sender;
        uint256 amount = params.amount;
        if (msg.value > 0) {
            // do not trust msg.value (see `Multicall.sol`)
            //audit WTF the amount that the user is suppose to deposit is the amount of this address? 
            //audit Does the User has to deposit ETH to this address first and then used 
            amount = address(this).balance;

            state.data.weth.deposit{value: amount}();
            state.data.weth.forceApprove(address(this), amount);
            from = address(this);
        }

        if (params.token == address(state.data.underlyingBorrowToken)) {
            state.depositUnderlyingBorrowTokenToVariablePool(
                from,
                params.to,
                amount
            );
            // borrow aToken cap is not validated in multicall,
            //   since users must be able to deposit more tokens to repay debt
            if (!state.data.isMulticall) {
                state.validateBorrowATokenCap();
            }
        //audit Any check to be sure that the token is the underlying token ? 
        } else {
            state.depositUnderlyingCollateralToken(from, params.to, amount);
        }

        emit Events.Deposit(params.token, params.to, amount);
    }
}
