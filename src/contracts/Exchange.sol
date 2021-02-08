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
    address mainnetUniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // TODO liquidation process
    uint256 ltv_out_of_ten = 5;

    // TODO array
    struct BorrowPosition {
        uint256 amountBase;
        uint256 priceInWei;
        uint256 asset; 
    }   

    struct DepositPosition {
        uint256 amountBase;
        uint256 asset;
    }

    struct Fraction {
        uint256 num;
        uint256 denom;
    }

    itmap openPositions;    
    using IterableMapping for itmap;
    uint256 keyCounter = 1;
    mapping(address => uint256) keys;

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
    Fraction maxProfitShareRate;
    Fraction profitShareConstant;
    Fraction maxCoverRate;

    WETHGateway weth;
    Erc20 aweth;
    PriceOracle poracle;
    Erc20 usdc;
    LendingPool lp;
    UniswapV2Router02 unirouter;

    event ProfitShareRateCalculated(uint256 num, uint256 denom);
    event CoverRateCalculated(uint256 num, uint256 denom);

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
        unirouter = UniswapV2Router02(mainnetUniswapRouter);

        pastCloses = 5;
        currentPastClosesCount = 0;
        // (MathError me, Exp memory result) = getExp(1, 1);
        // profitShareToCover = result;
        profitShareToCover = Fraction({num: 1, denom: 1});
        currentProfitShareToCover = Fraction({num: 0, denom: 0});
        supplyPoolCoverProportion = Fraction({num: 1, denom: 10});
        maxProfitShareRate = Fraction({num: 5, denom: 10});
        profitShareConstant = Fraction({num: 1, denom: 10});
        maxCoverRate = Fraction({num: 8, denom: 10});
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
        unscaledDepositsLong[msg.sender].amountBase += msg.value;
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
        require(unscaledDepositsLong[msg.sender].amountBase > 0, "user has no balance");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amountBase / principalTotalBalanceWei;

        if (all == 0) {
            require(
                amount <= msgSenderTotalDepositOwnership, "user does not own amount to withdraw"
            );
            uint256 newTotalDepositOwnership = msgSenderTotalDepositOwnership - amount;
            require(
                ltv_out_of_ten * valueOf(1, newTotalDepositOwnership, poracle.getAssetPrice(mainnetUSDC)) / 10 >= valueOf(2, unscaledBorrowsLong[msg.sender].amountBase, 1), "withdraw would cause borrow to be greater than max borrow"
            );

            uint256 x = amount * principalTotalBalanceWei / contract_aWETH_Balance;

            aweth.approve(mainnetWETHGateway, amount);
            weth.withdrawETH(amount, msg.sender);
            
            unscaledDepositsLong[msg.sender].amountBase -= x;
            principalTotalBalanceWei -= x;
        } else {
            require(unscaledBorrowsLong[msg.sender].amountBase == 0, "can't withdraw everything with outstanding borrow");

            aweth.approve(mainnetWETHGateway, msgSenderTotalDepositOwnership);
            weth.withdrawETH(msgSenderTotalDepositOwnership, msg.sender);

            principalTotalBalanceWei -= unscaledDepositsLong[msg.sender].amountBase;
            unscaledDepositsLong[msg.sender].amountBase = 0;
        }
    }
    
    /**
    @dev borrow usdc from the long pool
    @param amount of usdc to borrow in base units 
    **/
    function borrow_USDC_Long_Eth(uint256 amount) public {
        require(principalTotalBalanceWei > 0, "total principal 0");
        require(unscaledDepositsLong[msg.sender].amountBase > 0, "user has no balance");
        require(unscaledBorrowsLong[msg.sender].amountBase == 0, "user can only make one borrow for now");

        uint256 contract_aWETH_Balance = aweth.balanceOf(address(this));
        uint256 msgSenderTotalDepositOwnership = contract_aWETH_Balance * unscaledDepositsLong[msg.sender].amountBase / principalTotalBalanceWei;

        // hard coded limit on ltv, poll max ltv from aave TODO
        require(valueOf(2, amount + unscaledBorrowsLong[msg.sender].amountBase, 1) <= valueOf(1, msgSenderTotalDepositOwnership, poracle.getAssetPrice(mainnetUSDC)) * ltv_out_of_ten / 10);

        unscaledBorrowsLong[msg.sender].asset = 2;
        unscaledBorrowsLong[msg.sender].amountBase += amount;
        unscaledBorrowsLong[msg.sender].priceInWei = poracle.getAssetPrice(mainnetUSDC);

        A memory a = A({
            depositAmount: unscaledDepositsLong[msg.sender].amountBase, usdcweiPrice: unscaledBorrowsLong[msg.sender].priceInWei
        });
        openPositions.insert(keyCounter, a);
        keys[msg.sender] = keyCounter;
        keyCounter += 1;

        lp.borrow(
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 
            amount, 
            2, 
            0, 
            address(this)
        );
        usdc.transfer(msg.sender, amount);
    }

    /**
    @dev returns usdc balance of sender
    **/
    function senderUSDCBalance() public view returns(uint256) {
        return usdc.balanceOf(msg.sender);
    }

    /**
    @dev repay borrow using protocol math
    @param amount amount to repay
    @param all 1 for repay all, ignoring amount
    **/
    function repay_USDC_Long_Eth(uint256 amount, uint256 all) public {
        if (all == 1) {            
            uint256 currentPrice = poracle.getAssetPrice(mainnetUSDC);
            if (isPriceOverride) {
                // console.log("Old price:", 1000000000000000000 / currentPrice, "New price:", 1000000000000000000 / overwrittenPrice);
                currentPrice = overwrittenPrice;
            }

            bool profit = false;
            uint256 a = valueOf(1, unscaledDepositsLong[msg.sender].amountBase, poracle.getAssetPrice(mainnetUSDC));
            uint256 b = valueOf(1, unscaledDepositsLong[msg.sender].amountBase, overwrittenPrice);
            uint256 simpleDeltaDollars;
            if (a > b) {
                simpleDeltaDollars = a - b;
            } else if (a < b) {
                simpleDeltaDollars = b - a;
                profit = true;
            } else {
                console.log("unimplemented");
                simpleDeltaDollars = 0;
            }
            // console.log(simpleDeltaDollars);

            Fraction memory coverRate;
            Fraction memory profitShareRate;
            if (profitShareToCover.num == 0) {
                coverRate = Fraction({
                    num: 5,
                    denom: 100
                });
                profitShareRate = maxProfitShareRate;
            } else if (profitShareToCover.denom == 0) {
                profitShareRate = Fraction({
                    num: 5,
                    denom: 100
                });
                coverRate = maxCoverRate;
            } else {
                uint256 availableCoverage = supplyPoolCoverProportion.num * valueOf(1, queryTokenBalance(), currentPrice) / supplyPoolCoverProportion.denom;
                // console.log(availableCoverage);

                uint256 totalLossInAllOpenPositions = 0;
                for (
                    uint i = openPositions.iterate_start();
                    openPositions.iterate_valid(i);
                    i = openPositions.iterate_next(i)
                ) {
                    (, A memory value) = openPositions.iterate_get(i);
                    // reversed from natural way
                    if (value.usdcweiPrice < currentPrice) {
                        uint256 m = valueOf(1, value.depositAmount, value.usdcweiPrice);
                        uint256 n = valueOf(1, value.depositAmount, currentPrice);
                        totalLossInAllOpenPositions += m - n;
                    }
                }
                // console.log(totalLossInAllOpenPositions);

                coverRate = Fraction({num: availableCoverage, denom: totalLossInAllOpenPositions});
                if (totalLossInAllOpenPositions < availableCoverage) {
                    coverRate.num = totalLossInAllOpenPositions;
                }
                (uint256 p, uint256 q) = fracMin(coverRate.num, coverRate.denom, maxCoverRate.num, maxCoverRate.denom);
                coverRate.num = p;
                coverRate.denom = q;
                // console.log(coverRate.num, coverRate.denom);
                emit CoverRateCalculated(p, q);

                Fraction memory factor = Fraction({
                    num: profitShareToCover.denom, 
                    denom: profitShareToCover.num
                });
                (p, q) = fracMul(
                    factor.num, 
                    coverRate.num, 
                    factor.denom, 
                    coverRate.denom
                );
                (a, b) = fracAdd(
                    p, 
                    profitShareConstant.num, 
                    q, 
                    profitShareConstant.denom
                ); 
                Fraction memory reg = Fraction({
                    num: a, 
                    denom: b
                });
                (uint256 x, uint256 y) = fracMin(
                    reg.num, 
                    reg.denom, 
                    maxProfitShareRate.num, 
                    maxProfitShareRate.denom
                );
                profitShareRate = Fraction({
                    num: x, denom: y
                });
                // console.log(profitShareRate.num, profitShareRate.denom);
                emit ProfitShareRateCalculated(x, y);
            }     

            currentPastClosesCount += 1;
            if (profit) {
                currentProfitShareToCover.num += simpleDeltaDollars;
            } else {
                currentProfitShareToCover.denom += simpleDeltaDollars;
            }
            if (currentPastClosesCount == 5) {
                currentPastClosesCount = 0;
                // denom could be 0, num zero?
                profitShareToCover = Fraction({
                    num: currentProfitShareToCover.num, 
                    denom: currentProfitShareToCover.denom
                });
                currentProfitShareToCover.num = 0;
                currentProfitShareToCover.denom = 0;
            }

            // emit events and watch for them for the front end for all calculations
            // there is no debt accrued yet
            openPositions.remove(keys[msg.sender]);
            keys[msg.sender] = 0;
            if (profit) {
                (uint256 extraDebtDollars_num, uint256 extraDebtDollars_denom) = fracMul(
                    simpleDeltaDollars, 
                    1, 
                    profitShareRate.num, 
                    profitShareRate.denom
                ); 
                Fraction memory extraDebtBase_f = Fraction({
                    num: extraDebtDollars_num * 1000000, denom: extraDebtDollars_denom
                });
                uint256 extraDebtBase = 
                    extraDebtBase_f.num / extraDebtBase_f.denom;
                uint256 finalRepayAmountBase = 
                    unscaledBorrowsLong[msg.sender].amountBase + extraDebtBase;
                uint256 protocolReceivesAmountBase = 
                    extraDebtBase;

                require(
                    usdc.transferFrom(msg.sender, address(this), finalRepayAmountBase)
                );

                usdc.approve(address(lp), unscaledBorrowsLong[msg.sender].amountBase);
                lp.repay(
                    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                    unscaledBorrowsLong[msg.sender].amountBase,
                    2,
                    address(this)
                );
                // convert extra debt usdc to eth and deposit, updating ownership accordingly (already get from proportional ownership)
                // hold a larger amount of usdc before calling the swap, like when there is a a lot withdrawals 
                // min received for selling usdc, max pay for buy eth, other safety 
                require(usdc.approve(address(unirouter), protocolReceivesAmountBase), "approve failed");
                address[] memory path = new address[](2);
                path[0] = address(usdc);
                path[1] = unirouter.WETH();
                uint[] memory amounts = unirouter.swapExactTokensForETH(protocolReceivesAmountBase, 0, path, address(this), block.timestamp);
                weth.depositETH{value: amounts[1]}(address(this), 0);

                // console.log(unscaledBorrowsLong[msg.sender].amountBase, "w/ extra debt (share)", finalRepayAmountBase);
            } else {
                (uint256 lessDebtDollars_num, uint256 lessDebtDollars_denom) = fracMul(
                    simpleDeltaDollars, 
                    1, 
                    coverRate.num, 
                    coverRate.denom
                ); 
                Fraction memory lessDebtBase_f = Fraction({
                    num: lessDebtDollars_num * 1000000, denom: lessDebtDollars_denom
                });
                uint256 lessDebtBase = 
                    lessDebtBase_f.num / lessDebtBase_f.denom;
                uint256 finalRepayAmountBase = 
                    unscaledBorrowsLong[msg.sender].amountBase - lessDebtBase;
                uint256 protocolCoverAmountBase = 
                    lessDebtBase;

                // console.log(usdc.allowance(msg.sender, address(this)));
                require(
                    usdc.transferFrom(msg.sender, address(this), finalRepayAmountBase)
                );

                usdc.approve(address(lp), finalRepayAmountBase + lessDebtBase);
                lp.repay(
                    mainnetUSDC,
                    finalRepayAmountBase,
                    2,
                    address(this)
                );

                // withdraw equivalent amount of eth, swap to usdc lessDebtBase amount, then repay
                uint256 whole_USDC_WEI_price = poracle.getAssetPrice(mainnetUSDC);
                uint256 weiAmount = (whole_USDC_WEI_price * lessDebtBase) / 1000000;
                // console.log(weiAmount / 1000000000000000000);
                // console.log(
                //     aweth.balanceOf(address(this)) / 1000000000000000000
                // );
                aweth.approve(mainnetWETHGateway, weiAmount);
                weth.withdrawETH(weiAmount, address(this));

                // TODO wont get exact required usdc amount back needed to fully pay down borrow
                address[] memory path = new address[](2);
                path[1] = address(usdc);
                path[0] = unirouter.WETH();
                uint[] memory amounts = unirouter.swapExactETHForTokens{value: weiAmount}(0, path, address(this), block.timestamp);

                lp.repay(
                    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                    min(lessDebtBase, amounts[1]),
                    2,
                    address(this)
                );
                // console.log(unscaledBorrowsLong[msg.sender].amountBase / 1000000, "w/ less debt (cover)", finalRepayAmountBase / 1000000);
            }
            unscaledBorrowsLong[msg.sender].amountBase = 0;
        } else {
            console.log("unimplemented");
        }
    }

    receive() external payable {} 

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) {
            return a;
        } else {
            return b;
        }
    }

    /**
    @dev returns minimum of fractions
     */
    function fracMin(uint256 a_num, uint256 a_denom, uint256 b_num, uint256 b_denom) internal pure returns(uint256, uint256) {
        uint256 a_num_prime = a_num * b_denom;
        uint256 b_num_prime = b_num * a_denom;
        if (a_num_prime < b_num_prime) {
            return (a_num, a_denom);
        } else {
            return (b_num, b_denom);
        }
    }

    /**
    @dev returns sum of fractions
     */
    function fracAdd(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256, uint256) {
        uint256 denom = b * d;
        uint256 num = (a * d) + (c * b);
        return (num, denom);
    }

    /**
    @dev returns product of fractions
     */
    function fracMul(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256, uint256) {
        return (a * c, b * d);
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
    function valueOf(uint256 asset, uint256 amount, uint256 price) internal pure returns(uint256) {
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

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

interface LendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external;

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
}

interface PriceOracle {
    function getAssetPrice(address _asset) external view returns(uint256);
}

interface LPAddressesProvider {
    function getPriceOracle() external returns (address);
}

interface UniswapV2Router02 {
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);

    function WETH() external pure returns (address);
}

