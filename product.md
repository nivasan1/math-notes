- Orderflow + blockspace
  - Orderflow
    - Free txs + UI (intelligent routing of user txs)
  - Blockspace
    - Blockspace market-place (proto-rev)
    - Closer mempool / tx sequencing
- Extends capabilities 
  - Relayer guarantees
  - POB as a distribution channel
-  Comparison to SUAVE (credible commitment chain)
   - Where is commitment settled?
- Class of intents only settled on chain
- Adverse Selection?
  - 

- ## Skip Solve
  - High level -> low-level
  - 2 phases
    - Getting route
    - Getting recommendations for tokens
  - **Endpoints**
    - Snippet
      - Request -> response -> ibc-messages
    - First on-boarding service for a dev
  - Pretend sitting down w/ dev and walking thru swagger UI
## Neutron Fixes
- **goal** - Introduce support for consumer / provider chains in the sentinel
- **flow**
  - Each time a new validator signs in on the `consumer_chain`, if their cons_address for the consumer has changed it will be updated accordingly
- ## Changes
  - **schema**
    1. Add a new column to the `validators` table (`consumer_cons_address`)
       - `cons_address` field now represents the `provider` consumer address
    2. Backfill data for existing sentinels
    3. Make `consumer_cons_address` field non-nullable + unique in schema
        - From now on invariant is held that 
        - This task is blocked on **changes to validator-registration**
  - **sentinel**
    - No changes necessary
  - **validator-registration**
    - Upon completing signature validation, retrieve the `cons_address` on the consumer-chain, and update the entry corresponding to the `provider_cons_address`'s `consumer_cons_address` field
  - **data-layer**
    - All methods returning a validator, return the `consumer_cons_address` in the ConsAddress field
    - All methods expecting a ConsAddress expect the ConsAddress to be the `consumer_address`, use that as the idx into validators and make appropriate relationships w/ the `cons_address` field
      - Intuitively, the cons_address used externally from the data-layer is the consumer_cons_address, but the cons_address used in the DB is the provider_cons_address. We do this to maintain relational integrity (the provider cons_address is immutable)
- ## Tasks
1. Update Schema to include `consumer_address` field
    - Perform necessary backfilling in prod / test sentinels
2. Make `consumer_address`  non-nullable + unique constraints in DB
3. Update data-layer methods
   - At this point the sentinel has no knowledge of update consumer_addresses yet, but it will have the logic to be updated when the `consumer_cons_address`es are updated
4. Update validator-registration to update `consumer_cons_address` on successful sign-in for validators on consumer chains 
- What happens when a validator updates their consumer_address? How is sentinel made aware?
  - Validator will have to re-register?
  - 
## Testing
 - For testing data-layer changes
   - Spin-up local-testnet, change cons_address of validator behind sentry, have both vals sign-in again
## interchain Gas Tank
- **goal**
  - Prevent users having to maintain balance of gas-tokens on every chain they wish to transact on
