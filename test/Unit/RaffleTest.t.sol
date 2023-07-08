// SPDX-License-Identifier: MIT
pragma solidity^0.8.16;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
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
            callbackGasLimit
        ) = helperConfig.activeNetworkConfig();
        vm.deal(Player, STARTING_BALANCE);
    }
    // Test functions

    function testRaffleState() public view  {
        assert(raffle.getRaffleState() == Raffle.RaffleState.open);
    }

    function testenterRaffleWithoutEth() public  {
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
        vm.expectEmit(true,false,false,false,address(raffle));
        emit EnterRaffle(Player);
        raffle.enterRaffle{value: entranceFee}();
    }
}