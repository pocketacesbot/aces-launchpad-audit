// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import "forge-std/Script.sol";

contract SetTokenAddress is Script {
    function run() public {
        string memory network = vm.envString("NETWORK");
        console2.log("Deploying to network:", network);

        string memory privateKeyEnv = string(abi.encodePacked("PRIVATE_KEY_", network));
        uint256 deployerPrivateKey = vm.envUint(privateKeyEnv);
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        console.log("Deployer Public Key:", deployerPublicKey);

        string memory _implementationEnv = string(abi.encodePacked("PROXY_ADDRESS_", network));
        address _implementation = vm.envAddress(_implementationEnv);
        console.log("Proxy address:", _implementation);

        string memory tokenEnv = string(abi.encodePacked("ACES_TOKEN_ADDRESS_", network));
        address token = vm.envAddress(tokenEnv);
        console.log("Token Address:", token);

        AcesFactory implementation = AcesFactory(
            _implementation
        );

        vm.startBroadcast(deployerPrivateKey);

        implementation.setAcesTokenAddress(address(token));

        vm.stopBroadcast();

        console.log("Proxy Address:", address(implementation));

    }
}
