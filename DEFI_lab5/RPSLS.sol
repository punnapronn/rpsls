// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract Convert {
    function getHash(bytes32 data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }
}

contract RPSLS {
    address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];
    
    uint public reward = 0;
    mapping(address => bytes32) public commitments;
    mapping(address => uint) public choices;
    address[] public players;
    uint public gameStartTime;
    bool public gameActive = false;
    
    modifier onlyAllowedPlayers() {
        require(isAllowed(msg.sender), "Not an allowed player");
        _;
    }
    
    function isAllowed(address player) private view returns (bool) {
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (allowedPlayers[i] == player) {
                return true;
            }
        }
        return false;
    }
    
    function joinGame(bytes32 commitment) public payable onlyAllowedPlayers {
        require(players.length < 2, "Game already has two players");
        require(msg.value == 1 ether, "Must send exactly 1 ether");
        
        if (players.length == 1) {
            require(msg.sender != players[0], "Cannot join twice");
        }
        
        players.push(msg.sender);
        commitments[msg.sender] = commitment;
        reward += msg.value;
        
        if (players.length == 2) {
            gameStartTime = block.timestamp;
            gameActive = true;
        }
    }
    
    function revealChoice(uint choice, string memory secret) public onlyAllowedPlayers {
        require(gameActive, "Game is not active");
        require(choice >= 0 && choice <= 4, "Invalid choice");
        require(commitments[msg.sender] == keccak256(abi.encodePacked(choice, secret)), "Commitment mismatch");
        
        choices[msg.sender] = choice;
        
        if (choices[players[0]] != 0 && choices[players[1]] != 0) {
            _checkWinnerAndPay();
        }
    }
    
    function _checkWinnerAndPay() private {
        uint p0 = choices[players[0]];
        uint p1 = choices[players[1]];
        address payable player0 = payable(players[0]);
        address payable player1 = payable(players[1]);
        
        if ((p0 + 1) % 5 == p1 || (p0 + 3) % 5 == p1) {
            player1.transfer(reward);
        } else if ((p1 + 1) % 5 == p0 || (p1 + 3) % 5 == p0) {
            player0.transfer(reward);
        } else {
            player0.transfer(reward / 2);
            player1.transfer(reward / 2);
        }
        
        _resetGame();
    }
    
    function _resetGame() private {
        delete players;
        delete reward;
        gameActive = false;
    }
    
    function withdrawIfOpponentFails() public onlyAllowedPlayers {
        require(gameActive, "Game is not active");
        require(block.timestamp >= gameStartTime + 5 minutes, "Wait time not over");
        
        if (players.length == 1) {
            payable(players[0]).transfer(reward);
        } else if (choices[players[0]] == 0 || choices[players[1]] == 0) {
            payable(msg.sender).transfer(reward);
        }
        
        _resetGame();
    }
}
