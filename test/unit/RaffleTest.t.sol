// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol"; // ../ mean go up one level, ./ means same level
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE); // Put some funds to the PLAYER address
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////////////
    //------- Enter Raffle Tests -------//
    //////////////////////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        /* expectEmit is a function that we can use to check if an event is emitted
        Reference link: https://book.getfoundry.sh/cheatcodes/expect-emit?highlight=expectemit#expectemit
        function expectEmit(
            bool checkTopic1,
            bool checkTopic2,
            bool checkTopic3,
            bool checkData, // check for unindexed parameters?
            address emitter // Our raffle contract is our emitter, when we have a new entrance
        ) external;
         */
        vm.expectEmit(true, false, false, false, address(raffle));

        // Manually emit the event that we expect to emit, event is not types like enum or struct where we can import them
        // We have to redefine them in our test script
        // Be careful that the event name you defined here in RaffleTest.t.sol should be the same as the event name in Raffle.sol
        // Why? Because we are going to compare the event that we expect to emit with the event that we actually emit
        // If the event name is different, then the comparison will fail

        // Manually emit the event that we expect to emit. This will be used for later comparison
        emit EnteredRaffle(PLAYER);

        // Make the function call that should emit this event
        raffle.enterRaffle{value: entranceFee}();

        //vm.prank(PLAYER);
        //vm.expectEmit(true, false, false, false, address(raffle));
        //emit EnteredRaffle(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // We need to kick off the performUpkeep function, make the raffle in the CALCULATING state
        // To do this, checkUpkeep function needs to return true, ie. block.timestamp - s_lastTimeStamp >= i_interval
        vm.warp(block.timestamp + interval + 1); // Set the block timestamp to be greater than the interval. Used in forked local chain
        vm.roll(block.number + 1); // Set the block number to the next block

        // upkeepNeeded should return true now from the checkUpkeep function
        // should be able to call the performUpkeep function by passing some empty bytes
        raffle.performUpkeep("");

        // It should be in a calculating state, ie we cannot enter the raffle
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // This should revert
    }

    //////////////////////////////////////
    //------- CheckUpKeep  Tests -------//
    //////////////////////////////////////
    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
        // Make everything true except the checkBalance

        // Time has passed but no balance
        // Arrange
        vm.warp(block.timestamp + interval + 1); // Set the block timestamp to be greater than the interval. Used in forked local chain
        vm.roll(block.number + 1); // Set the block number to the next block

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // Set the block timestamp to be greater than the interval. Used in forked local chain
        vm.roll(block.number + 1); // Set the block number to the next block
        raffle.performUpkeep("");
        // Now in calculating state

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {}

    //////////////////////////////////////
    //------- PerformUpkeepTests -------//
    //////////////////////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep(""); // This should not revert
        // This test passed if performUpkeep will pass
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0; // or uint256(Raffle.RaffleState.OPEN);

        // If we just call performUpkeep, it will revert because checkUpkeep is false. As there is no balance, no players, no time passed

        // Act / Assert
        vm.expectRevert( // Expecting performUpkeep transaction to fail
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector, // With this errorcode
                currentBalance, // With these parameters
                numPlayers, // With these parameters
                raffleState // With these parameters
            )
        ); // Error in raffle with custom error
        raffle.performUpkeep(""); // This should revert
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if I need to test using the output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the request Id
        Vm.Log[] memory entries = vm.getRecordedLogs(); // get all values of all events
        // All logs are recorded in bytes32, so we need to decode them
        bytes32 requestId = entries[1].topics[1]; // topic[0] refers to the event name *entire event, topic[1] refers to the requestId

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // for calculating
    }

    //////////////////////////////////////
    //------- fulfillRandomWords -------//
    //////////////////////////////////////

    // Anytime we need to mock or pretend to be the chainlink vrf, these tests should be skipped on the forked testnet/mainnet
    modifier skipFork() {
        if (block.chainid != 31337) {
            return; // If we are nott using anvil blockchain, then skip this test
        }
        _; // If the condition is passed, then run the test
    }

    // We have to skip this test if we are on a fork testnet. Why? we are not using mock.
    // Fuzz testing: It means that we are going to try to call the function with a bunch of different inputs
    // Why? Because we want to make sure that the function can handle all the different inputs. This is to secure the contract / protocol
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId // Foundry will generate a random request Id for us and call this many times. Make sure the nonexistent requestt happens
    ) public raffleEnteredAndTimePassed skipFork {
        // Try to  call fulfillRandomWords in the mock directly, it should fail and revert
        // Arrange
        vm.expectRevert("nonexistent request");
        // We are being the chainlink vrf since on our local fake chain, we don't have the chainlink vrf
        // This test function wouldn't work on a real testnet because we are not the chainlink vrf M2 mock
        // We cannot fulfill the random words. only the chainlink node can do that
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        ); // 0 as the requestId and address of raffle as consumer
    }

    function testFullFillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1; // because we already have one player (0 is the first player)
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // uint160 is a type has the same size as address ie. address(2)
            hoax(player, STARTING_USER_BALANCE); // Give each player some ether, and set the player as the sender ie. vm.prank(player) + vm.deal(1 ether)
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 price = entranceFee * (additionalEntrants + 1); // +1 because we already have one player

        // Act
        // Get the request Id
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the request Id (kick off the request to chainlink vrf)
        Vm.Log[] memory entries = vm.getRecordedLogs(); // get all values of all events
        // All logs are recorded in bytes32, so we need to decode them
        bytes32 requestId = entries[1].topics[1]; // topic[0] refers to the event name *entire event, topic[1] refers to the requestId

        uint256 previousTimeStamp = raffle.getLastTimeStamp(); // Get the previous timestamp. We will compare this with the last timestamp after the fulfillRandomWords function is called

        // pretend to be chainlink vrf to 1. get random number 2. pick winner. Since we don't have the chainlink vrf on our local fake chain
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // It is best practice to have 1 assert per test function
        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); // raffle state should be open, check Raffle.sol fulfillRandomWords function override. It resets the raffle state to open
        assert(raffle.getRecentWinner() != address(0)); // recent winner variable should have something. It should not be 0
        assert(raffle.getLengthOfPlayers() == 0); // length of players should be 0
        assert(previousTimeStamp < raffle.getLastTimeStamp()); // last timestamp should be greater than the previous timestamp.
        console.log(raffle.getRecentWinner().balance); // 10050000000000000000
        console.log(price + STARTING_USER_BALANCE); // 10060000000000000000
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + price - entranceFee
        );
        // Check that the winner got the money
    }
}
