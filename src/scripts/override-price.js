const { ethers } = require("hardhat");

let address = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
let abi = [
    "function overridePrice(uint256 price) public",
    "function senderUSDCBalance() public view returns(uint256)"
];
let provider = new ethers.getDefaultProvider("http://localhost:8545");
let signer = new ethers.Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", provider);
let contract = new ethers.Contract(address, abi, signer);

function ETHUSDC_to_USDCWEI(k) {
    let a = ethers.BigNumber.from("1000000000000000000");
    let b = ethers.BigNumber.from(k);
    let c = a.div(b);
    return c.toString();
}

async function override() {
    let newPrice = ETHUSDC_to_USDCWEI("1100");
    await contract.overridePrice(ethers.BigNumber.from(newPrice));
}

async function foo() {
    console.log(await contract.senderUSDCBalance());
}

// foo().then(() => {}).catch((err) => {console.log(err)});
override().then(() => {}).catch((err) => {console.log(err)});