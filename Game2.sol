// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game is ConfirmedOwner {
   
    event WinnerPrized(address winner, uint256 price);
    event WinnerChoosed(uint256 randomNumber, address winner);

    
    address [] players;
    mapping(address => uint256) public PlayerBlance;
    uint256 private seed;

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

    
    function deposit(uint256 amount) external {

        uint256 bal = PlayerBlance[msg.sender];
        bal = bal + amount;
        require(bal >= tokenUnit, "non efficient amount");
        require(token.allowance(msg.sender, address(this)) >= amount, "non approved amount");
        token.transferFrom(msg.sender, address(this), amount);
        uint256 depositedAmount;
        for ( uint8 i = 0 ; i < bal / tokenUnit; i++){
            players.push(msg.sender);
            depositedAmount += tokenUnit;
        }  
        bal = bal - depositedAmount;
        PlayerBlance[msg.sender] = bal;
        
    }
 
    function chooseWinner() public onlyOwner {
        uint256 userCount = players.length;
        require(userCount > 0, "no valid depositors");
        uint256 rnd = uint(keccak256(abi.encodePacked(seed, blockhash(block.number)))) % userCount ;
        address winner = players[rnd];
        emit WinnerChoosed( rnd, winner);
        delete players;
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
