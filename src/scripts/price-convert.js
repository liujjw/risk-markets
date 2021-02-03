const hre = require("hardhat");
const {BigNumber} = require("ethers");

let wei = BigNumber.from("758340000000000");
let k = BigNumber.from("1000000000000000000").div(wei);
console.log(k.toString());

