// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import {AcesToken} from "./AcesToken.sol";
import {AcesLaunchpadToken} from "./AcesLaunchpadToken.sol";

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IAerodromeLiquidityManager {
    function addLiquidityWithQuote(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint256 slippageBps,
        address to
    ) external returns (uint amountAUsed, uint amountBUsed, uint liquidity);
}

/**
 * @title Aces Vault
 * @dev A contract for creating and managing tokens for trading keys with various curves.
 */
contract AcesFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using Math for uint256;

    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 ether;

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    address public tokenImplementation;
    address public acesTokenAddress;
    uint256 public lpAmount;
    address public liquidityManager; // external manager (preferred)

    enum Curves {
        Quadratic,
        Linear
    }

    struct Token {
        Curves curve;
        address tokenAddress;
        uint256 floor;
        uint256 steepness;
        uint256 acesTokenBalance;
        address subjectFeeDestination;
        uint256 tokensBondedAt;
        bool tokenBonded;
    }

    mapping(address tokenAddress => Token token) public tokens;
    mapping(address => mapping(address => bool)) private sellApprovals;

    event BondedToken(address tokenAddress, uint256 totalSupply);

    event CreatedToken(
        address tokenAddress,
        uint8 curve,
        uint256 steepness,
        uint256 floor
    );

    event Trade(
        address tokenAddress,
        bool isBuy,
        uint256 tokenAmount,
        uint256 acesAmount,
        uint256 protocolAcesAmount,
        uint256 subjectAcesAmount,
        uint256 supply
    );

    event FeeDestinationChanged(address newDestination);
    event ProtocolFeePercentChanged(uint256 newPercent);
    event SubjectFeePercentChanged(uint256 newPercent);

    event SellApprovalChanged(
        address indexed seller,
        address indexed operator,
        bool approved
    );

    uint256[50] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract.
     * @param initialOwner The address to be set as the initial owner.
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        // Set default values for protocol and subject fees
        protocolFeePercent = 500000000000000; // 0.5%
        subjectFeePercent = 500000000000000; // 0.5%
        lpAmount = 200_000_000 ether; // 200 million tokens
    }

    /**
     * @dev Checks whether the upgrade is authorized.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Sets the address of the Aces token.
     * @param _acesTokenAddress The address of the Aces token contract.
     */
    function setAcesTokenAddress(address _acesTokenAddress) public onlyOwner {
        require(_acesTokenAddress != address(0), "Invalid address");
        acesTokenAddress = _acesTokenAddress;
    }

    /**
     * @dev Sets the address of the liquidity manager.
     * @param _manager The address of the liquidity manager contract.
     */
    function setLiquidityManager(address _manager) external onlyOwner {
        liquidityManager = _manager;
    }

    /** 
     * @dev Sets the amount of LP tokens to be allocated.
     * @param _lpAmount The amount of LP tokens.
     */
    function setLpAmount(uint256 _lpAmount) public onlyOwner {
        require(_lpAmount <= MAX_TOTAL_SUPPLY, "Invalid lp amount");
        lpAmount = _lpAmount;
    }

    /**
     * @dev Sets the implementation address for the token clones.
     * @param impl The address of the token implementation contract.
     */
    function setTokenImplementation(address impl) external onlyOwner {
        require(impl != address(0), "Invalid impl");
        tokenImplementation = impl;
    }

    /**
     * @dev Creates a new token for trading shares with the specified bonding curve.
     * @param curve The curve type for price calculation.
     * @param steepness The steepness parameter for the curve.
     * @param floor The floor price for the shares.
     * @return token The index of the created token.
     */
    function createToken(
        Curves curve,
        uint256 steepness,
        uint256 floor,
        string memory name,
        string memory symbol,
        string memory salt,
        uint256 tokensBondedAt
    ) public returns (address) {
        require(steepness >= 1, "Invalid steepness value");
        require(steepness <= 10_000_000_000_000_000, "Invalid steepness value");
        require(floor <= 1_000_000_000, "Invalid floor value");
        require(acesTokenAddress != address(0), "Aces token address not set");
        require(tokensBondedAt >= 1 ether, "Invalid tokensBondedAt value");
        require(tokenImplementation != address(0), "Token implementation not set");
        require(tokensBondedAt <= MAX_TOTAL_SUPPLY - lpAmount, "tokensBondedAt exceeds max supply");
        bytes32 saltPacked = keccak256(abi.encodePacked(salt, msg.sender));
        address tokenAddress = Clones.cloneDeterministic(tokenImplementation, saltPacked);
        // initialize clone
        AcesLaunchpadToken(tokenAddress).initialize(name, symbol, msg.sender, tokensBondedAt);

        Token storage r = tokens[tokenAddress];
        r.tokenAddress = tokenAddress;
        r.curve = curve;
        r.steepness = steepness;
        r.floor = floor;
        r.acesTokenBalance = 0;
        r.subjectFeeDestination = msg.sender;
        r.tokenBonded = false;
        r.tokensBondedAt = tokensBondedAt;
        
        emit CreatedToken(
            tokenAddress,
            uint8(curve),
            steepness,
            floor
        );

        return tokenAddress;
    }

    /**
     * @dev Sets the address where protocol fees will be sent.
     * @param feeDestination The address to set as the fee destination.
     */
    function setProtocolFeeDestination(address feeDestination) public onlyOwner {
        require(feeDestination != address(0), "Invalid address");
        protocolFeeDestination = feeDestination;
        emit FeeDestinationChanged(feeDestination);
    }

    /**
     * @dev Sets the percentage of protocol fees.
     * @param feePercent The percentage of protocol fees to set.
     */
    function setProtocolFeePercent(uint256 feePercent) public onlyOwner {
        require(feePercent <= 500000000000000000, "Invalid fee percent"); // max 50%
        protocolFeePercent = feePercent;
        emit ProtocolFeePercentChanged(feePercent);
    }

    /**
     * @dev Sets the percentage of subject fees.
     * @param feePercent The percentage of subject fees to set.
     */
    function setSubjectFeePercent(uint256 feePercent) public onlyOwner {
        require(feePercent <= 500000000000000000, "Invalid fee percent"); // max 50%
        subjectFeePercent = feePercent;
        emit SubjectFeePercentChanged(feePercent);
    }

    /**
     * @dev Withdraws all ETH from the contract to the owner's address.
     */
    function withdrawETH() external onlyOwner {
        (bool success,) = address(owner()).call{value: address(this).balance}("");
        require(success, "Failed to refund Ether!");
    }

    /**
     * @dev Withdraws all ACES from the contract to the owner's address.
     */
    function withdrawACES(address tokenAddress) external onlyOwner {
        require(acesTokenAddress != address(0), "Aces token address not set");
        require(tokenAddress != address(0), "Invalid token address");

        // can only withdraw if token is bonded
        Token storage token = tokens[tokenAddress];
        require(token.tokenBonded, "Token not bonded yet");

        uint256 balance = token.acesTokenBalance;
        require(balance > 0, "No ACES to withdraw");
        token.acesTokenBalance = 0;

        require(IERC20(acesTokenAddress).transfer(owner(), balance), "ACES transfer failed");
    }

    uint256 constant W = 1e18;

    function _sumSquaresWei(uint256 sWei) internal pure returns (uint256) {
        // For token index n = sWei / W
        // Uses staged mulDiv to keep precision and avoid overflow.
        if (sWei == 0) return 0;

        // t1 = s(s+W)/W
        uint256 t1 = Math.mulDiv(sWei, sWei + W, W);          // ~ s^2 / W + ...
        // t2 = t1(2s+W)/W  => s(s+W)(2s+W)/W^2
        uint256 t2 = Math.mulDiv(t1, 2 * sWei + W, W);
        // sumSquares = t2 / (6 * W)
        return Math.mulDiv(t2, 1, 6 * W);
    }

    /**
     * @dev Quadratic pricing:
     *      Uses the difference of square sums to price a batch buy of `amount` tokens
     *      starting from current `supply`. Supply & amount are in 1e18 units; we downscale
     *      to whole tokens for the polynomial, then re-scale with 1e18.
     *      Formula (conceptual): price = (sum_{k=s}^{s+a-1} k^2)/steepness * 1e18 + floor * a
     */
    function getPriceQuadratic(
        uint256 supply,
        uint256 amount,
        uint256 steepness,
        uint256 floor
    ) public pure returns (uint256 price) {
        require(amount >= W, "Amount must be at least 1 token");
        require(supply >= W, "Total supply must be at least 1 token");
        require(amount % W == 0 && supply % W == 0, "Non-integer token units"); // (optional safety)

        // Indices in wei:
        // We want sum_{k = n}^{n + a - 1} k^2 where n = supply/W, a = amount/W
        // Convert range to wei-index endpoints for helper:
        uint256 startWei = supply;                 // corresponds to n
        uint256 endWei = supply + amount - W;      // corresponds to n + a - 1

        // Cumulative sums (using start-1 guard)
        uint256 sumBefore = _sumSquaresWei(startWei - W); // S(n-1)
        uint256 sumAfter  = _sumSquaresWei(endWei);       // S(n+a-1)
        uint256 summation = sumAfter - sumBefore;         // sum k^2 for indices

        // curveComponent = summation * 1e18 / steepness
        uint256 curveComponent = Math.mulDiv(summation, W, steepness);

        // linearComponent = floor * amountTokens; compute with mulDiv to avoid explicit division
        uint256 linearComponent = Math.mulDiv(floor, amount, W);

        return curveComponent + linearComponent;
    }

    /**
     * @dev Calculates the price for a linear curve given the supply, amount, steepness, and floor price.
     * @param supply The current supply of shares.
     * @param amount The amount of shares to buy.
     * @param steepness The steepness parameter for the curve.
     * @param floor The floor price for the shares.
     * @return price The total price for the shares.
     */
    function getPriceLinear(
        uint256 supply,
        uint256 amount,
        uint256 steepness,
        uint256 floor
    ) public pure returns (uint256 price) {
        require(amount >= 1 ether, "Amount must be at least 1 token");
        require(supply >= 1 ether, "Total supply must be at least 1 token");
        require(amount % W == 0 && supply % W == 0, "Non-integer token units");

        supply = supply / 1 ether;
        amount = amount / 1 ether;

        uint256 sum1 = (supply - 1) * supply;
        uint256 sum2 = (supply - 1 + amount) * (supply + amount);
        uint256 summation = sum2 - sum1;
        return (summation * 1 ether) / (steepness / 50) + (floor * amount);
    }

    /**
     * @dev Calculates the price for buying or selling shares based on the specified parameters.
     * @param tokenAddress The address of the token.
     * @param amount The amount of shares to buy or sell.
     * @param isBuy A boolean indicating whether the transaction is a buy or sell.
     * @return price The calculated price for the shares.
     */
    function getPrice(
        address tokenAddress,
        uint256 amount,
        bool isBuy
    ) public view returns (uint256 price) {
        AcesLaunchpadToken launchPadToken = AcesLaunchpadToken(tokenAddress);
        uint256 totalSupply = launchPadToken.totalSupply();
        
        Token storage r = tokens[tokenAddress];
        uint256 supply = isBuy ? totalSupply : totalSupply - amount;
        uint256 floor = r.floor;
        uint256 steepness = r.steepness;

        if (tokens[tokenAddress].curve == Curves.Quadratic) {
            return getPriceQuadratic(supply, amount, steepness, floor);
        } else if (tokens[tokenAddress].curve == Curves.Linear) {
            return getPriceLinear(supply, amount, steepness, floor);
        } 
    }

    /**
     * @dev Calculates the buy price for shares based on the specified parameters.
     * @param tokenAddress The address of the shares subject.
     * @param amount The amount of shares to buy.
     * @return price The calculated buy price for the shares.
     */
    function getBuyPrice(
        address tokenAddress,
        uint256 amount
    ) public view returns (uint256 price) {
        return getPrice(tokenAddress, amount, true);
    }

    /**
     * @dev Calculates the sell price for shares based on the specified parameters.
     * @param tokenAddress The address of the shares subject.
     * @param amount The amount of shares to sell.
     * @return price The calculated sell price for the shares.
     */
    function getSellPrice(
        address tokenAddress,
        uint256 amount
    ) public view returns (uint256 price) {
        return getPrice(tokenAddress, amount, false);
    }

    /**
     * @dev Calculates the buy price for tokens after applying protocol and subject fees.
     * @param tokenAddress The address of the token contract.
     * @param amount The amount of tokens to buy.
     * @return price The calculated buy price for the tokens after fees.
     */
    function getBuyPriceAfterFee(
        address tokenAddress,
        uint256 amount
    ) public view returns (uint256 price) {
        uint256 buyPrice = getBuyPrice(tokenAddress, amount);
        uint256 protocolFee = (buyPrice * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (buyPrice * subjectFeePercent) / 1 ether;
        return buyPrice + protocolFee + subjectFee;
    }

    /**
     * @dev Calculates the sell price for tokens after applying protocol and subject fees.
     * @param tokenAddress The address of the token contract.
     * @param amount The amount of tokens to sell.
     * @return price The calculated sell price for the tokens after fees.
     */
    function getSellPriceAfterFee(
        address tokenAddress,
        uint256 amount
    ) public view returns (uint256 price) {
        uint256 sellPrice = getSellPrice(tokenAddress, amount);
        uint256 protocolFee = (sellPrice * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (sellPrice * subjectFeePercent) / 1 ether;
        return sellPrice - protocolFee - subjectFee;
    }

    /**
     * @dev Allows a user to buy tokens.
     * @param tokenAddress The address of the token to buy.
     * @param amount The amount of tokens to buy.
     */
    function buyTokens(
        address tokenAddress,
        uint256 amount,
        uint256 acesAmountIn
    ) public {
        require(amount > 0, "Invalid amount");
        require(tokenAddress != address(0), "Invalid address");

        uint256 price = getPrice(tokenAddress, amount, true);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;

        AcesLaunchpadToken launchPadToken = AcesLaunchpadToken(tokenAddress);
        uint256 totalSupply = launchPadToken.totalSupply();

        Token storage token = tokens[tokenAddress];
        token.acesTokenBalance += price;

        require(!token.tokenBonded, "Token is bonded, cannot buy more");

        // Transfer Aces tokens from user to contract
        IERC20 acesToken = IERC20(acesTokenAddress);
        require(
            acesToken.transferFrom(msg.sender, address(this), acesAmountIn),
            "Aces token transfer to bonding curve contract failed"
        );

        require(
            acesAmountIn >= price + protocolFee + subjectFee,
            "Did not send enough Aces tokens"
        );

        // Mint launchpad tokens to user        
        launchPadToken.mint(msg.sender, amount);

        emit Trade(
            tokenAddress,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            totalSupply + amount
        );

        if (protocolFee > 0 && protocolFeeDestination != address(0)) {
            require(
                acesToken.transfer(protocolFeeDestination, protocolFee),
                "Aces token transfer to protocol failed"
            );
        }

        if (subjectFee > 0 && token.subjectFeeDestination != address(0)) {
            require(
                acesToken.transfer(token.subjectFeeDestination, subjectFee),
                "Aces token transfer to subject failed"
            );
        }

        // Refund any excess Aces tokens to user
        if (acesAmountIn > price + protocolFee + subjectFee) {
            require(
                acesToken.transfer(
                    msg.sender,
                    acesAmountIn - price - protocolFee - subjectFee
                ),
                "Aces token refund transfer failed"
            );
        }

        if (!token.tokenBonded && totalSupply + amount >= token.tokensBondedAt && totalSupply + amount <= launchPadToken.MAX_TOTAL_SUPPLY()) {
            token.tokenBonded = true;

            // Mint LP allocation to factory to pair with accrued ACES
            launchPadToken.mint(address(this), lpAmount);
            launchPadToken.setTransfersEnabled(true);

            uint256 acesForLiquidity = token.acesTokenBalance; // ACES accumulated in bonding curve

            if (liquidityManager != address(0) && acesForLiquidity > 0) {
                // Approve liquidity manager to pull tokens; use reset to 0 first pattern for safety
                launchPadToken.approve(liquidityManager, lpAmount);
                IERC20(acesTokenAddress).approve(liquidityManager, acesForLiquidity);

                // Add liquidity (revert on failure). Volatile pool assumed (stable = false), 50 bps slippage, LP recipient = owner.
                IAerodromeLiquidityManager(liquidityManager).addLiquidityWithQuote(
                    tokenAddress,
                    acesTokenAddress,
                    false,
                    lpAmount,
                    acesForLiquidity,
                    50,
                    owner()
                );

                token.acesTokenBalance = 0; // all used for liquidity
            }

            launchPadToken.renounceOwnership();
            emit BondedToken(tokenAddress, totalSupply + amount);
        }
    }

    /**
     * @dev Allows a user to sell tokens.
     * @param tokenAddress The address of the token to sell.
     * @param amount The amount of tokens to sell.
     */
    function sellTokens(
        address tokenAddress,
        uint256 amount
    ) public {
        require(amount > 0, "Invalid amount");
        require(tokenAddress != address(0), "Invalid address");

        Token storage token = tokens[tokenAddress];
        require(!token.tokenBonded, "Token is bonded, cannot sell");

        // Transfer Aces tokens from contract to user
        IERC20 acesToken = IERC20(acesTokenAddress);
        AcesLaunchpadToken launchPadToken = AcesLaunchpadToken(tokenAddress);
        
        require(
            launchPadToken.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );

        // token owner cant sell last token. Always needs to have 1 token for bonding curve to work
        if (msg.sender == launchPadToken.owner()) {
            require(
                launchPadToken.balanceOf(msg.sender) - amount > 0,
                "Cannot sell the last token"
            );
        }

        uint256 totalSupply = launchPadToken.totalSupply();

        uint256 price = getPrice(tokenAddress, amount, false);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;

        
        token.acesTokenBalance -= price;

        // Burn tokens from user
        launchPadToken.burnFrom(msg.sender, amount);

        emit Trade(
            tokenAddress,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            totalSupply - amount
        );

        require(
            acesToken.transfer(
                msg.sender,
                price - protocolFee - subjectFee
            ),
            "Aces token transfer failed"
        );

        if (protocolFee > 0 && protocolFeeDestination != address(0)) {
            require(
                acesToken.transfer(protocolFeeDestination, protocolFee),
                "Aces token transfer to protocol failed"
            );
        }

        if (subjectFee > 0 && token.subjectFeeDestination != address(0)) {
            require(
                acesToken.transfer(token.subjectFeeDestination, subjectFee),
                "Aces token transfer to subject failed"
            );
        }
    }
}
