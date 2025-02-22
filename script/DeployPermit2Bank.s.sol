// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Permit2Bank} from "src/Permit2Bank.sol";

contract DeployPermit2Bank is Script {
    address public permit2Clone;

    function deployPermit2Bank(
        address _permit2Clone
    ) public returns (Permit2Bank) {
        vm.startBroadcast();
        Permit2Bank permit2Bank = new Permit2Bank(_permit2Clone);
        vm.stopBroadcast();

        console.log("Deployed Permit2Bank at:", address(permit2Bank));

        return permit2Bank;
    }

    function run() external returns (Permit2Bank) {
        permit2Clone = Vm(address(vm)).getDeployment(
            "Permit2Clone",
            uint64(block.chainid)
        );

        Permit2Bank permit2Bank = deployPermit2Bank(permit2Clone);
        return permit2Bank;
    }
}