struct A {
    uint256 depositAmount;
    uint256 usdcweiPrice;
}
// Solidity docs
struct IndexValue { uint keyIndex; A value; }
struct KeyFlag { uint key; bool deleted; }

struct itmap {
    mapping(uint => IndexValue) data;
    KeyFlag[] keys;
    uint size;
}

library IterableMapping {
    function insert(itmap storage self, uint key, A memory value) internal returns (bool replaced) {
        uint keyIndex = self.data[key].keyIndex;
        self.data[key].value = value;
        if (keyIndex > 0)
            return true;
        else {
            keyIndex = self.keys.length;
            self.keys.push();
            self.data[key].keyIndex = keyIndex + 1;
            self.keys[keyIndex].key = key;
            self.size++;
            return false;
        }
    }

    function remove(itmap storage self, uint key) internal returns (bool success) {
        uint keyIndex = self.data[key].keyIndex;
        if (keyIndex == 0)
            return false;
        delete self.data[key];
        self.keys[keyIndex - 1].deleted = true;
        self.size --;
    }

    function contains(itmap storage self, uint key) internal view returns (bool) {
        return self.data[key].keyIndex > 0;
    }

    function iterate_start(itmap storage self) internal view returns (uint keyIndex) {
        return iterate_next(self, uint(-1));
    }

    function iterate_valid(itmap storage self, uint keyIndex) internal view returns (bool) {
        return keyIndex < self.keys.length;
    }

    function iterate_next(itmap storage self, uint keyIndex) internal view returns (uint r_keyIndex) {
        keyIndex++;
        while (keyIndex < self.keys.length && self.keys[keyIndex].deleted)
            keyIndex++;
        return keyIndex;
    }

    function iterate_get(itmap storage self, uint keyIndex) internal view returns (uint key, A memory value) {
        key = self.keys[keyIndex].key;
        value = self.data[key].value;
    }
}