# rpsls

### 1. **ป้องกันการ lock เงินไว้ใน contract**

- **การจ่ายเงินรางวัลอัตโนมัติ (`_checkWinnerAndPay`)**: เมื่อผู้เล่นทั้งสองเปิดเผยตัวเลือกของตน ระบบจะคำนวณผลและโอนเงินรางวัลไปยังผู้ชนะโดยอัตโนมัติ
- **กลไก Timeout (`withdrawIfOpponentFails`)**: หากผู้เล่นฝ่ายหนึ่งไม่เปิดเผยตัวเลือกของตนภายใน **5 นาที** อีกฝ่ายสามารถถอนเงินรางวัลทั้งหมดได้

```solidity
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
```

### 2. **การซ่อน choice และ commit**

เพื่อป้องกันไม่ให้คู่แข่งทราบตัวเลือกของอีกฝ่ายก่อนการเปิดเผย ผู้เล่นต้อง commit โดยใช้ค่าแฮชของตัวเลือกที่รวมกับค่า **secret** ก่อน เมื่อ commit แล้ว ผู้เล่นต้องเปิดเผยตัวเลือกพร้อมค่า secret เพื่อให้ระบบตรวจสอบความถูกต้อง

#### ขั้นตอน:

1. **Commit**: ผู้เล่นสร้างแฮชโดยใช้ `keccak256(abi.encodePacked(choice, secret))` และส่งค่าแฮชนั้นไปยังสัญญา
2. **Reveal**: หลังจากทั้งสองฝ่าย commit แล้ว พวกเขาจะเปิดเผยตัวเลือกและ secret ของตนเพื่อให้ระบบตรวจสอบ


**ขั้นตอน Commit**

```solidity
function joinGame(bytes32 commitment) public payable onlyAllowedPlayers {
    require(players.length < 2, "Game already has two players");
    require(msg.value == 1 ether, "Must send exactly 1 ether");

    players.push(msg.sender);
    commitments[msg.sender] = commitment;
    reward += msg.value;

    if (players.length == 2) {
        gameStartTime = block.timestamp;
        gameActive = true;
    }
}
```

**ขั้นตอน Reveal**

```solidity
function revealChoice(uint choice, string memory secret) public onlyAllowedPlayers {
    require(gameActive, "Game is not active");
    require(choice >= 0 && choice <= 4, "Invalid choice");
    require(commitments[msg.sender] == keccak256(abi.encodePacked(choice, secret)), "Commitment mismatch");
    
    choices[msg.sender] = choice;
    
    if (choices[players[0]] != 0 && choices[players[1]] != 0) {
        _checkWinnerAndPay();
    }
}
```

### 3. **จัดการกรณีที่ผู้เล่นเข้าร่วมไม่ครบ**

หากมีผู้เล่นเพียงคนเดียวเข้าร่วมและไม่มีคู่แข่ง ระบบจะอนุญาตให้ผู้เล่นถอนเงินคืนได้หลังจากเวลาผ่านไปตามที่กำหนด

```solidity
function withdrawIfOpponentFails() public onlyAllowedPlayers {
    require(gameActive, "Game is not active");
    require(block.timestamp >= gameStartTime + 5 minutes, "Wait time not over");

    if (players.length == 1) {
        payable(players[0]).transfer(reward);
    }

    _resetGame();
}
```

### 4. **การ reveal และนำ choice มาตัดสินผู้ชนะ**

เมื่อผู้เล่นทั้งสองเปิดเผยตัวเลือกของตน ระบบจะใช้กฎของ RPSLS เพื่อตัดสินผลลัพธ์:

- **(p0 + 1) % 5 == p1 หรือ (p0 + 3) % 5 == p1** → ผู้เล่น 1 ชนะ
- **(p1 + 1) % 5 == p0 หรือ (p1 + 3) % 5 == p0** → ผู้เล่น 0 ชนะ
- ถ้าไม่ตรงตามข้างบน เกมจะเสมอและคืนเงินให้ทั้งสองฝ่าย

```solidity
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
```

