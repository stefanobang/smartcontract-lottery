// SPDX-License-Identifier: MIT

//Enter lottery

//pick random number

//Winner selected at x minutes

pragma solidity ^0.8.8;

//chainlink VRF 사용
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error TransferFailed();
error LotteryNOTOPEN();
error Er_NotEnoughETH_ENTERED();

error UPKEEPNOTREQUIRED(
    uint256 currentBalance,
    uint256 numCustomers,
    uint256 lotteryState
);

/*
 */

contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    enum LotteryState {
        OPEN,
        CACULATE
    }

    //variables.....
    uint256 private immutable immut_entranceFee;
    address payable[] private s_customers; //s_player => s_customer

    VRFCoordinatorV2Interface private immutable immut_vrfCoordinator;
    bytes32 private immutable immut_gaslane;
    uint64 private immutable immut_subscriptionID;
    uint16 private constant REQEUST_CONFIRMATIONS = 3;
    uint32 private immutable immut_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1; //how many random numbers

    //Lotter Variables
    address private stored_recentWinner;
    LotteryState private stored_lotteryState;
    uint256 private stored_lastTime;
    uint256 private immutable immut_interval;

    //이벤트 만들기
    event LotteryEnter(address indexed customer);
    event RequestLotteryWinner(uint256 indexed requestID);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gaslane,
        uint64 subscriptionID,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        immut_entranceFee = entranceFee;
        immut_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        immut_gaslane = gaslane;
        immut_subscriptionID = subscriptionID;
        immut_callbackGasLimit = callbackGasLimit;
        stored_lotteryState = LotteryState.OPEN;
        stored_lastTime = block.timestamp;
        immut_interval = interval;
    }

    function enterLottery() public payable {
        //must be msg.value > minimum fee, or prints not enough
        if (msg.value < immut_entranceFee) {
            revert Er_NotEnoughETH_ENTERED();
        }
        if (stored_lotteryState != LotteryState.OPEN) {
            revert LotteryNOTOPEN();
        }

        s_customers.push(payable(msg.sender));

        //이벤트...
        emit LotteryEnter(msg.sender);
    }

    //chainlink keeper 사용
    //upkeepNeed를 찾고 true 돌려준다
    //만약 true면
    function checkUpkeep(
        bytes memory
    ) public override returns (bool upkeepRequired, bytes memory) {
        bool isOpen = LotteryState.OPEN == stored_lotteryState;
        //current time - previous time
        bool timePassed = ((block.timestamp - stored_lastTime) >
            immut_interval);
        bool hasCustomers = (s_customers.length > 0);
        bool hasBalance = address(this).balance > 0;

        //만약 upkeepRequired false이면 lottery 시간이 아님
        upkeepRequired = (isOpen && timePassed && hasCustomers && hasBalance);
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepRequired, ) = checkUpkeep("");
        if (!upkeepRequired) {
            revert UPKEEPNOTREQUIRED(
                address(this).balance,
                s_customers.length,
                uint256(stored_lotteryState)
            );
        }

        //request vrf
        // random number generated
        stored_lotteryState = LotteryState.OPEN;

        uint256 requestID = immut_vrfCoordinator.requestRandomWords(
            immut_gaslane, //gaslane
            immut_subscriptionID,
            REQEUST_CONFIRMATIONS,
            immut_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestLotteryWinner(requestID);
    }

    function fulfillRandomWords(
        uint256 requestID,
        uint256[] memory randomWords
    ) internal override {
        //s_customers size 10
        uint256 indexWinner = randomWords[0] % s_customers.length;
        address payable recentWinner = s_customers[indexWinner]; //우승자
        stored_lotteryState = LotteryState.OPEN;
        s_customers = new address payable[](0); //resetting the lottery & customer
        stored_lastTime = block.timestamp;

        stored_recentWinner = recentWinner;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");

        //must require success
        if (!success) {
            revert TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /*view / pure functions */
    function getEntranceFee() public view returns (uint256) {}

    //손님 정보 부르기
    function getCustomer(uint256 index) public view returns (address) {
        return s_customers[index];
    }

    //최근 우승자 부르기
    function getRecentWinner() public view returns (address) {
        return stored_recentWinner;
    }

    function getLotteryState() public view returns (LotteryState) {
        return stored_lotteryState;
    }

    function getNumWords() public returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_customers.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return stored_lastTime;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQEUST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return immut_interval;
    }
}
