// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import "forge-std/Script.sol";

contract DeployFactory is Script {
    function run() public {
        string memory network = vm.envString("NETWORK");
        console2.log("Deploying to network:", network);

        string memory privateKeyEnv = string(abi.encodePacked("PRIVATE_KEY_", network));
        uint256 deployerPrivateKey = vm.envUint(privateKeyEnv);

        vm.startBroadcast(deployerPrivateKey);

        AcesFactory implementation = new AcesFactory();

        vm.stopBroadcast();

        console.log("Factory Address:", address(implementation));
    }
}