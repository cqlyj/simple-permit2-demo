// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployPermit2} from "script/DeployPermit2.s.sol";
import {DeployPermit2Bank} from "script/DeployPermit2Bank.s.sol";
import {Permit2Clone} from "src/Permit2Clone.sol";
import {Permit2Bank} from "src/Permit2Bank.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IAllowanceTransfer, ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";

contract Permit2BankTest is Test {
    DeployPermit2 deployPermit2;
    DeployPermit2Bank deployPermit2Bank;
    Permit2Clone permit2;
    Permit2Bank permit2Bank;
    ERC20Mock token1 = new ERC20Mock();
    ERC20Mock token2 = new ERC20Mock();
    address user;
    uint256 userPrivateKey;

    function setUp() external {
        deployPermit2 = new DeployPermit2();
        deployPermit2Bank = new DeployPermit2Bank();
        permit2 = deployPermit2.run();
        permit2Bank = deployPermit2Bank.deployPermit2Bank(address(permit2));
        (user, userPrivateKey) = makeAddrAndKey("user");
        token1.mint(user, 1000);
        token2.mint(user, 1000);
        // Set up unlimited token approvals from the user onto the permit2 contract.
        vm.startPrank(user);
        token1.approve(address(permit2), type(uint256).max);
        token2.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function testDepositWithAllowanceTransferPermitRequiredWorks() external {
        IAllowanceTransfer.PermitSingle
            memory permitSingle = _generatePermitSingle(
                address(token1),
                1000,
                type(uint48).max,
                0,
                type(uint256).max
            );

        vm.startPrank(user);
        bytes memory signature = _signPermit(permitSingle, userPrivateKey);
        permit2Bank.depositWithAllowanceTransferPermitRequired(
            permitSingle,
            500,
            signature
        );
        vm.stopPrank();

        assertEq(token1.balanceOf(address(permit2Bank)), 500);
        assertEq(token1.balanceOf(user), 500);
    }

    function testDepositWithAllowanceTransferPermitNotRequiredWorks() external {
        // 1. No permit called yet
        vm.expectRevert();
        permit2Bank.depositWithAllowanceTransferPermitNotRequired(
            address(token1),
            1000
        );

        // 2. Call the permit first before directly depositing

        IAllowanceTransfer.PermitSingle
            memory permitSingle = _generatePermitSingle(
                address(token1),
                1000,
                type(uint48).max,
                0,
                type(uint256).max
            );

        vm.startPrank(user);
        bytes memory signature = _signPermit(permitSingle, userPrivateKey);
        permit2Bank.depositWithAllowanceTransferPermitRequired(
            permitSingle,
            500,
            signature
        );

        // now we can directly deposit since we still have 500 allowance left

        permit2Bank.depositWithAllowanceTransferPermitNotRequired(
            address(token1),
            500
        );
        vm.stopPrank();

        assertEq(token1.balanceOf(address(permit2Bank)), 1000);
        assertEq(token1.balanceOf(user), 0);
    }

    function testDepositBatchWithAllowanceTransferPermitRequiredWorks()
        external
    {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        uint160[] memory amounts = new uint160[](2);
        amounts[0] = 1000;
        amounts[1] = 1000;

        IAllowanceTransfer.PermitBatch
            memory permitBatch = _generatePermitBatch(
                tokens,
                amounts,
                type(uint48).max,
                0,
                type(uint256).max
            );

        IAllowanceTransfer.AllowanceTransferDetails[]
            memory allowanceTransferDetails = _generateAllowanceTransferDetails(
                user,
                address(permit2Bank),
                amounts,
                tokens
            );

        vm.startPrank(user);
        bytes memory signature = _signPermit(permitBatch, userPrivateKey);
        permit2Bank.depositBatchWithAllowanceTransferPermitRequired(
            permitBatch,
            allowanceTransferDetails,
            signature
        );
        vm.stopPrank();

        assertEq(token1.balanceOf(address(permit2Bank)), 1000);
        assertEq(token2.balanceOf(address(permit2Bank)), 1000);
        assertEq(token1.balanceOf(user), 0);
        assertEq(token2.balanceOf(user), 0);
    }

    function testDepositBatchWithAllowanceTransferPermitNotRequiredWorks()
        external
    {
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        uint160[] memory amounts = new uint160[](2);
        amounts[0] = 1000;
        amounts[1] = 1000;

        uint160[] memory firstDepositAmounts = new uint160[](2);
        firstDepositAmounts[0] = 500;
        firstDepositAmounts[1] = 500;

        IAllowanceTransfer.PermitBatch
            memory permitBatch = _generatePermitBatch(
                tokens,
                amounts,
                type(uint48).max,
                0,
                type(uint256).max
            );

        IAllowanceTransfer.AllowanceTransferDetails[]
            memory allowanceTransferDetails = _generateAllowanceTransferDetails(
                user,
                address(permit2Bank),
                firstDepositAmounts,
                tokens
            );

        vm.startPrank(user);
        bytes memory signature = _signPermit(permitBatch, userPrivateKey);
        permit2Bank.depositBatchWithAllowanceTransferPermitRequired(
            permitBatch,
            allowanceTransferDetails,
            signature
        );
        vm.stopPrank();

        assertEq(token1.balanceOf(address(permit2Bank)), 500);
        assertEq(token2.balanceOf(address(permit2Bank)), 500);
        assertEq(token1.balanceOf(user), 500);
        assertEq(token2.balanceOf(user), 500);

        // now we can directly deposit since we still have 500 allowance left

        uint160[] memory secondDepositAmounts = new uint160[](2);
        secondDepositAmounts[0] = 300;
        secondDepositAmounts[1] = 300;

        IAllowanceTransfer.AllowanceTransferDetails[]
            memory newAllowanceTransferDetails = _generateAllowanceTransferDetails(
                user,
                address(permit2Bank),
                secondDepositAmounts,
                tokens
            );

        vm.prank(user);
        permit2Bank.depositBatchWithAllowanceTransferPermitNotRequired(
            newAllowanceTransferDetails
        );

        assertEq(token1.balanceOf(address(permit2Bank)), 800);
        assertEq(token2.balanceOf(address(permit2Bank)), 800);
        assertEq(token1.balanceOf(user), 200);
        assertEq(token2.balanceOf(user), 200);
    }

    function testDepositWithSignatureTransferWithoutWitnessWorks() external {
        ISignatureTransfer.PermitTransferFrom
            memory permitTransferFrom = _generatePermitTransferFrom(
                address(token1),
                1000,
                0,
                type(uint256).max
            );

        bytes memory signature = _signPermit(
            permitTransferFrom,
            userPrivateKey
        );
        vm.prank(user);
        permit2Bank.depositWithSignatureTransferWithoutWitness(
            permitTransferFrom,
            signature
        );

        assertEq(token1.balanceOf(address(permit2Bank)), 1000);
        assertEq(token1.balanceOf(user), 0);
    }

    function testDepositWithSignatureTransferWithWitnessWorks() external {
        ISignatureTransfer.PermitTransferFrom
            memory permitTransferFrom = _generatePermitTransferFrom(
                address(token1),
                1000,
                0,
                type(uint256).max
            );

        bytes memory signature = _signPermit(
            permitTransferFrom,
            userPrivateKey,
            user
        );

        vm.prank(user);
        permit2Bank.depositWithSignatureTransferWithWitness(
            permitTransferFrom,
            user,
            signature
        );

        assertEq(token1.balanceOf(address(permit2Bank)), 1000);
        assertEq(token1.balanceOf(user), 0);
    }

    function testDepositBatchWithSignatureTransferWithoutWitnessWorks()
        external
    {
        ISignatureTransfer.TokenPermissions[]
            memory permitted = new ISignatureTransfer.TokenPermissions[](2);
        permitted[0] = ISignatureTransfer.TokenPermissions({
            token: address(token1),
            amount: 1000
        });
        permitted[1] = ISignatureTransfer.TokenPermissions({
            token: address(token2),
            amount: 1000
        });

        ISignatureTransfer.PermitBatchTransferFrom
            memory permitBatchTransferFrom = _generatePermitBatchTransferFrom(
                permitted,
                0,
                type(uint256).max
            );

        address[] memory to = new address[](2);
        to[0] = address(permit2Bank);
        to[1] = address(permit2Bank);
        uint256[] memory requestedAmount = new uint256[](2);
        requestedAmount[0] = 500;
        requestedAmount[1] = 500;

        ISignatureTransfer.SignatureTransferDetails[]
            memory signatureTransferDetails = _generateSignatureTransferDetails(
                to,
                requestedAmount
            );

        bytes memory signature = _signPermit(
            permitBatchTransferFrom,
            userPrivateKey
        );

        vm.prank(user);
        permit2Bank.depositBatchWithSignatureTransferWithoutWitness(
            permitBatchTransferFrom,
            signatureTransferDetails,
            signature
        );

        assertEq(token1.balanceOf(address(permit2Bank)), 500);
        assertEq(token2.balanceOf(address(permit2Bank)), 500);
        assertEq(token1.balanceOf(user), 500);
        assertEq(token2.balanceOf(user), 500);
    }

    function testDepositBatchWithSignatureTransferWithWitnessWorks() external {}

    function testWithdrawWorks() external {}

    function testWithdrawBatchWorks() external {}

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _generatePermitSingle(
        address token,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        uint256 sigDeadline
    ) internal view returns (IAllowanceTransfer.PermitSingle memory) {
        return
            IAllowanceTransfer.PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: token,
                    amount: amount,
                    expiration: expiration,
                    nonce: nonce
                }),
                spender: address(permit2Bank),
                sigDeadline: sigDeadline
            });
    }

    function _generatePermitBatch(
        address[] memory tokens,
        uint160[] memory amounts,
        uint48 expiration,
        uint48 nonce,
        uint256 sigDeadline
    ) internal view returns (IAllowanceTransfer.PermitBatch memory) {
        IAllowanceTransfer.PermitDetails[]
            memory details = new IAllowanceTransfer.PermitDetails[](
                tokens.length
            );
        for (uint256 i = 0; i < tokens.length; i++) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: amounts[i],
                expiration: expiration,
                nonce: nonce
            });
        }
        return
            IAllowanceTransfer.PermitBatch({
                details: details,
                spender: address(permit2Bank),
                sigDeadline: sigDeadline
            });
    }

    function _generateAllowanceTransferDetails(
        address from,
        address to,
        uint160[] memory amounts,
        address[] memory tokens
    )
        internal
        pure
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory)
    {
        IAllowanceTransfer.AllowanceTransferDetails[]
            memory allowanceTransferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](
                amounts.length
            );
        for (uint256 i = 0; i < amounts.length; i++) {
            allowanceTransferDetails[i] = IAllowanceTransfer
                .AllowanceTransferDetails({
                    from: from,
                    to: to,
                    amount: amounts[i],
                    token: tokens[i]
                });
        }
        return allowanceTransferDetails;
    }

    function _generatePermitTransferFrom(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline // deadline for signature
    ) internal pure returns (ISignatureTransfer.PermitTransferFrom memory) {
        return
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: token,
                    amount: amount
                }),
                nonce: nonce,
                deadline: deadline
            });
    }

    function _generatePermitBatchTransferFrom(
        ISignatureTransfer.TokenPermissions[] memory permitted,
        uint256 nonce,
        uint256 deadline // deadline for signature
    )
        internal
        pure
        returns (ISignatureTransfer.PermitBatchTransferFrom memory)
    {
        return
            ISignatureTransfer.PermitBatchTransferFrom({
                permitted: permitted,
                nonce: nonce,
                deadline: deadline
            });
    }

    function _generateSignatureTransferDetails(
        address[] memory to,
        uint256[] memory requestedAmount
    )
        internal
        pure
        returns (ISignatureTransfer.SignatureTransferDetails[] memory)
    {
        ISignatureTransfer.SignatureTransferDetails[]
            memory signatureTransferDetails = new ISignatureTransfer.SignatureTransferDetails[](
                to.length
            );
        for (uint256 i = 0; i < to.length; i++) {
            signatureTransferDetails[i] = ISignatureTransfer
                .SignatureTransferDetails({
                    to: to[i],
                    requestedAmount: requestedAmount[i]
                });
        }
        return signatureTransferDetails;
    }

    function _signPermit(
        IAllowanceTransfer.PermitSingle memory permitSingle,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = permit2Bank.getPermitSingleHash(permitSingle);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(
        IAllowanceTransfer.PermitBatch memory permitBatch,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = permit2Bank.getPermitBatchHash(permitBatch);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(
        ISignatureTransfer.PermitTransferFrom memory permitTransferFrom,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = permit2Bank.getPermitTransferFromHash(
            permitTransferFrom,
            address(permit2Bank)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(
        ISignatureTransfer.PermitTransferFrom memory permitTransferFrom,
        uint256 privateKey,
        address witnessParam
    ) internal view returns (bytes memory) {
        bytes32 digest = permit2Bank.getPermitWitnessTransferFromHash(
            permitTransferFrom,
            address(permit2Bank),
            witnessParam
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(
        ISignatureTransfer.PermitBatchTransferFrom
            memory permitBatchTransferFrom,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = permit2Bank.getPermitBatchTransferFromHash(
            permitBatchTransferFrom,
            address(permit2Bank)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        return abi.encodePacked(r, s, v);
    }
}
