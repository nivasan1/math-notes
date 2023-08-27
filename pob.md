# POB
## Components
- **x/builder**
- **ABCI++ Methods**
- **Mempool (Blockbuster)**
  - **sdk-mempool**
    - `PriorityNonceMempool`
      - Skip-list (ordered list optimized for bin. search)
      - Ordering
        - Ordered by sender nonce, priority
        - Rules
          - For given sender, txs are ordered by nonce
          - Otherwise, txs are ordered by priority
    - ![Alt text](Screen%20Shot%202023-07-03%20at%206.48.04%20PM.png)
- 
