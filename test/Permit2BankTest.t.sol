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
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(token1),
                    amount: 1000,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(permit2Bank),
                sigDeadline: type(uint256).max
            });

        vm.startPrank(user);

        bytes32 digest = permit2Bank.getPermitSingleHash(permitSingle);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        // NOTE: It's not v, r, s, but r, s, v
        bytes memory signature = abi.encodePacked(r, s, v);

        permit2Bank.depositWithAllowanceTransferPermitRequired(
            permitSingle,
            signature
        );

        vm.stopPrank();

        assertEq(token1.balanceOf(address(permit2Bank)), 1000);
        assertEq(token1.balanceOf(user), 0);
    }
}
