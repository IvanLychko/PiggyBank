pragma solidity ^0.4.24;

/*
*
*__/\\\\\\\\\\\\\__________________________________________________/\\\\\\\\\\\\\______________________________________________
* _\/\\\/////////\\\_______________________________________________\/\\\/////////\\\_______________________________/\\\_________
*  _\/\\\_______\/\\\__/\\\___/\\\\\\\\____/\\\\\\\\_____/\\\__/\\\_\/\\\_______\/\\\______________________________\/\\\_________
*   _\/\\\\\\\\\\\\\/__\///___/\\\////\\\__/\\\////\\\___\//\\\/\\\__\/\\\\\\\\\\\\\\___/\\\\\\\\\_____/\\/\\\\\\___\/\\\\\\\\____
*    _\/\\\/////////_____/\\\_\//\\\\\\\\\_\//\\\\\\\\\____\//\\\\\___\/\\\/////////\\\_\////////\\\___\/\\\////\\\__\/\\\////\\\__
*     _\/\\\_____________\/\\\__\///////\\\__\///////\\\_____\//\\\____\/\\\_______\/\\\___/\\\\\\\\\\__\/\\\__\//\\\_\/\\\\\\\\/___
*      _\/\\\_____________\/\\\__/\\_____\\\__/\\_____\\\__/\\_/\\\_____\/\\\_______\/\\\__/\\\/////\\\__\/\\\___\/\\\_\/\\\///\\\___
*       _\/\\\_____________\/\\\_\//\\\\\\\\__\//\\\\\\\\__\//\\\\/______\/\\\\\\\\\\\\\/__\//\\\\\\\\/\\_\/\\\___\/\\\_\/\\\_\///\\\_
*        _\///______________\///___\////////____\////////____\////________\/////////////_____\////////\//__\///____\///__\///____\///__
*/

import "./Ownable.sol";
import "./SafeMath.sol";

contract Betting {

    uint8 public constant betCount = 28;
    uint8 public constant betKillCount = 2;
    struct Bet {
        uint256 minSum;     // min value eth for choose this bet
        uint256 cooldown;   // time for reset timer
    }

    Bet[] public bets;

    constructor() public {
        bets.push(Bet(0.01 ether, 86400));  // 24 hour
        bets.push(Bet(0.02 ether, 82800));  // 23 hour
        bets.push(Bet(0.03 ether, 79200));  // 22 hour
        bets.push(Bet(0.04 ether, 75600));  // 21 hour
        bets.push(Bet(0.05 ether, 72000));  // 20 hour
        bets.push(Bet(0.06 ether, 68400));  // 19 hour
        bets.push(Bet(0.07 ether, 64800));  // 18 hour
        bets.push(Bet(0.08 ether, 61200));  // 17 hour
        bets.push(Bet(0.09 ether, 57600));  // 16 hour
        bets.push(Bet(0.1 ether, 54000));   // 15 hour
        bets.push(Bet(0.11 ether, 50400));  // 14 hour
        bets.push(Bet(0.12 ether, 46800));  // 13 hour
        bets.push(Bet(0.13 ether, 43200));  // 12 hour
        bets.push(Bet(0.14 ether, 39600));  // 11 hour
        bets.push(Bet(0.15 ether, 36000));  // 10 hour
        bets.push(Bet(0.16 ether, 32400));  // 9 hour
        bets.push(Bet(0.17 ether, 28800));  // 8 hour
        bets.push(Bet(0.18 ether, 25200));  // 7 hour
        bets.push(Bet(0.19 ether, 21600));  // 6 hour
        bets.push(Bet(0.2 ether, 18000));   // 5 hour
        bets.push(Bet(0.21 ether, 14400));  // 4 hour
        bets.push(Bet(0.22 ether, 10800));  // 3 hour
        bets.push(Bet(0.25 ether, 7200));   // 2 hour
        bets.push(Bet(0.5 ether, 3600));    // 1 hour
        bets.push(Bet(1 ether, 2400));      // 40 min
        bets.push(Bet(5 ether, 1200));      // 20 min
        bets.push(Bet(10 ether, 600));      // 10 min
        bets.push(Bet(50 ether, 300));      // 5 min
    }

    function getBet(uint256 _betIndex) public view returns(uint256, uint256) {
        Bet memory bet = bets[_betIndex];
        return (bet.minSum, bet.cooldown);
    }

    function getBetIndex(uint256 _sum) public view returns(uint256) {
        for (uint i = 0; i < betCount; i++) {
            if (bets[i].minSum == _sum) return i;
        }

        revert('Bet not found');
    }

    function getMinBetIndexForKill(uint256 _index) public view returns(uint256) {
        if (_index < betKillCount) return 0;

        return _index - betKillCount;
    }

}

