/**
 * @type import('hardhat/config').HardhatUserConfig
 */  
require("@nomiclabs/hardhat-waffle");

task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log("Account ", account.address, " has balance ", (await account.getBalance()).toString());
  }
});

task("deploy", "deploys the protocol contract", async () => {
  const factory = await ethers.getContractFactory("Exchange");
  const exchange = await factory.deploy();
  // console.log(await exchange.deployTransaction.wait());
  // 0x5FbDB2315678afecb367f032d93F642f64180aa3
});

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/-2LDGUa_GoVc-AouiahUGfDxDiWXwNQe",
        blockNumber: 11754095
      }
    }
  },
  paths: {
    sources: "./src/contracts",
    tests: "./test/contracts",
    cache: "./cache",
    artifacts: "./artifacts"
  },
};

