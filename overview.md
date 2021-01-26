
# About
A protocol built on top of Aave v2 that establishes markets for the exchange of risk, based on pooled collateralization. There is no in-protocol algorithmic underwriting, instead borrowers (sellers) deposit collateral (unnecessary with credit delegation useful for CEXes, Kraken margin trading for example) to borrow an asset from a risk pool, which allows them to decrease their realized risk from some position in exchange for a portion of their realized profits.

## Risk pools
Lenders (buyers) deposit assets into risk pools, of which there are two categories: long and short. Risk pools are deposited into Aave for passive yield. However, yield from risk pools has increased volatility due to the borrower and lender obligations.

## Borrower and lender obligations
If a borrower decides to close out a position at a loss, lenders collectively absorb some of the loss. Likewise, if a borrower closes out a position at a profit, lenders collectively share in the upside.

## Long and short risk rools
If a seller borrows from a long risk pool, a loss is recorded if the asset price drops. Likewise for a short risk pool; a loss is recorded if the asset price increases.

## Uses
For example, in a bull market, lenders will buy risk from long risk sellers to gain passive market exposure as these long risk sellers use the protocol to hedge a highly leveraged position. In a bear market, lenders share the upside of shorting, and the downside of going long. Nonetheless, buyers and sellers alike must consistently make informed decisions about market conditions to avoid low/negative yields and large losses. Moreover, the protocol is not very efficient for smaller, short term positions.

# Implementation
Rates are set algorithmically based on supply and demand, and maintain protocol solvency.  

## Parameters
### `supplyPoolCoverProportion` 
determines what fraction of the current asset supply pool value can be taken to cover losses in the corresponding risk pool; each asset has its own rate

### `riskPoolShareRateCurveParams`
parameters for the curve that determines what fraction of every USD simple profit goes toward increasing the borrower's debt obligation above its initial value to go back to the supply pool

## Profit sharing rates in the event of a simple profit
We assume that a borrower makes a simple profit from their position, which we define as the positive difference between the value of a position at some higher price and the value of the position at some lower price. To put it more succinctly, 

    simpleProfit = positionSize * (newPrice / oldPrice)

We also suppose that at all cover rates, the total loan forgiveness value will be about the same irrespective of the total outstanding loan amount due to the properties of the rate being derived from the constant product equation. Profit sharing rates are inversely related to cover rates to stimulate supply and demand. We assume that in risk pools, the rate at which losses are realized is not roughly the same as the rate at which profits are realized. Specific formula undetermined. 

## Pessimistic cover rates in the event of loss
Each fraction of one USD (we denominate all value in USD) in simple loss from risk pools is uniformly covered in the event of a realized loss according to current protocol rates. The protocol is agnostic to how positions are ultimately managed, e.g. there are no incentives to close a position either early or late. Cover rate `r` is the solution of the constant product equation: 

    availableCoverage = supplyPoolForgivenessRate * totalSupply * conversionFactorToUSD
    availableCoverage = r * outstandingLoanValue

Loans can only be borrowed up to the underlying assets LTV ratio, and rates get worse as utilization approaches the LTV ratio. In this system, all outstanding loans can be completely repaid at a loss at once, but rates for borrowers are not ideal in this risk-averse scheme. Available coverage is guaranteed to never exceed a predictable amount, allowing for the most pessimistic lower bound on total yields.

## Yield calculations
An APY is important for lenders to compare yields across protocols. For borrowers, the cover rate, profit sharing rate, and the interest rate are sufficient for making decisions. There is only one asset to start with, ETH, to keep things simple. Possible USDC support for example would be allowing lending and borrowing but long/short would not make sense; for DAI, arbitrage. With stablecoin supply pools, users would be able to make loans directly into stablecoins without having to incur the cost of swapping. In a multi-asset system with other volatile assets (not stablecoins), losses and gains would be split appropriately by dollar value supplied in long and short categories. ETH is available for lending/borrowing and long/short. Thus, the current APY for ETH lenders for example is calculated as follows

    ETH_APY = AAVE_ETH_APY + AnnualizedProfitRate - AnnualizedLossRate 
    AnnualizedProfitRate = DollarsSharedOverLastEpoch * AnnualizationFactor
    AnnualizedLossRate = DollarsPaidOutOverLastEpoch * AnnualizationFactor
    1 Epoch = 512 blocks

The APY in this case is floating. 512 blocks is over an hour based on current block times, so there is a lag in actual current APY rates, which is not ideal in case of market flash crashes. This parameter should be tweaked based on protocol activity. An `x` epoch average, e.g. a 30-epoch average, should also be available.    

## Additional considerations
The protocol is built using Aave's liquidity markets and as such subject to all its risks and rewards, such as liquidations, yields, and governance changes. The usage of the protocol is virtually identical to using Aave or other money market liquidity protocols, except for the additional volatility of exchanging risk of course. 

Market manipulation by "whales" 

Borrowers who deposit into long but borrow from short
  

