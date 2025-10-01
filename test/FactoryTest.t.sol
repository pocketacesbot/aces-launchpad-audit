// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {AcesToken} from "../src/AcesToken.sol";
import {AcesLaunchpadToken} from "../src/AcesLaunchpadToken.sol";
import {AcesFactory} from "../src/AcesFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FactoryTest is Test {
    AcesFactory public factory;
    AcesToken public acesToken;
    ERC1967Proxy public proxy;

    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address owner = address(0x4);

    address protocolFeeDestination = address(0xdead);

    uint256 constant CURVE_STEEPNESS = 100_000_000;

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        AcesFactory implementation = new AcesFactory();
        proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(implementation.initialize, owner));
        factory = AcesFactory(address(proxy));

        AcesLaunchpadToken launchpadTokenImpl = new AcesLaunchpadToken();
        
        acesToken = new AcesToken("Aces Token", "ACES");

        vm.startPrank(owner);
        factory.setTokenImplementation(address(launchpadTokenImpl));
        factory.setAcesTokenAddress(address(acesToken));
        factory.setProtocolFeeDestination(protocolFeeDestination);
        vm.stopPrank();

        acesToken.transfer(alice, 100_000 ether);
        acesToken.transfer(bob, 10_000 ether);
        acesToken.transfer(charlie, 10_000 ether);
    }

    function test_BuyTokens() public {
        uint256 amount = 10_000 ether;

        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 10_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);

        vm.startPrank(alice);

        uint256 balance = launchpadToken.balanceOf(address(this));
        assertEq(balance, 1 ether); // initial supply from clone

        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);

        acesToken.approve(address(factory), cost);

        factory.buyTokens(tokenAddress, amount, cost);

        balance = launchpadToken.balanceOf(address(alice));
        console2.log("Alice balance: %s", balance);
        assertEq(balance, amount);

        vm.stopPrank();
    }

    function test_ProtocolFees() public {
        uint256 amount = 10_000 ether;

        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 100_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);

        vm.startPrank(alice);

        uint256 balance = launchpadToken.balanceOf(address(this));
        assertEq(balance, 1 ether); // initial supply from clone

        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);

        balance = launchpadToken.balanceOf(address(alice));
        assertEq(balance, amount);

        vm.stopPrank();

        uint256 protocolBalance = acesToken.balanceOf(protocolFeeDestination);
        assertGt(protocolBalance, 0);
    }

    function test_SellTokens() public {
        uint256 amount = 10_000 ether;

        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 100_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);

        vm.startPrank(alice);

        uint256 acesBalance = acesToken.balanceOf(address(alice));
        assertEq(acesBalance, 100_000 ether);

        uint256 balance = launchpadToken.balanceOf(address(this));
        assertEq(balance, 1 ether); // initial supply from clone

        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);

        acesToken.approve(address(factory), cost);

        factory.buyTokens(tokenAddress, amount, cost);

        balance = launchpadToken.balanceOf(address(alice));
        assertEq(balance, amount);

        acesBalance = acesToken.balanceOf(address(alice));
        assertLt(acesBalance, 100_000 ether - cost + 1 ether); // allow for rounding

        uint256 sellPrice = factory.getSellPriceAfterFee(tokenAddress, amount);

        factory.sellTokens(tokenAddress, amount);

        balance = launchpadToken.balanceOf(address(alice));
        assertEq(balance, 0);

        acesBalance = acesToken.balanceOf(address(alice));
        assertGt(acesBalance, 100_000 ether - cost + sellPrice - 1 ether); // allow for rounding

        vm.stopPrank();

        assertEq(launchpadToken.owner(), address(factory));
    }

    function test_WithdrawAcesNoBuys() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", amount);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();


        // Bob buys 10,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        uint256 costMinusFee = factory.getPrice(tokenAddress, amount, true);

        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, amount);
        vm.stopPrank();

        assertEq(acesToken.balanceOf(address(factory)), costMinusFee);
        assertEq(factory.owner(), address(owner));

        // Owner withdraws aces
        vm.startPrank(owner);
        factory.withdrawACES(tokenAddress);
        vm.stopPrank();

        assertEq(acesToken.balanceOf(address(factory)), 0);
        assertEq(acesToken.balanceOf(address(owner)), costMinusFee);

    }

    function test_WithdrawAcesWithBuysAndSells() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", amount);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        // Bob buys 6,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, 6_000 ether);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, 6_000 ether, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, 6_000 ether);
        vm.stopPrank();

        // Bob sells 5,000 tokens
        vm.startPrank(bob);
        uint256 sellAmount = 5_000 ether;
        factory.sellTokens(tokenAddress, sellAmount);
        balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, 1_000 ether);
        vm.stopPrank();

        // Charlie buys 2,000 tokens
        vm.startPrank(charlie);
        uint256 charlieBuyAmount = 2_000 ether;
        uint256 charlieCost = factory.getBuyPriceAfterFee(tokenAddress, charlieBuyAmount);
        acesToken.approve(address(factory), charlieCost);
        factory.buyTokens(tokenAddress, charlieBuyAmount, charlieCost);
        balance = launchpadToken.balanceOf(address(charlie));
        assertEq(balance, charlieBuyAmount);
        vm.stopPrank();

        // Bob buys 7,000 tokens
        vm.startPrank(bob);
        uint256 bobSecondBuyAmount = 7_000 ether;
        uint256 bobSecondCost = factory.getBuyPriceAfterFee(tokenAddress, bobSecondBuyAmount);
        acesToken.approve(address(factory), bobSecondCost);
        factory.buyTokens(tokenAddress, bobSecondBuyAmount, bobSecondCost);
        balance = launchpadToken.balanceOf(address(bob));
        vm.stopPrank();

        // Owner withdraws aces
        vm.startPrank(owner);
        factory.withdrawACES(tokenAddress);
        vm.stopPrank();

        assertEq(acesToken.balanceOf(address(factory)), 0);
    }

    function test_TestTransferTokens() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 100_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        // Bob buys 10,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        uint256 costMinusFee = factory.getPrice(tokenAddress, amount, true);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, amount);

        // Bob tries to transfer tokens to Charlie - should fail because token is paused
        vm.expectRevert("Token transfers are paused");
        launchpadToken.transfer(charlie, 1 ether);  // Attempt to transfer 1 token

        vm.stopPrank();

        assertEq(launchpadToken.owner(), address(factory));
        assertEq(acesToken.balanceOf(address(factory)), costMinusFee);
        assertEq(factory.owner(), address(owner));
    }

    function test_TestBondingAndBuy() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 10_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        // Bob buys 10,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, amount);
        vm.stopPrank();

        vm.startPrank(charlie);
        cost = factory.getBuyPriceAfterFee(tokenAddress, 2_000 ether);
        acesToken.approve(address(factory), cost);
        vm.expectRevert("Token is bonded, cannot buy more");
        factory.buyTokens(tokenAddress, 2_000 ether, cost);
        vm.stopPrank();

    }

    function test_TestBondingAndSell() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 10_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        uint256 totalSupply = launchpadToken.totalSupply();
        assertEq(totalSupply, 1 ether); // initial supply from clone
        console2.log("Total supply: %s", totalSupply);

        // Bob buys 10,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, amount);

        cost = factory.getSellPriceAfterFee(tokenAddress, 2_000 ether);
        acesToken.approve(address(factory), cost);
        vm.expectRevert("Token is bonded, cannot sell");
        factory.sellTokens(tokenAddress, 2_000 ether);
        vm.stopPrank();
    }

    function test_TestBondingAndTransferToken() public {
        uint256 amount = 10_000 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, CURVE_STEEPNESS, 0, "Aces Launchpad Token", "ACLP", "my-salt", 10_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        // Bob buys 10,000 tokens
        vm.startPrank(bob);
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);
        acesToken.approve(address(factory), cost);
        factory.buyTokens(tokenAddress, amount, cost);
        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, amount);

        launchpadToken.transfer(charlie, 1 ether);  // Attempt to transfer 1 token
        uint256 charlieBalance = launchpadToken.balanceOf(address(charlie));
        assertEq(charlieBalance, 1 ether);
        
        vm.stopPrank();
    }


    function test_PriceCalculations() public {
        uint256 steepness = 100_000_000;
        uint256 cost = factory.getPriceQuadratic(1 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 1 token: %s", cost);

        cost = factory.getPriceQuadratic(1_000 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 1_000 tokens: %s", cost);

        cost = factory.getPriceQuadratic(100_000 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 100,000 tokens: %s", cost);

        cost = factory.getPriceQuadratic(1_000_000 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 1,000,000 tokens: %s", cost);

        cost = factory.getPriceQuadratic(100_000_000 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 100,000,000 tokens: %s", cost);

        cost = factory.getPriceQuadratic(1_000_000_000 ether, 1 ether, steepness, 0);
        console2.log("Cost to buy 1,000,000,000 tokens: %s", cost);

        vm.stopPrank();
    }


    // sending in less than 1 token and no Aces tokens
    function test_AuditOne_BuyLessThanOneFail() public {
        uint256 amount = 0.99 ether;

        // Alice creates token
        vm.startPrank(alice);
        address tokenAddress = factory.createToken(AcesFactory.Curves.Quadratic, 100_000, 0, "Aces Launchpad Token", "ACLP", "my-salt", 10_000 ether);
        AcesLaunchpadToken launchpadToken = AcesLaunchpadToken(tokenAddress);
        vm.stopPrank();

        // Bob buys tokens. Sends in ZERO aces to buy less than 1 launchpad token
        vm.startPrank(bob);
        vm.expectRevert("Amount must be at least 1 token");
        uint256 cost = factory.getBuyPriceAfterFee(tokenAddress, amount);

        acesToken.approve(address(factory), cost);
        vm.expectRevert("Amount must be at least 1 token");
        factory.buyTokens(tokenAddress, amount, 0);

        uint256 balance = launchpadToken.balanceOf(address(bob));
        assertEq(balance, 0);

        console2.log("Bob balance: %s", balance);

        vm.stopPrank();
    }

    // setting tokensBondedAt to more than max supply minus liquidity pool amount
    function test_AuditTwo_SetTokenBondedAtMoreThanMaxSupply() public {
        uint256 amount = 1_500_000_000 ether; // 1.5 billion, more than max supply of 1 billion

        // Alice creates token
        vm.startPrank(alice);
        vm.expectRevert("tokensBondedAt exceeds max supply");
        factory.createToken(AcesFactory.Curves.Quadratic, 100_000, 0, "Aces Launchpad Token", "ACLP", "my-salt", amount);
        vm.stopPrank();
    }

    // setting tokensBondedAt to more than max supply minus liquidity pool amount
    function test_AuditTwo_SetTokenBondedAtExactAmount() public {
        uint256 amount = 800_000_000 ether; // 800 million, exact amount

        // Alice creates token
        vm.startPrank(alice);
        factory.createToken(AcesFactory.Curves.Quadratic, 100_000, 0, "Aces Launchpad Token", "ACLP", "my-salt", amount);
        vm.stopPrank();
    }



}
