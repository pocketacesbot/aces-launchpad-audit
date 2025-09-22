// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import { AcesLaunchpadToken } from "../src/AcesLaunchpadToken.sol";

contract DeployToken is Script {
    function run() public {
        string memory network = vm.envString("NETWORK");
        console2.log("Deploying to network:", network);

        string memory privateKeyEnv = string(abi.encodePacked("PRIVATE_KEY_", network));
        uint256 deployerPrivateKey = vm.envUint(privateKeyEnv);
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        console2.log("Deployer Public Key:", deployerPublicKey);

        vm.startBroadcast(deployerPrivateKey);

        AcesLaunchpadToken token = new AcesLaunchpadToken();

        vm.stopBroadcast();

        console2.log("Token Address:", address(token));

    }
}
