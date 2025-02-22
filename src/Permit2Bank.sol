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
    event DepositBatch(
        address indexed user,
        IAllowanceTransfer.PermitDetails[] details
    );

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
        // Transfers the allowed tokens from user to spender (our contract)
        i_permit2.transferFrom(
            msg.sender,
            address(this),
            permitSingle.details.amount,
            permitSingle.details.token
        );

        emit Deposit(
            msg.sender,
            permitSingle.details.token,
            permitSingle.details.amount
        );
    }

    ///
    /// @param token The token to deposit
    /// @param amount The amount to deposit
    /// @notice Allowance Transfer when permit has already been called and isn't expired and within allowed amount.
    /// @notice i_permit2._transfer() performs all the necessary security checks to ensure the allowance mapping for the spender is not expired and within allowed amount.
    function depositWithAllowanceTransferPermitNotRequired(
        address token,
        uint160 amount
    ) external {
        s_userToTokenAmount[msg.sender][token] += amount;
        i_permit2.transferFrom(msg.sender, address(this), amount, token);

        emit Deposit(msg.sender, token, amount);
    }

    ///
    /// @param permitBatch The permit message signed for multiple token allowances
    /// @param signature The off-chain signature for the permit message
    /// @dev The PermitBatch struct is defined in IAllowanceTransfer.sol with the only one field changed from PermitSingle:
    /// @dev - PermitDetails[] details
    /// @notice Most of the logic is the same as depositWithAllowanceTransferPermitRequired() but with multiple token allowances.
    function depositBatchWithAllowanceTransferPermitRequired(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external {
        // This contract must have spending permissions for the user.
        if (permitBatch.spender != address(this))
            revert Permit2Bank__InvalidSpender();

        // Credit the caller
        for (uint256 i = 0; i < permitBatch.details.length; i++) {
            s_userToTokenAmount[msg.sender][
                permitBatch.details[i].token
            ] += permitBatch.details[i].amount;
        }

        // owner is explicitly msg.sender
        i_permit2.permit(msg.sender, permitBatch, signature);

        // Transfers the allowed tokens from user to spender (our contract)
        for (uint256 i = 0; i < permitBatch.details.length; i++) {
            i_permit2.transferFrom(
                msg.sender,
                address(this),
                permitBatch.details[i].amount,
                permitBatch.details[i].token
            );
        }

        emit DepositBatch(msg.sender, permitBatch.details);
    }

    function depositBatchWithAllowanceTransferPermitNotRequired(
        IAllowanceTransfer.PermitBatch calldata permitBatch
    ) external {
        for (uint256 i = 0; i < permitBatch.details.length; i++) {
            s_userToTokenAmount[msg.sender][
                permitBatch.details[i].token
            ] += permitBatch.details[i].amount;
        }

        // Transfers the allowed tokens from user to spender (our contract)
        for (uint256 i = 0; i < permitBatch.details.length; i++) {
            i_permit2.transferFrom(
                msg.sender,
                address(this),
                permitBatch.details[i].amount,
                permitBatch.details[i].token
            );
        }

        emit DepositBatch(msg.sender, permitBatch.details);
    }

    ///
    /// @param permitFrom The permit message signed for a single token transfer
    /// @param signature The off-chain signature for the permit message
    /// @dev The PermitTransferFrom struct is defined in ISignatureTransfer.sol contains the following fields:
    /// @dev - TokenPermissions permitted
    /// @dev   - address token
    /// @dev   - uint160 amount
    /// @dev - uint256 nonce
    /// @dev - uint256 deadline => deadline on the permit signature
    /// @notice Instead of changing an allowance mapping in Permit2, we can call permitTransferFrom() immediately
    /// @notice As long as the signature and permit data are successfully verified.
    /// @notice This is more gas efficient due to fewer state updates, and best suited for situations where multiple transfers are not expected.
    /// @notice Signatures associated with a specific permission request cannot be reused because upon transfer completion the associated nonce is flipped from 0 to 1.
    /// @notice There is no method to "get the current nonce" as with Allowance Transfers because nonces are stored as bits in an unordered manner within a bitmap.
    /// @notice You can generate nonces in any way you wish as long as the generation technique does not cause collisions => Incrementation or randomness (with a sufficiently large range) are both valid.
    /// @notice Normal SignatureTransfer
    function depositWithSignatureTransferWithoutWitness(
        ISignatureTransfer.PermitTransferFrom calldata permitFrom,
        bytes calldata signature
    ) external {
        s_userToTokenAmount[msg.sender][
            permitFrom.permitted.token
        ] += permitFrom.permitted.amount;

        // Transfer tokens from the caller to this contract
        i_permit2.permitTransferFrom(
            // The permit message. Spender is inferred as the caller (this contract)
            permitFrom,
            // The transfer recipient and amount.
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: permitFrom.permitted.amount
            }),
            // The owner of the tokens, which must also be the signer of the message, otherwise this call will fail.
            msg.sender,
            // The packed signature that was the result of signing the EIP712 hash of `permit`.
            signature
        );

        emit Deposit(
            msg.sender,
            permitFrom.permitted.token,
            permitFrom.permitted.amount
        );
    }

    function depositWithSignatureTransferWithWitness() external {}

    function depositBatchWithSignatureTransferWithoutWitness() external {}

    function depositBatchWithSignatureTransferWithWitness() external {}

    function withdraw() external {}

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
