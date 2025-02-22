// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Permit2Clone} from "src/Permit2Clone.sol";

contract DeployPermit2 is Script {
    function run() external returns (Permit2Clone) {
        vm.startBroadcast();
        Permit2Clone permit2 = new Permit2Clone();
        vm.stopBroadcast();
        console.log("Deployed Permit2 at:", address(permit2));
        return permit2;
    }
}
