// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import {AcesToken} from "../src/AcesToken.sol";
import "forge-std/Script.sol";

contract SendAcesToken is Script {
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
        address tokenAddress = vm.envAddress(tokenEnv);
        console.log("Token Address:", tokenAddress);

        AcesToken token = AcesToken(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        token.transfer(0x4CF99cD1aed51c3B662427fe7693aB9D94daA2E7, 100_000_000 ether);

        vm.stopBroadcast();


    }
}
