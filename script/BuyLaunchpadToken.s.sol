// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import {AcesToken} from "../src/AcesToken.sol";
import {AcesLaunchpadToken} from "../src/AcesLaunchpadToken.sol";
import "forge-std/Script.sol";

contract BuyLaunchpadToken is Script {
    function run() public {
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

        string memory launchpadTokenEnv = string(abi.encodePacked("LAUNCHED_TOKEN_IMPLEMENTATION_", network));
        address launchpadTokenAddress = vm.envAddress(launchpadTokenEnv);
        console.log("Launchpad Token Address:", launchpadTokenAddress);

        AcesToken token = AcesToken(tokenAddress);

        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(launchpadTokenAddress);

        AcesFactory factory = AcesFactory(proxy);

        vm.startBroadcast(deployerPrivateKey);

        uint256 balance = token.balanceOf(deployerPublicKey);
        console.log("Deployer ACES Balance:", balance / 1 ether);

        uint256 launchpadBalance = launchpadToken.balanceOf(deployerPublicKey);
        console.log("Deployer Launchpad Token Balance:", launchpadBalance / 1 ether);

        uint256 amount = 1_000 ether;
        uint256 price = factory.getBuyPriceAfterFee(launchpadTokenAddress, amount);
        console2.log("Cost to buy", amount / 1 ether, "tokens:", price);

        token.approve(address(factory), price);
        factory.buyTokens(launchpadTokenAddress, amount, price);

        balance = token.balanceOf(deployerPublicKey);
        console.log("Deployer ACES Balance After Purchase:", balance / 1 ether);

        launchpadBalance = launchpadToken.balanceOf(deployerPublicKey);
        console.log("Deployer Launchpad Token Balance After Purchase:", launchpadBalance / 1 ether);

        vm.stopBroadcast();

    }
}
