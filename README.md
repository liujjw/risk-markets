# About 
A protocol built on top of Aave v2 that establishes markets for the exchange of risk, based on pooled collateralization. There is no in-protocol algorithmic underwriting, instead borrowers (sellers) deposit collateral to borrow an asset from a risk pool, which allows them to decrease their realized risk from some position in exchange for a portion of their realized profits. 

# Design
Refer to `overview.md` for an in-depth protocol design overview. 

# Usage
Start the forked mainnet chain with Alchemy keys and Hardhat config `npx hardhat node`, deploy the contract `npx hardhat --network localhost deploy`, start the server `node src/app/server.js` navigate to `index.html`, run the override price script `npx hardhat run src/srcipts/override-price.js`. Remember to reset metamask accounts.
