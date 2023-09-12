# Proveably Random Raffle Contracts

## About
This code is to create a proveable random smart contract lottery.

## What we want it to do?

1. Users can enter by paying for a ticket
    1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
    1. And this will be done programatically
3. Using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF -> Randomness (Random is hard in blockchain, it may result in different states on different nodes if it is truely random. So we use Chainlink VRF to get a random number from a trusted source)
    2. Chainlink Automation -> Time-based trigger


## To install the Chainlink Brownie Contracts, run the following command: 
This brownie contract is used to interact with the Chainlink VRF and Chainlink Automation contracts, and a lot more minimal compared to the smartcontractkit/chainlink repo.
```
forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```

## Mid-Cap:
1. EnterRaffle function: make sure people buy tickets with the entrance fee. Add them to the s_players array.

2. After enough time has passed, the checkUpkeep gets called by chainlink modes
If it returns true, or if it is time for the lottery to be drawn,
ChainLink nodes will in a decentralized context call the performUpKeep function
Which will kick off a request to the chainlink VRF

3. We will wait a couple blocks
Once the chainlink nodes responds,
it will call the fulfillRandomWords function, which will  pick a random winner and reset everything

Next step, we need to do some testing to make sure it works

## Tests!
1. Write some deploy scripts
2. Write our tests
   1. Work on a local chain
   2. Forked Testnet
   3. Forked Mainnet

## Install Solmate library
```
forge install transmissions11/solmate --no-commit
```

## Another famous library is OpenZeppelin in https://github.com/OpenZeppelin/openzeppelin-contracts

## Add Foundry-devops to search for the latest broadcast
You can either find it from the broadcast folder or run the following command:
```
forge install ChainAccelOrg/foundry-devops --no-commit
```
## To know what to test, we need to know what we want to test
```
forge coverage --report debug > coverage.txt
```
This creates a file. See from "Analysing contracts..." to the end of the file. This is what we want to test.
In this project, we mainly care raffle.sol since it is the main contract.

## To run the test in forked sepolia
```
forge test --fork-url $SEPOLIA_RPC_URL
```

## Use Anvil to test the contract
```
forge test
```

forge test --debug TestFunctionName