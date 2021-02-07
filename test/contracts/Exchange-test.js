const { expect } = require("chai");
const { BigNumber, Contract } = require("ethers");
const { ethers } = require("hardhat");

describe('Exchange', () => {

    async function logAccountBalance(exchange, expecting) {
        const balance = await exchange.signer.getBalance();
        console.log("Account ", exchange.signer.address, " has balance ", ethers.utils.formatEther(balance), " expecting about ", expecting);
    }

    xit("Deposits eth into aave, gets aweth for itself.", async () => {
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("100") 
        };
        await exchange.depositLongEth(overrides);
        expect(await exchange.queryTokenBalance()).to.equal(ethers.utils.parseEther("100"));
        // await logAccountBalance(exchange, "9900");
    })

    xit("Correctly withdraws all proportional ownership.", async () => {
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("100") 
        };
        await exchange.depositLongEth(overrides);

        const user2Signer = new ethers.Wallet
        ("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", exchange.provider);
        const exchange2 = exchange.connect(user2Signer);
        await exchange2.depositLongEth(overrides);

        // console.log(exchange.signer);
        // console.log(exchange.provider);
        const secsInYear = 3.154 * 10**7;
        await exchange.provider.send("evm_increaseTime", [secsInYear]);
        await exchange.provider.send("evm_mine", []);

        await exchange.withdrawLongEth(ethers.utils.parseEther("0"), ethers.BigNumber.from("1"));
        await exchange2.withdrawLongEth(ethers.utils.parseEther("0"), ethers.BigNumber.from("1"));
        expect(await exchange.queryTokenBalance()).to.equal(ethers.BigNumber.from("0"));
        // await logAccountBalance(exchange, "10000");
        // await logAccountBalance(exchange2, "10000");
    })

    // TODO
    xit("Correctly withdraws some proportional ownership.", async () => {
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("100") 
        };
        await exchange.depositLongEth(overrides);

        const user2Signer = new ethers.Wallet
        ("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", exchange.provider);
        const exchange2 = exchange.connect(user2Signer);
        await exchange2.depositLongEth(overrides);

        // console.log(exchange.signer);
        // console.log(exchange.provider);
        const secsInYear = 3.154 * 10**7;
        await exchange.provider.send("evm_increaseTime", [secsInYear]);
        await exchange.provider.send("evm_mine", []);

        // const contractBalanceAfterYear = await exchange.queryTokenBalance()
        // console.log(contractBalanceAfterYear.toString());
        // const contractBalanceAfterYear = ethers.BigNumber.from("201127669880230806958");
        // const interest = contractBalanceAfterYear.sub(ethers.utils.parseEther("200"));
        // const halfInterest = interest.div(2);
        await exchange2.withdrawLongEth(ethers.utils.parseEther("50"));
        await exchange2.withdrawLongEth(ethers.utils.parseEther("50"));
        await exchange.withdrawLongEth(ethers.utils.parseEther("100"));
        await exchange.withdrawLongEth(halfInterest);
        await exchange2.withdrawLongEth(halfInterest);
        // expect(await user1.getBalance()).to.equal(user1BalanceOriginal.add(halfInterest));
        // expect(await user2.getBalance()).to.equal(user2BalanceOriginal.add(halfInterest));

        expect(await exchange.queryTokenBalance()).to.equal(ethers.BigNumber.from("0"));
        // console.log((await exchange.signer.getBalance()).toString());
        // console.log((await exchange2.signer.getBalance()).toString());
    })

    xit("Correctly borrows", async () => {
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("1000") 
        };

        await exchange.depositLongEth(overrides);
        await exchange.borrow_USDC_Long_Eth(ethers.utils.parseUnits("100000", 6));
        var borrowedBalance = ethers.utils.formatUnits(await exchange.senderUSDCBalance(), 6);
        expect(borrowedBalance).to.equal("100000.0");
    })

    function ETHUSDC_to_USDCWEI(k) {
        let a = BigNumber.from("1000000000000000000");
        let b = BigNumber.from(k);
        let c = a.div(b);
        return c.toString();
    }

    function UDSCWEI_to_ETHUSDC(x) {
        let a = BigNumber.from("1000000000000000000");
        let b = BigNumber.from(x);
        let c = a.div(b);
        return c.toString();
    }

    xit("Computes approximate simple profit", async () => {
        // enable corrresponding console.log in .sol
        const depositAmountInEth = 100;
        const borrowAmountInUSDC = 10000;
        const newPriceETHUSDC = 2000;
        const oldPriceETHUSDC = 1383;

        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        // await logAccountBalance(exchange, "10000");
        let overrides = {
            value: ethers.utils.parseEther(depositAmountInEth.toString()) 
        };
        await exchange.depositLongEth(overrides);
        await exchange.borrow_USDC_Long_Eth(ethers.utils.parseUnits(borrowAmountInUSDC.toString(), 6));
        // https://www.cryps.info/en/USDC_to_Wei/
        // console.log(ETHUSDC_to_USDCWEI("1645"), "expecting about 608,417,087,166,870"); 
        // console.log(UDSCWEI_to_ETHUSDC("608417087166870"), "expecting about 1645"); 
        let simpleDeltaEstimate = (depositAmountInEth * newPriceETHUSDC) - (depositAmountInEth * oldPriceETHUSDC); 
        const newPriceUSDCWEI = ETHUSDC_to_USDCWEI(newPriceETHUSDC);
        await exchange.overridePrice(ethers.BigNumber.from(newPriceUSDCWEI));
        await exchange.repay_USDC_Long_Eth(ethers.utils.parseUnits("0", 6), ethers.BigNumber.from("1"));
        console.log("expecting about", simpleDeltaEstimate);
    })

    xit("Computes reasonable cover rates and profit share rates, one position. Repays appropriate borrow amount.", async () => {
        // collective borrowers, borrow at 1384, 692000 value deposit, 100000 borrow
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("500") 
        };
        await exchange.depositLongEth(overrides);
        await exchange.borrow_USDC_Long_Eth(ethers.utils.parseUnits("100000", 6));

        // represents collective suppliers, no borrows, 1 mil value
        const user2Signer = new ethers.Wallet
        ("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", exchange.provider);
        const exchange2 = exchange.connect(user2Signer);
        let overrides2 = {
            value: ethers.utils.parseEther("1000") 
        };
        await exchange2.depositLongEth(overrides2);

        // price drops, 500000 value deposit 
        const newPriceUSDCWEI = ETHUSDC_to_USDCWEI("1000");
        await exchange2.overridePrice(ethers.BigNumber.from(newPriceUSDCWEI));

        // borrower deposit is included in supply pool for coverage 
        await exchang
        await exchange.repay_USDC_Long_Eth(BigNumber.from("0"), BigNumber.from("1"));
        console.log("expecting about 150000 / 192000 for cover rate");
    })

    
    it("Computes reasonable cover and profit share rates, multiple positions.", async () => {
        // borrower 1, borrow at 1384, 692k value deposit, 300k borrow
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("500") 
        };
        await exchange.depositLongEth(overrides);
        await exchange.borrow_USDC_Long_Eth(ethers.utils.parseUnits("300000", 6));
        // price drops, 500k value deposit so 192k loss now 
        let newPriceUSDCWEI = ETHUSDC_to_USDCWEI("1000");
        await exchange.overridePrice(ethers.BigNumber.from(newPriceUSDCWEI));

        // borrower 2, borrow at 1000, 100k value deposit, 40k borrow
        const user3Signer = new ethers.Wallet
        ("0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", exchange.provider);
        const exchange3 = exchange.connect(user3Signer);
        let overrides3 = {
            value: ethers.utils.parseEther("100") 
        };
        await exchange3.depositLongEth(overrides3);
        await exchange3.borrow_USDC_Long_Eth(ethers.utils.parseUnits("40000", 6));
        // price drops, 90k value deposit so 10k loss, 900*500 = 450k -> 192+50 = 242k, total 252k
        newPriceUSDCWEI = ETHUSDC_to_USDCWEI("900");
        await exchange3.overridePrice(ethers.BigNumber.from(newPriceUSDCWEI));

        // represents collective suppliers, no borrows, 1 mil value
        const user2Signer = new ethers.Wallet
        ("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", exchange.provider);
        const exchange2 = exchange.connect(user2Signer);
        let overrides2 = {
            value: ethers.utils.parseEther("1000") 
        };
        await exchange2.depositLongEth(overrides2);

        // price rises, total loss now just 500*1100=550k -> 692-550=142k
        newPriceUSDCWEI = ETHUSDC_to_USDCWEI("1100");
        await exchange2.overridePrice(ethers.BigNumber.from(newPriceUSDCWEI));

        // borrower deposit is included in supply pool for coverage 
        // infinite approve of usdc to deployed contract 
        let infinite = BigNumber.from("0x" + "f".repeat(64));
        let usdc_abi = [
            "function approve(address _spender, uint256 _value) public returns (bool success)",
            "function allowance(address _owner, address _spender) public view returns (uint256 remaining)"
        ];
        let usdc = new Contract("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", usdc_abi, exchange.signer);   
        await usdc.approve(exchange.address, infinite);
        // console.log(
        //     (await usdc.allowance(exchange.signer.address, exchange.address)).toString()
        // );
        await exchange.repay_USDC_Long_Eth(BigNumber.from("0"), BigNumber.from("1"));
        // 1600 eth deposited, 1600*1100*0.1 is 176000 so 176000/142k too high
        // console.log("expecting 8 / 10 for cover rate");
        // 142k usdc loss, 8 / 10 of that is covered, so only need to repay 28.4k usdc, so user keeps some usdc, and loses some eth that was deposited
    })
});