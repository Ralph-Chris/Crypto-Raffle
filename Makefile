include .env

.PHONY: all test deploy 

m:; forge test --mt

clean:; forge clean

install:; forge install smartcontractkit/chainlink-brownie-contracts && forge install transmissions11/solmate

deploy-sepolia:; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA) --account chris1 -- broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil:; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(ANVIL) --account chriskey --broadcast