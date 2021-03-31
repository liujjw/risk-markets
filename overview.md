
# About
A protocol built on top of Aave v2 that establishes markets for the exchange of risk, based on pooled collateralization. There is no in-protocol algorithmic underwriting, instead borrowers (sellers) deposit collateral (unnecessary with credit delegation useful for CEXes, Kraken margin trading for example) to borrow an asset from a risk pool, which allows them to decrease their realized risk from some position in exchange for a portion of their realized profits. Suppliers (buyers) receive Aave's base APY plus shared profits and losses from sellers. The frontend currently resembles depositing and borrowing on Aave.

## Risk pools
Lenders (buyers) deposit assets into risk pools, of which there are two categories: long and short. Risk pools are deposited into Aave for passive yield. However, yield from risk pools has increased volatility due to the borrower and lender obligations.

## Borrower and lender obligations
If a borrower decides to close out a position at a loss, lenders collectively absorb some of the loss. Likewise, if a borrower closes out a position at a profit, lenders collectively share in the upside.

## Long and short risk rools
If a seller borrows from a long risk pool, a loss is recorded if the asset price drops. Likewise for a short risk pool; a loss is recorded if the asset price increases.

## Uses
For example, in a bull market, lenders will buy risk from long risk sellers to gain passive market exposure as these long risk sellers use the protocol to hedge a highly leveraged position. In a bear market, lenders share the upside of shorting, and the downside of going long. Nonetheless, buyers and sellers alike must consistently make informed decisions about market conditions to avoid low/negative yields and large losses. The protocol is not very efficient for smaller, short term positions.

# Design 
## Rates
Rates are set algorithmically based on supply and demand. The total profit sharing can exceed the the total loss coverage, as in this scenario both parties "win" despite borrowers losing more profits. At any given point there is a historical or current protocol-wide ratio of profit sharing value to loss coverage value, `profitShareToCoverRatio`, which defaults to one in the beginning. Once there is enough data on this, we can caluclate this ratio based on a floating number of past closes, perhaps in sync with the yield calculations. If profitShare is zero, maximize the profit share rate and minimize the cover rate. Similarly for cover. Both cannot be zero.

A fraction of every USD simple profit goes toward increasing the borrower's debt obligation above its initial value to go back to the supply pool. We assume that a borrower makes a simple profit from their position, which we define as the positive difference between the value of a position at some higher price and the value of the position at some lower price, i.e.,

    simpleProfit = (amountDepositedInEth * priceAtClose) - (amountDepositedInEth * priceAtBorrow)

Users must borrow to be able to receive protocol hedging, otherwise they are just passive depositers. 

