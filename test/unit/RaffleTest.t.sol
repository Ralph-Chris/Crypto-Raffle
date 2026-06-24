//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle, HelperConfig} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Base.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestRaffle is Test{

    address private PLAYER = makeAddr("chris");
    uint256 private BALANCE = 50 ether;
    uint256 private enteranceFee;
    address account;
    uint256 interval;
    address vrfCoordinator;



    Raffle raffle;
    HelperConfig helperConfig;

    event Players (address indexed player);

    modifier joining() {
        vm.prank(PLAYER);
        raffle.joinRaffle{value: enteranceFee}();
        _;
    }

    modifier Joining() {
        vm.prank(PLAYER);
        raffle.joinRaffle();
        _;
    }

    modifier passTime() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll (block.number +1 );
        _;
    }

    modifier onlyAnvil() {
        if(block.chainid != 31337) {
            revert();
        }_;
    }

    function setUp() public {
        vm.roll(block.number +1);
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.deal(PLAYER, BALANCE);
        enteranceFee = config.enteranceFee;
        account = config.account;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;

    }

    function testCanJoinRaffleWithEnoughEnteranceFee() public {
        vm.prank(PLAYER);
        raffle.joinRaffle{value: enteranceFee}();
    }

    function testCantJoinWithoutEnoughEnteranceFee() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__EnteranceFeeNotMet.selector);
        raffle.joinRaffle();
    }

    function testPlayersGetEmittedAfterJoining() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Players(PLAYER);
        vm.prank(PLAYER);
        raffle.joinRaffle{value: enteranceFee}();
    }

    function testRaffleIsOpenAfterDeployment() public {
        vm.prank(PLAYER);
        raffle.joinRaffle{value: enteranceFee}();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.OPEN);
    }

    function testPlayersGetAddedToArrayList() public {
        vm.prank(PLAYER);
        raffle.joinRaffle{value: enteranceFee}();
        address player = raffle.getPlayersAddress(0);
        assert(PLAYER == player);
    }

    function testPeformUpkeepFailsWhenAllConditionsAreNottMet() public joining {
        vm.expectRevert(Raffle.Raffle__CantPeformUpkeep.selector);
        raffle.performUpkeep();
    }

    function testPeformUpkeepPassWhenAllConditionsAreMet() public joining {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number +1 );
        bool state = raffle.checkUpkeep();
        assert (state == true);
    }

    function testPeformUpkeepIsCalculating() public joining passTime {
        raffle.performUpkeep();
        vm.expectRevert(Raffle.Raffle__RaffleIsPickingWinner.selector);
        raffle.joinRaffle{value:enteranceFee}();
        Raffle.RaffleState state = raffle.getRaffleState();
        assert (state == Raffle.RaffleState.PICKING_WINNER);

    }

    function testPeformUupkeepReturnsRequestId() public joining passTime {
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(raffleState == Raffle.RaffleState.PICKING_WINNER);
        assert( uint256(requestId) > 0);
    }

    function testFulfillRandomWords() public joining passTime onlyAnvil {
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));


    }

    function testJoinRaffleWithMultiplePlayersAndPickingWinner() public onlyAnvil { 
        uint160 startIndex = 1;
        uint160 endIndex = 10;
        for (uint160 i=startIndex; i<endIndex; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.joinRaffle{value: 1 ether}();
        }

        vm.warp(block.timestamp + interval +1 );
        vm.roll(block.number + 1);
        
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        address winner = raffle.getRecentWinner();
        Raffle.RaffleState state = raffle.getRaffleState();
        uint256 winnerBal = address(winner).balance;

        console.log("recent winner is: ", winner);
        assert (winnerBal > 8);
        assert (state == Raffle.RaffleState.OPEN);

    }

    function testBadWinnerRewardFails() public joining {
        vm.expectRevert(Raffle.Raffle__RewardFailed.selector);
        raffle.transferBadWinner();
    }
}
