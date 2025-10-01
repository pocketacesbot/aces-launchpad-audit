// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AerodromeLiquidityManager} from "../src/AerodromeLiquidityManager.sol";

interface IERC20Like {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _n, string memory _s) { name = _n; symbol = _s; }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value; return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "bal");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value; return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allow");
        require(balanceOf[from] >= value, "bal");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - value;
        balanceOf[from] -= value; balanceOf[to] += value; return true;
    }
}

contract MockAerodromeRouter {
    // Simple quote returns desired minus 1% to simulate adjustment
    function quoteAddLiquidity(
        address /*tokenA*/,
        address /*tokenB*/,
        bool /*stable*/,
        uint amountADesired,
        uint amountBDesired
    ) external pure returns (uint amountA, uint amountB, uint liquidity) {
        amountA = (amountADesired * 99) / 100; // 1% less
        amountB = (amountBDesired * 99) / 100; // 1% less
        liquidity = (amountA + amountB) / 2; // arbitrary
    }

    function addLiquidity(
        address /*tokenA*/,
        address /*tokenB*/,
        bool /*stable*/,
        uint amountADesired,
        uint amountBDesired,
        uint /*amountAMin*/,
        uint /*amountBMin*/,
        address to,
        uint /*deadline*/
    ) external pure returns (uint amountA, uint amountB, uint liquidity) {
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = (amountA + amountB) / 2;
        require(to != address(0), "to=0");
    }
}

contract AerodromeLiquidityManagerTest is Test {
    AerodromeLiquidityManager manager;
    MockAerodromeRouter router;
    MockERC20 tokenA;
    MockERC20 tokenB;
    address user = address(0xBEEF);

    function setUp() external {
        router = new MockAerodromeRouter();
        manager = new AerodromeLiquidityManager(address(router), address(this));
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");

        // Mint tokens to user
        tokenA.mint(user, 1_000 ether);
        tokenB.mint(user, 2_000 ether);

        // User approves manager
        vm.startPrank(user);
        tokenA.approve(address(manager), type(uint256).max);
        tokenB.approve(address(manager), type(uint256).max);
        vm.stopPrank();
    }

    function test_addLiquidityWithQuote_happyPath() external {
        vm.startPrank(user);
        (uint aUsed, uint bUsed, uint liq) = manager.addLiquidityWithQuote(
            address(tokenA),
            address(tokenB),
            false,
            100 ether,
            150 ether,
            50, // 0.5% slippage
            user
        );
        vm.stopPrank();

        assertEq(aUsed, 100 ether, "amountA used mismatch");
        assertEq(bUsed, 150 ether, "amountB used mismatch");
        assertGt(liq, 0, "liquidity should be > 0");
        // Balances reduced
        assertEq(tokenA.balanceOf(user), 900 ether, "tokenA bal");
        assertEq(tokenB.balanceOf(user), 1_850 ether, "tokenB bal");
    }

    function test_addLiquidityWithQuote_revertHighSlippage() external {
        vm.startPrank(user);
        vm.expectRevert(bytes("slippage too high"));
        manager.addLiquidityWithQuote(
            address(tokenA),
            address(tokenB),
            false,
            100 ether,
            150 ether,
            600, // 6% > cap
            user
        );
        vm.stopPrank();
    }

    function test_addLiquidityWithQuote_revertZeroAddr() external {
        vm.startPrank(user);
        vm.expectRevert(bytes("to=0"));
        manager.addLiquidityWithQuote(
            address(tokenA),
            address(tokenB),
            false,
            10 ether,
            10 ether,
            50,
            address(0)
        );
        vm.stopPrank();
    }
}
