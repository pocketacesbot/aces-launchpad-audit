// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {AcesToken} from "../src/AcesToken.sol";
import {AcesLaunchpadToken} from "../src/AcesLaunchpadToken.sol";
import {AcesFactory} from "../src/AcesFactory.sol";

contract FactoryTest is Test {
    AcesFactory public factory;
    AcesToken public acesToken;

    bytes internal creation;
    bytes internal args;

    uint256 constant MASK_12_BITS = 0x0FFF;
    uint256 constant WANTED = 0x0ACE;

    address bob = address(0x1);
    address alice = address(0x2);
    address charlie = address(0x3);
    address protocolFeeDestination = address(0xdead);

    /*
    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        factory = new AcesFactory();
        acesToken = new AcesToken("Aces Token", "ACES");
        factory.setAcesTokenAddress(address(acesToken));
        factory.setProtocolFeeDestination(protocolFeeDestination);

        acesToken.transfer(alice, 100_000 ether);
        // acesToken.transfer(bob, 10_000 ether);
        // acesToken.transfer(charlie, 10_000 ether);

    }
    */

    /*
    function Create2Address() public view {
        bytes32 salt;
        address predicted;

        uint256 iters;
        uint256 MAX_ITERS = 5_000_000; // safety cap; expected ~65k on average for 16-bit suffix

        for (;;) {
            salt = bytes32(iters); // simple salt scheme; customize if you like
            predicted = factory.predictFromBytecode(creation, args, salt);


            // Check last 2 bytes of the address == 0xACE5 (case-insensitive in hex)
            if ((uint16(uint160(predicted)) == 0xACE5)) {
                break;
            }

            // Check last 3 hex chars (12 bits)
            if ((uint160(predicted) & MASK_12_BITS) == WANTED) {
                break;
            }


            unchecked {
                ++iters;
                if (iters > MAX_ITERS) revert("ACE5 not found within cap");
            }
        }

        console2.log("Iterations to find suffix:", iters);
        console2.logBytes32(salt);
        console2.log("Predicted:", predicted);
    }
    */

}
