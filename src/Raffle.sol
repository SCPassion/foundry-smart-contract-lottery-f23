// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle contract
 * @author SC Wong
 * @notice This contract is for creating a sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    /** Type declarations **/
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /** State variables **/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // @dev Duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    /** Events **/
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        // We need to pass the address of the VRF Coordinator to the constructor of VRFConsumerBaseV2
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator); //type cast this address to an interface VRFCoordinatorV2Interface, vrfCoordinator is dependent on the network. This shows how to connect to chainlink VRF
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // EnterRaffle should be external payable instead of public payable
    // We are not going to have anything inside of this contract to call this function, so it should be external
    // More gas efficient
    // Allow participant to emter the raffle
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            // Make sure nobody is entering the raffle when it is not open
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender)); //payable to allow to get eth or whatever token

        // Whenever we make a storage update, we should emit an event
        // 1. Makes migration easier
        // 2. Makes front-end "indexing" easier
        emit EnteredRaffle(msg.sender);
    }

    // Just return when the winner is supposed to be picked
    /**
     * @dev This is the function that the Chainlink Automation nodes call to see if it is time to perform an upkeep
     * The following conditions should be all true for this to return true:
     * 1. The time interval has passed between raffle runs, make sure enough time has passed to pick a winner
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Inplicit) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        // If the function you used require an input parameter and you are not using it, ignore it by /**/
        // upKeepNeeded: True is needed when the lottery is ready to pick a winner
        // performData: Additional Data that you want to pass to the performUpkeep function

        // Logic of checkUpkeep function:
        // This function is view, so the chainlink nodes are going to call this checkUpkeep function as view function.
        // It is not going to change the state of the contract or send a transaction (ie.simulation)
        // Then if everything is true, then the chainlink nodes will call the performUpkeep function

        // Kick off a chainlink VRF call
        // Make sure enough time has passed to pick a winner
        // eg. 1000 - 500 = 500, interval 600 seconds -> not enough time passed
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // Return is it time for this lottery to get updated?
    }

    // 1. Get a random number
    // 2. User the random number to pick a winner
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        // Call the checkUpKeep function here to make sure it is indeed time to do the upkeep

        // The chainlink keepers will kick off the chain link vrf call for us
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        // 1. make a Request RNG to Chainlink contract
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane (maximum gas limit)
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // number of confirmations for your random number to be considered valid
            i_callbackGasLimit, // max gas limit for the callback function
            NUM_WORDS // number of random numbers to be generated
        );
        // 2. Get the random number from the callback function from chainlink

        emit RequestedRaffleWinner(requestId);
    }

    // using style CEI: Check, Effects, Interactions
    // Return out fulfillRandomWords function
    // This function is existed in VRFConsumerBaseV2.sol, and we are overwriting it.
    // Now, we have the random number, what do we do?
    // After making a i_vrfCoordinator.requestRandomWords, this function wil be called
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // require(if -> errors) -> Do the checks first because it is more gas efficient

        // Effects (Effect our own contract) -> Update the state variables
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Reset the s_player to remove the previous players
        s_lastTimeStamp = block.timestamp; // Start the clock over
        emit PickedWinner(winner);

        // Interactions (Interact with other contracts / address)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            // revert the transaction
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Function **/

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