- 
## Fee Abstraction
## PEPC reading
- **eigenlayer**
  - Actively validated services
    - off-chain services requiring slashable stake to incentivize actors to act accordingly
    - **problems**
      - Bootstrapping AVS (where does actor's stake come from?)
      - Value Leakage - Users of AVS service have to pay fees to AVS + ethereum fees
  - **pooled security via restaking**
    - Eth validators set beacon chain withdrawal creds to AVS contract, and run module corresponding to AVS
    - Permissionless slashing rules?
  - **free-market governance**
    - AVS create market for validators
      - AVS incentivize participants via staking rewards
      - Validators are consumers
    - **open market-place where AVSs can rent pooled security by Ethereum Validators**
  - **comparison to existing services**
    - **liquid staking**
      - Stake in network representing by token
        - Can redeem via DEFI (DEX)
        - Can redeem for initial staked assets after waiting withdrawal period
    - **super-fluid staking**
      - Users can stake LP tokens in network
  - **restaking methods**
    - Withdrawal address change
    - stake LSTs
    - Stake LP tokens 
    - Stake LP tokens of stEth
  - **Slashing**
    - Cost-of-Corrupting < Profit-from-Corruption (robust security)
- Need mechanism for credible signalling generally
  - PAP (principle-agent-problem) in protocol
    - Two slashing sources (protocol, eigenlayer), validators running eigenlayer have lower trust assumption (can be slashed in eigenlayer, but change not affected in protocol)
- **two-slot IP-PBS**
  - First slot finalize proof proposer entering into commitment, (i.e I expect next proposer to sign state-root $A$)
  - Next slot not finalized unless condition is met
  - Nodes can re-write any history before check-point?
    - How to prevent?
    - Add additional conditions on attestors (still risk of attestors failing to do job)
  - Idea: slash attestors who attest to blocks conflicting w/ commitment
    - i.e blocks in which proposer removes commitment from history (over-writes prev. slot block)
    - blocks where proposer violates commitment (and payment is unlocked)
  - pessimistic block validity
    - Block comes along w/ conditions (EVM bytecode) per commitment to determine whether commitment is satisfied
    - Encode additional cosm-wasm conditions in `ProcessProposal` 
- **contracts where third party pays**
  - Buyers submit bids to proposer
    - Proposer chooses winner (how to ensure counter-party pays?)
  - Bids are constructed as conditional txs?
    - Similar to bids in POB, but for more general use-cases? I.e block N + 10 will be built by `0xabc`
- **contracts where proposer pays**
  - Require validity proofs (SNARK for condition to be satisfied a-priori)
  - Recall pessimistic construction + slashing attestors to blocks where proposer violates commitment
- **PEPC Examples**
  - In protocol oracles
  - POB (granular block-building rules), PBS, etc.
  - Sync-chain (IBC?)
## Chainlink Staking
### Trust Minimization
### Staking
- Staking / slashing in traditional blockchains solves for **internal consistency**
  - Rules / proof are all made available by the protocol (i.e pub-keys of valid entities + signatures on messages)
- Oracle reports are a property of _external_ (off-chain data)
- **super-linear staking impact**
  - Adversary must have resources >> deposited funds (slashable stake)
- **implicit stake**
  - Bitcoin operators dis-incentivized to 51% attack as value of BTC depressed via lack of community confidence
  - _future fee opportunity_ - Reputation system used in chain-link for fee-allocation to dis-incentivize vals from acting poorly
- Stake + FFO comprise incentive to act correctly
- Maximize resources required for entity to corrupt network
  - Virtuous cycle of economic security, higher security -> higher fees from users -> more participation in network = more stake -> higher security (harder to economically compromise)
- **adversary**
  - Adversary is modeled as a _briber_
- **protocol**
  - Each reporting round, nodes can act as **watchdogs**, who observe aggregated value, and create alert if the report is faulty, payoff is derived from deposited stake of faulty participants
  - **assumptions**
    - 1/3 nodes are controlled by adversary
    - Rest of nodes are rational (i.e can be corrupted if reward is high enough)
  - Second-tier is **credible threat** (similar to additional penalty on lier / lesser penalty on teller in prisoner's dilemma)
  - 
# Ideas
 - **creating blue oceans**
   - Value innovation
 - **finding problems (not solutions)**
   - 
 - Lens + Custodial services?
 - Lens + secrets management?
 - Broadly speaking
   - Secrets management on the block-chain
 - **DEFI (AMMs) Lending Markets, etc.**
 - **Community Notes**
   - Friend.tech
   - Worldcoin
   - lens
 - **Quadratic Funding (vitalik)**
 - **fee-markets**
 - **game-theory**
   - Economists v. engineers
- Infra-as-a-service plays
- Healthcare payments
  - Talk to mom / other professionals
  - Advance payments
  - Credit issuance
  - Debt underwriting?
- RWAs?
  - Treasury bonds-on chain?
- **purpose of PEPC in cosmos**?
  - blockspace auctions?
  - ePBS
    - Why move PBS into protocol?
      - Relaying currently done as public good
      - censorship resistance? Smth to do w/ p2p
      - decentralize relay-set
- Analogs of ePBS to IBC-relaying in cosmos?
  - Move IBC-relaying into protocol?
  - Validators include client-updates + packets in their VEs
    - Vals include attestations to IBC-messages in VE, if proposer fails to include all (valid) IBC-messages attested to, proposer gets slashed (or does not get block-reward)
    - 
- **patreon**?
  - Tools for creators?
- # Social Finance
  - Friends.tech
  - Crowd funded hedge fund
    - I.e register a multi-sig
    - trading revenue distributed to holders of token
    - Index tokens
  - Fractional ownership of lens profile
  - Secondary Market for friends.tech shares
  - Twitch, youtube,
  - Lens tokenization modules?
    - Index tokenization (on-chain index)
    - 
  - Shares of profiles
  - Slashable stake
    - slashing conditions
  - Tax from shares trading
    - Accrue to multi-sig?
    - Accrue to token?
  - Decouple from lens
    - General framework for developing revenue-share from entity (generalized friend.tech)
  - Tokenization of trading (indexes)
    - Creators of indexes commit to basket in index first
  - Tokenization of reputation
  - Patreon version of friend.tech
  - Make arbitrary the object ur buying shares in
    - Make it as a lens profile
  - Advertisements on block-chain?
    - Advertisements / making shit viral seems useful w/ DLT?
      - What is primary alpha here?
    - What are necessary components?
  - 
# Why did ETH dump
- Recession alr. happened?
- Recession is going to be delayed significantly