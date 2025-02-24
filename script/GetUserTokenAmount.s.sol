// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Permit2Bank} from "src/Permit2Bank.sol";
import {Vm} from "forge-std/Vm.sol";

contract GetUserTokenAmount is Script {
    address public constant TOKEN_ADDRESS =
        0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant DEFAULT_ANVIL_WALLET =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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
        uint256 userTokenAmount = Permit2Bank(permit2Bank).getUserTokenAmount(
            DEFAULT_ANVIL_WALLET,
            TOKEN_ADDRESS
        );
        vm.stopBroadcast();

        console.log(
            "User %s has %s tokens in Permit2Bank",
            DEFAULT_ANVIL_WALLET,
            userTokenAmount
        );
    }
}
