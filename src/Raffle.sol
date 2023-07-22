// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 *@title Raffe contract
 *@author 0xpranav
 *@notice This contract is to create simple raffle contract
 *@dev Implement ChainLink VRFv2
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    // Custom Errors
    error Raffle__NotEnoughEth();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 currentPlayers,
        uint256 raffleState
    );

    // Enum or Type Declaration
    enum RaffleState {
        open, // 0
        calculating // 1
    }
    // Constant and Immutable variables
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    // State Variables
    address payable[] s_players;
    uint256 private s_lastTimeStamp;

    // Events
    event EnterRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestId(uint256 indexed requestId);

    // Construtor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        // Whenever We need to inheret the contract that has constructor, we have to call in our constructor

        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.open;
    }

    // Functions
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEth();
        }
        if (s_raffleState != RaffleState.open) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    /**
     * @dev This is the function that chainlink Automation nodes call
     * to check if its time to perform Upkeep function.
     * The following should be true for this function to return true:
     * 1. Time interval should be passed in the raffle run
     * 2. Raffle should be open
     * 3. Should have enough eth or players
     * 4. Subscription Id should be funded with LINK
     */

    function checkUpkeep(
        bytes memory /*Check Data */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*perform data*/)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = RaffleState.open == s_raffleState;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /**/) external override {
        // Check if enough time is passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.calculating;
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestId(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // We will use Modulo of size of participants to draw the winner
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.open;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);
    }

    // Getter Functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
