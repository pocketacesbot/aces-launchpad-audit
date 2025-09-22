// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import {AcesToken} from "../src/AcesToken.sol";
import "forge-std/Script.sol";

contract CreateToken is Script {
    function run() public {
        uint256 CURVE_STEEPNESS = 100_000_000;

        string memory network = vm.envString("NETWORK");
        console2.log("Deploying to network:", network);

        string memory privateKeyEnv = string(abi.encodePacked("PRIVATE_KEY_", network));
        uint256 deployerPrivateKey = vm.envUint(privateKeyEnv);
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        console.log("Deployer Public Key:", deployerPublicKey);

        string memory _implementationEnv = string(abi.encodePacked("PROXY_ADDRESS_", network));
        address proxy = vm.envAddress(_implementationEnv);
        console.log("Proxy address:", proxy);

        string memory tokenEnv = string(abi.encodePacked("ACES_TOKEN_ADDRESS_", network));
        address tokenAddress = vm.envAddress(tokenEnv);
        console.log("Token Address:", tokenAddress);

        AcesToken token = AcesToken(tokenAddress);

        AcesFactory factory = AcesFactory(proxy);

        vm.startBroadcast(deployerPrivateKey);

        uint256 balance = token.balanceOf(deployerPublicKey);
        console.log("Deployer ACES Balance:", balance / 1 ether);

        address launchpadTokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token2", "ACLP2", "my-salt", 80_000 ether);
        
        vm.stopBroadcast();

        console2.log("Factory Launchedpad Token Address:", launchpadTokenAddress);

    }
}