contract PiggyBank is Ownable, Betting {

    using SafeMath for uint256;

    event NewRound(uint256 _roundId, uint256 _endTime);
    event CloseRound(uint256 _roundId);
    event UpdateRound(uint256 _roundId, address _winner, uint256 _endTime, uint256 _cap);
    event Test(uint256 test);

    struct Round {
        uint256 endTime;
        uint256 cap;
        uint256 lastBetIndex;
        address winner;
    }

    Round[] public rounds;
    uint256 public currentRound;
    uint256 public constant defaultRoundTime = 86400;   // 24 hours
    uint256 public constant ownerDistribution = 15;     // 15%
    uint256 public constant referrerDistribution = 5;     // 5%
    mapping (address => address) playerToReferrer;

    constructor() public {

    }

    function getRoundInfo(uint256 _roundId) public view returns(uint256, uint256, uint256, address) {
        Round memory round = rounds[_roundId];
        return (round.endTime, round.cap, round.lastBetIndex, round.winner);
    }

    function _payToWinner(uint256 _roundId) private {
        rounds[currentRound].winner.transfer(rounds[currentRound].cap);
    }

    function _startNewRoundIfNeeded() private {
        if (rounds.length > currentRound) return;

        uint256 roundId = rounds.push(Round(now + defaultRoundTime, 0, 0, 0x0));
        emit NewRound(roundId, now);
    }

    function _closeRoundIfNeeded() private {
        if (rounds.length <= currentRound) return;
        if (now <= rounds[currentRound].endTime) return;

        _payToWinner(currentRound);
        currentRound = currentRound.add(1);
        emit CloseRound(currentRound - 1);
    }

    function depositRef(address _referrer) payable public {
        uint256 betIndex = getBetIndex(msg.value);

        // close if needed
        _closeRoundIfNeeded();

        // for new rounds
        _startNewRoundIfNeeded();

        require(betIndex >= getMinBetIndexForKill(rounds[currentRound].lastBetIndex), "More bet value required");
        Bet storage bet = bets[betIndex];

        // work with actual
        rounds[currentRound].cap = rounds[currentRound].cap.add(msg.value * (100 - ownerDistribution) / 100);
        rounds[currentRound].endTime = now.add(bet.cooldown);
        rounds[currentRound].winner = msg.sender;

        // distribution
        uint256 ownerPercent = ownerDistribution;
        if (playerToReferrer[msg.sender] == 0x0 && _referrer != 0x0 && _referrer != msg.sender) playerToReferrer[msg.sender] = _referrer;
        if (playerToReferrer[msg.sender] != 0x0) {
            playerToReferrer[msg.sender].transfer(msg.value * referrerDistribution / 100);
            ownerPercent = ownerPercent.sub(referrerDistribution);
        }
        owner.transfer(msg.value * ownerPercent / 100);

        emit UpdateRound(currentRound, rounds[currentRound].winner, rounds[currentRound].endTime, rounds[currentRound].cap);
    }

    function deposit() payable public {
        depositRef(0x0);
    }

    function payWinCap() public {
        _closeRoundIfNeeded();
    }

}
