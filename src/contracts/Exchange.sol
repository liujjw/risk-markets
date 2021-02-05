// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "hardhat/console.sol";
// import "./Exponential.sol";

contract Exchange {
    address kovanAaveLendingPool = 0x9FE532197ad76c5a68961439604C037EB79681F0;
    address mainnetAaveLendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address mainnetWETHGateway = 0xDcD33426BA191383f1c9B431A342498fdac73488;
    address kovanWETHGateway = 0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF;
    address mainnetaWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    // TODO fetching addresses
    address mainnetLPAddrsProvider = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
    // address kovanLPAddrsProvider = 0x88757f2f99175387ab4c6a4b3067c77a695b0349;
    address mainnetUSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // TODO liquidation process
    uint256 ltv_out_of_ten = 5;

    // TODO array
    struct BorrowPosition {
        uint256 amountBaseUnits;
        uint256 priceInWei;
        uint256 asset; 
    }   

    struct DepositPosition {
        uint256 amountBaseUnits;
        uint256 asset;
    }

    struct Fraction {
        uint256 num;
        uint256 denom;
    }

    mapping(address => DepositPosition) unscaledDepositsLong; 
    uint256 principalTotalBalanceWei;
    mapping(address => BorrowPosition) unscaledBorrowsLong; 
    bool isPriceOverride;
    uint256 overwrittenPrice;
    uint256 pastCloses;
    uint256 currentPastClosesCount;
    // Exp profitShareToCover; 
    Fraction profitShareToCover;
    Fraction currentProfitShareToCover;
    Fraction supplyPoolCoverProportion;

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

        pastCloses = 5;
        currentPastClosesCount = 0;
        // (MathError me, Exp memory result) = getExp(1, 1);
        // profitShareToCover = result;
        profitShareToCover = Fraction({num: 1, denom: 1});
        currentProfitShareToCover = Fraction({num: 0, denom: 0});
        supplyPoolCoverProportion = Fraction({num: 1, denom: 10});
    }

    /**
    @dev receives eth from user to supply for long
    **/   
    function depositLongEth() payable public {
        // LendingPool lp = LendingPool(mainnetAaveLendingPool);
        // lp.deposit(asset, amount, address(this), 0);
        // console.log("ETH balance before: ", address(this).balance);

        weth.depositETH{value: msg.value}(address(this), 0);
        principalTotalBalanceWei += msg.value;
        unscaledDepositsLong[msg.sender].amountBaseUnits += msg.value;
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
        require(principalTotalBalanceWei > 0, "total principal 0");
        require(unscaledDepositsLong[msg.sender].amountBaseUnits > 0, "user has no balance");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amountBaseUnits / principalTotalBalanceWei;

        if (all == 0) {
            require(amount <= msgSenderTotalDepositOwnership, "user does not own amount to withdraw");
            uint256 newTotalDepositOwnership = msgSenderTotalDepositOwnership - amount;
            require(ltv_out_of_ten * valueOf(1, newTotalDepositOwnership, poracle.getAssetPrice(mainnetUSDC)) / 10 >= valueOf(2, unscaledBorrowsLong[msg.sender].amountBaseUnits, 1), "withdraw would cause borrow to be greater than max borrow");

            uint256 x = amount * principalTotalBalanceWei / contract_aWETH_Balance;

            aweth.approve(mainnetWETHGateway, amount);
            weth.withdrawETH(amount, msg.sender);
            
            unscaledDepositsLong[msg.sender].amountBaseUnits -= x;
            principalTotalBalanceWei -= x;
        } else {
            require(unscaledBorrowsLong[msg.sender].amountBaseUnits == 0, "can't withdraw everything with outstanding borrow");

            aweth.approve(mainnetWETHGateway, msgSenderTotalDepositOwnership);
            weth.withdrawETH(msgSenderTotalDepositOwnership, msg.sender);

            principalTotalBalanceWei -= unscaledDepositsLong[msg.sender].amountBaseUnits;
            unscaledDepositsLong[msg.sender].amountBaseUnits = 0;
        }
    }
    
    /**
    @dev borrow usdc from the long pool
    @param amount of usdc to borrow in base units 
    **/
    function borrow_USDC_Long_Eth(uint256 amount) public {
        require(principalTotalBalanceWei > 0, "total principal 0");
        require(unscaledDepositsLong[msg.sender].amountBaseUnits > 0, "user has no balance");
        require(unscaledBorrowsLong[msg.sender].amountBaseUnits == 0, "user can only make one borrow for now");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amountBaseUnits / principalTotalBalanceWei;

        // hard coded limit on ltv, poll max ltv from aave TODO
        require(valueOf(2, amount + unscaledBorrowsLong[msg.sender].amountBaseUnits, 1) <= valueOf(1, msgSenderTotalDepositOwnership, poracle.getAssetPrice(mainnetUSDC)) * ltv_out_of_ten / 10);

        unscaledBorrowsLong[msg.sender].asset = 2;
        unscaledBorrowsLong[msg.sender].amountBaseUnits += amount;
        unscaledBorrowsLong[msg.sender].priceInWei = poracle.getAssetPrice(mainnetUSDC);

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
    // TODO need to ACUTALLY repay the usdc
    function repay_USDC_Long_Eth(uint256 amount, uint256 all) payable public {
        if (all == 1) {
            // currentPastClosesCount += 1;
            unscaledBorrowsLong[msg.sender].amountBaseUnits = 0;

            uint256 currentPrice = poracle.getAssetPrice(mainnetUSDC);
            if (isPriceOverride) {
                // console.log("Old price:", 1000000000000000000 / currentPrice, "New price:", 1000000000000000000 / overwrittenPrice);
                currentPrice = overwrittenPrice;
            }

            bool profit = false;
            uint256 a = valueOf(1, unscaledDepositsLong[msg.sender].amountBaseUnits, poracle.getAssetPrice(mainnetUSDC));
            uint256 b = valueOf(1, unscaledDepositsLong[msg.sender].amountBaseUnits, overwrittenPrice);
            uint256 c;
            if (a > b) {
                c = a - b;
            } else if (a < b) {
                c = b - a;
                profit = true;
            } else {
                console.log("unimplemented");
                c = 0;
            }

            (uint256 c_num, uint256 c_denom) = getC();
            
            // if (profit) {
            //     currentProfitShareToCover.num += profitShareAmnt;
            // } else {
            //     currentProfitShareToCover.denom += lossCoverageAmnt;
            // }
            // Exponential.Exp ratio = profitShareToCover;
            // if (currentPastClosesCount == 5) {
            //     currentPastClosesCount = 0;
            //     // denom could be 0
            //     ratio = Exponential.Exp();
            // }
        } else {
            console.log("unimplemented");
        }
    }

    /**
    @dev returns cover rate
     */
    function getC() internal view returns(uint256, uint256) {
        uint256 availableCoverage = supplyPoolCoverProportion.num * queryTokenBalance() 
    } 

    /**
    @dev sets price of usdc for testing, disable for live
    **/
    function overridePrice(uint256 price) public {
        isPriceOverride = true;
        overwrittenPrice = price;
    }

    /**
    @dev returns the value of asset in whole usdc
    @param asset the type of asset, 1 for eth, 2 for usdc
    @param amount of the asset in base units 
    **/
    function valueOf(uint256 asset, uint256 amount, uint256 price) private view returns(uint256) {
        if (asset == 1) {
            // (amount / 1000000000000000000) * (1000000000000000000 / a)
            return amount / price;
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