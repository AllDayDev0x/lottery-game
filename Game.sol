// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game is ConfirmedOwner {
   
    event WinnerPrized(address winner, uint256 price);
    event WinnerChoosed(uint256 randomNumber, address winner);
    event BoundSet(uint256 Lower, uint256 Upper);
    event SoldSlot(uint256 SlotNumber, address player);
    event WonSlot(uint256 slotNumber);

    mapping(address => uint256) public PlayerBlance;
    uint256 private seed;
    uint256 public upperBound;
    uint256 public lowerBound;
    uint256[] slotList;
    uint256[] soldSlotList;
    mapping (uint256 => address) playersOfSlot;

    // Addresses
    address projectWalletAddress;
    address burnWalletAddress;

    // Others
    IERC20 public token;
    uint256 public constant tokenUnit = 10 ** 18;

    constructor(
        address _tokenAddr,
        address _projectWalletAddr,
        address _burnWalletAddr,
        uint256 _seed
    ) 
        ConfirmedOwner(msg.sender)
    {
        token = IERC20(_tokenAddr);
        projectWalletAddress = _projectWalletAddr;
        burnWalletAddress = _burnWalletAddr;
        seed = _seed;
    }

    /* set upper bound and lower bound */
    function setBound (uint256 upper, uint256 lower) external onlyOwner{
        upperBound = upper;
        lowerBound = lower;
        emit BoundSet(lower, upper);
    }

    /* buy slot */
    function buySlot (uint256 slotNumber) external{
        require(PlayerBlance[msg.sender] > tokenUnit, "Fund not enought!");
        require(upperBound > 0 && lowerBound > 0);
        require(playersOfSlot[slotNumber] == address(0), "This slot was slod");
        require(upperBound >= slotNumber && slotNumber >= lowerBound, "This slot not available");

        uint256 balance = PlayerBlance[msg.sender];
        balance -= tokenUnit;
        playersOfSlot[slotNumber] = msg.sender;
        PlayerBlance[msg.sender] = balance;
        soldSlotList.push(slotNumber);
        emit SoldSlot(slotNumber, msg.sender);
    }  

    function deposit(uint256 amount) external {

        uint256 bal = PlayerBlance[msg.sender];
        bal = bal + amount;
        
        require(token.allowance(msg.sender, address(this)) >= amount, "non approved amount");
        token.transferFrom(msg.sender, address(this), amount);
        PlayerBlance[msg.sender] = bal;
        
    }
 
    function chooseWinner() public onlyOwner {
      
        uint256 rnd = lowerBound + uint(keccak256(abi.encodePacked(seed, blockhash(block.number)))) % (upperBound - lowerBound) ;
        uint256 winnerSlot = rnd;
        address winner = playersOfSlot[winnerSlot];
        
        // require(winner != address(0), "No winner, the prize go next round");
        if(winner == address(0)){
            rnd = uint(keccak256(abi.encodePacked(seed, blockhash(block.number)))) % soldSlotList.length;
            winnerSlot = soldSlotList[rnd];
            winner = playersOfSlot[winnerSlot];
            emit WonSlot(winnerSlot);

        }else{
            emit WonSlot(winnerSlot);
            
        }
        
        emit WinnerChoosed( winnerSlot, winner);
        prizeWinner(winner);
      
    }
    
    function prizeWinner(address _winner) internal {
        uint256 balance = address(this).balance;
        uint256 bal_winner = balance * 80 / 100;
        uint256 bal_project = balance * 15 / 100;

        (bool success, ) = payable(_winner).call{value: bal_winner}("");
        require(success, "transfer failed");
        emit WinnerPrized(_winner,bal_winner);
        (success, ) = payable(projectWalletAddress).call{value: bal_project}("");
        require(success, "transfer failed");
    }

    
    function setSeed( uint256 _seed) external onlyOwner{
        seed = _seed;
    }
    
    function withdrawEth() public onlyOwner{
        
        payable(address(msg.sender)).transfer( address(this).balance);

    }
    receive() external payable {}
}
