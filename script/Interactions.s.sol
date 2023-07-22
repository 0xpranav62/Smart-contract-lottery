// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscriptionId is Script {
    function createSubIDfromConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubID(vrfCoordinator, deployerKey);
    }

    function createSubID(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subid on blockId", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is: ", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubIDfromConfig();
    }
}

contract FundSubscription is Script {
    uint96 constant FUND_AMOUNT = 3 ether;

    function FundSubscriptionConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundsubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundsubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address link,
        uint256 deployerKey
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        FundSubscriptionConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
