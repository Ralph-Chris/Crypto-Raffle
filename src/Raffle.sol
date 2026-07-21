//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

/**
 * @title Crypto Raffle
 * @author RalphChris
 * @notice This Contract allow people to join a contest by sending Eth to the contract. at
 * @notice the end of the Raffle, a random winner is picked and rewarded
 * @dev Use chainlink VRF for random selection of the winner and chainlink automation
 * @dev to ensure the pickWinner function is been called automatically when some conditions are met
 */

/* Imports */
import {VRFConsumerBaseV2Plus} from "@chainlink/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__EnteranceFeeNotMet();
    error Raffle__RaffleIsPickingWinner();
    error Raffle__CantPeformUpkeep();
    error Raffle__RewardFailed();

    /* Type Deceleration */
    enum RaffleState {
        OPEN,
        PICKING_WINNER
    }
    /* State Variable */
    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players;

    /* Events */
    event Players(address indexed player);
    event RequestId(uint256 indexed requestId);
    event Winner(address indexed winner);

    /* Modifiers */

    /**
     * @dev the constructor would need the following to be provided during deployment
     * @dev enteranceFee: the minimum amount required to perticipate in the raffle
     * @dev interval: The required time that should pass for the winner to be picked
     * @dev vrfCoordinator: VRF-Coordinator address that would provide our contract the
     * random word
     * @dev KeyHash: address that has the required gas-lane and amount of time we are
     * willing to spend when calling chainlink VRF for random words
     * @dev subscriptionId: an account that contains sufficient link for the callback transaction
     * @dev callbackGasLimit: The maximum amount of gas you are willing to spend when fulfillRandomWords
     * is been called by the VRFCoordinator
     */
    /* Constructor */
    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    /* Function */

    function joinRaffle() public payable {
        if (msg.value < i_enteranceFee) {
            revert Raffle__EnteranceFeeNotMet();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleIsPickingWinner();
        }
        s_players.push(payable(msg.sender));
        emit Players(msg.sender);
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersAddress(uint256 index) external view returns (address) {
        return s_players[index];
    }

    /**
     * @dev checkUpkeep is a condition that checks to ensure the contract has enough players,
     * has balance above zero, and the required time interval has passed.
     * @dev from the chainlink VRFCoordinator
     */
    function checkUpkeep() public view returns (bool upkeepNeeded) {
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        upkeepNeeded = hasPlayers && hasBalance && timeHasPassed;
    }

    /**
     * @dev performUpkeep is the function that request the random word from the chainlink VRF.
     * if first calls checkUpkeep to ensure that certain conditions are met before requesting
     * random words.
     */

    function performUpkeep() public {
        bool upkeepNeeded = checkUpkeep();
        if (!upkeepNeeded) {
            revert Raffle__CantPeformUpkeep();
        }

        s_raffleState = RaffleState.PICKING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestId(requestId);
    }

    /**
     * @dev fulfillRandomWords is the function The VRF Coordinator call after generating
     * the random words.
     */

    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    )
        internal
        override
    {
        uint256 index = randomWords[0] % s_players.length;
        address winner = s_players[index];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        emit Winner(s_recentWinner);

        (bool success,) = payable(s_recentWinner).call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__RewardFailed();
        }
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function transferBadWinner() public {
        BadWinner badWinner = new BadWinner();
        (bool Success,) = payable(address(badWinner)).call{value: address(this).balance}("");
        if (!Success) {
            revert Raffle__RewardFailed();
        }
    }
}

contract BadWinner {}
