// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "./IERC20.sol";

/*interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}*/

contract Convert {
    function getHash(bytes32 data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }
}

contract RPSLS {
    uint public reward = 0;
    mapping(address => bytes32) public commitments;
    mapping(address => uint) public choices;
    mapping(address => bool) public hasRevealed;
    address[] public players;
    uint public gameStartTime;
    uint public revealDeadline;
    bool public gameActive = false;
    IERC20 public token;
    uint256 public betAmount = 1000000000000; // 0.000001 ether in smallest unit
    
    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }
    
    function joinGame(bytes32 commitment) public {
        require(players.length < 2, "Game already has two players");
        require(token.allowance(msg.sender, address(this)) >= betAmount, "Insufficient allowance");
        
        if (players.length == 1) {
            require(msg.sender != players[0], "Cannot join twice");
        }
        
        players.push(msg.sender);
        commitments[msg.sender] = commitment;
        
        if (players.length == 2) {
            require(token.allowance(players[0], address(this)) >= betAmount, "Player 1 has not approved");
            require(token.allowance(players[1], address(this)) >= betAmount, "Player 2 has not approved");
            
            token.transferFrom(players[0], address(this), betAmount);
            token.transferFrom(players[1], address(this), betAmount);
            reward = betAmount * 2;
            
            gameStartTime = block.timestamp;
            revealDeadline = gameStartTime + 5 minutes;
            gameActive = true;
        }
    }
    
    function revealChoice(uint choice, string memory secret) public {
        require(gameActive, "Game is not active");
        require(block.timestamp <= revealDeadline, "Reveal period ended");
        require(choice >= 0 && choice <= 4, "Invalid choice");
        require(commitments[msg.sender] == keccak256(abi.encodePacked(choice, secret)), "Commitment mismatch");
        
        choices[msg.sender] = choice;
        hasRevealed[msg.sender] = true;
        
        if (hasRevealed[players[0]] && hasRevealed[players[1]]) {
            _checkWinnerAndPay();
        }
    }
    
    function _checkWinnerAndPay() private {
        uint p0 = choices[players[0]];
        uint p1 = choices[players[1]];
        address winner;
        
        if ((p0 + 1) % 5 == p1 || (p0 + 3) % 5 == p1) {
            winner = players[1];
        } else if ((p1 + 1) % 5 == p0 || (p1 + 3) % 5 == p0) {
            winner = players[0];
        }
        
        if (winner != address(0)) {
            require(IERC20(address(token)).transfer(winner, reward), "Transfer failed");
        } else {
            token.transfer(players[0], reward / 2);
            token.transfer(players[1], reward / 2);
        }
        
        _resetGame();
    }
    
    function _resetGame() private {
        delete players;
        delete reward;
        gameActive = false;
    }
    
    function withdrawIfOpponentFails() public {
        require(gameActive, "Game is not active");
        require(block.timestamp > revealDeadline, "Reveal period not ended");
        
        if (hasRevealed[players[0]] && !hasRevealed[players[1]]) {
            token.transfer(players[0], reward);
        } else if (hasRevealed[players[1]] && !hasRevealed[players[0]]) {
            token.transfer(players[1], reward);
        } else {
            token.transfer(msg.sender, reward);
        }
        
        _resetGame();
    }
}
