// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

contract AcesLaunchpadToken is ERC20, Ownable, Pausable {
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion tokens

    uint256 public tokensBondedAt;
    address public subjectFeeDestination;
    
    // Track if this instance has been initialized (for clone pattern)
    bool private _initialized;
    
    // Per-clone name and symbol overrides
    string private _nameOverride;
    string private _symbolOverride;
    
    /// @dev Implementation constructor - deploy with empty metadata and renounce ownership immediately.
    constructor() ERC20("", "") Ownable(msg.sender) {
        // Mark implementation initialized so it cannot be re-used directly.
        _initialized = true;
        // Pause implementation to prevent accidental transfers.
        _pause();
        // Implementation should not retain an owner; renounce to avoid misuse.
        _transferOwnership(address(0));
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _subjectFeeDestination,
        uint256 _tokensBondedAt
    ) public {
        require(!_initialized, "Already initialized");
        _initialized = true;
        
        // Set clone-specific name and symbol
        _nameOverride = _name;
        _symbolOverride = _symbol;

        tokensBondedAt = _tokensBondedAt;
        subjectFeeDestination = _subjectFeeDestination;

        // Set clone owner (factory or end-user depending on factory logic)
        _transferOwnership(msg.sender);

    // mint initial supply to beneficiary/subject
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

    // Override name and symbol functions to return clone-specific values
    function name() public view override returns (string memory) {
        if (bytes(_nameOverride).length > 0) {
            return _nameOverride;
        }
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        if (bytes(_symbolOverride).length > 0) {
            return _symbolOverride;
        }
        return super.symbol();
    }
}

