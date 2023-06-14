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
