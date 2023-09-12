// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

// The run part is used when you broac the script with
// forge script run script/DeployRaffle.s.sol:FundSubscription --rpc-url=http://localhost:8545 ...etc..ab

// Create a subscription for us
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    // This create subscription function can be used in another script (ie. deployRaffle) by providing the vrfCoordinator address
    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        // Call the createsubscription function on the vrfCoorinator mock, this is found by looking at the hex from metamask.
        // You can also view the function in the chainlink repo
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address Link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription", subId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainID", block.chainid);

        if (block.chainid == 31337) {
            //on a local chain
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            ); // This doesn't exist in the actual contract, we need to do transfer and call things
            vm.stopBroadcast();
        } else {
            // Do a real transfer here
            vm.startBroadcast(deployerKey);
            LinkToken(Link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            ); // This doesn't exist in the actual contract, we need to do transfer and call things
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        // What is the different between vm.prank(OWNER) vs vm.startBroadcast(deployerKey)?
        // vm.prank(OWNER) is used in the test script, but vm.startBroadcast(deployerKey) is used in the deploy script
        // What library is vm.prank() from?
        // vm.prank() is from forge-std/Script.sol
        vm.startBroadcast(deployerKey); //pass in the private key to use for the broadcasting
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle); // call addconsumer with a deployer key, ie with a private key
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId, deployerKey); // You have to be the owner of the consumer contract to add it to the subscription
        // For a test script, you could use vm.prank(). But in our deploy script, we need to use the actual key
    }

    function run() external {
        // refer to : https://github.com/Cyfrin/foundry-devops
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
