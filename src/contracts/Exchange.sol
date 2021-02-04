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
    Exp profitShareToCover; 
    Fraction currentProfitShareToCover;

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
        (MathError me, Exp memory result) = getExp(1, 1);
        profitShareToCover = result;
        currentProfitShareToCover = Fraction({num: 0, denom: 0});
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

            // (MathError m1, Exp memory fmtNewPrice) = getExp(1, currentPrice);
            // (MathError m2, Exp memory fmtOldPrice) = getExp(1, unscaledBorrowsLong[msg.sender].priceInWei);
            // uint256 positionSize = unscaledBorrowsLong[msg.sender].amountBaseUnits;
            // Exp memory larger;
            // Exp memory smaller;
            // bool profit;
            // if (lessThanExp(fmtNewPrice, fmtOldPrice)) {
            //     larger = fmtOldPrice;
            //     smaller = fmtNewPrice;
            //     profit = false;
            // } else if (greaterThanExp(fmtNewPrice, fmtOldPrice)) {
            //     larger = fmtNewPrice;
            //     smaller = fmtOldPrice;
            //     profit = true;
            // } else {
            //     console.log("unimplemented");
            // }
            // (MathError me1, Exp memory e1) = mulScalar(larger, positionSize);
            // (MathError me2, Exp memory e2) = mulScalar(smaller, positionSize);
            // (MathError me3, Exp memory simpleDelta) = subExp(e1, e2);
            // console.log(truncate(simpleDelta));
   
            uint256 a = valueOf(1, unscaledDepositsLong[msg.sender].amountBaseUnits, poracle.getAssetPrice(mainnetUSDC));
            uint256 b = valueOf(1, unscaledDepositsLong[msg.sender].amountBaseUnits, overwrittenPrice);
            uint256 c;
            if (a > b) {
                c = a - b;
            } else if (a < b) {
                c = b - a;
            } else {
                console.log("unimplemented");
                c = 0;
            }
            // console.log("contract calculated delta", c);

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

    // BEGIN TODO import properly ---------------------------------------------
    /**
    * @title Careful Math
    * @author Compound
    * @notice Derived from OpenZeppelin's SafeMath library
    *         https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
    */
    /**
     * @dev Possible error codes that we can return
     */
    enum MathError {
        NO_ERROR,
        DIVISION_BY_ZERO,
        INTEGER_OVERFLOW,
        INTEGER_UNDERFLOW
    }

    /**
    * @dev Multiplies two numbers, returns an error on overflow.
    */
    function mulUInt(uint a, uint b) internal pure returns (MathError, uint) {
        if (a == 0) {
            return (MathError.NO_ERROR, 0);
        }

        uint c = a * b;

        if (c / a != b) {
            return (MathError.INTEGER_OVERFLOW, 0);
        } else {
            return (MathError.NO_ERROR, c);
        }
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function divUInt(uint a, uint b) internal pure returns (MathError, uint) {
        if (b == 0) {
            return (MathError.DIVISION_BY_ZERO, 0);
        }

        return (MathError.NO_ERROR, a / b);
    }

    /**
    * @dev Subtracts two numbers, returns an error on overflow (i.e. if subtrahend is greater than minuend).
    */
    function subUInt(uint a, uint b) internal pure returns (MathError, uint) {
        if (b <= a) {
            return (MathError.NO_ERROR, a - b);
        } else {
            return (MathError.INTEGER_UNDERFLOW, 0);
        }
    }

    /**
    * @dev Adds two numbers, returns an error on overflow.
    */
    function addUInt(uint a, uint b) internal pure returns (MathError, uint) {
        uint c = a + b;

        if (c >= a) {
            return (MathError.NO_ERROR, c);
        } else {
            return (MathError.INTEGER_OVERFLOW, 0);
        }
    }

    /**
    * @dev add a and b and then subtract c
    */
    function addThenSubUInt(uint a, uint b, uint c) internal pure returns (MathError, uint) {
        (MathError err0, uint sum) = addUInt(a, b);

        if (err0 != MathError.NO_ERROR) {
            return (err0, 0);
        }

        return subUInt(sum, c);
    }

    /**
    * @title Exponential module for storing fixed-precision decimals
    * @author Compound
    * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
    *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
    *         `Exp({mantissa: 5100000000000000000})`.
    */

    uint constant expScale = 1e18;
    uint constant halfExpScale = expScale/2;
    uint constant mantissaOne = expScale;

    struct Exp {
        uint mantissa;
    }

    /**
     * @dev Creates an exponential from numerator and denominator values.
     *      Note: Returns an error if (`num` * 10e18) > MAX_INT,
     *            or if `denom` is zero.
     */
    function getExp(uint num, uint denom) pure internal returns (MathError, Exp memory) {
        (MathError err0, uint scaledNumerator) = mulUInt(num, expScale);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        (MathError err1, uint rational) = divUInt(scaledNumerator, denom);
        if (err1 != MathError.NO_ERROR) {
            return (err1, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: rational}));
    }

    /**
     * @dev Adds two exponentials, returning a new exponential.
     */
    function addExp(Exp memory a, Exp memory b) pure internal returns (MathError, Exp memory) {
        (MathError error, uint result) = addUInt(a.mantissa, b.mantissa);

        return (error, Exp({mantissa: result}));
    }

    /**
     * @dev Subtracts two exponentials, returning a new exponential.
     */
    function subExp(Exp memory a, Exp memory b) pure internal returns (MathError, Exp memory) {
        (MathError error, uint result) = subUInt(a.mantissa, b.mantissa);

        return (error, Exp({mantissa: result}));
    }

    /**
     * @dev Multiply an Exp by a scalar, returning a new Exp.
     */
    function mulScalar(Exp memory a, uint scalar) pure internal returns (MathError, Exp memory) {
        (MathError err0, uint scaledMantissa) = mulUInt(a.mantissa, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: scaledMantissa}));
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mulScalarTruncate(Exp memory a, uint scalar) pure internal returns (MathError, uint) {
        (MathError err, Exp memory product) = mulScalar(a, scalar);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return (MathError.NO_ERROR, truncate(product));
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mulScalarTruncateAddUInt(Exp memory a, uint scalar, uint addend) pure internal returns (MathError, uint) {
        (MathError err, Exp memory product) = mulScalar(a, scalar);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return addUInt(truncate(product), addend);
    }

    /**
     * @dev Divide an Exp by a scalar, returning a new Exp.
     */
    function divScalar(Exp memory a, uint scalar) pure internal returns (MathError, Exp memory) {
        (MathError err0, uint descaledMantissa) = divUInt(a.mantissa, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: descaledMantissa}));
    }

    /**
     * @dev Divide a scalar by an Exp, returning a new Exp.
     */
    function divScalarByExp(uint scalar, Exp memory divisor) pure internal returns (MathError, Exp memory) {
        /*
          We are doing this as:
          getExp(mulUInt(expScale, scalar), divisor.mantissa)
          How it works:
          Exp = a / b;
          Scalar = s;
          `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
        */
        (MathError err0, uint numerator) = mulUInt(expScale, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }
        return getExp(numerator, divisor.mantissa);
    }

    /**
     * @dev Divide a scalar by an Exp, then truncate to return an unsigned integer.
     */
    function divScalarByExpTruncate(uint scalar, Exp memory divisor) pure internal returns (MathError, uint) {
        (MathError err, Exp memory fraction) = divScalarByExp(scalar, divisor);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return (MathError.NO_ERROR, truncate(fraction));
    }

    /**
     * @dev Multiplies two exponentials, returning a new exponential.
     */
    function mulExp(Exp memory a, Exp memory b) pure internal returns (MathError, Exp memory) {

        (MathError err0, uint doubleScaledProduct) = mulUInt(a.mantissa, b.mantissa);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        // We add half the scale before dividing so that we get rounding instead of truncation.
        //  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717
        // Without this change, a result like 6.6...e-19 will be truncated to 0 instead of being rounded to 1e-18.
        (MathError err1, uint doubleScaledProductWithHalfScale) = addUInt(halfExpScale, doubleScaledProduct);
        if (err1 != MathError.NO_ERROR) {
            return (err1, Exp({mantissa: 0}));
        }

        (MathError err2, uint product) = divUInt(doubleScaledProductWithHalfScale, expScale);
        // The only error `div` can return is MathError.DIVISION_BY_ZERO but we control `expScale` and it is not zero.
        assert(err2 == MathError.NO_ERROR);

        return (MathError.NO_ERROR, Exp({mantissa: product}));
    }

    /**
     * @dev Multiplies two exponentials given their mantissas, returning a new exponential.
     */
    function mulExp(uint a, uint b) pure internal returns (MathError, Exp memory) {
        return mulExp(Exp({mantissa: a}), Exp({mantissa: b}));
    }

    /**
     * @dev Multiplies three exponentials, returning a new exponential.
     */
    function mulExp3(Exp memory a, Exp memory b, Exp memory c) pure internal returns (MathError, Exp memory) {
        (MathError err, Exp memory ab) = mulExp(a, b);
        if (err != MathError.NO_ERROR) {
            return (err, ab);
        }
        return mulExp(ab, c);
    }

    /**
     * @dev Divides two exponentials, returning a new exponential.
     *     (a/scale) / (b/scale) = (a/scale) * (scale/b) = a/b,
     *  which we can scale as an Exp by calling getExp(a.mantissa, b.mantissa)
     */
    function divExp(Exp memory a, Exp memory b) pure internal returns (MathError, Exp memory) {
        return getExp(a.mantissa, b.mantissa);
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) pure internal returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mantissa < right.mantissa;
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mantissa <= right.mantissa;
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mantissa > right.mantissa;
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp memory value) pure internal returns (bool) {
        return value.mantissa == 0;
    }
    // END -----------------------------------------------------------------
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