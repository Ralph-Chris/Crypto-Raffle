//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HelperConfig, CodeConstant} from "script/HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {LinkToken} from "test/mocks/LinkToken.t.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script, CodeConstant {
    
    function createSubscriptionUsingConfig() public returns(uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        address account = config.account;
        (uint256 subId, address coordinator) = createSubscription(vrfCoordinator, account);
        return (subId, coordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns(uint256 subid, address) {
        console.log("your vrfCoordinator address: ", vrfCoordinator);
        vm.roll(block.number +1);
        vm.startBroadcast(account);
        uint256 subId = IVRFSubscriptionV2Plus(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your new subscriptionId is: ", subId);
        console.log("Using vrfCoordinator address: ", vrfCoordinator);
        return (subId, vrfCoordinator);

    }

}

contract FundSubscription is Script, CodeConstant {

    uint256 private AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        uint256 subId = config.subscriptionId;
        address account = config.account;
        address link = config.link;
        fundSubscription(vrfCoordinator, account, link, subId);
    }

    function fundSubscription(address vrfCoordinator,
    address account, 
    address link,
    uint256 subId) public {
        if (block.chainid == LOCAL_CHAIN) {
            vm.startBroadcast(account);
            console.log("fund vrfConsumer: ", vrfCoordinator);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, AMOUNT * 1000);
            vm.stopBroadcast();
        }
        else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function addConsumer (uint256 subId,
        address consumer,
        address account,
        address vrfCoordinator) public {
            console.log("add Consumer vrfCoonsumer address: ", vrfCoordinator);
        vm.startBroadcast(account);
        IVRFSubscriptionV2Plus(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }
}