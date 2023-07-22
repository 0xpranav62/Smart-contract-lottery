// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // Events
    event EnterRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address Player = makeAddr("player");
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            ,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(Player, STARTING_BALANCE);
    }

    modifier PlayerEnteredAndTimeIsPassed() {
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipfork() {
        if (block.chainid != 31337) {
            return;
        } else _;
    }

    // Test functions

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.open);
    }

    function testenterRaffleWithoutEth() public {
        // Arrange
        vm.prank(Player);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testIfPlayerInTheRaffle() public {
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == Player);
    }

    function testEmitWhenEnterRaffle() public {
        vm.prank(Player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnterRaffle(Player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleCalculating()
        public
        PlayerEnteredAndTimeIsPassed
    {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(Player);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////
    // checkUpkeep //
    /////////////////
    function testIfBalanceIsNotEnough() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);
        // raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testIfTimeIsPassed() public {
        // return false
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.timestamp + 1);
        // raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testIfRaffleIsOpen() public PlayerEnteredAndTimeIsPassed {
        // Return false

        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    ////////////////////
    // perform Upkeep //
    ////////////////////
    function testPerformUpKeepOnlyWhenCheckUpReturnTrue()
        public
        PlayerEnteredAndTimeIsPassed
    {
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertIfCheckUpReturnFalse() public {
        uint256 currentBalance = 0;
        uint256 currentLength = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                currentLength,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepEmitRequestId()
        public
        PlayerEnteredAndTimeIsPassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();

        console.log("RequestId:", uint256(requestId));
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    function testFullFillRandomWordsOnlyCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public PlayerEnteredAndTimeIsPassed skipfork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFinalTest() public PlayerEnteredAndTimeIsPassed skipfork {
        uint256 startingIndex = 1;
        uint256 numberOfPlayers = 5;
        for (uint256 i = startingIndex; i <= numberOfPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 prize = entranceFee * (numberOfPlayers + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        console.log("Raffle Prize: ", raffle.getRecentWinner());
        console.log("Total prize", prize + STARTING_BALANCE);
        // Assert
        assert(
            raffle.getRecentWinner().balance ==
                prize + STARTING_BALANCE - entranceFee
        );
    }
}
