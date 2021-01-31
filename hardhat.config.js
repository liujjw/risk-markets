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

module.exports = {
  solidity: "0.6.12",
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

