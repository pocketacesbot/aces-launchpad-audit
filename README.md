## Aces.fun

### Install

```shell
$ forge install foundry-rs/forge-std
$ forge install OpenZeppelin/openzeppelin-foundry-upgrades
$ forge install OpenZeppelin/openzeppelin-contracts-upgradeable
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
