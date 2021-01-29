/**
    Scrap code, possibly used for a pooled leverage feature in the future. Contains a lot of cut+paste code from Compound protocol docs.
*/
contract PooledLeverage {
    mapping(uint256 => LongPosition) positions;
    mapping(uint256 => bool) usedKeys;
    //f64 percentFee = 0.01
    uint256 feePool;
    // money market protocol param: compound, will accrue comp 
    // position governance with the token, each position is its own contract, with a central comptroller 
    // the protocol aggregates a capital, offering significantly more leverage than individual positions
    uint256 totalEthCap = 1000;

    struct LongPosition {
        uint256 priceToCloseOutAt;
        uint256 targetPrincipalEth,
        mapping(address => uint256) contributions;
        uint256 timeout;
        uint256 timeCreated;
        address creator;

        // uint256 targetPrice,
        // fixed stop,
        // timeout 
    }
    
    function newLongPosition(uint256 id, uint256 _targetPrice, fixed _stop) public payable {
        // reward for creation, reward if right by timeout 
        uint256 total = msg.value;
        uint256 reserves = 
        positions[id] = LongPosition({
           principal = 
           targetPrice = _targetPrice;
           stop = _stop;
        });
    }
    
    function payable public acceptPayment(uint256 id) {
        feePool += percentFee * msg.value;
        
    }
    
    function closeOutLeveragedPosition() {
        
    }
    
    struct ContractAddresses {
        address cEth = 0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5;
        address compound = 0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5;
        address compoundComptroller = 0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b;
        address cUSDC = 0x39aa39c021dfbae8fac545936693ac917d5e7563;
        address uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        address USDC = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;
        address WETH = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
    }
    
    function leverage(uint256 id) {
        LongPosition longPosition = positions[id];
        require(longPosition.ready);
        longPosition.ready = false; // re-entrancy prevention; todo get rid of used positions
        uint256 next = longPosition.principal;
        while (next > 15) {
            require(supplyEthToCompound(cEthAddress, longPosition.principal));
            next = factor * next;
            require(borrowErc20Example());
            require(convert());
        }
        // gas cost on the order of 10^6
        // a reserve is kept for the protocol upgrades 
        // posting collateral also gets tokens 
        // need some way to de leverage, somebody has to post a lot of collateral, which is more than 
        // logarithmicall y decreases 
        
    }
    
    function supplyEthToCompound(address payable _cEtherContract, uint256 amount)
        returns (bool)
    {
        CEth cToken = CEth(_cEtherContract);

        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit MyLog("Exchange Rate (scaled up by 1e18): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        emit MyLog("Supply Rate: (scaled up by 1e18)", supplyRateMantissa);

        cToken.mint.{value: msg.value}();
        return true;
    }
    
    function borrowErc20Example(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _priceOracleAddress,
        address _cDaiAddress
    ) public payable returns (uint256) {
        CEth cEth = CEth(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        PriceOracle priceOracle = PriceOracle(_priceOracleAddress);
        CErc20 cDai = CErc20(_cDaiAddress);

        // Supply ETH as collateral, get cETH in return
        cEth.mint.value(msg.value)();

        // Enter the ETH market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cEtherAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(address(this));
        if (error != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        // Get the collateral factor for our collateral
        // (
        //   bool isListed,
        //   uint collateralFactorMantissa
        // ) = comptroller.markets(_cEthAddress);
        // emit MyLog('ETH Collateral Factor', collateralFactorMantissa);

        // Get the amount of DAI added to your borrow each block
        // uint borrowRateMantissa = cDai.borrowRatePerBlock();
        // emit MyLog('Current DAI Borrow Rate', borrowRateMantissa);

        // Get the DAI price in ETH from the Price Oracle,
        // so we can find out the maximum amount of DAI we can borrow.
        uint256 daiPriceInWei = priceOracle.getUnderlyingPrice(_cDaiAddress);
        uint256 maxBorrowDaiInWei = liquidity / daiPriceInWei;

        // Borrowing near the max amount will result
        // in your account being liquidated instantly
        emit MyLog("Maximum DAI Borrow (borrow far less!)", maxBorrowDaiInWei);

        // Borrow DAI
        uint256 numDaiToBorrow = 10;

        // Borrow DAI, check the DAI balance for this contract's address
        cDai.borrow(numDaiToBorrow * 1e18);

        // Get the borrow balance
        uint256 borrows = cDai.borrowBalanceCurrent(address(this));
        emit MyLog("Current DAI borrow amount", borrows);

        return borrows;
    }
    
    // need calculations to see if viable, aggregation leads to less fees, "economies of scale"
    function short() {
        
    }
    
    function arbitrage() {
        
    }
    
    function liquidate() {
        
    }

    function claimPayout(uint256 id) {
        f64 fraction = principal / positions[id].contributions[msg.sender];
        msg.sender.transfer(fraction * this.balance);
    }
    
    function redeemTokens() {
        
    }
    
    event MyLog(string, uint256);



    function supplyErc20ToCompound(
        address _erc20Contract,
        address _cErc20Contract,
        uint256 _numTokensToSupply
    ) public returns (uint) {
        // Create a reference to the underlying asset contract, like DAI.
        Erc20 underlying = Erc20(_erc20Contract);

        // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(_cErc20Contract);

        // Amount of current exchange rate from cToken to underlying
        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit MyLog("Exchange Rate (scaled up by 1e18): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        emit MyLog("Supply Rate: (scaled up by 1e18)", supplyRateMantissa);

        // Approve transfer on the ERC20 contract
        underlying.approve(_cErc20Contract, _numTokensToSupply);

        // Mint cTokens
        uint mintResult = cToken.mint(_numTokensToSupply);
        return mintResult;
    }

    function redeemCErc20Tokens(
        uint256 amount,
        bool redeemType,
        address _cErc20Contract
    ) public returns (bool) {
        // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(_cErc20Contract);

        // `amount` is scaled up by 1e18 to avoid decimals

        uint256 redeemResult;

        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/developers/ctokens#ctoken-error-codes
        emit MyLog("If this is not 0, there was an error", redeemResult);

        return true;
    }

    function redeemCEth(
        uint256 amount,
        bool redeemType,
        address _cEtherContract
    ) public returns (bool) {
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(_cEtherContract);

        // `amount` is scaled up by 1e18 to avoid decimals

        uint256 redeemResult;

        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/docs/ctokens#ctoken-error-codes
        emit MyLog("If this is not 0, there was an error", redeemResult);

        return true;
    }

    // This is needed to receive ETH when calling `redeemCEth`
    function() external payable {}
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}


interface CErc20 {
    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);
}


interface CEth {
    function mint() external payable;

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);
}

interface Comptroller {
    function markets(address) external returns (bool, uint256);

    function enterMarkets(address[] calldata)
        external
        returns (uint256[] memory);

    function getAccountLiquidity(address)
        external
        view
        returns (uint256, uint256, uint256);
}


interface PriceOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
}


    event MyLog(string, uint256);



    function myEthRepayBorrow(address _cEtherAddress, uint256 amount)
        public
        returns (bool)
    {
        CEth cEth = CEth(_cEtherAddress);
        cEth.repayBorrow.value(amount)();
        return true;
    }

    function myErc20RepayBorrow(
        address _erc20Address,
        address _cErc20Address,
        uint256 amount
    ) public returns (bool) {
        Erc20 dai = Erc20(_erc20Address);
        CErc20 cDai = CErc20(_cErc20Address);

        dai.approve(_cErc20Address, amount);
        uint256 error = cDai.repayBorrow(amount);

        require(error == 0, "CErc20.repayBorrow Error");
        return true;
    }

    function borrowEthExample(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _cDaiAddress,
        address _daiAddress,
        uint256 _daiToSupplyAsCollateral
    ) public returns (uint) {
        CEth cEth = CEth(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        CErc20 cDai = CErc20(_cDaiAddress);
        Erc20 dai = Erc20(_daiAddress);

        // Approve transfer of DAI
        dai.approve(_cDaiAddress, _daiToSupplyAsCollateral);

        // Supply DAI as collateral, get cDAI in return
        uint256 error = cDai.mint(_daiToSupplyAsCollateral);
        require(error == 0, "CErc20.mint Error");

        // Enter the DAI market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cDaiAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(address(this));
        if (error2 != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        // Borrowing near the max amount will result
        // in your account being liquidated instantly
        emit MyLog("Maximum ETH Borrow (borrow far less!)", liquidity);

        // Get the collateral factor for our collateral
        // (
        //   bool isListed,
        //   uint collateralFactorMantissa
        // ) = comptroller.markets(_cDaiAddress);
        // emit MyLog('DAI Collateral Factor', collateralFactorMantissa);

        // Get the amount of ETH added to your borrow each block
        // uint borrowRateMantissa = cEth.borrowRatePerBlock();
        // emit MyLog('Current ETH Borrow Rate', borrowRateMantissa);

        // Borrow a fixed amount of ETH below our maximum borrow amount
        uint256 numWeiToBorrow = 20000000000000000; // 0.02 ETH

        // Borrow DAI, check the DAI balance for this contract's address
        cEth.borrow(numWeiToBorrow);

        uint256 borrows = cEth.borrowBalanceCurrent(address(this));
        emit MyLog("Current ETH borrow amount", borrows);

        return borrows;
    }

    // Need this to receive ETH when `borrowEthExample` executes
    function() external payable {}
