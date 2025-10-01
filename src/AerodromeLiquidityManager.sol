// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IAerodromeRouterMinimal {
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

/**
 * @title AerodromeLiquidityManager
 * @dev External contract responsible for quoting and adding liquidity to Aerodrome pools.
 * Designed to be called by AcesFactory (or an owner/controller) to separate concerns and
 * reduce stack depth in the factory.
 */
contract AerodromeLiquidityManager is Ownable {
    address public router;
    uint256 public constant MAX_BPS = 10_000;

    event RouterUpdated(address indexed newRouter);
    event LiquidityAdded(
        address indexed caller,
        address indexed tokenA,
        address indexed tokenB,
        bool stable,
        uint amountAUsed,
        uint amountBUsed,
        uint liquidity,
        address to
    );

    constructor(address _router, address _owner) Ownable(_owner) {
        require(_router != address(0), "router=0");
        router = _router;
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "router=0");
        router = _router;
        emit RouterUpdated(_router);
    }

    /**
     * @notice Adds liquidity to an Aerodrome pool using provided token amounts with a simple slippage tolerance.
     * @param tokenA First token address.
     * @param tokenB Second token address.
     * @param stable Whether to use a stable pool.
     * @param amountADesired Desired amount of tokenA.
     * @param amountBDesired Desired amount of tokenB.
     * @param slippageBps Max slippage in basis points (e.g. 50 = 0.5%).
     * @param to Recipient of LP tokens.
     * @return amountAUsed Actual amount of tokenA provided.
     * @return amountBUsed Actual amount of tokenB provided.
     * @return liquidity LP tokens minted.
     */
    function addLiquidityWithQuote(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint256 slippageBps,
        address to
    ) external returns (uint amountAUsed, uint amountBUsed, uint liquidity) {
        (amountAUsed, amountBUsed, liquidity) = _addLiquidityWithQuote(
            Params({
                tokenA: tokenA,
                tokenB: tokenB,
                stable: stable,
                amountADesired: amountADesired,
                amountBDesired: amountBDesired,
                slippageBps: slippageBps,
                to: to
            })
        );
    }

    struct Params {
        address tokenA;
        address tokenB;
        bool stable;
        uint amountADesired;
        uint amountBDesired;
        uint256 slippageBps;
        address to;
    }

    struct Local { uint qa; uint qb; uint minA; uint minB; }

    function _addLiquidityWithQuote(Params memory p) internal returns (uint amountAUsed, uint amountBUsed, uint liquidity) {
        require(p.slippageBps <= 500, "slippage too high"); // cap at 5%
        require(p.tokenA != address(0) && p.tokenB != address(0), "token=0");
        require(p.to != address(0), "to=0");

        IAerodromeRouterMinimal r = IAerodromeRouterMinimal(router);

        // Pull tokens from caller
        require(IERC20Minimal(p.tokenA).transferFrom(msg.sender, address(this), p.amountADesired), "pullA");
        require(IERC20Minimal(p.tokenB).transferFrom(msg.sender, address(this), p.amountBDesired), "pullB");

        Local memory l;
        (l.qa, l.qb, ) = r.quoteAddLiquidity(p.tokenA, p.tokenB, p.stable, p.amountADesired, p.amountBDesired);
        l.minA = l.qa - (l.qa * p.slippageBps / MAX_BPS);
        l.minB = l.qb - (l.qb * p.slippageBps / MAX_BPS);

        // Approve router
        require(IERC20Minimal(p.tokenA).approve(router, p.amountADesired), "approveA");
        require(IERC20Minimal(p.tokenB).approve(router, p.amountBDesired), "approveB");

        (amountAUsed, amountBUsed, liquidity) = r.addLiquidity(
            p.tokenA,
            p.tokenB,
            p.stable,
            p.amountADesired,
            p.amountBDesired,
            l.minA,
            l.minB,
            p.to,
            block.timestamp + 15 minutes
        );

        emit LiquidityAdded(msg.sender, p.tokenA, p.tokenB, p.stable, amountAUsed, amountBUsed, liquidity, p.to);
    }
}
