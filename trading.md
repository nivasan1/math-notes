# Trading
- Write smth here every day
- ## Remilia?
  - Invest in meme
  - Utilization of twitter
- ## Money Markets?
  - Non-crypto trades?

# Derivatives Reading
- **derivative**
  - Financial instrument, value of which derives from various underlying variables (ostensibly, price of some asset)
## Futures
- ### **forward contract**
  - Agreement to buy / sell asset at future time $t$ for some price $p$
  - Value of holding dollars vs. dividend from stock to that point, expected price at $t$, etc.
    - **one party is long**
      - One party purchasing at $t$ (expect to make money)
    - **one party is short**
      - One party is sellling at future date for $p$
  - **spot**
    - Buy asset rn
  - **payoffs**
    - $S_T - K$ (long)
      - $K$ is price of unit asset in future
      - $S_T$ is price of unit asset at $T$
        ![Alt text](Screen%20Shot%202023-07-29%20at%201.57.23%20PM.png)
  - How does RFR come into play?
    - Can borrow anything, at $5%$ interest rate (RFR)
      - Can lend, and receive $5%$ interest
    - If gold is $300$$ (spot)
      - If I have gold
        - I can sell gold for 300, lend 300 dollars (gain $5%$ 15), and buy gold back after a year
        - I.e if long future is < 315 I make money
      - If I borrow 300
        - Buy gold, sell future
        - Expect 315 at least
        - i.e if long future is > 315 I make money
- ### **futures contract**
  - Exact delivery date is not specified (have a range instead)
- ### **options**
  - **call option**
    - Holder has **right** (contrast to futures / forward) to buy underlying at specified date for strike price
      - American - Excercised any time up to expiration
      ![Alt text](Screen%20Shot%202023-07-29%20at%202.19.14%20PM.png)
    - Holder in the hold price of option * units, until stock price is > strike price
  - **put option**
    - Holder has right to sell the underlying at specified date for specified price
      - European - holder can only exercise at maturity date
    - If strike price is greater than current price, borrow / buy stocks at spot, and sell for strike (walk w/ profit)
  - **option positions**
    - two sides buyer of option, seller of option
      - i.e long / short, call / put
        - long in call - Buyer of the call
        - Short in call - Seller of call - Has to deliver shares to long-holder of call contract
          - In the money as long as price of stock less than strike price + wiggle room (in for units + option contract price)
        ![Alt text](Screen%20Shot%202023-07-29%20at%202.34.07%20PM.png)
  - **payoff**
    - holder of long in call
      - $max(S_T - (K + C), 0)$ (per unit)
         -  $S_T$ is price of stock at $T$
         -  $K$ is strike
         -  $C$ is contract price
    - holder of short in call
      - $min(K - S_T, 0) + C$
        - When strike is less than current stock price, will lose money (adjusted by sale price of the option)
- ### Pricing
  - **short selling**
    - Borrow asset, sell, wait for price to drop, buy back and take profit
  - Interest rate calculations
    - Suppose $10%$ annual
      - Can be broken into $10% / periods$ where after each period, the interest = $P * (1 + R / periods)$ is re-invested, 
      - I.e $A(1 + R/m)^{m}$, as $m \rightarrow \infty$, $Ae^{R}$ is the continuously compounded interest
  - **forward contract pricing**
    - **scenarios**
      - $S_0$ (stock price rn) is $40$, RFR is $5%$ $F_0$ (forward price rn) is $43$ (forward contract overpriced)
        - Borrow 40, have to payback $40e^{0.5}$ at future expiry
        - Buy share, sell forward contract make $43 - 40e^{0.5}$
      - $S_0$ 40, RFR $5%$, $F_0$ 39 (forward contract underpriced)
        - Short share (borrow + sell rn) make 40 lend, and purchase 39 forward contract, make $40e^{0.05} - 39$
    - **naive**
      - Arbitrage exists unless $F_0 = S_0e^{rT}$ ($T$ is time to expiry of forward contract)
  - **forward contract pricing (with dividends)**
## Large selling Event?
- How stable is US economy?
  - Seems like it may not be? Commercial housing market?
## Perpetuals
- **perpetual**
  - Futures contract w/ no expiry
- **maintenance-margin** - Required amt. of collateral required to increase position size
- Accounts whose total value falls below maintenance margin have position closed by **liquidation engine**
  - liquidator can take up to entire balance of portfolio, positions purchased at **liquidation** price
- Users deposit collateral to act as buffer in price movements
  - Say I deposit $c$ as collateral, then I will safe in $c - margin\_req$ price-movements in my position
- **perpetual funding rate**
  - **funding rate**
    - Payments made between holders of perpetual contracts.
    - Used to align spot-price w/ perpetual-price.
      - Perpetual has no expiry, how to ensure that the perpetual price is aligned w/ spot?
    - Directly dependent on spot / perp price
    - Depends on interest of underlying
      - i.e long = borrowing asset
## Interest Rate Derivatives
## Options
### Greeks
