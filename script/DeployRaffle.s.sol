// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    // We need a HelperConfiguration to help identify the parameters in the constructor for Raffle.sol
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // The following only happens if you don't have a subscriptionId
            // Here we create a subscription and fund it with $LINK

            // We need to create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            // Fund the subscription with $LINK
            // We only need the fundSubscription function, so we can call it directly. Other parts are defined in the DeployRaffle script
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        // Deploy the Raffle contract
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        // Since it is a brand new raffle, We always going to want to add a consumer for this contract
        // Add the Raffle contract to our list of consumers in the chainLink subscription management
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );

        return (raffle, helperConfig);
    }
}
