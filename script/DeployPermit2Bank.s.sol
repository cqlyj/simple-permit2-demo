// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Permit2Bank} from "src/Permit2Bank.sol";

// import {Vm} from "forge-std/Vm.sol";

contract DeployPermit2Bank is Script {
    // @Notice you need to manually set the permit2Clone address from the script output
    address public constant PERMIT2_ADDRESS =
        0x5FbDB2315678afecb367f032d93F642f64180aa3;

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
        // permit2Clone = Vm(address(vm)).getDeployment(
        //     "Permit2Clone",
        //     uint64(block.chainid)
        // );

        Permit2Bank permit2Bank = deployPermit2Bank(PERMIT2_ADDRESS);
        return permit2Bank;
    }
}
