// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Permit2Bank} from "src/Permit2Bank.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";

contract Deposit is Script {
    // @notice update to your owner burner wallet address
    address constant DEFAULT_ANVIL_WALLET =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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

    function depositWithSignatureTransferWithoutWitness(
        address permit2Bank,
        ERC20Mock erc20
    ) public {
        ISignatureTransfer.PermitTransferFrom
            memory permitTransferFrom = _generatePermitTransferFrom(
                address(erc20),
                1e18,
                0,
                type(uint256).max
            );

        bytes32 digest = Permit2Bank(permit2Bank).getPermitTransferFromHash(
            permitTransferFrom,
            permit2Bank
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_WALLET, digest);
        // NOTE: It's not v, r, s, but r, s, v
        bytes memory signature = abi.encodePacked(r, s, v);

        Permit2Bank(permit2Bank).depositWithSignatureTransferWithoutWitness(
            permitTransferFrom,
            signature
        );

        console.log("Deposited ERC20 tokens to Permit2Bank!!!");
    }

    function run() external {
        address permit2Bank = Vm(address(vm)).getDeployment(
            "Permit2Bank",
            uint64(block.chainid)
        );

        console.log(
            "The most recently deployed Permit2Bank contract is at address: %s",
            permit2Bank
        );

        vm.startBroadcast();

        console.log("Deploying ERC20Mock contract...");
        ERC20Mock erc20 = new ERC20Mock();
        console.log(
            "Deployed ERC20Mock contract at address: %s",
            address(erc20)
        );

        console.log("Minting ERC20 tokens...");
        erc20.mint(DEFAULT_ANVIL_WALLET, 1e18);
        console.log("ERC20 tokens minted to address: %s", msg.sender, "1e18");

        console.log("Approving Permit2 contract to transfer ERC20 tokens...");
        erc20.approve(
            address(Permit2Bank(permit2Bank).getPermit2()),
            type(uint256).max
        );

        console.log(
            "This script will deposit ERC20 tokens to Permit2Bank contract with the Signature Transfer method without a witness."
        );
        console.log(
            "You can change the way the deposit is made by modifying script under script/Deposit.s.sol"
        );
        depositWithSignatureTransferWithoutWitness(permit2Bank, erc20);

        vm.stopBroadcast();
    }
}
