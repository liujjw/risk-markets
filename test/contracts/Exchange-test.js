const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe('Exchange', () => {

    it("Deposits eth into aave, gets aweth for itself.", async () => {
        const factory = await ethers.getContractFactory("Exchange");
        const exchange = await factory.deploy();
        let overrides = {
            value: ethers.utils.parseEther("100") 
        };
        await exchange.depositLongEth(overrides);
        expect(await exchange.queryTokenBalance()).to.equal(ethers.utils.parseEther("100"));
    })

    it("Correctly withdraws all proportional ownership.", async () => {
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
        // console.log((await exchange.signer.getBalance()).toString());
        // console.log((await exchange2.signer.getBalance()).toString());
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

    it("Correctly borrows", async () => {
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
});
// gas cost? disable? compute?