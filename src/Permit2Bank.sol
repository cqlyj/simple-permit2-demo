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

    /// @dev A string that defines the typed data that the witness was hashed from. It must also include the TokenPermissions struct and comply with EIP-712 struct ordering.
    /// @notice Structs are alphabetical!
    /// @notice When hashing multiple typed structs, the ordering of the structs in the type string matters. Referencing EIP-721:
    /// @notice If the struct type references other struct types (and these in turn reference even more struct types),
    /// @notice then the set of referenced struct types is collected,
    /// @notice sorted by name and appended to the encoding.
    /// @notice An example encoding is Transaction(Person from,Person to,Asset tx)Asset(address token,uint256 amount)Person(address wallet,string name)
    /// @dev The full type string with witness:
    /// @dev "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Witness witness)TokenPermissions(address token,uint256 amount)Witness(address user)"
    /// @dev However, we only want to REMAINING EIP-712 structured type definition,
    /// @dev starting exactly with the witness.
    /// @dev The ""PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline," comes from `PermitHash` library:
    /// @dev string public constant _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
    /// @dev    "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    string private constant WITNESS_TYPE_STRING =
        "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address user)";

    // The type hash must hash our created witness struct.
    bytes32 constant WITNESS_TYPEHASH = keccak256("Witness(address user)");

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Witness {
        address user;
    }

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
    event DepositBatch(
        address indexed user,
        ISignatureTransfer.SignatureTransferDetails[] details
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

    ///
    /// @param permitFrom The permit message signed for a single token transfer
    /// @param user The extra witness data
    /// @param signature The off-chain signature for the permit message
    /// @notice Custom data called the "witness" can be added to signatures.
    /// @notice This is useful when using relayers or specifying custom order details
    /// @notice Extremely useful to add validation to the rest of the interaction when employing the relayer approach.
    /// @dev The witness data requires the creation of a custom witness struct, along with the associated type string and type hash.
    function depositWithSignatureTransferWithWitness(
        ISignatureTransfer.PermitTransferFrom calldata permitFrom,
        address user,
        bytes calldata signature
    ) external {
        s_userToTokenAmount[msg.sender][
            permitFrom.permitted.token
        ] += permitFrom.permitted.amount;

        bytes32 witness = keccak256(
            abi.encode(WITNESS_TYPEHASH, Witness(user))
        );

        i_permit2.permitWitnessTransferFrom(
            permitFrom,
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: permitFrom.permitted.amount
            }),
            msg.sender, // The owner of the tokens has to be the signer
            witness, // Witness - Extra data to include when checking the user signature
            WITNESS_TYPE_STRING, // EIP-712 type definition for REMAINING string stub of the typehash
            signature // The resulting signature from signing hash of permit data per EIP-712 standards
        );

        emit Deposit(
            msg.sender,
            permitFrom.permitted.token,
            permitFrom.permitted.amount
        );
    }

    ///
    /// @param permitBatchFrom The permit message signed for multiple token transfers
    /// @param signature The off-chain signature for the permit message
    /// @notice Most of the logic is the same as depositWithSignatureTransferWithoutWitness() but with multiple token transfers.
    function depositBatchWithSignatureTransferWithoutWitness(
        ISignatureTransfer.PermitBatchTransferFrom calldata permitBatchFrom,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external {
        for (uint256 i = 0; i < transferDetails.length; i++) {
            s_userToTokenAmount[msg.sender][
                permitBatchFrom.permitted[i].token
            ] += permitBatchFrom.permitted[i].amount;
        }

        i_permit2.permitTransferFrom(
            permitBatchFrom,
            transferDetails,
            msg.sender,
            signature
        );

        emit DepositBatch(msg.sender, transferDetails);
    }

    function depositBatchWithSignatureTransferWithWitness() external {}

    function withdraw() external {}

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
