// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";

/// @title DepositTokenLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains functions for interacting with underlying tokens
/// @dev Mints and burns 1:1 Size deposit tokens in exchange for underlying tokens
library DepositTokenLibrary {
    using SafeERC20 for IERC20Metadata;

    /// @notice Deposit underlying collateral token to the Size protocol
    /// @param state The state struct
    /// @param from The address from which the underlying collateral token is transferred
    /// @param to The address to which the Size deposit token is minted
    /// @param amount The amount of underlying collateral token to deposit
    //audit-ok @paul So non-tranferable-collateral-token to underlying-collateral-token == 1:1
    function depositUnderlyingCollateralToken(
        State storage state,
        address from,
        address to,
        uint256 amount
    ) external {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(
            state.data.underlyingCollateralToken
        );

        //audit-issue @paul If someone give the protocol approval. Can be front-run to deposit his token in the library by someone else.
        underlyingCollateralToken.safeTransferFrom(from, address(this), amount);
        state.data.collateralToken.mint(to, amount);
    }

    /// @notice Withdraw underlying collateral token from the Size protocol
    /// @param state The state struct
    /// @param from The address from which the Size deposit token is burned
    /// @param to The address to which the underlying collateral token is transferred
    /// @param amount The amount of underlying collateral token to withdraw
    function withdrawUnderlyingCollateralToken(
        State storage state,
        address from,
        address to,
        uint256 amount
    ) external {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(
            state.data.underlyingCollateralToken
        );
        //audit-issue @paul let anybody burn token on behalf of someone else ? Does not check that the From is the msg.sender
        //audit-issue @paul Anybody can call this function setting their address as "to" and set the "from" a know address who possess collateral-token
        state.data.collateralToken.burn(from, amount);
        underlyingCollateralToken.safeTransfer(to, amount);
    }

    /// @notice Deposit underlying borrow token to the Size protocol
    /// @dev The underlying borrow token is deposited to the Variable Pool,
    ///        and the corresponding Size borrow token is minted in scaled amounts.
    /// @param state The state struct
    /// @param from The address from which the underlying borrow token is transferred
    /// @param to The address to which the Size borrow token is minted
    /// @param amount The amount of underlying borrow token to deposit
    function depositUnderlyingBorrowTokenToVariablePool(
        State storage state,
        address from,
        address to,
        uint256 amount
    ) external {
        state.data.underlyingBorrowToken.safeTransferFrom(
            from,
            address(this),
            amount
        );

        IAToken aToken = IAToken(
            state
                .data
                .variablePool
                .getReserveData(address(state.data.underlyingBorrowToken))
                .aTokenAddress
        );

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        state.data.underlyingBorrowToken.forceApprove(
            address(state.data.variablePool),
            amount
        );
        state.data.variablePool.supply(
            address(state.data.underlyingBorrowToken),
            amount,
            address(this),
            0
        );

        uint256 scaledAmount = aToken.scaledBalanceOf(address(this)) -
            scaledBalanceBefore;

        state.data.borrowAToken.mintScaled(to, scaledAmount);
    }

    /// @notice Withdraw underlying borrow token from the Size protocol
    /// @dev The underlying borrow token is withdrawn from the Variable Pool,
    ///        and the corresponding Size borrow token is burned in scaled amounts.
    /// @param state The state struct
    /// @param from The address from which the Size borrow token is burned
    /// @param to The address to which the underlying borrow token is transferred
    /// @param amount The amount of underlying borrow token to withdraw
    function withdrawUnderlyingTokenFromVariablePool(
        State storage state,
        address from,
        address to,
        uint256 amount
    ) external {
        IAToken aToken = IAToken(
            state
                .data
                .variablePool
                .getReserveData(address(state.data.underlyingBorrowToken))
                .aTokenAddress
        );

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        state.data.variablePool.withdraw(
            address(state.data.underlyingBorrowToken),
            amount,
            to
        );

        uint256 scaledAmount = scaledBalanceBefore -
            aToken.scaledBalanceOf(address(this));

        state.data.borrowAToken.burnScaled(from, scaledAmount);
    }
}
