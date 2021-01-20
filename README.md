# Overview 
A protocol built on top of Aave that establishes markets for the exchange of risk, based on pooled collateralization. There is no in-protocol algorithmic underwriting, instead borrowers (sellers) deposit collateral (unnecessary with credit delegation, CEX integration with Kraken for example) to borrow an asset from a risk pool, which allows them to decrease their realized risk from some position in exchange for a portion of their realized profits.

## Risk pools
Lenders (buyers) deposit assets into risk pools, of which there are two categories: long and short. Risk pools are deposited into Aave for passive yield. However, yield from risk pools has increased volatility due to the borrower and lender obligations. 

## Borrower and lender obligations
If a borrower decides to close out a position at a loss, lenders collectively absorb some of the loss. Likewise, if a borrower closes out a position at a profit, lenders collectively share in the upside.

## Long and short risk rools
If a seller borrows from a long risk pool, a loss is recorded if the asset price drops. Likewise for a short risk pool; a loss is recorded if the asset price increases.

## Uses
For example, in a bull market, lenders will buy risk from long risk sellers to gain passive market exposure. Nonetheless, buyers and sellers alike must consistently make informed decisions about market conditions to avoid low/negative yields and large losses. 

## Rates


Scenario 1:
Leveraged long ETH. Deposit USDC, get ETH, repeat. ETH price goes down. Want to close out position.Will need to pay back "less" collateral relative to when ETH price goes up or stays the same. In this way, losses are lessened, lenders lose money. Otherwise, ETH price goes up. Want to close out position. Will need to pay back "more" collateral relative to ETH price staying the same or goes down. In this way, gains are also lessened, lenders are compensated, profit. Lenders make money in a bull market and lose money in a bear market. Both parties profit only in a bull market. Need access to an existing large pool of liquidity. The used collateral is a fraction of the deposited collateral. Borrowers will "always" want to use this service. It is up to lenders to assess the market to provide liquidity in these pools. It gives them exposure to the bull market without directly trading. 

Scenario 2:
But there are "two" pools. There is also the short pool, where returns are reversed. In a bear market, lenders share the upside of shorting, and the downside of going long. 

In total:
In a bear market, the short pool will be used. In a bull market, the long pool with be used. Nneed algorithmically set rates. 