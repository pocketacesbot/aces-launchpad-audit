## Aces.fun

### Overview

The **AcesFactory** contract is the core of the Aces.fun platform - a bonding curve-based token launchpad that enables users to create and trade tokens with mathematical pricing curves before they graduate to decentralized exchanges.

#### Key Features:

- **Token Creation**: Creates clones of `AcesLaunchpadToken` using OpenZeppelin's minimal proxy pattern for gas-efficient deployment
- **Bonding Curves**: Supports quadratic and linear pricing curves that determine token prices based on supply
- **Trading System**: Enables buying and selling tokens on the bonding curve with automatic price discovery
- **Graduation Mechanism**: Automatically enables transfers and renounces ownership when tokens reach their bonding threshold
- **Fee Management**: Configurable protocol and subject fees with automatic distribution
- **DEX Integration**: Built-in Aerodrome router integration for creating liquidity pairs upon graduation
- **Upgradeable Architecture**: Uses UUPS proxy pattern for contract upgrades while maintaining state

#### How It Works:

1. Users call `createToken()` to deploy a new launchpad token with specified bonding curve parameters
2. Tokens start paused and can only be traded through the factory's bonding curve
3. As users buy tokens, the price increases according to the mathematical curve (quadratic or linear)
4. When the token reaches its `tokensBondedAt` threshold, it "graduates":
   - Transfers are enabled
   - Ownership is renounced to make it fully decentralized
   - Can be listed on DEXs via the integrated Aerodrome router

The factory uses ACES tokens as the base currency for all trades and accumulates them for each token's liquidity pool.

### Install

```shell
$ forge install foundry-rs/forge-std
$ forge install OpenZeppelin/openzeppelin-foundry-upgrades
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable
$ forge install OpenZeppelin/openzeppelin-contracts
```

### Deploy to Anvil

```shell
$ forge create FixedMath --rpc-url=$RPC_URL_ANVIL --private-key=$PRIVATE_KEY_ANVIL --broadcast
$ forge script script/DeployAcesToken.s.sol --broadcast --rpc-url anvil
$ forge script script/DeployAcesLaunchpadToken.s.sol --broadcast --rpc-url anvil
$ forge script script/DeployAcesFactory.s.sol --broadcast --rpc-url anvil --libraries src/FixedMath.sol:FixedMath:$FIXED_MATH_ANVIL
$ forge script script/DeployProxy.s.sol --broadcast --rpc-url anvil

$ forge script script/SetTokenAddress.s.sol --rpc-url anvil --broadcast
$ forge script script/SetLaunchpadTokenAddress.s.sol --rpc-url anvil --broadcast

$ forge script script/BuyLaunchpadToken.s.sol --rpc-url anvil --broadcast
```

### Deploy to Sepolia

```shell
$ forge create FixedMath --rpc-url=$RPC_URL_SEPOLIA --private-key=$PRIVATE_KEY_SEPOLIA --verify

$ forge script script/DeployAcesToken.s.sol --broadcast --rpc-url sepolia --verify
$ forge script script/DeployAcesLaunchpadToken.s.sol --broadcast --rpc-url sepolia --verify

$ forge script script/DeployAcesFactory.s.sol --broadcast --rpc-url sepolia --libraries src/FixedMath.sol:FixedMath:$FIXED_MATH_SEPOLIA --verify
$ forge script script/DeployProxy.s.sol --broadcast --rpc-url sepolia --verify

$ forge script script/SetTokenAddress.s.sol --rpc-url sepolia --broadcast -vvvv 
$ forge script script/SetLaunchpadTokenAddress.s.sol --rpc-url sepolia --broadcast -vvvv 
$ forge script script/SetProtocolFeeDestination.s.sol --rpc-url sepolia --broadcast -vvvv
$ forge script script/CreateToken.s.sol --rpc-url sepolia --broadcast -vvvv --verify
$ forge script script/BuyLaunchpadToken.s.sol --rpc-url sepolia --broadcast -vvvv
$ forge script script/SendAcesTokens.s.sol --rpc-url sepolia --broadcast -vvvv
```

### Audit
1. Required amount to buy at least 1 token, and supply must be at least 1 token
2. Added check for amount to be less than launchpad token max total supply
3. Added check in getPriceQuadratic, getPriceLinear to ensure total supply is at least 1 token to avoid underflow
4. Added Aerodrome liquidity manager integration to create liquidity pairs on bonding
5. Added storage gap for upgradeability - https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
6. /* two step ownership transfer */
7. Upgraded withdrawETH to use call instead of transfer to avoid gas limit issues - https://docs.openzeppelin.com/contracts/4.x/api/utils#Address:sendValue-address-uint256-
8. Added check in withdrawACES to ensure token is bonded before allowing withdrawal of ACES tokens
9. /* would disallow smart contract wallets */
10. /* ownable 2 step */
11. Removed payable from sellTokens
12. Inserted liquidity manager address variable and setter function
13. Removed upgradeTo function to prevent unauthorized upgrades

// 333333333333333332833333333333333333500000000000000000
// 2666666666666666664666666666666666667000000000000000000
// 2333333333333333331833333333333333333500000000000000000