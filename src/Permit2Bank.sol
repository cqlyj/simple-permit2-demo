// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPermit2, IAllowanceTransfer, ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Permit2Bank {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IPermit2 private immutable i_permit2;
    mapping(address user => mapping(address token => uint256 amount))
        private s_userToTokenAmount;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Permit2Bank__InvalidSpender();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IPermit2 _i_permit2) {
        i_permit2 = _i_permit2;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///
    /// @param permitSingle The permit message signed for a single token allowance
    /// @param signature The off-chain signature for the permit message
    /// @dev The PermitSingle struct is defined in IAllowanceTransfer.sol contains the following fields:
    /// @dev - PermitDetails details
    /// @dev   - address token
    /// @dev   - uint160 amount
    /// @dev   - uint48 expiration => allowance expiration timestamp
    /// @dev   - uint48 nonce
    /// @dev - address spender
    /// @dev - deadline on the permit signature
    /// @dev Allowance Transfer when permit has not yet been called or needs to be refreshed.
    /// @notice The allowance transfer technique requires us to update the allowance mapping in the Permit2 contract by calling permit2.permit() before we can transfer funds on behalf of the user.
    /// @notice After i_permit2.permit() has been called for a particular user with specific allowance data, it is redundant to call it again unless needed.
    /// @notice the permit() call increments a nonce associated with a particular owner, token, and spender for each signature to prevent double spend type attacks.
    function depositWithAllowanceTransferPermitRequired(
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external {
        // This contract must have spending permissions for the user.
        if (permitSingle.spender != address(this))
            revert Permit2Bank__InvalidSpender();

        // Credit the caller
        s_userToTokenAmount[msg.sender][
            permitSingle.details.token
        ] += permitSingle.details.amount;

        // owner is explicitly msg.sender
        i_permit2.permit(msg.sender, permitSingle, signature);

        emit Deposit(
            msg.sender,
            permitSingle.details.token,
            permitSingle.details.amount
        );
    }

    function depositWithAllowanceTransferPermitNotRequired() external {}

    function depositBatchWithAllowanceTransfer() external {}

    function depositWithSignatureTransfer() external {}

    function depositBatchWithSignatureTransfer() external {}

    function withdraw() external {}

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
