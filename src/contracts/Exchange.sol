// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "hardhat/console.sol";

contract Exchange {
    address kovanAaveLendingPool = 0x9FE532197ad76c5a68961439604C037EB79681F0;
    address mainnetAaveLendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address mainnetWETHGateway = 0xDcD33426BA191383f1c9B431A342498fdac73488;
    address kovanWETHGateway = 0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF;
    address mainnetaWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;

    mapping(address => uint256) unscaledBalancesLong;
    uint256 principalTotalBalance;

    WETHGateway weth;
    Erc20 aweth;

    /**
    * @dev inits abstractions of contracts
    **/
    constructor() public {
        weth = WETHGateway(mainnetWETHGateway);
        aweth = Erc20(mainnetaWETH);
    }

    /**
    * @dev receives eth from user to supply for long
    **/   
    function depositLongEth() payable public {
        // LendingPool lp = LendingPool(mainnetAaveLendingPool);
        // lp.deposit(asset, amount, address(this), 0);
        // console.log("ETH balance before: ", address(this).balance);

        weth.depositETH{value: msg.value}(address(this), 0);
        principalTotalBalance += msg.value;
        unscaledBalancesLong[msg.sender] += msg.value;

        // console.log("aWETH balance after deposit: ", aweth.balanceOf(address(this)));
        // console.log("ETH balance after deposit: ", address(this).balance);

    }

    /** 
    * @dev returns aweth balance of contract
    **/
    function queryTokenBalance() public view returns(uint256) {
        return aweth.balanceOf(address(this));
    }
    
    /**
    * @dev returns eth to user
    * @param amount amount of eth to withdraw
    * @param all whether to withdraw everything, 0 for false 1 for true, ignores amount
    **/
    function withdrawLongEth(uint256 amount, uint256 all) public {
        // lp.withdraw(asset, amount, msg.sender);
        require(principalTotalBalance > 0, "total principal 0");
        require(unscaledBalancesLong[msg.sender] > 0, "user has no balance");
        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 totalOwnership = contract_aWETH_Balance * unscaledBalancesLong[msg.sender] / principalTotalBalance;
        if (all == 0) {
            require(amount <= totalOwnership, "invalid amount");
            uint256 x = amount * principalTotalBalance / contract_aWETH_Balance;
            aweth.approve(mainnetWETHGateway, amount);
            weth.withdrawETH(amount, msg.sender);
            unscaledBalancesLong[msg.sender] -= x;
            principalTotalBalance -= x;
        } else {
            aweth.approve(mainnetWETHGateway, totalOwnership);
            weth.withdrawETH(totalOwnership, msg.sender);
            principalTotalBalance -= unscaledBalancesLong[msg.sender];
            unscaledBalancesLong[msg.sender] = 0;
        }
    }
    
    /**
    * @dev 
    * @param
    **/
    // function borrowLongEth(uint256 amount) public {
    //     uint256 totalOwnership = address(this).balance * unscaledBalancesLong[msg.sender] / principalTotalBalance;
    //     // hard coded limit on ltv, poll max ltv from aave todo
    //     require(amount <= totalOwnership * 8 / 10);
    //     weth.borrowETH(amount, 1, 0);
    //     msg.sender.transfer(amount);    
    // }

    /**
    * @dev 
    * @param
    **/
    // function repayLongEth() payable public {

    // }
}

interface WETHGateway {
    function depositETH(address onBehalfOf, uint16 referralCode) payable external;

    function withdrawETH(uint256 amount, address to) external;

    function borrowETH(uint256 amount, uint256 interestRateMode, uint16 referralCode) external;

    function repayETH(uint256 amount, uint256 rateMode, address onBehalfOf) external;
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function balanceOf(address _owner) external view returns (uint256 balance);
}

interface LendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external;
}