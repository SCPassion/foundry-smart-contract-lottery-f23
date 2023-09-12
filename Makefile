-include .env # include all environment variables

.PHONY: all test deploy # There are gonna to be the targets for this makefile.
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
help:
	@echo "Usage:"
	@echo "make deploy [ARGS=...]"

build:; forge build

install:; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

test:; forge test

# --verify
#    Verify contract after creation. Runs forge verify-contract with the appropriate parameters.

# Default the network to use ANVIL
NETWORK_ARGS := -- rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# if --network sepolia is used, then the network is sepolia, otherwise anvil stuff
# Detect if we are passing the --network sepolia argument, if so, use the sepolia network Internally, forge will use the sepolia network to deploy the contract. Otherwise, it will use the default anvil local blockchain.
ifeq ($(findstring --network sepolia, $(ARGS)), --network sepolia)
	NETWORK_ARG := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


# With the @ symbol, we can call the target without having to write the target name to the terminal.
deploy: # Foundry will call the deployRaffle contract by using the run function from the deploy script to deploy the contract.
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS) 