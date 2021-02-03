// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "hardhat/console.sol";

contract Exchange {
    address kovanAaveLendingPool = 0x9FE532197ad76c5a68961439604C037EB79681F0;
    address mainnetAaveLendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address mainnetWETHGateway = 0xDcD33426BA191383f1c9B431A342498fdac73488;
    address kovanWETHGateway = 0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF;
    address mainnetaWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    // TODO switch to fetching registry addresses
    address mainnetLPAddrsProvider = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    // address kovanLPAddrsProvider = 0x88757f2f99175387ab4c6a4b3067c77a695b0349;
    address mainnetUSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // TODO liquidation process
    uint256 ltv_out_of_ten = 5;

    // TODO a List (solidity array works) of borrows for a user at certain prices
    struct BorrowPosition {
        uint256 amount;
        uint256 ETH_USDC_price;
        uint256 asset; 
    }   

    struct DepositPosition {
        uint256 amount;
        uint256 asset;
    }

    mapping(address => DepositPosition) unscaledDepositsLong; 
    uint256 principalTotalBalanceEth;
    mapping(address => BorrowPosition) unscaledBorrowsLong; 
    bool isPriceOverride;
    uint256 overridenPrice;
    uint256 pastCloses = 10;
    uint256 currentPastClosesCount = 0;

    WETHGateway weth;
    Erc20 aweth;
    PriceOracle poracle;
    Erc20 usdc;
    LendingPool lp;

    /**
    @dev inits abstractions of contracts
    **/
    constructor() public {
        LPAddressesProvider lpap = LPAddressesProvider(mainnetLPAddrsProvider);
        address poracleAddr = lpap.getPriceOracle();
        poracle = PriceOracle(poracleAddr);
        
        weth = WETHGateway(mainnetWETHGateway);
        aweth = Erc20(mainnetaWETH);
        lp = LendingPool(mainnetAaveLendingPool);
        usdc = Erc20(mainnetUSDC);
    }

    /**
    @dev receives eth from user to supply for long
    **/   
    function depositLongEth() payable public {
        // LendingPool lp = LendingPool(mainnetAaveLendingPool);
        // lp.deposit(asset, amount, address(this), 0);
        // console.log("ETH balance before: ", address(this).balance);

        weth.depositETH{value: msg.value}(address(this), 0);
        principalTotalBalanceEth += msg.value;
        unscaledDepositsLong[msg.sender].amount += msg.value;
        unscaledDepositsLong[msg.sender].asset = 1;

        // console.log("aWETH balance after deposit: ", aweth.balanceOf(address(this)));
        // console.log("ETH balance after deposit: ", address(this).balance);

    }

    /** 
    @dev returns aweth balance of contract
    **/
    function queryTokenBalance() public view returns(uint256) {
        return aweth.balanceOf(address(this));
    }
    
    /**
    @dev returns eth to user
    @param amount amount of eth to withdraw
    @param all whether to withdraw everything, 0 for false 1 for true, ignores amount
    **/
    function withdrawLongEth(uint256 amount, uint256 all) public {
        // lp.withdraw(asset, amount, msg.sender);
        require(principalTotalBalanceEth > 0, "total principal 0");
        require(unscaledDepositsLong[msg.sender].amount > 0, "user has no balance");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amount / principalTotalBalanceEth;

        if (all == 0) {
            require(amount <= msgSenderTotalDepositOwnership, "user does not own amount to withdraw");
            uint256 newTotalDepositOwnership = msgSenderTotalDepositOwnership - amount;
            require(ltv_out_of_ten * valueOf(newTotalDepositOwnership, 1) / 10 >= valueOf(unscaledBorrowsLong[msg.sender].amount, 2), "withdraw would cause borrow to be greater than max borrow");

            uint256 x = amount * principalTotalBalanceEth / contract_aWETH_Balance;

            aweth.approve(mainnetWETHGateway, amount);
            weth.withdrawETH(amount, msg.sender);
            
            unscaledDepositsLong[msg.sender].amount -= x;
            principalTotalBalanceEth -= x;
        } else {
            require(unscaledBorrowsLong[msg.sender].amount == 0, "can't withdraw everything with outstanding borrow");

            aweth.approve(mainnetWETHGateway, msgSenderTotalDepositOwnership);
            weth.withdrawETH(msgSenderTotalDepositOwnership, msg.sender);

            principalTotalBalanceEth -= unscaledDepositsLong[msg.sender].amount;
            unscaledDepositsLong[msg.sender].amount = 0;
        }
    }
    
    /**
    @dev borrow usdc from the long pool
    @param amount of usdc to borrow in base units 
    **/
    function borrow_USDC_Long_Eth(uint256 amount) public {
        require(principalTotalBalanceEth > 0, "total principal 0");
        require(unscaledDepositsLong[msg.sender].amount > 0, "user has no balance");
        require(unscaledBorrowsLong[msg.sender].amount == 0, "user can only make one borrow for now");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amount / principalTotalBalanceEth;

        // hard coded limit on ltv, poll max ltv from aave TODO
        require(valueOf(amount + unscaledBorrowsLong[msg.sender].amount, 2) <= valueOf(msgSenderTotalDepositOwnership, 1) * ltv_out_of_ten / 10);

        unscaledBorrowsLong[msg.sender].asset = 2;
        unscaledBorrowsLong[msg.sender].amount += amount;
        unscaledBorrowsLong[msg.sender].ETH_USDC_price = get_ETH_USDC_Price();

        lp.borrow(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount, 2, 0, address(this));
        usdc.transfer(msg.sender, amount);
    }

    /**
    @dev returns usdc balance of sender
    **/
    function USDC_Balance() public view returns(uint256) {
        return usdc.balanceOf(msg.sender);
    }

    /**
    @dev repay borrow using protocol math
    @param amount amount to repay
    @param all 1 for repay all, ignoring amount
    **/
    function repay_USDC_Long_Eth(uint256 amount, uint256 all) payable public {
        if (all == 1) {

        } else {
            console.log("unimplemented");
        }
    }

    /**
    @dev sets price of eth for testing, disable for live
    @param newCurrentPrice new current price of eth 
    **/
    function overridePrice(uint256 newCurrentPrice) public {
        isPriceOverride = true;
        overridenPrice = newCurrentPrice;
    }

    /**
    @dev calculates eth/usdc price after fetching usdc/eth price from aave price orcale
    **/
    function get_ETH_USDC_Price() public view returns(uint256) {
        uint256 usdc_eth_price_in_wei = poracle.getAssetPrice(mainnetUSDC);
        uint256 wei_per_eth = 1000000000000000000;
        uint256 k = wei_per_eth / usdc_eth_price_in_wei;
        // console.log(k);
        return k;
    }

    /**
    @dev returns the value of asset in usdc
    @param asset the type of asset, 1 for eth, 2 for usdc
    @param amount of the asset in base units 
    **/
    function valueOf(uint256 asset, uint256 amount) private view returns(uint256) {
        if (asset == 1) {
            (amount / 1000000000000000000) * get_ETH_USDC_Price();
        } else if (asset == 2) {
            return amount / 1000000;
        }
    }
}

interface WETHGateway {
    function depositETH(address onBehalfOf, uint16 referralCode) payable external;

    function withdrawETH(uint256 amount, address to) external;

    function borrowETH(uint256 amount, uint256 interestRateMode, uint16 referralCode) external;

    function repayETH(uint256 amount, uint256 rateMode, address onBehalfOf) external;

    function getWETHAddress() external returns (address);
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function balanceOf(address _owner) external view returns (uint256 balance);
}

interface LendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external;

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
}

interface PriceOracle {
    function getAssetPrice(address _asset) external view returns(uint256);
}

interface LPAddressesProvider {
    function getPriceOracle() external returns (address);
}