The parameter `supplyPoolCoverProportion` determines what fraction of the current asset supply pool value can be taken to cover losses in the corresponding risk pool (and suppliers' deposit each decrease slightly to cover it); each asset has its own rate. The protocol should never get insolvent and liquidated (this would be catastrophic); one way this is prevented is by having a good constant for fixed percentage payout at any given point in such a way that the LTV from loans still outstanding does not rise above the liquidation threshhold. A requirement that is "good enough" is to never pay out to the risk pool more than is paid back in to close a position, i.e. the LTV ratio when a position is closed out never increases. This requirement imposes a cap on how much total value is covered in a loss; this requirement could be loosened in the future with more analysis. 

Each fraction of one USD (we denominate all value in USD) in simple loss from risk pools is uniformly covered in the event of a realized loss according to current protocol rates. That is, the debt obligation for borrowers is decreased. The protocol is agnostic to how positions are ultimately managed, e.g. there are no incentives to close a position either early or late. 

Cover rate `coverRate` is based on the constant product equation: 

    availableCoverage = supplyPoolCoverProportion * dollarValueOf(totalSupply)
    min(availableCoverage, totalLossInAllOpenPositions) = r * totalLossInAllOpenPositions
    coverRate = min(r, maxCoverRate)

`totalLossInAllOpenPositions` is always 0 or greater, so `r` always makes sense except for the edge case when the fraction is 0. This is computed as the value change from the price the borrow was made to when the value is calculated. This value changes constantly, perhaps too much, as the price changes, but it is our way of changing the cover rate based on demand; this method is also very costly in terms of gas usage as it is a heavy computation:
    
    current usdcwei price p
    set s (mapping) containing struct e of wei deposit amounts b, usdcwei price at borrow time c
    for all e in s (iterate, but can't alter mapping while doing this):
        totalLoss = 0
        if e.c > p:
            totalLoss += valueOf(e.b, e.c) - valueOf(e.b, p)

possibly simplified as 

    current usdcwei price p
    set s containing struct e of wei deposit amounts b, usdcwei price at borrow time c
    integer sum k
    for all e in s:
        k += valueOf(e.b, e.c)
    integer sum j
    for all e in s:
        if e.c > p:
            j += valueOf(e.b, p)
    totalLoss = k - j

Alternatively, we could represent demand as the value of recent losses in a given period. We make the simplifying assumption that borrow position is greater than total coverage of loss.

Loans can only be borrowed up to the underlying assets LTV ratio, and rates get worse as utilization approaches the LTV ratio. In this system, all outstanding loans can be completely repaid at a loss at once, but rates for borrowers are not ideal in this risk-averse scheme. Available coverage is guaranteed to never exceed a predictable amount, allowing for the most pessimistic lower bound on total yields. In a scenario of sustained losses wherein loss coverage exceeds profit sharing, yield for lenders would decrease to the point where there is a loss of liquidty for borrowers, giving an indicator of market conditions.

From the cover rate `coverRate`, we set the profit share rate `profitShareRate`

    factor = 1 / profitShareToCoverRatio
    profitShareRate = min((factor * coverRate) + profitShareConstant, maxProfitShareRate)

When the ratio dips below 1, we need higher profit sharing rates to keep yields for suppliers profitable. When the ratio rises above 1, we can lower profit sharing rates. This is done using the `factor`. At 1, the `profitShareRate` is just the `profitShareConstant` added to the `coverRate`.

## Proportional ownership
Each of the protocol long and short pools for a particular asset are implemented as a single large Aave position. For example, all long Eth deposits are pooled together into one Aave deposit into Eth, i.e. the protocol owns all aTokens. Every user that makes a deposit owns a fraction of the total deposit pool with interest equal to the fraction of the total principal without interest their deposit was. When withdrawing, the amount requested to be withdrawn is 

    amount = (x / totalPrincipal) * poolBalance

where we can solve for `x`. 

## Pools
There is only one pair for now, ETH/USDC, with ETH being the asset that is held as collateral for a long/short position. The protocol will need its own liquidation process or some similar penalty (something else entirely, credit delegation or change onBehalfOf to user) for LTV ratios that become too high. The USDC comes from Aave's USDC pool, so proper liquidation/penalties will be essential to prevent the protocol's entire position being liquidated.

## Yield calculations
An APY is important for lenders to compare yields across protocols. For borrowers, the cover rate, profit sharing rate, and the interest rate are sufficient for making decisions. Possible USDC support for example would be allowing lending and borrowing but long/short would not make sense; for DAI, arbitrage. With stablecoin supply pools, users would be able to make loans directly into stablecoins without having to incur the cost of swapping. In a multi-asset system with other volatile assets (not stablecoins), losses and gains would be split appropriately by dollar value supplied in long and short categories. ETH is available for lending/borrowing and long/short. The current APY for ETH lenders is calculated as follows

    ETH_APY = AAVE_ETH_APY + AnnualizedProfitRate - AnnualizedLossRate 
    AnnualizedProfitRate = (DollarsSharedOverLastEpoch / supplyPoolValue) * AnnualizationFactor
    AnnualizedLossRate = (DollarsPaidOutOverLastEpoch /supplyPoolValue) * AnnualizationFactor
    1 Epoch = 512 blocks

The `AnnualizationFactor` annualizes the rate with the effect of compounding. The APY in this case is floating. 512 blocks is over an hour based on current block times, so there is a lag in actual current APY rates, which is not ideal in case of market flash crashes. This parameter should be tweaked based on protocol activity. An `x` epoch average, e.g. a 30-epoch average, should also be available.    

# Protocol math
Solidity does not provide good suport for decimals, but they are crucial for accurate financial accounting. A simple approach would be to use a fraction struct to deal with decimals, with division avoided as long as possible. However, this is not full featured enough for lots of arithmetic. 

## Libraries
We use Compound's `Exponential` library for a somewhat familiar approach to dealing with decimals.

## Representing WETH price
We can get USDC/Wei from Aave price oracles. We calculate ETH/USDC price as follows
    
    1 usdc / x wei
    x wei * k = 1 weth = 1000000000000000000 wei 
    (1 usdc / x wei) * (k / k) = k usdc / x * k wei = k usdc / 1 weth

Reverse the calculation to solve for `x` given `k` (`x wei * k  = 10^18 wei`). Decimals can be accounted for with the appropriate abstractions and libraries. This approach is the more natural way to think about prices (not using Exponential yet, for require() only). 

Alternatively, all calculations are done with wei and the base price format from the price oracle, stored as `price = (1.000000 usdc / x wei)`, so that when `(newPrice * y wei) - (oldPrice * y wei)` gives units in whole `usdc` (using Exponential, need to convert when overriding price, for rates math).

# Additional considerations
The protocol is built with Aave's liquidity markets and subject its risks and rewards, such as liquidations, yields, interest, and governance changes. All yields and interest from borrows and lending are maintained.

Miscellaneous: market manipulation by "whales", pooling leverage for less fees feature, optimize gas usage, more analysis for better rates eg get rid of fixed, change terminology from lending/borrowing to true "risk market", composability, "pieces", project funding, liquidations/penalty and spreadsheet modelling 

