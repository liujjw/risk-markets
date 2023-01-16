# About 
A protocol built on top of Aave v2 that establishes markets for the exchange of risk, based on pooled collateralization. There is no in-protocol algorithmic underwriting, instead borrowers (sellers) deposit collateral to borrow an asset from a risk pool, which allows them to decrease their realized risk from some position in exchange for a portion of their realized profits. 

# "Exchanging risk by taking directional positions in token markets"
Refer to `overview.md` for an in-depth protocol design overview. 

# Usage
Start the forked mainnet chain with Alchemy keys and Hardhat config `npx hardhat node`, deploy the contract `npx hardhat --network localhost deploy`, start the server `node src/app/server.js` navigate to `index.html`, run the override price script `npx hardhat run src/srcipts/override-price.js`. Remember to reset metamask accounts. Use on Chrome with Access-Control-Allow-Origin extension.

# Todo
-a countercyclical long scenario (eg, before the 2020-2021 bull run): compute a responsible max 20% leverage PnL with tradfi(eg HELOC or a low interest loan) and compare to high leverage spiral and defi interest rates and yields with protocol protection PnL, to see if the protocol does better
-not to say anything of forex land with their 20x leverage...
-leverage spirals literature and computing equilibrium for the protocol
-formal analysis of compound
-migrate to react
-compound/aave token yield/interest rate model for integrating a token 
