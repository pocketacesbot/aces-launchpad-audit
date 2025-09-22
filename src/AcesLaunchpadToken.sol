// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

contract AcesLaunchpadToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion tokens

    uint256 public tokensBondedAt;
    address public subjectFeeDestination;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _subjectFeeDestination,
        uint256 _tokensBondedAt
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(msg.sender); // factory
        __Pausable_init();

        tokensBondedAt = _tokensBondedAt;
        subjectFeeDestination = _subjectFeeDestination;

        // mint initial supply to user that created the clone
        _mint(_subjectFeeDestination, 1 ether);

        // start paused by default
        _pause();
    }

    function renounceOwnership() public override onlyOwner {
        // Allow renouncing ownership only when transfers are enabled (unpaused)
        require(!paused(), "Cannot renounce ownership while paused");
        _transferOwnership(address(0));
    }

    function setTransfersEnabled(bool _enabled) external onlyOwner {
        if (_enabled) _unpause(); else _pause();
    }

    // Explicitly block transfers when paused by overriding public transfer functions.
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!paused(), "Token transfers are paused");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!paused(), "Token transfers are paused");
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(!paused(), "Token transfers are paused");
        return super.approve(spender, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Cannot mint to the zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(this.totalSupply() + amount <= MAX_TOTAL_SUPPLY, "Total supply exceeded");

        _mint(to, amount);
    }
}

