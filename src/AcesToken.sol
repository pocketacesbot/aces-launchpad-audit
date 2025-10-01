// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract AcesToken is ERC20, Ownable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, 800_000_000 ether); // Mint initial supply to the owner
        _mint(0x246ca431fd1353610Bf20F9d4fbD240148522Dc8, 25_000_000 ether);
        _mint(0xFa896e205975c4C77918e789898F766478144a54, 25_000_000 ether);
        _mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 25_000_000 ether); // anvil account 1
    }
}

