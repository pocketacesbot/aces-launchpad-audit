// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AcesFactory} from "../src/AcesFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Script.sol";

contract DeployProxy is Script {
    function run() public {
        string memory network = vm.envString("NETWORK");
        console2.log("Deploying to network:", network);

        string memory privateKeyEnv = string(abi.encodePacked("PRIVATE_KEY_", network));
        uint256 deployerPrivateKey = vm.envUint(privateKeyEnv);
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        console.log("Deployer Public Key:", deployerPublicKey);

        string memory _implementationEnv = string(abi.encodePacked("FACTORY_ADDRESS_", network));
        address _implementation = vm.envAddress(_implementationEnv);
        console.log("Contract address:", _implementation);

        vm.startBroadcast(deployerPrivateKey);

        bytes memory data = abi.encodeCall(AcesFactory.initialize, (deployerPublicKey));
        ERC1967Proxy proxy = new ERC1967Proxy(_implementation, data);

        vm.stopBroadcast();

        console.log("UUPS Proxy Address:", address(proxy));

    }
}
