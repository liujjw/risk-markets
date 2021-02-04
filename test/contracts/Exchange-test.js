const { expect } = require("chai");
const { BigNumber } = require("ethers");
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
        var borrowedBalance = ethers.utils.formatUnits(await exchange.USDC_Balance(), 6);
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

    xit("Computes correct simple profit", async () => {
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
});