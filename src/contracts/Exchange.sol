pragma solidity >=0.6.12;

import "ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange {
    // user needs to call corresponding erc20's approve for kovan lending pool 
    address kovanLendingPool = 0x9FE532197ad76c5a68961439604C037EB79681F0;
    mapping(address => uint256) unscaledBalancesLong;
    
    constructor() public {
        
    }
    
    function depositLong(address asset, uint256 amount) {
        ILendingPool lp = ILendingPool(kovanLendingPool);
        // perhaps add bTokens, an ERC20 given to depositors
        lp.deposit(asset, amount, address(this), 0);
        unscaledBalancesLong[msg.sender] = unscaledBalancesLong[msg.sender] + amount;
        Erc20 erc20 = Erc20(asset);
        erc20.approve()
    }
    
    function withdrawLong(address asset, uint256 amount) {
        ILendingPool lp = ILendingPool(kovanLendingPool);
        lp.withdraw(asset, amount, msg.sender);
    }
    
    function depositShort(address asset, uint256 amount) {
        
    }
    
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}
