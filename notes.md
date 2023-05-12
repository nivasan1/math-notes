### Fri. Dec. 16 
- Perform Rebase Of `Mev-Cosmos-Sdk` To Terra_Version, And Deploy On Terra-Testnet
    - Modify Execute Contract / Deployment Of Contracts For Testing? 
- Finish Handlers For Internal Status Server (Maybe Display In Front-End) ?
- Set Up Personal Laptop (Make Sure To Bring It Home) 
- Mon. Dec. 19
    - Mag Response. `Locksimubundle` Is A Lock That Must Be Held Whenever The Caller Is Interacting With The App's `Bundlestate`. This Locks The Mempool's `Applyblockmtxs`, Which Are Locks That Must Be Held For Interacting With Any Of The App States (Proposal, Bundle, Deliver, Check). This Means That Whenever We Are Referencing / Mutating That State For Simulation, We Know That Our Simulation Results Will Not Be Interrupted By Another Simulation. The `Applyblockmtxs[Simutype_Bundle]` Lock Is Held By `Runbundlesimulation` For Each Height, That Means That In Order To Mutate The `Bundlestate` Is Must Be Between Calls To `Runbundlesimulation` Or It Must Be Done In `Runbundlesimulation`
    - When / How To Return Simulation Responses
        - *Solution 1* - Simulate Bundle Independently, Return `Delivertxresponse` From That Simulation As The Bundleresponse For Searcher
            - Pros
                - Gives The Opportunity Have Store-Operations Before Aggregate Simulation, Can Skip Over Simulations If We Alr Know The Store-Key Conflicts
            - Cons
                - Likely Requires A Refactor Of The Selection Engine / Requires More Granular Locking Rules On Application States
        - *Solution 2* - Don't Respond With Any `Responsedelivertxs`
            - Pros - Significantly Less Implementation Complexity, Not Leaking Any Details In Auction / Simulation
            - Cons - Potentially Worse Ux
    - What Happens If `Netstate.Proposalblockparams.Maxgas = -1` ?
        - `Gbs.Maxgas = -1`, `Totalgas = 0`, So This Check
        ```Go
            // Break If We've Reached The Max Gas Or Max Bytes
            If Totalgas >= Gbs.Maxgas || Totalbytes >= Gbs.Maxbytes {
                Break
            }
        ```
        Short Circuits, And We Select No Bundles
        - Could Change Short-Circuit Check To This
        ```Go
            // Break If We've Reached The Max Gas Or Max Bytes
            If Totalgas >= Gbs.Maxgas && Gbs.Maxgas != -1 || Totalbytes >= Gbs.Maxbytes && Gbs.Maxbytes != -1 {
                Break
            }
        ```
        - `Gbs.Maxgas = -1` `Totalgas >= 0`
            - Short Circuit Is Not Reached Here, Dependent Upon Second Leg Of Conditional Statement
            - Call To `Trysimulatebundle` `Remaining Gas = Gbs.Maxgas - Totalgas < -1`, Gas Check In `Trysimulatebundle` Is Skipped, This Is Expected Behavior (We Don't Care Abt Checking That Bundle Is Withing Gas / Bytes Constraint Anymore)
        - `Gbs.Maxgas <= Totalgas` And `Gbs.Maxgas > -1`, Short-Circuit Is Reached, We Won't Be Adding Any Subsequent Bundles
        - Also Could Move `Gas / Byte` Check Into `Trysimulatebundle` (How Do We Maintain Running Total Of Gas / Bytes Used)
            - `Selectionengine` Maintain Current `Totalgas`, And Call `Trysimulatebundles` With `Gbs.Maxgas - Totalgas` And `Gbs.Maxbytes - Totalbytes`
                - Invariant Held, If `Gbs.Maxgas > -1` `Gbs.Maxgas - Totalgas >= 0`
                - If `Gbs.Maxgas = -1`, Then All Calls To `Trysimulatebundle` Won't Do Gas Check
            - Pro
                - Remove Check From `Selectionengine` Makes The Implementation Less Coupled (Responsibility Of Checking Gas / Bytes Not Overlapping Between `Selectionengine` And `Trysimulatebundle`)
            - Cons
                - Have To Generate Paymenttx Before Doing Check, Even If We Know That The Bundle Will Be Over Limit
            - Choice - Remove `Gas / Bytes` Check From Trysimulatebundle, This Moves The Job Of Gas / Bytes Checking To `Trysimulatebundle` Responsibility Is Clearly Defined   
                - `Selectionengine` Still Has To Maintain Cumulative Total Of `Totalgas / Totalbytes` From All Bundles 
                    - `Selectionengine` Rightly Has Access To This Data Uniquely, B.C It Is The Only Module Aware Of All Bundles To Be Selected.
    - Global Abci Mutex
        - `Applyblockmtxs[Simutype]`, Only Lock For Spsecific Simu_Types, Can Introduce A New Simu_Type To Do Isolated Simulations In Paralell
            - What Is The Purpose Of `Applyblockmtxs` Then? 
                - Synchronize Accesses To The `Responsecallbacks` On The Client's Application
        - `Localclient` - Takes Out A Lock On The Application Before Processing Calls
            - Sync - Calls Lock The Application And Then Make Call
            - Async - Adds Call To A Buffer, Iterates Through Buffer (Still Calls Application Synchronously), And Then Calls The Callback Fn With Response
        - `Grpcclient` - 
            - Has A `Grpc` Connection To The Abciapplication
            - Requests Can Be Made In Paralell, But Processing Of Call-Backs Is Made Synchronous (In This Case, There Is No Global Abci Mutex)
        - `Socketclient` - 
            - Connection Made Via Tcp/Ip Sockets, 
            - In This Case As Well There Is No Global Abci Application Mutex
    - Why Don't We Want Searchers To Know They Lost The Auction Until After Auction Has Ended?
        - Don't Want Results Of Auctions To Be Leaked From Searchers? Sealed-Bid Auction Means That Each Searcher Prices Their Arbitrage Themselves On Publicly Available Info.
            - Asymmetric Bundle Responses Means That Some Searchers Have Access To Information That Others Don't
                - First Searcher Sees A Response From Simulation, Thinks They Are In The Auction (They Shld Have Won This Opportunity), Second Searcher Sees They Aren't In, They Resend Bundle With Higher Auction Fee, Win Auction For Store-Keys And First Searcher Who Shld Have Won Now Loses
    - Flashbots Builder
        - Builder Receives Reqs. From Searchers `Onpayloadattribute` Aggregates Bundles, And Sends Requests To `Miner` (This Actually Builds The Block)
        - Requests Sent On A Regular Cadence (1 / Sec.), Requests To `Miner` Return A Block (Block Chosen By Profit, Auction Fee)
    - What To Do About Database Timestamps
        - Time Between Last Connection From Peers Could Be Exported To Db / Status Endpoint
        - Aggregated In The Internal-Server
    - `Mem.Heighttofirenext` 
        - For Each Proposal, Heighttofirenext == `Proposalblock.Height + 1` 
        - 
## Implementing Solution 1 For Delivertx Responses
 - Problem: Currently Data From `Responsedelivertx` In `Broadcastbundlesync` Request Is Not Well-Defined In Multi-Bundle. 
    - In Single-Bundle: `Responsedelivertx` Is The Result Of Isolated Simulation On Top Of `Proposalstate`, Determines Whether Or Not The Bundle Is Valid In Isolation
    - In Multi-Bundle: `Responsedelivertx` Can Originate From Any Round Of Simulation, And May Not Necessarily Be The Result Of Isolated Simulation (Bundle Is Simulated On Top Of Conflict, But Is Thrown Out Anyways)
        - If We Are To Respond With `Responsedelivertx` Results, The Simulation Should Originate From Simulation On Top Of `Proposalstate` 
        - Isolated Simulation On Ingress Must Not Be In Conflict With Simulation Of Bundles In Auction
        - Result From `Broadcastbundlesync` Must Not Leak Any Details From The Auction, I.E - Whether The Bundle Has Won / Lost The Auction, Any Sentinel-Specific Data Returned As Part Of The `Responsedelivertx` 
 - What Bundle Ingress Currently Does
    - Bundle Is Ingressed -> Bundle Is Checked Statelessly (Checktx, Potentially We Can Just Make This Delivertx If Height Is Within Bounds) -> 
        - Currently Each `Broadcastbundlesync` Thread Blocks On Receiving From `Bundleresponsech` (Either Closed, Or On First `Writebundleresponsetochan`)
            - Checks For `Simulationerror`  (Can Be Handled In Isolated Simulation) 
            - Checks For `Notskipproposer` (Blocks In Case Bundle Is Queue For Simulation And Proposal For Heightlastfiredfor +1 Is Not Received Yet) 
- What We Want It To Do
    - Bundle Is Ingressed
        - Precheck Bundle For Auction, Determine Desired Height For Auction
        - Bundle Has Been Pre-Checked And Is Determined Valid
        - If `Bundle.Desiredheight == Mem.Heighttofirenext && Hadskipproposer`
            - Intuitively, This Means That The Bundle Has Been Ingressed While The Auction Is On-Going, In Which Case, The Proposalstate Is The Correctstate For Tob Simulation, And The Bundle Can Be Immediately Checked On Ingress
            - Instead Of Checktx, Run Delivertx For All Txs In Bundle
            - If Any Txs Fail, Bundle Does Not Pass Checkbundle And Response Will Be Returned Immediately
        - Otherwise, Upon Receiving Proposal
            - Iterate Through All Bundles In Bundlequeue
                - For Each Bundle, Aggregate Delivertxresponses, And Write The Responses To The Bundle Channel
    - Modify `Checkbundle` To Just Use `Delivertx` With An Updated Runmode
        - Required Data From Checktx Is Also Present In Delivertx Response
        - Can Add New Simutype To Delivertx, 
            - One For Checktx State (`Simutype_Bundlecheckstateless`)
                - Follows Same Procedure As Checktx
            - One For Executing Delivertx (`Simutype_Bundlecheckstateful`)
                - Branches Off Of `Proposalstate`, And Executes Txs
# Tues Dec. 20
## Implementation Of Solution 1 On Mev-Cosmos-Sdk
 - *Solution 1* -  Add New `Abci.Simutype`: `Simutype_Checkbundle`, Only Relevant For Delivertx, This Create A New State `Bundlecheckstate` By Branching From `Proposalstate` All Modifications To State Will Be Made There.
    - Pros - Delay State-Transitions
 - *Solution 2* - We Can Just `Cachewrap` The `Proposalstate`, Pass That Context To Runtx, And Not `Write` Changes From Cache To `Proposalstate`
 - *Considerations*
    - For Each Bundle, How Do We Maintain The Intermediary States Of Txs In The Bundle Between Calls To Delivertx? 
        - State Must Be Stored In Memory (I.E In The Form Of A Volatile State In Baseapp?)  
            - Txs In Bundle May Depend On Each Other
    - Tob Bundle Simulation Must Be Able To Occur In Paralell With Auction Simulation
        - Simulations Must Not Be Touching The Same State
            - I.E Auction Simulation Modifies `Simubundlestate` And `Simubundlestatecache` 
            - Beginning Of Simulation Branches From `Simuproposalstate`, Tob Simulation Must Occur On Top Of `Simuproposalstate` 
    - If It Was Just A Single Tx
        - No New State Is Needed (I.E Can Just Cachewrap `Proposalstate`, And Defer Write)
    - **Solution 1**
        - Add New `Simutype` For `Delivertx`, `Beginblock`, 
            - `Simutype` In `Beginblock` Branches `Bundlecheckstate` From `Simuproposalstate` 
            - `Simutype` In `Delivertx` Writes To `Bundlecheckstate`, Does Not Keep Track Of `Storeoperations` (I.E Tracing Is Not Enabled)
        - Pros 
            - Enables Tob Simulation To Occur In Paralell With Simulation Of Bundles
        - Cons 
            - Overhead In Modifying `Beginblock` And `Delivertx` Adding `Bundlecheckstate` 
            - How Similar Is This To Logic For `Simutype_Bundle`?
                - Similar Logic With Branching
                    - Rollback / Commit Is Not Present, We Always Reset The `Bundlecheckstate`
                - Perhaps We Can Make This Logic Arbitrary W/ Several Volatile States Per-Bundle?
        - Considerations 
            - How To Properly Subdivide Logic Of Store Branching And `Deliverbundle`?
                - Could Handle Process Of `Beginblock` In `Deliverbundle` (Call `Beginblock` On Condition)  
                    - Does Handling `Beginblock` (Branching Of State) Muddle Responsibilities? 

    - What Is Needed In Solution
        - Simulation Of All Txs In Bundle On Top Of `Proposalstate`
        - If One Tx Depends On Prev. One, It Must Be Simulated That Way
            - This Is Solved With Volatile State In Baseapp. How Do We Ensure That This Is Reset To `Proposalstate`. By Remaking Cachewrap Before `Delivertxs`
        - 
    - **Solution 2**
        - Handle Branching Of `Proposalstate` In `Delivertx`
        - Cons 
            - Muddles Responsibility Of `Delivertx`
                - Now Tasked With Executing / Caching State Transitions From Txs And Branching State On Which Txs Will Be Written To
    - Note
        - Iteraction Sentinel <> Application Is Not Cleanly Defined
        - How We Create States On Which To Simulate Bundles
        - Can This Be Changed With Prepare / Process Proposal?
        - Can This Be Changed By Adding New Abci Methods To The Application 
            - Generalizes Interaction With Application For Simulation
            - Instead Of `Delivertx` Can Implement `Deliverbundle`
    - Internal Server 
        - Signin Page
        - Display Of Status-Endpoint Data
    - **Chosen Solution**
        - *Solution 1*
            - Create New State `Checkbundlestate` From `Proposalstate` On `Beginblock` With Simutype_Checkbundle
                - Set A Newgasmeter, So That Delivertxs Will Be Able To Consume Gas
            - Create A New `Runmode` For `Delivertx`, 
                - This `Runmode` 
    - Is There A Case In Which Tob Simulation Removes A Bundle That Should Not Have Been Removed?
        - Allowed Bundles
            - All Txs In Bundle Are From Same Signer
            - Two Sequences Of Txs, (Sender, Sender, ..., Signer, Signer, Signer...)
        - Reasons For Failing
            - Sequence Number
                - Sender Solves This By Merging Bundles Together 
                    - Only Reason You Can't Do This, Is If You Want Overlap Of Sections (This Is Potentially A Front-Run)
                    - Also Would Have Been Caught In Store-Key Checking Anyways
    - *Debugging*
        - Bundles Failing In `Simulateandprunebundles` 
            - Last Tx (Should Be Payment Tx) Is Invalid, Cannot Be Simulated
                - Must Append Payment Tx Somewhere? 
        - `Delivertxresponses` From `Execution.Go::Deliverbundle` Is Nil?
            - Only Time That This Could Have Happened Is In An Error In `Deliverbundle`?
                - `Delivertxresponses` - Generated From `Deliverbundle`
                - `Prunedelivertxresponse` Is Working Correctly (Modifies Slice In Place)
        - Go Initializations
            - **(Wednesday Dec. 21)**
            - `Delivertxresponses` Re-Initialized In Sub-Block, Which Did Not Carry Over To Parent Block
        - Factoring Generation Of `Payment` Tx
            - *Solution 1* 
                - Factor Payment Generation Logic Into `Generatepaymenttx()` In `Clistmempool`
                    - Call This In Deliverbundle (Conditioned By `Simutype`), Or 
                    - Call This In `Trysimulatebundle`
                - Pros 
                    - Gathers Responsibility Of Handling Tob Simulation In `Deliverbundle`
                - Cons 
                    - Muddles Responsibility Of `Deliverbundle`
            - **Solution 2**
                - Factor Payment Generation Into Mempool
                - Factor `Deliverbundle` Logic + Tob Simulation Logic Into `Simulatebundleattob`
                    - Must Call `Beginblock` There
                    - Lock Some Mutex So That Two Concurrent Simulations Are Not Possible
                    - Generate And Update Payment Tx In Bundle
                - Pros 
                    - Separate Tob Simulation Logic Into `Simulatebundleattob`
                    - Clear Responsibilities Between `Deliverbundle` And `Simulatebundleattob`
                - Cons 
                    - Still Requires `Rpc.Environment` To Have A Reference To `Blockexecutor`
        - `Paymentserver` - Context Deadline Is `1ms` Perhaps Too Short To Use Reliably In Future?
        - Possible Case Where We Miss A Bundle?
            - 2 Threads Ingressing -> Both Reach `Queuebundleforsimulation` Simultaneously
                - One Updates `Bundlequeueatheight` And Sends On `Bundlech` 
                - One Updates `Bundlequeueatheight` Before Simulation Thread Reads, But Sees Blocked Channel And Doesn't Send?
                - ^ Impossible - Send Happens After Update To Bundlequeue, 
                    - If Update Happens And Is Blocked, That Means Simulation Thread Hasn't Read
                    - If Update Happens And Is Not Blocked, That Means Simulation Thread Has Read, And That It Is Abt To Start Simulation
                        - Scenario Where We Re-Simulate
                            - Thread 1 Updates And Sends
                            - Simulation Thread Reads
                            - Thread 2 Updates, Reads Un-Blocked Channel, Sends
                            - Simulation Thread Reads `Bundlequeueatheight` And Simulates
                            - Simulation Thread Re-Reads From Channel Immediately And Starts Simulation Again W/ No New Bundles (This Is Fine)

        - Deadlock In `[Peers-Db]`?
            - Not A Deadlock, Error Was That `Val-1` Was Not Started
        - *Debugging* 
            - Race Condition On Bundle.Txs (Index Out Of Bound In `Deliverbundle` Call Back)?
                - Where Are The Mutators
            - Invalid Pointer De-Reference In `Prunedelivertxresponses`
                - Errored Simulation Result May Return Responses For Some Txs, And Nil For Others?
            - Callbacks On Proxyapps Could Possibly Be Interrupting Each Other
                - Tob And Regular Simulation Occur Simultaneously
                - Callbacks Defined In `Deliverbundle` Bound To Local Index Variable
                    - Set To Zero Each Time It Is Reset
                - Thread 1 Calls `Deliverbundle` -> Delivers Two Bundles
                - Thread 2 Calls `Deliverbundle` -> Delivers Three Bundles, Increments Counter From 0 -> 2, Yields To Thread 1
                - Thread 1 Delivers Last Bundle, Index Is Now At `3`, Thread Panics
            - `Prunedeliveryresponses` 
                - One Or More Of `Delivertxresponses` Was `Nil` 
                    - Dereferenced
        - *Solution 1* 
            - Add A New *Proxyappcheckbundle*
                - Caller Holds Lock On `Checkbundlestate` So This Is Already Thread-Safe, As Long As Future Users Of `Checkbundleapp` Know To Hold The `Checkbundlestate` Mutex
                - Have To Tell `Deliverbundle` Which App To Use Hold On `Simutype` - Up To Caller Of `Deliverbundle` To Determine Which Lock To Hold
            - Pros
                - Simple To Implement, Follows Existing Logic
                    - Seems Like An Anti-Pattern To Hold A Lock Across Multiple Stack-Frames (Function Calls)
        - *Solution 2*
                - Move `Applyblockmtx` Holding Responsibility To `Deliverbundle` 
                    - Responsiblity Is More Granular, Only One Lock Is Needed Over The Proxyappconn
                    - How To Prevent Two `Runbundlesimulations` Happening In Paralell?
                        - Introduce Mutex In `Cs.State`
                    - How To Prevent Two `Deliverbundle`S Happening In Paralell?
                        - Use `Proxyappbundle` 
                        - Lock On The `Simutype_Bundle`'S Lock
                            - Only Reason To Do This Is To Prevent Multiple Threads From Modifying Proxyappcallback
                            - 
                - Cons
                    - Simulation Over Multiple States Must Be Made Syncronous
                    - Ultimately,

        - Go With *Solution 1*, But Recognize The Vuln. With Introducing New Proxyappconns / Locks For Each Baseapp State In A Linear
            - Currently For Each Volatile State In The Base-App We Introduce A New `Proxyapp` And A Mutex That We Lock Whenever We Make Calls To The Application Through The Proxyapp
            - All Abci Calls Are Synchronized, So We Have No Advantage In Using Multiple Proxyapps To The Same Abci Server In Paralell (Threading Abci Calls Are Still Synchronized
            - All Sentinel Specific Interaction With The App Is Done In `Blockexec` I'm Wondering What The Specific Purpose Of This Object Is, Could We Factor Into `Sentinel` Reactor?

- *Abci*
    - Why Do We Need The Payments Logic / Generating Txs In Simulation?
        - Invariant - Validator Payments Must Be Committed On Chain W/ Bundle
            - Don't Want To Hold Funds On Balance Sheet
        - Registration / Payment Generation Can Be Generated On-Chain Via A Smart-Contract?
            - Don't Need To Be Accounting For Seq. / Acc. Number In Simulation
            - Can Have Searchers Pay Contract / Validators Receive Funds From Contract
    - New Abci Interface
        - Multiple Simulations Happening In Paralell?
        - Potentially Fewer Modifications To `Consensus/State.
- Idea 
    - Regular Messages Sent / Received By Nodes
        - Send Within Some Short Interval
        - Each Message Triggers Some Application Specific Logic To Occur
            - Validity Of Message To Receiver Is Unknown (Arbitrary Faults Not Allowed)
            - Sender Processes Result Of Message For Arbitrary Fault?
        - What Does This Achieve
            - Probablistic Guarantee Of Validity Of Node? 
- *Thurs. 22*
    - Linear For Proxyapp Issues - *done*
    - Review Will's Stm Pr
    - Checkout Mono-Repo - *In progress*
    - Work On Internal-Dashboard - *P1*
- Moving `simulateProposalThenBundles` into its own go-routine
## Ideas about Multi-Bundle Refactor into mono-repo
 - Plan for spec
    - Identify high-level interfaces needed for generalized bundle selection (best way to abstract mechanisms into their own independent objects.)
        - Must be able to implement interfaces for single bundle
    - Write out set of PRs into mono-repo needed to accomplish this.
    - Idea
        - Write single-bundle with a set of interfaces that are as general as we need, and factor all simulation / auction logic out of `consensus/state.go::State` and `mempool/clist_mempool.go::ClistMempool` 
 - Changes
    - ``
 - Purpose
    - Currently
### Mono-repo state
### Components of Multi-Bundle that can be implemented as interfaces
- Selection Engine
    - Interface
    ``` go
    type BundleSelectionEngine interface {
        // could cut down params to just bundles
        // do we need to check for the quit signal here? I wonder if we can have this running in a separate go-routine
        // and tell it to quit through a channel that the implementor of the bundle selection engine has
        SelectBundles([]Bundle, types.Block) ([]mempl.Bundle, int64, bool)
    }
    ```
    - Responsibility - Given a set of bundles
        - Return their profitability
        - Return the set of bundles that will successfully be committed on chain
            - No front-runs / sandwich attacks
            - `GreedyBundleSelector` - Only allow bundles that have no read / write conflicts w/ store-keys touched previously
        - Currently
            - Also has
### Potential Interface Groupings
 - *Solution 1*
    - Separate into these interfaces
        - **Auction Engine**
            - Resposibility - Given a proposal, apply it against the application, make necessary state changes.
            - Responsibility - Take signals from consensus (FireSentinel, Quit)
            - Responsibility - Manage SelectionEngines (BundleSelection, Secure-Txs Selection)
            - Handle updates to `WinningBundles` and `SecureTxs`
            - Handle insertion into the `BundleQueueAtHeight`
            - Keeps track of open auctions / skip proposers (all of this is currently done in the `mempool/CListMempool`) 
                - Can possibly be responsible for `SchedulingSentinelBroadcast` and `FireSentinel`
        - **BaseAppAdapter**
            - Responsibility - Encapsulate connections to the baseApp for
                - Delivering Bundles
                    - TOB simulation
                    - Auction simulation of bundles
                    - Generating payments for validators
                - Applying received proposals to the BaseApp
            - Maintain `proxyAppConnections` that are necessary for `proposalSimulation`, `bundleSelection` etc.
        (Below could potentially be sub-classes of a larger **SelectionEngine**)
        - **BundleSelectionEngine** 
            - Responsibility - Given a set of bundles, respond with a list of bundles and auction fee for those bundles
                - Bundles returned must all be committed on chain together
        - **SecureTxsSelectionEngine**
            - Responsibility (Must be parametrized by set of `WinningBundles`) 
                - Given a set of SecureTxs, simulate on top of `WinningBundles` ()
    - How this would work
        - Instantiate **AuctionEngine** in NewNode, likely a field of **Sentinel**
        - *ConsensusState* and *Clist_mempool* (wherever firing of sentinel happens) maintain references to *AuctionEngine*
    - Pros 
        - Highly abstracted design (individual components enabled a large amount of flexibility in implementation)
        - Only have to expose minimal details about the auction to any other packages
            - `Consensus/State::State.go` only needs to know about starting an auction on receipt of a proposal
            - `mempool/clist_mempool.go::CListMempool` only has to worry about asking for `WinningBundles`, and telling the `AuctionEngine` to update bundles in DB
                - Potentially can have the `AuctionEngine` control firing / `ScheduleSentinelBroadcast` so `AuctionEngine` just tells the `ClistMempool` what to add to its mempool
    - Cons
        - *AuctionEngine* has a large responsibility
        - *AuctionEngine* possibly takes on many of the tasks that are currently assigned to the *Sentinel* obj.
    - Rollout
        - Factor logic from `blockExec` into a basic implementation of `BaseAppAdapter`
        - Factor selection logic for single bundle in `SimulateBundleAtTOB` in `BaseAppAdapter`
        - Implement single-bundle
            - Use **BaseAppAdapter** only for `TOB` / bundle simulation
                - Call `BeginBlock` for each bundle to set the `TOBSimuState` in the `BaseApp`
                - Call `DeliverTx` for each tx in the bundle to Simulate on top of the `TOBSimuState`
            - **BundleSelectionEngine** - Straight-forward to implement for single-bundle
        - Implement the **AuctionEngine**, **BaseAppAdapter** and a single-bundle implementation of **BundleSelectionEngine**
            - Plugin the **AuctionEngine**, and **BaseAppAdapter** where they are needed 
                - Do this in a way that is as generalizable as possible, so that we can simply implement multi-bundle as an implementation of the **BundleSelectionEngine**
    - Analysis
        - `AuctionEngine` is effectively the Sentinel
        - Not Necessary
            - **BaseAppAdapter**
    - Ideal Integration w/ minimal intrusion into Sentinel
        - **AuctionEngine**
            - `CListMempool` handles ingress of bundles, passes bundle ingress `AuctionEngine` handles signalling / stopping BundleSelectionEngine / SecureTxsEngine
        - **BundleSelectionEngine** (responsibility is well defined)
        - **BaseAppAdapter** - Not necessary, can have **AuctionEngine** set predicates on the `BundleSelectionEngine` 
        - **BundleSelectionEngine** (single-bundle)
            - Use `SimulateBundleAtTOB` as validity predicate
                - `BundlesAtHeight` will be copied, and iterated backwards, first bundle to pass is chosen as WinningBundle
                - `QueueBundleForSimulation` logic remains the same
                - Always simulate over after selection?
                    - After selection can prune bundles with `AuctionFee` less than `WinningBundle`
                    - How to separate logic in bundle selection from `AuctionEngine`?
                        - Can have `AuctionEngine` implementation be diff. for single bundle as well
                    - How to make as testable as possible?
    - Diagram
        - Sentinel is only interface to **AuctionEngine**
            - Triggered by OnFinalizeCommitHandler, 
            - Triggered by OnHandleCompleteProposalHandler
        -  Sentinel triggers **AuctionEngine** to QueueBundleForAuction from ingress thread
            - Ingress thread triggers hook in sentinel, makes calls to **AuctionEngine**
        - Sentinel grabs WinningBundles from auction

 - *Solution 2*
    - Abstract only `trySimulateBundle`, `runBundleSimulation` and `BundleSelectionEngine` 
        - Assume `trySimulateBundle` and `runBundleSimulation` will be methods in interface in `AuctionEngine` 
- *Internal Dashboard*
    - Present data on the `/internal` route
    - What data will be presented in the table?

    | moniker | node_id| connection_status| time_last_connected| version |
    |---------|--------|------------------|--------------------|---------|
    - query
        - Get (moniker, cons_address) from validator's table 
            - `select moniker, cons_address from validators`
        - Get (node_id, version) indexed by cons_address from nodes
            - `select moniker, validators.cons_address, node_id, version from validators inner JOIN nodes on validators.conTis_address = nodes.cons_address;`
        - Get (timestamp, status) from connections
            - `select distinct on (nodes.node_id)  moniker, validators.cons_address, nodes.node_id, version, connections.status, connections.timestamp from validators inner JOIN nodes on validators.cons_address = nodes.cons_address inner JOIN connections on nodes.node_id = connections.node_id order by nodes.node_id, connections.timestamp DESC;`
- Adding timestamps to DB
    - `winning_bundles`, `losing_bundles`, `nodes`, (sentinel-monorepo PR)
    -  `validators`, `api_keys`, `payment_info` (val-reg PR)
    - Storing timestamps?
        - Updating timestamps in the DBs?
        - Storing as a timestamp
        - Storing as a Unix timestamp (number of seconds from )
    - Comments 
        - `validators` - Want to know when a validator registered only (can be time of row creation) (other columns will be updated but changing timestamp will modify meaning of original timestamp) (`registration_time`)
        - `nodes` - Want to know when the node was first registered, this can be retrieved by having timestamp set on creation (no trigger) (same as validators) (`registration_timestamp`)
        - `api_keys` - Not necessary here (can be a timestamp entered on initial register_node request)
        - `payment_info` - ok
        - `winning_bundles` / `losing_bundles` - Want to know what the bundle timestamps are w/r the block timestamp of their desired height
    - Backfilling
        - `losing` / `winning` bundles - want to have the approximate time of first entered (better name for timestamps)
        - `validators` - need proxy of timestamp for validators (get info from first entry in `val_profits`) (block timestamp of first bundle landed on chain successfully proposed by them)
    - Internal dashboard
        - Want to only have validator level info
            - Are they connected (any one of their nodes is connected)
            - Are they disconnected (not connected) 
            - Are they dead (disconnected, and latest time of connection for any node is > 2 weeks / non-existent)
                - Order of importance for alerting
                    - Validators who have disconnected within the day (HIGHEST: RED)
                    - Validators who have disconnected within 2 weeks. Val is not assumed to be dead, but may be inactive (MEDIUM: orange)
                    - Validator's who've been disconnected for longer than 2 weeks
            - Sort data on backend?
                - Can sort the array as necessary before sending it to the browser?
        - Query
            - `moniker`, `connection_status`, `timestamp`
                - Can get this by union of connected / disconnected vals + timestamps
                - *Solution 1* - Take union of all queries
                     - Want to re-use `conn_data` table
                - Return table with connection status per validator, and handle sorting in backend
                - *Solution 2* - get query and handle sorting in back-end
                    - Pros
                        - Simpler query
                    - Cons
                        - Sorting not done in sql
    - Running in prod DBs
        - `Juno`- https://rpc-archive.junonetwork.io/block?height={height}
            - `./backfill -nodeAddr='https://rpc-archive.junonetwork.io' -pgxPassword='O82F$6tlgqCu' -dbHost='juno-1-db.skip-internal.money'`
            - PID : 732407
        - `Terra` - https://terra-rpc.stakely.io/block?height={height}
            - `./backfill -nodeAddr='https://terra-rpc.stakely.io' -pgxPassword='O82F$6tlgqCu' -dbHost='phoenix-1-db.skip-internal.money'`
            - PID : 732429
        - `Evmos` - https://eth.bd.evmos.org:26657/block?height=7495765
            - `./backfill -nodeAddr='https://eth.bd.evmos.org:26657' -pgxPassword='O82F$6tlgqCu' -dbHost='evmos_9001-2-db.skip-internal.money'`
            - Will have to create new branch to make changes there, also will have to pass in new DB URL. NO
        - Steps
            - Have to run `set_triggers` sql script
                - Adds the `registration_timestamp` column to `validators, nodes`. Adds `auction_timestamp` to winning / losing bundles. Adds `last_update_timsetamp`
                    - What to do about `last_update_timestamp`? Will currently be set to the time the `set_triggers` script was run, but will be updated as validators update their payment address
                        - Can be backfilled? Not necessary?
            - Run backfiller
                - Will have to make the DB url configurable (DBs that will be updated should have the same DB password)?
                - Will have to make the `/block/height` URL configurable?
            - Have to run `backfill.sql` file on each DB
    - Solution
        - Make DB URL / password / node address configurable as CLI params
            - Test against the juno backup DB
            - Test making requests to the nodes with x # threads
        - Have to make another branch for evmos requests? No
            - **Solution 1** -
                - Check that the Evmos URL is used in the backfiller (do this in a helper fn)
                - Can make a method to format URL for backfiller
            - **Solution 2** -
                - is there a diff evmos archive node to use? Yes
    - Debugging
        - Size of connected vals query is 49
        - Size of disconnected vals query is 2
        - Size of dead vals query is 6 (there are 56 validators?)
- How to update `winning / losing_bundles`?
    - Currently heights populated in `winning_bundles` and `losing_bundles` are heights that are not in `val_profits`
    - Want to update `auction_timestamp` with `val_profits.timestamp` where `val_profits.height = losing_bundles.height
        - Update `auction_timestamp` value in joined table? 
            - Inner Join `losing_bundles` and `val_profits` on `height` as joinedTable
            - Update `JoinedTable.auction_timestamp = val_profits.timestamp[height]` where `joinedTable.height = val_profits.height`
- How to update timestamps in `nodes` and `validators` 
    - For each validator, 
        - Set their registration timestamp to the earliest entry in `winning_bundles` or `losing_bundles` , where the proposer is the validator
            - Guaranteed to know that at this point the validator has def. registered their node
            
- **Solution**
    - Make a psql trigger for inserts and updates into the tables
        - Have to handle inserts / updates into winning / losing bundles separately
    - `winning_bundles` and `losing_bundles` are only inserted into once, so don't set trigger
        - Update afterwards with output from scriptq
- **READ AND UNDERSTAND KEEFER's SPEC**
    - Write diagram
    - Assume his spec is correct (changes to spec only as needed via proof, should be carefully considered)
- **Sentinel-Refactor** Notes
    - What is an `adapter`?
### Mev-Cosmos-Sdk
# Tue. Jan. 3
### Debugging Payments Server
 - Error that occurs is `iavl.MutableTreeWithOpts()` takes wrong arguments, call initialized in mev-cosmos-sdk
    - Cosmos-sdk uses `v0.19.0`, payments server uses `v0.19.4`
- Tentative Solution
    - Imports of injective / ethermint depend on `iavl v0.19.4` 
        - This means that the version of `iavl` used is `v0.19.4`
    - Remove imports of `injective` / `ethermint` 
    - Pros
        - This allows us to keep our main-branch safe, and have compatibility w/ all chains for the payments server
    - Cons 
        - Forces us to use diff. branches of payments server for all chains
- Can change usage of local `mev-cosmos-sdk` to be, cosmos repository
    - Pros
        - Can possibly use single version of payments server for all chains?
    - Cons
        - In the future we are limited to using cosmos-sdk v0.45.9 for all chains, as opposed to their native versions of cosmos-sdk
### TX-Feeder refactor
- Idea: move the code-base to pure go
    - Not necessary at present, no advantages to js implementation
- Ideal functionality 
    - Same binary / script for all chains
    - References a config shared among all chains
        - Config has all necessary data, i.e payment, 
    - started through CLI with args
    - metrics
        - bundles_sent(label: chain_id)
        - amount_in_native_denom(address: )
            - Used for alerting when gas-fees are decreasing too much
    - Can run from single host, i.e multiple senders per chain
- Bundle-feeder productionization: Give us instant feedback on new testnet versions(Nikhil)
    - Refactor to have maximal code reuse across different networks
    - Refactor so that they don’t need to be restarted (i.e. no net fund transfer between wallets)
    - Add liveness metrics to the bundle-feeder scripts
    - Deploy all scripts on a single host or each one on a host related to its target network (for all testnets)
- Code-Re-use
    - Creating clients for sending
    - Generating txRaw (can make abstract class for generating txRaw?)
        - Evmos implementation
        - Injective implementation
        - Juno / terra / duality? implementation
    - **Juno / Terra** 
        - Generate signers with `getOfflineSignerWithProto`
            - Generated with `mnemonic` 
            - Generated with chain config, found from cosmos-chain-registry
        - Get `privKey` from signers 
        - Generate clients using `getSigningCosmosClient`
        - Generate `SkipBundleClient` from `sentinelEnvEndpoint` 
        - Bundle broadcast loop
            - Loops and creates bundle send msg + auction payment via payment msg generation (unique implementation)
    - **injective**
        - Process of retrieving signer is same as above
            - Process of retrieving `privKey` is from signer (as above)
        - `createSendTxRaw` unique to injective (method can be copied into interface implementation)
        - bundle Send loop is the same
            - Generate skipBundleClient
            - Create two txs through tx generation
            - Create bundle, and send
    - **evmos**
        - Generating signer is the same
        - Signing / sending bundle is the same
        - Process of generating tx is different
    - **Config**
- **Refactor plan**
    - Define base-class `BundlePaymentSender`
        - Handles instantiation of `signers` (in constructor)
            - takes config object as parameter
            - Instantiation of privKeys as well
        - Generation of payment tx / bundle Tx (this will be left to implementations)
            - Standard implementations (left to implementor)
        - Bundle Creation
            - Method also left to implementation
            - Account for multi-bundle?
        - Creation / sending of bundles
    - Define driver 
        - Instantiates necessary clients (takes chain-ids in config)
            - parses arguments from config
        - Iteratively runs sender methods on all BundleSenders
## Questions For Refactor
### Sentinel Management of Bundles is Weird
 - Seems like there should be a holding pen for all bundles for each height?
 - Need to have some-way of storing all received bundles for each height, up until choosing the set of `winningBundles`
### Move ValidatorPeerManager into Sentinel
- Sentinel sends set of winningBundles and proposer to fire to `BundleBroadcastReactor`
- `Ingress` - Reads / writes to Sentinel whenever new validators join
## Thu. Jan 5
### PR Reviews
 - *Moving `AVERAGE_BLOCK_TIME`*
    - Previously stored as a globabl-exported variable from the `state` package
    - Moved into private instance variable on the `blockExecutor`
    - Question 
        - Why is estimated block timestamp necessary?
            - Used in `MakeBundleSimulationBlcok` for estimating block-timestamp
                - *Aside* - No lock on `ExecCommitBlock` 
                    - Can result in two simultaneous calls to `execApplyBlock` which can both modify the proxyAppCallback (race-condition on the call-back)
            - Sets the block timestamp in the context to the estimated one for bundle simulations 
                - Potentially triggers time-dependent events in sdk
    
- *Moving Payments from `Sentinel` package into its own package in `Sentinel-Core*
    - Moves `PaymentsClient / PaymentsConfig` into their own package in the sentinel
    - Why does `PaymentsClient` need to live in the mempool?
        - `state/blockExecutor / consensus/State` need access to the same `PaymentsConfig / PaymentsClient`
- *Pull SentinelMempool Out of BlockExecutor` *
    - `blockExecutor` doesn't need tendermint specific mempool functionality?
    - `CListMempool.Update()` - Is this not needed to remove committed txs from the `ClistMempool`?
        - What does `ClistMempool.Update()` do?
            - Closes `bundle.ResponseCh` 
            - Removes `SecureTxs` once they have been committed in blocks
            - Deletes `WinningBundles`, `HadSkipProposer`, `PreProposalBundleQueue` etc.
    - Solution - Wait to merge the PR until we control the `Node` package, so that we aren't instantiating a no-op mempool
- *Split `State` to Tendermint Specific and Sentinel Specific Fields*
    - Changes to `updateState` not necessary?
        - Method is not exported by regular tm.
            - Do we have to override this in `sentinel` 
## Sentinel-Monorepo Notes
- Modify sentinel routes 
    - Have them served on a server whose implementation is totally controlled by sentinel-tendermint
    - RPC - What is in tendermint, why?
    - How to enforce concerns from notion doc, after separation
### sentinel rpc refactor
- How is it done currently?
    - Currently `Sentinel` specific RPC endpoints defined in the `rpc/client/interface.go::Client` object
        - Possibly revert to vanilla tendermint `Client`, extend interface in sentinel, and export that package in node?
            - Sentinel specific methods are defined in the `ABCIClient` interface (why is this?)
            - Also define them in the `.../light/...`
                - Is this even necessary? Doesn't seem that the light client needs the sentinel rpc methods?
                - Light client also serves as a proxy for tendermint rpc?
                    - Used to serve requests as if it is a tm full node, receives requests, fulfills them, cross-checks against a trusted full node, and responds
                - *There is only one sentinel, so light-client functionality is not necessary*
        - `rpc/client` is default implementation used by most of tendermint
    - How is tendermint rpc served?
        - `sentinelcore` rpc methods reference a diff. rpc environment than vanilla tendermint's
        - `node` sets up rpc in `startRPC` 
            - Configures environments above
            - retrieves listen addresses from config, and serves over those addresses
                - Sets up websocket manager in `NewWebsocketManager`
                    - registers `/websocket` route with `WebsocketManager`
                - Configures `RPC` routes
                    - Handled in `rpc/jsonrpc/server`
                    - 
            - Also sets up `grpc` handlers, defined in `rpc/grpc/core`
    - Removing `light` client dependencies on sentinel functionality
        - Light rpc client must have the same interface as `rpc/client::Client`
    - `checkTx` ?
        - Overridden rpc method, can replace in func-map with what is defined in the `sentinel-rpc` package
    - Overridden methods
        ``` go
        BroadcastBundleAsync(context.Context, []types.Tx, int64, []byte, string) (*ctypes.ResultBroadcastBundle, error)
        BroadcastBundleSync(context.Context, []types.Tx, int64, []byte, string) (*ctypes.ResultBroadcastBundle, error)

        // Setters for validator settings
        SetValidatorFrontRunningProtection(context.Context, string, string) (*ctypes.ResultSetValidatorFrontRunningProtection, error)
        SetValidatorPaymentAddress(context.Context, string, string) (*ctypes.ResultSetValidatorPaymentAddress, error)
        SetValidatorPaymentPercentage(context.Context, string, string) (*ctypes.ResultSetValidatorPaymentPercentage, error)

        GetPeers(context.Context, string) (*ctypes.ResultGetPeers, error)
        RegisterNode(context.Context, string, string, string) (*ctypes.ResultRegisterNode, error)

        // DEPRECATED, but still included for backwards compatibility:
        RegisterNodeApi(context.Context, string, string) (*ctypes.ResultRegisterNodeApi, error)
        // part of mempool's rpc client interface
        CheckTx(context.Context, types.Tx, string, string) (*ctypes.ResultCheckTx, error)
        ```
    - What happens to `CheckTx` in the lightClient implementation?
        - We over-wrote `CheckTx` with our own checkTx endpoint, does the light-client ever have to use this?
            - Perhaps when running as a tendermint HTTP Proxy server
    - Overwrote `UnsafeFlushMempool`
        - 
 - **Solution 1**
    - Revert sentinel-tendermint's `/rpc` and `/light` libraries to standard tm
    - Instantiate routes / RPCFuncs in `sentinelrpc`
    - Register routes in `startRPC` 
        - Append sentinel routes to tendermint ones
    - Questions
        - Best way to handle CheckTx (interface is different)
            - Can over-ride `checktx` route for clients / light client Proxy
        - What methods are needed for the light-client in state-syncing node?
            - All routes except `CheckTx` will be the same
            - Can deprecate CheckTx method in sentinelrpc
                - Not necessary to export
    - Pros
        - Simple solution
        - Directly separates tendermint rpc dependencies from sentinel-core's
    - Consx
        - Client implementations from tendermint will not include implementations for sentinel specific rpc 
            - Does not look like this functionality will be missed?
- Comments
    - Attempt to totally depre
## Friday:
- Will comment
    > The way I'm thinking about this now is that we should move the "fire sentinel" sequence to be more stateless (i.e., I don't like that it uses the mempool state to determine what to fire -- we should have a stateless "fire sentinel" entry function that we tell exactly what to fire). If we agree on that then I think the PostFinalizeCommitHandler should start taking more and more parameters, rather than try to embed them in CListMempool state. I also thought long term the CListMempool should go away entirely in the sentinel. But this feels more like a refactor conversation, I don't want to manage all of that here. If this change is marginally acceptable, I'd rather ship this first and then we can shift our sights to the refactor and clean everything up.
## Implementing Disconnected Validators Route
- query
``` sql
SELECT
  validators.oper_address
FROM (
	SELECT cons_address
	FROM nodes
	LEFT JOIN (
	  SELECT
	    node_id,
	    max(timestamp) AS latest_timestamp
	  FROM connections
	  GROUP BY node_id
	) AS latest_connections
	ON nodes.node_id = latest_connections.node_id
	INNER JOIN connections
	ON nodes.node_id = connections.node_id
	AND timestamp = latest_timestamp
	WHERE status = 'connected' 
) AS connected_nodes
RIGHT JOIN validators 
ON connected_nodes.cons_address = validators.cons_address
WHERE connected_nodes.cons_address IS NULL
	GROUP BY validators.cons_address;
```
- Returns the operator address of all validators
    - Who currently have no connected nodes
        - This includes, all validators whose
## Debugging Duality Tx-Feeder
- Error `bad mnemonic` from `getOfflineSigners` from `cosmsjs-utils`
    - `getOfflineSigners`
        - Takes plain-text mnemonic
        - Takes `chain` object defined
            ``` javascript
                chain: {
                    bech32_prefix: string; // this is cosmos
                    slip44: number; // slip44 ?
                };
            ```
            - 
## Implementing v0 of RPC refactor
> 1. Pull all the code out of Tendermint, wholesale into Sentinel Repo
> 2. Build the interfaces for bundles according to spec
> 3. Define a return type for the APIs
> 4. AuctionResult - result of submitting a bundle to the auction
> 5. SkipSecureResult - result of submitting to skip secure
> 6. Implement BundleQueue interface
> 7. Build BundleService that uses the above types to implement routes, with unit tests
> 8. Repeat #2 a/b/c/ but for the ValidatorService (Talking with Barry it seems like we should implement both at the same time)
> 9. Wire up routes in Tendermint to these new handlers, and rip out existing routes
> 10. Remove any and all extraneous code that is no longer used
- PRs
1. Separate rpc logic from sentinel and tendermint
2. Implement validator-rpc and bundle-rpc (can be in separate PRs)
    - Interfaces
    - registering routes

## PR 1 - Rip Tendermint RPC out of tendermint
- Define routes in `sentinel-core`
- Revert ABCI client interface 
    - Deal with diffs between vanilla tendermint / sentinel-monorepo?
    - Can remove dependencies on tendermint from sentinel-core?
        - Not actually revert rpc / light-client code
        - Only serve sentinel-tendermint json-rpc in node.go
    - Remove all tendermint core routes from the rpc API
        - Only use the `sentinel-core.Environment`
        - Remove `grpcServices`
        - Remove `webSocketServices`
    - Revert all code in sentinel-tendermints back to rpc / light back to vanilla tendermint
``` go
import (
    "tendermint/tendermint/whatever"
)

type Foo struct {
    w interface{} // this means that we can place an object of any type here, (or an interface type that has a subset of the intersection of the methods implemented by types in diff. versions)
}

// then given a type *whathever
var w *whatever.Whatever
foo := Foo{w}
```
 - PRs for each tm version 

## Scheduler
 - Guaranteed execution across chains (domain)
    - Synchronously
 - Block builder guarantees LPs will execute trades at price specified by builders
 - Sell timestmap delimited periods during which a proposer is given permission to propose a block
## REST Response Types
- REST responses
    - Successful response should just return the data itself
        - Pass the data on sucess to response as `map[string]interface{}`
        - Use `map[string]interface{}` passed into `respond` as the response data
        - Adhere to standards from sdk-rest interface
    - Non-successful response should return an error object defined like so
        - Define new `rpcError` object that defines the error, `code` + `message`
            - Where `code` is the equivalent json-rpc error associated w/ request
            - `message` is the actual error message returned to client
## Tendermint Light Client Daemon
- Is this spawned whenever a node is started?
- Light-client
    - Receives header of a block
        - Contains merkle-root hash of `IAVL+` state tree
- The client can verify headers against previous ones to guarantee that the state is correct
    - Tendermint state never forks, i.e ancestors of every block will always be the same
        - Can verify current header against header from `h-1`
- Light-client receives header, 
    - Verifies that `> 2/3` validators have signed the header (instant finality), any other `2/3` majority implies that `> 1/3` faulty nodes (impossible)
- Validator-set can change
    - If validator set does change, light-client has to download headers w/ proof of validator-set changes
- Client receives header
    - Verifies state against merkle-root hash via a merkle-proof, can ask full-node for whatever txs it needs to form the merkle proof
### Sentinel-Monorepo PR
- **Solution 1**
    - Make changes / ship first w/ `tendermint v0.34.19`, then do subsequent PRs after
        - One PR per version
    - Considerations 
        - Will other tm-versions break if `rpc-refactor` is merged?

- **Solution 2**
    
- Testing?
    - How can changes to `tm-rpc` be tested internally?
        -`startUpRPC` - Check that sentinel handlers exist?
        - Test that non-sentinel handlers do not exist
## Tuesday Jan 10.
### Sentinel-Monorepo PRs
- **ENG-386**
    - Putting an upper-bound on `bundle.DesiredHeight`
    - Conclusion:
        - Auction-height bound is determined by the block-time of the chain (max_wait_time_in_sec / blocks_per_second)
        - Can move to constant?
    - ASIDE
        - **ALWAYS LABEL CONSTANTS** (usually in all-caps)
- **ENG-396**
    - Have `BroadcastTxAsync / Sync` route to the `BroadcastSecureTx` endpoint
    - Approved
### Sentinel RPC refactor PRs
### Testing
 - Test starting the `rpc` and attempting to land requests
    - Requests to `sentinel-rpc` routes should be handled successfully
    - Requests to `tendermint-rpc` routes should not be handled successfully
### Structuring PRs
- **Solution 1**
    - PR each reversion (of `/rpc` and `/light`) as separate PRs onto `sentinel-monorepo`  
- **Questions**
- What files are necessary to revert for `PR`?
    - Solution - Revert `/rpc` and `/light` to main
        - Outcomes - Diff will be much smaller
            - Reverting of `/rpc` / `/light` is scoped in diff PR: Pro
            - Diff for PR will be smaller
            - Potentially makes the code break?
                - This should not happen
                    - Changes in `sentinel-core` should be agnostic to whatever is done in `sentinel-tendermint` and vice-versa
- Ideal
    - PR for defining routes in `sentinel-core` in a way that is agnostic to `sentinel-tendermint`
        - This includes instantiations in `node.go`
    - PRs for reverting `/rpc` and `/light`?
        - Can potentially do PRs for each version?
            - This makes most sense
        - Dependent upon initial PR separating dependencies to where nothing will break from instantiation
- What should not happen
    - PR1 
        - This PR should ideally only be changes to `sentinel-core` and corresponding `node.go`s
            - There should be minimal changes to `/rpc` and `/light`
    - Subsequent PRs
        - These should only be reverting `sentinel-tendermint` code that is no longer in use
- Actionables
    - Look at diffs to see what specifically is changed in current branch
        - Attempt to revert `/rpc` and `/light` to 
    - After reversion what is breaking
        - `/rpc/client`
            - The implementations use `sentinelrpc` definitions, which return `sentinelrpc.ctypes` response types, 
        - `/rpc/core/routes.go` - Expects to see a `sentinelrpc.CheckTx()` but this handler is not defined
            - **Solution 1** 
                1. Change the `Client` interface in `/rpc` 
                    - This change would need to be made across all of `sentinel-tendermint`s
                2. Add the `CheckTx` route back to `sentinelrpc` so that the other `Routes` objects can safely compile
                    - Remove once all sentinel-tendermints have been safely reverted
            - **Solution 2**
                - Can define `sentinelrpc` interface?
                    - Embed that interface into `/rpc/client::Client`?
                        - What are the advantages?
                            -Define interface once in `sentinelrpc` and will not have to re-define?
                        - Still requires changes in all sub-sentinel-tendermints
                    - Can just stub `CheckTx` implementation in sentinel-tendermints?
                        - Not necessary, saves us from having to define / remove in `sentinelrpc`
                            - Requires us to make changes to all of the sentinel-tendermints
                        - Can remove `CheckTx` from the `rpc::Client` interface
            - **Question**
                - Why are there no errors in `/light`?  
                    - Changing the `rpc/client` rpc interface would break the `light/client` implementation
                - 
            - **Solution 3**
                - Can remove the `sentinel-rpc` methods from `rpc/Client` and from `light/client`
                - Pros
                    - Pushes earlier work of reversion forward?
                        - Is this necessary, is there a way around this?
                    - PR will rip sentinel-tendermint rpc out of all sentinel-tendermints?
                        - Possibly an advantage
                - Cons
                    - PR will be much larger, possibly will be a poor division of responsibility
                    - May be hard to review?
                    - Potentially may be reverting code that we need?
- **Reasoning**
    - Any changes made to `/light` and `/rpc` were only made to accomodate us moving sentinel-rpc / response definitions to `sentinel-core`
        - From this point on `/light` and `/rpc` have no importance in sentinel execution, they can / will be reverted to their vanilla tendermint versions
    - 
### Debugging Relayer Reconnection
- **Sequence**
    - Node receives proposal
        - *Question* - When does not timeout on proposal
            - What does this scenario entail
## Wed. Jan. 11
### Review Branching Strategy
- To build / deploy `sentinel-monorepo`
    - `main` is a buffered branch
        - All PRs merged into main
    - Each release requires tag of release branch
        - Sentinel will be auto-deployed
### Make PR ready
- Any routes that are not included in `sentinel-tendermint-v0.34.19`?
### PR Into Half-life
- **How does it Work?**
- Driver of monitor process in `validator.go` 
- **Config**
- Notification section
    - Specify what notification type is requested   
        - Only `discord` is supported now
    - Specify webhook token + id
- Validator Section
    - For each entry in validator section
        - Specify names / addreses of sentries (can add whether they are running `mev-tendermint` here)
        - Specify rpc-endpoint of validator
    - *Fullnode Field*?
        - Determines whether to check `signing` / `slashing` info for the node
    - *Sentries*
        - Each sentry w/ name and grpc listen address
            - Must also have the rpc listen address?
            - Can also just be quer 
- **Root command**
    - Reads config
    - Checks if a discord notification config exists, if so, instantiates a discord notification service
    - Config
        - For each validator in config, run `runMonitor`
- **Discord Notification Service**
- **Top Level Monitoring Service**
- Maintain `ValidatorAlertState`
    - Tracks number of alert events per alert?
    - Spawns `monitorValidator` and `monitorSentry`
- *MonitorValidator*
    - Instantiates client to validator's rpc server (`26657`) and queries slashing / signing params (if the val. is a full node)
    - After that, instantiates a `status` request to the node (this is where we over-ride status request)
    - (If the validator is a full-node ) After status request, checks for each block (since the last height queried), and checks for missing signatures 
        - If validator's signature is not present in the block, the validator has not signed, and the missed block count is incremented
    - Accrues all errors from validator monitoring and returns to caller
-  *monitorSentry*
    - 
### Panic + Halflife PRs
- Alerting on `is_peered_with_sentinel` is false
- PRs on `half-life` + `panic`
### Half-Life
- Import `mev-tendermint` and over-ride status requests in `monitorValidator` and `monitorSentry`
- Add the 
- **Pause**
## Panic
### Docs
 - `Cosmos nodes will be monitored through their Prometheus, REST, and Tendermint RPC endpoints.`
- **Operation** 
    - **Start-Up**
- **Components**
    - **System-Monitoring** 
        - *Moniter Manager* process
           - Manages existing *system-monitors*
           - One per *machine* (notion is abstracted from user, can be contrainer, bare-metal machine, data-center)
        - *System Monitor*
            - Scrapes data from *node exporter* (`/status` endpoint), aggregates data, and sends to
                - Transfers scraped data via `RabbitMQ` (asynchronous message broker between services (can be over sockets / IPC)) to system data transformer
    - **Data Transformation + Storage**
        - **System Data Transformer**
            - Receives data (scraped data is queued by monitors), aggregates scraped data with current state (stored in REDIS), and then sends combinded data to *System Data Store* and *Alerter*
        - **System Data Store**
            - Stores alerts / transformed data in a persistent key/value database for efficient queries            
    - **Alerting**
        - **System Alerting**
            - Receives scraped data, checks for whether the alert rules have been met, and routes alert signals to **Channel Handler**
        - **Channel Handler**
            - Receives alerts specified for a specific channel-id and routes them to the node operator via the channel associated with the channel-id (Slack, tg, etc.)
- **System Monitor**
    - Left off here: `https://github.com/SimplyVC/panic/blob/40cdb9f87723a75ed364fc76a006fdcc8343fdd1/alerter/src/monitors/node/cosmos.#L398`
    - Monitor uses a `TendermintRPCAPIWrapper`
    - `get_status` - Fetches data from the status endpoint from the node
- **Implementation**
    - `CosmosNodeMonitor` - This is what is responsible for scraping `/status` endpoint of node, and ultimately retrieving `MEVInfo`
        - Done in `_get_tendermint_rpc_direct_data`
    - Status data is processed in `_process_retrieved_tendermint_rpc_data`
    - **Monitorables**
        - Have to add `is_peered_with_sentinel` in monitorables
    - **Data_transformer**
        - `_update_tendermint_rpc_state`
            - This is where the aggregated data from the monitor is received and updated
        - `_transform_tendermint_rpc_data` 
            - This is where the data published by the `CosmosNodeMonitor` is ingested and transformed
        - `_process_transformed_tendermint_rpc_data_for_alerting`
            - Where transformed tendermint data is sent, before being sent to the alerter\
        - `_process_transformed_data_for_saving`
            - Where the transformed tendermitn data is sent before saving
            - Unclear if this is needed for the `MEVInfo`
                - No modifications needed here, this just saves a deepcopy of the transformed data
    - *CosmosNodeStore*
        - Does this need to be modified? 
        - Data from `CosmosNodeTransformer` is sent here to be stored, uncertain if this is important `_sentinel_peering_info`
    - **Alerts**
        - Requires a change to the **AlertsConfig**
            - Must define a new **Cosmos Node Alterter**
        - Need to define an alert type for `IsPeeringWithSentinel`
        - **Alerter**
            - Receives data from the `RabbitMQ` Message Queue
                - Determines if it is configuration data or Monitoring Data
            - Passes tendermint data to be processed at `_process_tendermint_rpc_result`
                - Iterate through returned data and process the transformed data
        - `_process_tendermint_rpc_result`
            - Processes `error` conditions raised from data retrieved from `/status` endpoint
            - Use `classify_solvable_conditional_alert_no_repetition`
                - takes `node` / `validator` id, name of `metric`
                - Alert constructor if condition is true
                - Conditional function to determine if true_alert should be raised + args
                - Args for true_alert constructor
                - data_for_alerting
                - alert_solved constructor + args
    - What is the `CosmosNodeAlertConfigFactory`
        - Config is sent over wire to alerter (where is the config that is sent over wire defined?)
- **Plan Of Attack**
    - Structure similarly to how `Node / ValidatorIsSyncing`
        - i.e - `Node / Validator IsPeeredWithSentinel`
    - What needs to be modified
        - `CosmosNodeMonitor`
        - `CosmosNode` (monitorables)
        - `CosmosNodeTransformer`
        - `CosmosNodeDataStore` (both redis / mongoDB)
        - `CosmosNodeAlerter`
            - `CosmosNodeAlertConfigFactory` / `CosmosNodeAlertConfig`
    - **Actionables**
        - Define new alerts / alerts configs for alerts
            - Define Alert in Config
                - `CosmosNodeAlertConfig`
                    - Add `node_is_peered_with_sentinel` and `validator_is_peered_with_sentinel` (how to differentiate between a node / validator.. config?)? 
                - `CosmosNodeAlertConfigFactory`
                    - Update `CosmosNodeAlertConfig` in `add_new_config`
            - Define new alert type (code, constructor, etc.)
                - Add to metrics group
                - Define constructor
                - Add to `CosmosNodeAlertingFactory` (this is where the alert is actually tracked)
        - Define process of retrieving data from sentinel (`CosmosNode`(monitorables), `CosmosNodeMonitor`)
            - `CosmosNodeMonitor`
            - `_get_tendermint_rpc_data` - Determine how to retrieve the data from the `/status` endpoint, 
                - Should this be conditional on a `node_config` field? Determine if it is a `mev-tendermint` node this way?
                    - This check would probs belong in the `Alerter` then
            - `_process_retrieved_tendermint_rpc_data`
                - Define process of getting data from monitor and aggregating for sending to the `DataStore` and the `Alerter`
        - Define process of transforming the `/status` data and sending to the `DataStore` and the `Alerter`
            - `CosmosNodeDataTransformer`
            - Handle logic in `_transform_tendermint_data`
            - Handle logic in `_transform_data_for_alerting`
            - Handle updates to state in `_update_tendermint_state`
                - This is where the definitions in the `CosmosNode` (monitorables) comes into play
        - Handle receiving data on `CosmosNodeDataStore` (Ignore data store for now this is not necessary)
            - `_process_mongo_tendermint_rpc_result_store`
            - `_process_redis_tendermint_rpc_result_store`
        - Handle processing of alert at the `Alerter`
            - Check if the node is `validator` or not
                - Should the check for `is_mev_tendermint` node be in the alerter?
### Peering Investigation
- Add logging for when `01Node` disconnects from the sentinel
    - Whenever we receive a ping from `01Node` add a log that we have received the ping and the timesteamp
    - Whenever we send a pong back to `01Node` add a log that we have sent the pong back to `01Node`
## Fri. Jan. 13
- Finish working on `Panic` PR
    - Figure out flaky test?
- One of the equality constraints isn't being solved?
    - `_node(_validator)_is_peered_with_sentinel` exists in config
    - Specify default argument, but the argument is not being passed into config?
        - Keywords are specified correctly
- Test alerter config? 
- What to do about `node_config.is_mev_tendermint_node` field?
    - pass through meta-data?
        - This is the field that is added to the tendermint data json after being processed
    - Where will the conditional check be?
## Debugging
- What to do about `Config` objects
    - Alerts config, the severity metric `is_node_peered_with_sentinel`?
        - Can possibly make this optional? No either way, has to be included, and it can be enabled / disabled via the UI
## Polygon Architecture Notes
### Polygon Layers
- **Ethereum Layer** - Set of contracts on mainnet
- **Heimdall Layer**
    - Monitor staking contracts on ethereum, commit polygon network checkpoints to eth mainnet. Based on tendermint
- **Bor**
    - Block producing bor nodes, shuffled by Heimdall nodes
## Staking and Plasma Contracts
- Staking contracts enable users to stake `Matic` and become a validator of polygon txs
## Heimdall
- Aggregates blocks produced by `Bor`, creates merkle-root hash of all blocks produced, publishes root hash of intermediary blocks to mainnet
    - I assume publishing of root-hash solves the data-availability problem? Where are the intermediary txs / merkle tree stored (need aunts / uncle nodes to form proof)?
    - State of chain is immutable at checkpoints (possible fork of state between check-points?)
- Periodically shuffles block-producers for `bor` consensus layer.
## Architecture
- Each node is architected with 2 layers, `bor` + `heimdall`
- Sprint = 64 blocks
- Span = 100 sprints
- **Delineation**
    - **Heimdall**
        - Proof-of-stake validation
        - Handles validator set updates / management (interacts with contracts on EVM) 
        - Checkpointing of blocks
    - **Bor**
        - VM
        - Proposer / producer set selection
- Every sprint has a new proposer
    - Selection of proposer per sprint is determined by tendermint consensus
    - Validator set to use between sprints is given at each span from Heimdall
- System call interface (between Heimdall <> Bor)
    - System call interface is as follows, implemented via privileged contract-calls
    - `proposeState`
        - propose `stateID` if not already proposed
    - `commitState`
        - Notify `StateReceiver` contract of current `stateID`
        - remove the current `proposedState`
            - I assume this signifies a commit of the current pending state between span?
    - `proposeSpan`
        - Update proposal for `span`
    - `proposeCommit`
        - Update span / time_period
        - Update validators / producers for `sprint`
- More on system-call
    - Only accessible to `system-address`
    - Manipulates contract state outside of a regular EVM tx
- **Heimdall**
    - `Begin` \ `EndBlock` of `Heimdall` processes updates to validator set and relays to `peppermint`
    - **PepperMint**
        - Modified tendermint with `secp256k1` signin
- **Bor Consensus**
    - Proposers are selected from `producers` sent by bor at each sprint
        - Proposer selection for each block in a sprint (all blocks in sprint have same proposer) is determined by tendermint proposer selection with voting weights / set from `Heimdall`
        - `Bor` also selects back-up proposers
    - Each producer in the sprint has a defined priority, any of them may sign and broadcast headers, but their signature is weighted by their priority
        - i.e backup proposers can sign and broadcast blocks whenever
        - Blocks within sprint are delayed by a designated `Period`
        - Does this mean that potentially anyone can sign / broadcast block within sprint?
            - Forks are possible, but resolved by `difficulty` assignment
    -
## Tests
### Monitor
- If the node is a `mev_tendermint_node` 
    - Check that the `is_peered_with_sentinel` field is set correctly
- If the node is not a `mev_tendermint` node
    - Check that the field is not set
- **Checking Diff**
    - New monitorable for `is_peered_with_sentinel` added
### Transformer
### Alerter
## Tue. Jan. 17
- Write tests for `data_transformer`
- Write tests for `alerter`
- Consider refactoring test cases for `monitor`
- Set up monitoring on a local validator running mev-tendermint, 
## Data Transformer
- On each message from message queue
    - Process and validate the sent data (as json), receive node_id, and node_parent_id
    - **Question**
        - Should `Redis` be used to load state of the node's peering status with the sentinel?
            - Currently this doesn't matter as any-time the node is not peered, the alert is raised. I.e if the node goes down, and comes back up, the previous state is irrelevant for the current alerting status
            - Alternatively - Could set a threshould of ~10 seconds that the node is able to be not peered with sentinel?
                - In this case, we have to load state from `redis`
        - Think about edge-cases where not saving data about node status may be harmful?
            - What if the node transitions from being a `mev-tendermint` node to not being one
## Test Cases For Transformer!!
1. If the node is not a `mev-tendermint` node, `is_peered_with_sentinel` should not be set in the returned response for process tendermint rpc data for alerting
    - `test_process_transformed_data_for_alerting_returns_expected_data` - Can modify or make test similar to this one
        - Add new `transformed_data` format, copy all results, and add new field
        - Add new processed data result
2. Only should be getting `is_peered_with_sentinel` if the node is a `mev-tendermint-node`
    - This is covered in above test?
- Functions to consider `process_transformed_tendermint_rpc_data_for_alerting`, 
    - What does adding this test-case account for?
        - Case when `is_peered_with_sentinel` exists
3. Consider test of updating state, test that the expected monitorable is set?
    - `test_update_state_updates_state_correctly_if_result`
        - Update the expected state to have `is_peered_with_sentinel` set to true
    - Pass expected transformed data `mev` and check that the values are set correctly
4. Testing parsing of data?
    - Add a test with raw data `is_peered_with_sentinel`
    - `test_process_raw_data_updates_state_if_no_processing_errors`
        - Add a new `raw_data` format with mev metrics added
## Test Cases For Alerter!!
### CosmosNode Alerting Factory Tests
- These should pass automatically?
- **Bug**
    - `PeeredWithSentinel` - Should not be a `ClassifySolvableAlertCondition
    - This actually may be ok?
        - `CosmosNodeAlertingFactory` is instantiated each time a tendermint-rpc metric is processed by the alerter
            - This means that alerting factory is refreshed on each `consume` of tendermint-rpc data
    - When `is_peered_with_sentinel` is disabled, no alerts
        - `test_process_tendermint_rpc_result_does_not_classify_if_metrics_disable`
    - Test that alert is raised correctly in `test_process_tendermint_rpc_result_classifies_correctly_if_data_valid`
### Cosmos Node Alerter tests
 - Test that when given correct `tendermint_rpc_data` alert is fired
## Look into run_alerter.py
- How is the config set? How to change config before running test on validator?
- `queue_data_selector_helper.py`
    - `_add_nodes` - Could this be how the node config is instantiated?
    - Store and retrieve configs from `mongoDB`
        - Stored according to a `NodeSubModel` Data model
    - `get_all_configs_available`
        - Given a `MongoAPI` query for all config objects from the DB
            - Determine validity of all chain / node configs + channels in DB
        - Instantiates config objects as necessary, returns an array of all the config objects + their routing keys (these should not be changed)
    - Data from `get_all_configs_available` is routed via `RabbitMQ` to the respective services
- What about for adding to alerts config?
    - `SeverityAlertSubConfig`?
        - Each alert input as an individual entry here?
- Removing `is_mev_tendermint_node` from config?
    - **Pro**
        - Don't have to mess with UI
        - 
### What code to go back through and clean up b4 PR
- Go back through and clean up monitor tests
- Attempt to follow similar path as in `data_transformer` tests
    - Find tests that need to be modified (what is the desired functionality to test
        - Test that `_get_tendermint_rpc_data` retrieves the expected data in the correct cases
            - Only set `is_peered_with_sentinel` if it exists
                - i.e If the `mev-info` field of `/status` response exists
        - Test `_get_tendermint_rpc_data` gets the correct data
            - Returns `is_peered_with_sentinel` if it is present in the response
        - Test that `is_mev_tendermint` field of `meta-data` response is set correctly
            - I.e only if `is_peered_with_sentinel` is returned in the `_get_tendermint_rpc_data` response
        - Check that all of this comes together in `_monitor`
## Secure Txs in DB
### Schema
```
CREATE TABLE public.secure_txs (
    sender TEXT NOT NULL,
    height INT NOT NULL DEFAULT -1,
    tx_hash TEXT NOT NULL,
    submitted_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    committed_timestamp TIMESTAMP,
    code INT NOT NULL DEFAULT -1,
    failed_delivery BOOLEAN NOT NULL DEFAULT FALSE
    PRIMARY KEY (tx_hash)
);
```
- What do we get from this?
    - Can query txs by sender_address, height, timestamp
    - Can query all txs that didn't end up on chain
    - Can query all txs that ended on chain but failed
    - Can query all txs that ended on chain successfully
    - Can corroborate time from submitted to time committed on chain
- What else could we possibly want?
    - Front-end graphing
        - Graph volume of secure txs over time / height
    - User analytics
        - Associate each tx with a user, valuable
        - Search for a specific user's tx
    - Performance
        - Question - What about txs that we send, but aren't received by proposers? These will just be logged as if they were never sent, is this desired behavior?
            - What do we do about bundles? 
                - Any bundles added to `winning_bundles` will be added to `WBQ`, and are expected to end on chain
                    - two outcomes
                        1. Added to `WinningBundleQueue`    
                            - Sent to validator, expected to end up on chain. Final succcess of bundle is determined from `validator-registration` chain query
                                - In this case, we know that we sent the bundle to the validator, if any of the txs don't end up on chain, we know that the proposer did not receive the bundle, etc.
                        2. Not added to `WinningBundleQueue`
                            - Bundle hash will be logged in `losing_bundles`, not sent to validator / not expected to end up on chain
                - SecureTxs
                    - Two outcomes
                        1. Tx is never sent to a validator
                            - Code will be `-1`
                        2. Tx is sent to a validator, but a validator does not include in block
                            - We have no way of tracking this, the tx remains in the DB until it is committed again
                                - Perhaps never, in which case, we get `-1` as the code still
                        3. Tx is sent to a validator, reaped, and ends up on chain
                            - The code will be >= 0 in this case, this is expected, we can determine outcomes based on the code for the tx
        - We have the time taken between the secTx being submitted, and it ending up on chain
            (answer) - This is a separate concern / issue, and should be treated as such
                - **Possible solution** - for each tx, log the `ResponseDeliverTxs` in failingBundles? 
                    - If the `ResponseDeliverTx.Code` is `-1` we know the tx did not end up on chain, failure in gossip / reap logic
                    - Otherwise, one of the txs in the bundle failed, and we can determine specifically what the failure resulted from / consult chain for more detail
        - With current schema is there a better way?
            - Add second table `failed_secure_tx`, 
                - Add a field to the `secure_tx` `failed_delivery`, only set to true if bundle has been delivered more than once
                    - Also can add a slice of cons_addresses of proposers delivered to (any more proposers delivered to than one, and we know its a failure)
- Possible case
    - Receive proposal
        - Next validator to propose is a skip val --> start simulation
    - Simulation started
        - Simulate and select bundle
    - New proposal is received, next proposer is skip, winning_bundles hasn't been reset,
        - All bundles in `ppbq` fail, `wbq` isn't updated, 
    - FireSentinel, `wbq` is added to mempool, although the winning bundle would fail on chain
- Solution
    - We should purge `winningBundleQueue` whenever we receive a new proposal
## Failure Introspection
- **Purpose** - For `bundles` and `secure txs` we need to know and classify all possible failures that can happen after the sentinel has fired.
    - Knowing the above, we can intelligently collect data to diagnose when these failures happen.
### Bundles
- Bundle exists in `winningBundles` and has been sent to a proposer, but was not included in block. There are two cases to consider
    - The validator did not receive the bundle
        - This is an error in networking
            - The peer may have been un-responsive at the time that the bundle was sent? Etc.
                - We can monitor the sentinel's connection status to all peers granularly
    - The validator did receive the bundle
        - This is an error in `mev-tendermint`'s reap-logic (if this were to happen)
            - We have no way of monitoring what is happening on the `mev-tendermint` node, without adding new metrics and asking that all validators expose them
- Bundle exists in `winningBundles`, has been sent to a proposer, and has failed on chain
    - This indicates an error in sentinel simulation
- Currently, both of the above issues are grouped into a single table, `failing_bundles`. For entries in `failing_bundles` there is no non-trivial way (without a chain-query) to determine which of the above error buckets caused the bundle to be added to `failing_bundles` 
    - We also only check to see if the `paymentTx` ended up on chain, so we actually have no way of recording the second error bucket
### Secure Txs
- SecureTx has been sent to a proposer, and has not ended up in the block
    - This is due to the same reasons as for a `bundle`
        - Error in networking
        - Error in reap-logic
- SecureTx has been sent to a proposer, has ended up in a block, but has failed.
    - Currently we do not simulate `secure_txs` but in the future we will, and this indicates a failure in simulation
- We now have the ability to distinguish both of the above errors from each other in the `secure_txs` table
    - We have `deliver_tx_code` field, this enables us to determine if the tx failed in `DeliverTx`
    - We have `proposers_delivered_to`, this enables us to determine which proposers have received the `secure_tx`. If more than one proposer is present here we know that each send (except for the send to the last validator) failed for the first reason
### Notes
- We may need more detail regarding failures of the first kind (proposer did not receive bundles / secTxs after the sentinel has sent them).
    - We cannot monitor what is happening on the `mev-tendermint` nodes
    - We can monitor the state of the peers each `proposer` is associated with, this is logged in the `connections` table, however, there is currently no way of correlating `winning_bundles` / `secure_txs` with the `connections` table
- We need to account for all txs in a bundle / their `DeliverTx` response codes when adding `bundle` entries into the `failing_bundles` table

- **Implementation**
- **Solution 1**
    1. On ingress add `secure tx` to the DB
        - Sets the sender
        - Sets the `tx_hash`
        - Sets the `submitted_timestamp`
        - This will be done in `BroadcastSecureTx`
    2. Gather all `secureTxs` added to the `mempool` at `addWinningBundlesAndSecureTxs`
        - For each `secureTx` gathered, add the proposer to fire for to the set of proposersFiredTo in the secureTx
    3. Gather data on `Update` into the `secureTx`
- **Solution 2**
    - Change the `secureTxMap` data structure
        - Each `secureTx` now has fields needed for the `secureTx` table
            - Insertions will update these fields with the necessary data
            - Add method to mark committed
            - Add method to mark expired
            - Add method for a batch delete
    - `SecureTxStore` interface will be as follows
    ```
    type SecureTxStore interface {
        // called from the ingress thread after checkTx to add a secureTx to the set of securetxs
        AddSecureTx(tx Tx, gasWanted int64, expiryHeight int64, sender string)
        // ranges over the set of secureTxs with the predicate specified, used when adding securetxs to the mempool
        Range(rangePred func() bool)
        // Removes all securetxs with expiryHeight >= expiryHeightToPrune, all pruned txs will be logged in the database
        PruneSecureTxs(expiryHeightToPrune int64)
        // marks the given txHash as committed if it exists in the set of secureTxs
        MarkCommitted(txHash string, DeliverTxResCode int64)
    }

    type SecureTx struct {
        Tx           types.Tx
        GasWanted    int64 // amount of gas this tx states it will require
        ExpiryHeight int64 // height at which this tx should expire (no longer be broadcast)
        submitted_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
        committed_timestamp TIMESTAMP,
        deliver_tx_code INT,
        proposers_delivered_to TEXT,
        sender TEXT NOT NULL,
    }

    func (*st) AddProposerDeliveredTo(proposer string) {}
    ```
    1. On ingress, `BroadcastSecureTx` will call `AddSecureTx` on `SecureTxStore`
        - Add SecureTx
            - This will add a new `secure_tx` to the `SecureTxStore`, setting default `submit_time` sender, `gasWanted` expiryHeight, etc. .
    2. On `addSecureTxToMempool` 
        - Range with func
            - Adds a new proposer on the `SecureTx` object (this is done in a for-each)
    3. On `Update`
        - Mark Committed for all txs in the `SecureTxStore` if they already exist
    4. Solution
        - Just use a mutex to protect the objects?
            - What specifically needs to be protected here?
                - MarkCommitted?
                - PruneSecureTxs?
        - `sync.Map` and mutexes on individual 
## PR Fixes
- Any modified test cases should be reverted to original, and new test-cases should be created to specifically target the functionality to be tested
- Add a test-case for the `AlertStore` and newly defined alerts
- Modify `DataStore` as necessary
- Start fixing the test cases, separating hijacked test-cases into new ones

## Failure Introspection
- DB docs
    - Add docs for `skip txs`
- Properly updating `failing_bundles` table
    - May need a change to schema?
- What is needed from this table?
    - For any failures for the bundle, want to know the error codes for the failures?
        - Committed failures
        - Not ended up on chain failures
    - for each failure, can map deliver tx order by the order entry in the db?
    ``` 
    failed_txs    | codes
    tx1, tx2, tx3 | -1, 4, 4
    ``` 
- In the above case, `-1` indicates a bundle tx did not end up as committed
    - How 
## Logging SecureTxs in the DB
- For each tx, what needs to be logged?
    - `sender`
    - `tx_hash` 
    - `submitted_timestamp`
    - `height` (in case of non-committed txs, this will be the expiry)
- **Question**
    - What is the proper way to instantiate in `ClistMempool`?
        - Pass in `peerDB` to `ClistMempool`, `peerDB` is a dependency of the `ClistMempool`
    - Add a new getter to the `SecureTxManager`?
    - Adding metrics to the `SecureTxManager`?
            - Does this improve abstraction?
    - Have to change schema for all deployments
    - What should be recorded, proposer address or peer?
        - Only should be set on `broadcastTxRoutine` 
            - This means that whatever proposer the `secureTx` is fired to should be receiving the `secureTx`
                - Advantage of logging peers (no real advantage here)?
                    - Should make for easier queries?
                    - Data is aggregated, can be removed if we don't want? Makes schema annoying
                - Have `committed_timestamp` (this is whenever the secure tx has been added to the mempool)
                    - Possible to corroborate connections table data against the peer fire
                        - Can determine which nodes were connected to sentinel with the same `api_key` as the proposer that was fired to
        - Solution, instead of making changes in `broadcastBundleRoutine`
            - Change `FireSentinel` to only add `securetxs` to mempool if the next proposer is a skip val
## Panic PR
- Write test to determine SentinelPeeringAlert is logged in the `AlertStore`
## Updates to `failing_bundles` insertion logic
- How to go about doing this?
    - Could migrate `/sentinel` package into the `sentinel-core` directory? Make this as a single PR
    - Make changes to `Update` logic as a PR on top of this
- Will be composed of 4 PRs
    - 1 PR to migrate `/sentinel` into `/sentinel-core` in `monorepo`
        - Not necessary but a good change imo. Doing this
    - 1 PR to handle update logic in `CListMempool.Update()`
    - 1 PR to auction for changes to `failing_bundles` schema
    - 1 PR to validator-registration to remove the `failing_bundles` update logic
        - Dependency
### Failing Bundles Schema change
- Current Schema
```
	cons_address text NOT NULL,
	bundle_hash text NOT NULL,
	PRIMARY KEY (bundle_hash)
```
- Proposed changes
```
	cons_address text NOT NULL,
	bundle_hash text NOT NULL,
    failed_txs text NOT NULL, // in the case that no txs ended up on chain, all of the txs will be logged here
    failure_res_codes text NOT NULL // this will be a comma separated list of deliver_tx response code (-1 indicates tx was not in block)
	PRIMARY KEY (bundle_hash)
```
- **Questions**
    - Choose to handle this in `ClistMempool.Update()`?
        - Have data from WinningBundle Queue / Block / ABCI Responses
            - Map tx-hash to deliver-tx response from block in `CListMempool.Update()`
            - Pass this along with copy of WinningBundleQueue to failure-examination thread
                - Call this fn `examine-failures`
                - Method with `CListMempool` as receiver
            - Iterate through bundle, index into data, and determine for each bundle if any txs failed (not included on chain), 
        - Handle update in separate thread from `Update()` to prevent un-necessary latency in consensus
    - Handle this in `ValidatorRegistration` service?
        - Have data from winning_bundles
        - Doing it here will def reduce implementation complexity
            - Is it registration-service's job to be doing this?
                - Definitely not, profit updating and logging of failed bundles is def not smth that falls upon registration service
- **Analysis**
    - What does this updating achieve?
        - From now on, any time a tx from winning bundles is not included in a block, or ends up invalid on chain it is logged (perhaps should add a new metric)?
            - We can alert on this data
            - We can better introspect failures of this nature (either in simulation or in gossip)
    - What are consequences here?
        - Possibly additional complexity in `CListMempool()`?
            - Better abstraction outside of the `CListMempool()`?
                - Is that necessary for this PR ?
    - What is the purpose of this PR?
        - Fix error handling logic (consequences of abstraction can be addressed later)
- **Plan**
    1. Make PR to move `/sentinel` into `/sentinel-core`
        - One directory temporarily (payments stuff has already been moved into `sentinel-core`) this is the MVP for PR
            1. `/db` (done) + tested
    2. Make changes to `sentinel-monorepo` `CListMempool` Update logic to handle above cases
        - Make schema changes to `failing_bundles`
        - These changes can be tested in isolation, so its cool
    3. Make changes to `validator-registration`
- **Question**
    - What updates happen when the proposer is not a skip-val?

### Failure Introspection
- DB docs
    - Add docs for `skip txs`
- Properly updating `failing_bundles` table
    - May need a change to schema?
- What is needed from this table?
    - For any failures for the bundle, want to know the error codes for the failures?
        - Committed failures
        - Not ended up on chain failures
    - for each failure, can map deliver tx order by the order entry in the db?
    ``` 
    failed_txs    | codes
    tx1, tx2, tx3 | -1, 4, 4
    ``` 
- In the above case, `-1` indicates a bundle tx did not end up as committed
    - How
- Updates to `winning_bundles`  + `failing_bundles` happens atomically
    - I.e create a tx, and aggregate queries into a batch, and execute atomically?
- Handle updates in `updateIngressedBundlesInDB`
## PR Changes
- `targetValidator` set in `simulateProposalThenBundles` not necessary to set in `FireSentinel`
    - What is purpose of `heightForProposalSentinelLastFiredFor`?
        - Only updated in `FireSentinel` set to `HeightToFireNext`
            - Either equal to latest proposal received, or 1 greater
                - Only greater than heightProposalLastSeen after `FireSentinel` and before proposal has been received
                - Any bundles ingressed after `finalizeCommit` 
- move `TxKey` defn into a utils pacakge?
## Addressing PR Review panic
- Explicitly defined booleans must be converted to instance variables on the test-cases modified
    - Specifically: `alerter/test/alerter/alerters/node/test_cosmos.py`
- Any test-cases that have been altered should be reverted, and a new test-case should be added with desired functionality
- Modify `AlertStore` + `CosmosNodeStore`
### Tests to review
- `/alerter/test/alerter/alerters/node/test_cosmos.py`
- `/alerter/test/alerter/factory/test_cosmos_node_alerting_factory.py`
- `/alerter/test/alerter/managers/test_cosmos.py`
- 
## Builder module thoughts
- **Partial-Block Building** - Leaves out `prefix` / `suffix` of block for protocol relevant txs and mempool txs respectively
- **Accountability of Builders** - Builders sign portion of block they publish, leaves them available to be punished
    - Proposer doesn't include txs that were included in auction -> they will be slashed
- **TLDR**
    -
## Grouping Bundle Tables by time when data will be updated?
- Using bundle_hash as a foreign key between bundles table and other data
## Data Model could be too coupled?
 - Add more tables?
    - Auction_data (height, proposer, timestamp, was_skip_val)
    - Secure_txs (secure_tx_id) (create identifier and use identifier as bundle_hash in determination)
    - txs store all txs
    - bundles
    - Fire_data (height, hash)
- What is the advantage to this vs. having a larger amt. of data spread between multiple tables?
# Database Stuff
- How to handle firing data?
    - How do we know that a secure_tx was fired more than once?
- Can map height -> secure_tx_id?
    - What is the purpose of this? We want to know what secure_txs were fired when?
- Should we assume that any winning bundle is automatically sent to proposer?
    - This is a valid assumption
- How to deal with failures of secure_txs?
    - I.e a secure-tx fails on chain?
        - In this case, the failure is recorded, the secure tx is purged
    - What if the secure_tx is a repeated tx?
        - What happens in this case? Not really relevant, we can just remove these on ingress / in consumption
- What about failures where the secure_tx is sent more than once?
    - In this case we can have a send_count field of the secure_tx?
        - Do we want to know what heights the secure_tx was sent, but not received?
- If we want to know heights, we should create a many-to-many mapping
## GENERAL PRACTICES
- **TERMS**
    - **Entity**
        - An entity will always be represented as a table
        - Each row in a table that is an entity stores only data that is relevant to the unique instance of the entity the row describes
            - Data within a row should not be duplicated among multiple entities
        - Rows in an entity-table correspond to instances of the entity, these tables are indexed by a unique identifier of the entity
            - This identifier is the primary key for the table
    - **Relation**
        - Relations relate two entity tables by enabling a join between these tables.
        - **Mapping (table between foreign keys)**
            - In this case a table exists, where each column is a foreign-key from an entity table
                - An example is bundle_txs (bundle_hash <-> tx_hash)
        - **Referential idx (foreign key)** 
            - In this case, entity table A and entity table B are related via embedding the primary-key of A (resp. B) as a foreign key in B (resp. A).
            - An example being, secure_txs.tx_hash -> txs, similarly bundle_txs.tx_hash -> txs
## What tables should exist?
- `bundles`
    - Entity storing data specific to an individual bundle
    - Foreign key height to `auction_data`
- `auction_data`
    - Entity storing auction data, uniquely indexed by height
- `txs`
    - Entity storing tx-data, uniquely indexed by tx_hash
        - txs from failing_bundles have a NULL deliver_tx_response
- `bundle_txs`
    - Mapping relation between bundles and txs
        - txs is a foreign_key that references the txs table
            - Txs should not appear in bundle_txs when they don't exist in txs
        - bundle_hash is a foreign key referencing bundles
- `secure_txs`
    - Entity storing data pertaining to a particular secure_tx 
        - Has foreign_key -> txs, where tx_hash is a foreign key to txs
        - Foreign key to `auction_data`
- `secure_tx_transmissions`
    - Many-to-many mapping, between `secure_tx_id` <> `auction_data`
    - This is relevant for failure introspection of `secure_txs`
- `validators`
    - This table will store entities representing data for a validator (configurations, oper_address, cons_address, api_key, etc.)
    - It will have the `api_key` as the primary key, in theory, the cons_address may also be used as a unique identifier for the validators
    - It will use the `cons_address` as an index
    - All of the data stored for each entity will be populated on validator sign-up, and modified later on requests from the validator
- `nodes`
    - This table will be representing the node entity
    - It will reference the validators table via the `api_key` foreign_key
    - It will use the `node_id` as the primary key of the table
- `sessions`
    - This table will represent the `session` entity 
    - It will use the `session_key` as a primary key
    - It will reference the validators table via the `oper_address` foreign key
- `connections`
    - This table will represent a connection entity
    - It will reference the nodes table via the `node_id` foreign-key
    - We will have an index on the node_id for searching via equality relation (i.e `SELECT ... FROM connections WHERE ... = node_id`)
### How I see these tables being used in practice
- Upon receiving / simulation a proposal (at this point we know who the proposer is)
    - We update the auction_data table 
        - The commit_timestamp will be null
- bundles + secure_txs + txs + committed_timestamp are populated on `CListMempool.Update()`
    - I assume this data will be aggregated in the sentinel and propagated to the data-layer service
- We can determine a bundle is not a winning bundle if at least one of its txs has a NULL deliver_tx_response code
    - At least one of the tx_hashes in the bundle will be unique to the bundle (it's sender will be different)
- In determination of validator_profits, we can iterate through the txs table, choose successful txs, and search for skip_payout messages
    - We can map these to heights via the height
- **We can create views that track data aggregated from these tables such as**
    - failing / losing bundles
    - secure_txs that have been fired more than once
### Schemas
``` sql
CREATE TABLE public.auction_data (
    height INT NOT NULL,
    proposer TEXT NOT NULL, -- all auction_data referecnes valid auctions (proposer is a skip validator)
    auction_timestamp TIMESTAMP NOT NULL,
    commit_timestamp TIMESTAMP,
    validator_profit NUMERIC(20), -- data pertaining to profit calculations
    network_profit NUMERIC(20)
    PRIMARY KEY (height)
    FOREIGN KEY (proposer) REFERENCES (validators)
)

CREATE TABLE public.bundles (
    bundle_hash TEXT NOT NULL,
    submitter TEXT NOT NULL,
    payment NUMERIC(20) NOT NULL,
    desired_height INT NOT NULL,
    PRIMARY KEY (bundle_hash)
    FOREIGN KEY (height) REFERENCES (auction_data)
);

CREATE TABLE public.secure_txs (
    secure_tx_id TEXT NOT NULL, -- unique hash of sender || submission_timestamp || tx_hash
    submitter TEST NOT NULL,
    submission_timestamp TIMESTAMP DEFAULT NOW(),
    tx_hash TEXT NOT NULL,
    removal_height INT NOT NULL,
    FOREIGN KEY (tx_hash) REFERENCES (txs)
    FOREIGN KEY (height) REFERENCES (auction_data)
    PRIMARY KEY (secure_tx_id)
)

CREATE TABLE public.txs (
    tx_hash TEXT NOT NULL,
    deliver_tx_response INT, -- val < 0 => not present in block, > 0 => deliver_tx failure, 0 => success, NULL => tx of losing_bundle
    committed_height INT NOT NULL,
    PRIMARY KEY (tx_hash)
    FOREIGN KEY (committed_height) REFERENCES (auction_data.height)
)

CREATE TABLE public.bundle_txs (
    tx_hash TEXT NOT NULL, 
    bundle_hash TEXT NOT NULL,
    INDEX ON (bundle_hash)
    FOREIGN KEY (bundle_hash) REFERENCES (bundles)
    FOREIGN KEY (tx_hash) REFERENCES (txs)
)

CREATE TABLE public.secure_tx_transmissions (
    secure_tx_id TEXT NOT NULL,
    height_transmitted INT NOT NULL
    FOREIGN KEY (secure_tx_tx) REFERENCES (secure_txs)
    FOREIGN KEY (height_transmitted) REFERENCES (auction_data)
)

CREATE TABLE public.validators (
    cons_address text NOT NULL,
    oper_address text NOT NULL,
    moniker text,
    network_coverage float(53),
    registration_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
    api_key TEXT NOT NULL,
    payment_address text NOT NULL,
    payment_percentage int NOT NULL,
    front_running_protection boolean DEFAULT TRUE,
    last_update_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
    PRIMARY KEY (api_key)
)

CREATE TABLE public.nodes (
    node_id text NOT NULL,
    api_key text NOT NULL,
    version text,
    registration_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
    PRIMARY KEY (node_id)
    FOREIGN KEY (api_key) REFERENCES validators
)

CREATE TABLE public.sessions (
    session_key TEXT NOT NULL,
    oper_address TEXT NOT NULL,
    timeout TIMESTAMP NOT NULL,
    signer TEXT NOT NULL
    PRIMARY KEY (session_key) 
    FOREIGN KEY (oper_address) REFERENCES (validators)
)

CREATE TYPE status AS ENUM ('connected', 'disconnected')

CREATE TABLE public.connections (
    node_id TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    status status NOT NULL,
    FOREIGN KEY (node_id) REFERENCES (nodes)
    INDEX ... using hash (node_id)
)
```
# Data Layer (service will be called (data-tsar))
- What is the purpose of this service?  
    - Hide all interactions with DB behind a shared service
    - Orchestrate all writes to the DB in a single place
- What are the obstacles?
    - Communication between services that need access to DB and the DB service
        - Is there any ordering between writes that must happen? How to ensure that a request that comes in before another one is executed before?
            - Validator regisers their node -> Validator is up to propose, and queries the DB to determine whether the validator is indeed a proposer?
                - Implement some kind of write through cache in services, as well as a timestamped ordering between them?
    - Consistency between services?
        - How do we guarantee that order of reads / writes is maintained for each service?
            - Can attach sequence numbers to each service that interacts with the data-layer?
        - How do we guarantee that order of reads / writes is guaranteed between services?
            - i.e val-reg writes, and sentinel reads?
        - How do guarantee atomicity between services
            - Validator initialization?
    - How is the API consumed between services?
        - GRPC, the API is not public, should be fast, and the query language should be versioned / ingestable by other services (i.e through a protobuf data-type that is exported from the data-layer package)
## Alternative
- Writing package for queries that is exported to sentinel / validator-registration?
    - Does there even need to be a standalone service for this?
        - Could we just write a standard client / expected return types for the queries?
            - All the sequel is then abstracted from the services, and they just have to import the library and make use of it?
    - Break `AddMEVCommitData` into multiple APIs
      - `RegisterBundles`
      - Either takes `Winning + Failing` or `Losing`
        - Split into two APIs
## Pros / Cons
 - Less service maintenance
    - Don't have to worry abt creating / monitoring a whole new service
 - Fewer un-reliables?
    - All of the DB interaction will then be happening in process?
        - Is this better?
 - Con: There will be multiple services all writing to a single DB?
    - Choice - Migrate to a single DB service for all chains
## DB Service
 - DB Service will be serving a grpc interface that super-sets the peersDB interface + val-reg interface
# Protobuf / GRPC Notes

- **Field Presence**
    - *no presence* - protobuf stores only field values (non-present values can be undefined) -> singular (default)
    - *explicit presence* - All fields have explicit value, and whether they are present -> optional (have to specify)
    - **Presence Disciplines** - Determine how services / data defined at the API (IDL) translate to their serialized counterpart
        - *no presence* - Relies on field value at deserialization time to determine value of field (can imply what to de-serialize given the type of the receiver)
        - *explicit presence* - Relies on explicit tracking state (relies n whatever is sent over the wire)
    
    ## Presence in tag-value stream (wire format) serialization
    
    - Serialized data takes the form of a tagged-self-delimiting set of values
        - All values returned in the stream are *present*
        - No information abt. non-present values are transmitted in serialized message
- Oneof explicitly determine that the value of the field will either be one of the values
    - Different from optional in that both values if optional can be present in payload
    - Have to keep logic forward compatible
        - All data-layers can be updated easily and frequently
        - Clients (VR + sentinel) can't be updated as frequently, must be able to understand messages as they are redefined at the data-layer service level
        - What abt. clients changing the nature of the data they need?
            - I.e we want to keep the API as extensible as possible? So that as the schema changes, the set of data sent by VR + sentinel will not have to change as schemas change
            / as we update service
    - On the wire, field numbers `= i` are used as identifiers to determine which data-types correspond to what in the serialized message
        - This means that each number defines to the parser the length (in bytes of the data-type) including null space in *explicit presence*
        - In this case, changing the data-type associated with a field-number will not be *backwards-compatible* the entire message will fail to serialize
            - Clients receiving data won't parse correctly
        - New fields always added after the largest field number
            - Removing fields corresponds to making them null in clients that haven't upgraded
    - [https://protobuf.dev/programming-guides/dos-donts/](https://protobuf.dev/programming-guides/dos-donts/)
- **Best Practices**
    - TLDR: Design APIs for extensibility
        - Clients should be able to read serialized data without updating as often as the server (*forwards compatible*)
        - Servers should be able to serialize data that can be read by all clients without having to standardize its version (*backwards compatible*)
    - Prefer composite data types to non-composite ones
        - Instead of having a `repeated int prices = 1 ;`, prefer a `repeated price prices = i ;`
            - This way the prices API can be extended as one sees fit (perhaps we need to change the price from an int to a float)
    - New fields should be added as a new field number, and old fields should be marked as deprecated
        - **NEVER REPLACE AN EXISTING FIELD** - This causes older versions to break in serialization
    - Prefer use of `optional` field rules
        - This lets clients by-pass the excluded field
## Generating code from .proto defs
- Compiler for protobuf
    - `brew install protobuf`
        - This adds `protoc` to PATH, for use in compiling `.proto` files
    - For specifying paths to imports used in protobuf definition being compiled use `-I=<relative_path_to_directory>`
    - For generating go-code: `go install google.golang.org/protobuf/cmd/protoc-gen-go@latest `
        - This adds flags to `protoc`, `--go_out`, `--go_opt`
            - Argument to `--go_out=<dir>`, `<dir>` is the directory where the generated go code will live.
            - Argument to `--go_opt=<option>=<arg>`
                - This is likely not needed
    - For generating stubs to services defined in protobuf, also need: `go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2`
        - This adds flags to `protoc`, `--go-grpc_out`, ...
    - Example: `protoc data-layer/proto/service.proto -I. --go-grpc_out=.`
    - The above command requires that the `.proto` has the `go_option = <path_to_output dir>;` specified
        - In this case, if the above command is run in the top-level directory, the generated code will be output in the directory specified in the `go_option` definition
    - TLDR:
        - If `go_option=mydir/proto`, the running the command in the parent of `mydir` will generate go code in `mydir/proto/<>.pb.go`
- Explanation of flags
    -
## Organization Of Codebase
 - Server implemenation will live in `server`
 - Queries will live in `queries`?
 - Expect creation of `views` for each query received from the val-reg server
    - Are there any queries that would be benefitted from streams? Adds un-necessary complexity to the requests, would be better off not doing this now
        - Perhaps in the future as more data is requested this would be better
- Classes involved
    - `server` - Receive / perform business logic on requests received from the client
    - `DBStatementPreparer` 
        - Prepare statements for queries, given the business logic
        - Any expected views / set-up for each DB is performed in the start-up routine
        - This is the only class that has any awareness of the schema
        - Export views to be consumed by server / connection manager in hooking up DB connections
        - Should this be the driver of the `DBConnManager` class?
        - Advantages:
            - Can handle rows from queries, b.c I imagine they will be different between versions of the DBStatementPreparer
        - If the DBStatementPreparer has no knowledge of the `pgx` package, how can the iterator functions be defined?
            - Iterator functions will be different dependent upon the `DBStatementPreparer` used    
    - `DBConnManager` 
        - Manage connections to the DBs
            - Establish connection Hook 
        - Define functions for executing queries, and performing function on rows returned
            - These will be paginated by chain-id of DB action performed
        - Handle transactions
            - Takes as arguments arrays of prepared statements from `DBStatementPreparer`
            - Takes conditions required to be met for tx to be committed?
                - This can include data returned from the stream?
        - Look more into `pgx` for documentation / best-practices
    - `Metrics`
        - `RequestsServiced`
            - labelled by chain_id
            - Incremented for each request
        - `Liveness`
            - Gauge incremented on start
            - Decremented on close
    - `Config`
        - Config object, only handled by main
        - Input into start command for the DBService
- **Questions**
    - What is the ideal separation of the `DBStatementPreparer` and the `DBConnManager`
        - Ideal outcome: `DBConnManager` - Handles all connections to the DB, this logic will not be changed across schema changes etc.
                                         - Driver will be the `DBService` obj. - maintains refs. to `DBConnManager` and `DBStatementPreparer` 
        - Ideal outcome: `DBStatementPreparer` - Handles creation of queries, this will be the only package that is exposed to the DB schema, idea is to isolate changes to here only as time progresses    
                                               - `DBService` logic + `DBConnManager` logic will not change, even as the schemas are changed etc.
    - Question: How to handle passing closures to the Query functions from `DBStatementPreparer`?
        - These should be handled by the `DBStatementPreparer`? 
            - Should these be included in the interface? Yes, should be returned by the getQueries method, (can define creation of these scan functions in helper functions that can be re-used)
    - Define scan functions and export from `DBConnManager`?
        - have the QueryFunc take an arbitrary set of interfaces
    - Instead of passing `*[]*Validator` could pass a `ValidatorQueue`?
        - Does this make more sense than current implementation? Probs, but this is a detail that can be sorted after interface defs
    - Could the passing of a `*[]` indicate a bad design pattern?
## Patterns
- Pattern for asynchronous calls to the DB
    - Have DB take stream as argument
    - Use value from stream as a parameter for the request
        - If value is not satisfied, then don't commit, if it is then commit
- Return value of commit to the caller
    - So they can handle the revert logic, in case the commit fails
- In case of val-reg <> sentinel
    - There is no need 
- Instantiating queries
    - Data from request will be passed to the `StatementPreparer`
        - Job will be do create queries given requests
- `NodesPerValidator` 
    - Returns a mapping between `cons_address` -> `nodes`
        - Perhaps change to a `ValidatorId` as the index?
## PR Feedback
 - `Data Access Object`
    - Move `StatementPreparer` into a `DAO`
 -**** `ConnManager` 
    - Move the `Execute` + `Query` + `ExecuteTransaction` methods out of the interface, and into helper methods
    - Remove `mtx`, concurrent accesses to the connManager map is fine
    - `Conn(chain_id) *pgx.Conn`  
    - `NewDBConnManager(queries []Query)`
        - Method takes list of queries / views to be initialized upon instantiation
- `DAO` for each object? `DAO` to represent all available options on the DB?
    - Could create `DAOs` for each entity in the DB?
    - Not necessary now, can just implement, and factor in future as needed.
- Solution, create several `DAOs` each serving a purpose of manipulating or interacting with a specific entity?\
## General Practice
- Clear boundaries between each object
    - Single Responsibility

- **DAO Pattern**
    - Ideally one for each entity?
        - Programatically represent an (or set of ) entit(y/ies) in the DB
## Testing
 - Test with `pgmock`
## Create Tx Batch Object
 - Group txs across different databases
 ```
type txBatch interface {
    // add a tx to the batch
    Add(conn, queryFunc)
    // send an error to the error channel
    Error(error)
    // close, wait for the txs to complete, and commit / defer all of them if necessary
    Close()
}
 ```
 - Implementation will be a timedTxBatch
    - Adds a timeout to the execution of all txs
## Context
 - `Context` - used to transfer data across API lines
 - Composed as follows
    ```
        type Context interface {
            // signify that this Context is cancelled
            Done() <-chan struct{}
            // return error that spurred cancellation
            Error() error
            // deadline after which context will be cancelled
            Deadline() time.Time
        } 
    ```
 - `context.Background` - Designated as the top-level context, all other contexts are derived from this
    - Contexts are derived from each other, forming a tree
    - Background context is never cancelled, and has no timeout
 - When a parent of a context is cancelled `<-ctx.Done()`, all of its children are also cancelled (can receive from `<-Done()`)
 - contexts passed to functions are expected to cancel running as soon as possible after a receive on the `<-ctx.Done()` channel is possible
## Questions
 - What happens when adding after an error has already occurred in the batch?
    - Maybe close logic is not actually useful? Come back to this, first test the `TxBatch` object
        - Would the class be more useful, if instead of creating queries, the user passed in a function closure?
            - Give standard constructor of txFunc, that way granular access to tx object is available
## Change the way Bundle Hash is determined
## Terra Upgrade
## Precommit Question
- For $f$ validators, where $f < N / 3$, it is possible that they have broadcasted conflicting votes to the network
    - In this case, there will be at most $ 2N / 3 + k$ votes where, $k = xf + b$, where $b < f$
    - Need to send to $2f + 1$ vals. as $1 / 3 + f$ vals?
## Error in inserting losing bundles when not skip proposer
 - Error here due to insertion when the next proposer is not a skip-validator
    - In this case the `cons_address` field of the losing bundle
## PR Comments
- `DBConnManager` hiding full features of the DB?
# Mon. Feb 13 Goals
- Before logging off
  - Finish data-layer implementation
  - Start implementing changes to val-reg + sentinel tmrw
  - Start migration of queries Wed.
  - Finish thurs.
## Data-Layer Conn Manager
- Can simply define an interface for the `pgxpool.Conn` object
  - Alternatively just implement, and use `pgxmock` when testing SentinelDAO?
  - Or define interface for connection? Have that returned by the driver
- Define `Conn` interface, with methods as follows
```
type Conn interface {
	Begin(context.Context) (pgx.Tx, error)
	Exec(context.Context, string, ...interface{}) (pgconn.CommandTag, error)
	Query(context.Context, string, ...interface{}) (pgx.Rows, error)
}
```
### Testing Conn Manager
  - Possible to test with `pgxmock`?
  - Change to use `RDSPoolConstructor` method as parameter to Constructor
  - Also have to make interface for `pool`?
## SentinelDataManager Notes
- Perhaps `Validator` object is getting too cluttered?
  - Option 1. Split into multiple objects? This makes more sense
    - 1. For essential validator id data (validators table data inserted on registration)
      - Essential validator data will be data included on registration
    - 2. For network validator data (moniker, network_coverage, etc.)
    - 3. Potentially split up API for setting validator?
- ## Missing API
  - `Update Profits`
  - `Get Connections`
- ## Queries For Bundles?
  - Query heights for profit calculations?
  - Query all winning-bundles
    - Filtered by address-submitted
    - Excluding a set of addresses
## Testing SentinelDataManager
## Metrics
	- Liveness Counter
	- Failed operations
## Modifying bldr to use data-layer
- Generate config in `network.py`
  - Start Dockerfile with reference to `config`?
  - Entrypoint command lets dockerfile act as an executable
- Generate config, and add dockerfile to docker-compose obj. in docker
## Integration with Sentinel
- Create new dbProvider interface, i.e
```
type sentinelDBProvider interface {
    tmnode.DBProvider
    func () peerdb.PeerDB
}
```
 - Making sentinel-monorepo change backward compatible (i.e agnostic to config change) 
   - If the conn string parameter is present for data-layer instantiate, otherwise ignore
## Readings
### IBC Paper
- 
### Shared Sequencer Set
### Heterogeneous Paxos
## ABCI++
## Problems for SetValidator
- Problem
  - Possibly many different reasons for which the API exists
    1. One way of thinking abt API is that it is for general configuration of a validator?
       1. Many ways / circumstances for configuring a validator?
        - When validator is updating payment percentage, address, front-running protection etc.
          - What abt. making APIs for each one?
        - Group all into a ValidatorConfig, and have API to set ValidatorConfig? Then just case on what is the value being updated
    2. Just use `SetValidator` method
       1. This object is too broad, subject to change frequently
          1. Instead break into smaller pieces (this makes the most sense)
       2. Can then j make APIs for updating specific values, i.e updating payment_address / payment_percentage, etc.
    3. Can use IsNull() in psql, and reference existing value using $@column\_name$
- Solution - Break `Validator` into multiple objects
  - ValidatorConfig
  - ValidatorProfit
  - Validator
- `GetValidators` - returns array of validatorDatas (all three above combined)
- Will introduce
  - `SetValidatorProfit`
  - `SetValidatorConfig`
  - `SetValidator` (makes more sense / encapsulates values as necessary)
- Under what circumstances will API be used
  - Updates to validator configs
    - Payment address, payment percentage, etc.
  - Updates to `monikers`

## Weak Subjectivity
- nothing at stake problem?
- **consensus** - Secure execution of a state-transition, according to a set of rules (can also be done via zk-proofs), where right to perform STs distributed among economic set
  - Must be securely decentralized
- POW - Miners choose chain which they intend to contribute to (determine next hash given ancestor)
  - Unprofitable to double-sign (contribute half-work to one fork, and other half to another)
- **Nothing at stake**
  - Voting is free in POS (resource not consumed in votes (however slashing conditions consume resource after detection?))
- Fundamentally consumption of resource (in traditional BFT resource is ownership of a PK pair) is difficult to determine in POS, since resource is on chain itself ()
  - In POS diff. entities have diff. views of val-set / weights
## Cross-chain validation
- **Model**
  - Validator set on consumer chain determined by tokens bonded by val on provider chain, misbehavior on consumer chains slashes stake on provider (eigenlayr?)
  - Long range nothing at stake attacks? How to maintain security during unbonding
    - Given light-clients require trusting period to determine val-set, how does this tie into security of CCV
- Value of interchain security
  - In the limit every (cosmos) chain uses consensus effectively as a means of attributing a decision to a set of trusted actors bonded by an economic incentive to act _correctly_
  - Sequencer is where these preferences shared between actors validating roll-ups can be disseminated 
    - Naive - Every validator can attach specific data to their blocks, vals can unpack data if they understand, and attach their own data to certificate (can even change rules for signing certificate)
- Consumer chain
  - Receives **VSC**s (validator set changes) from the provider (given through an IBC packet), gives to staking module, and adjusts stake in network accordingly
  - Given a number of violations, the consumer chain relays those proofs to the provider chain
![Alt text](Screen%20Shot%202023-03-12%20at%205.02.05%20PM.png)
- **Channel initialization** for non-existing chains (chain will be consumer from genesis block)
  1. Create Clients
     - Provider receives proposal for consumer CCV
     - Provider chain instantiates light client of consumer, validator nodes of provider create full-nodes for consumer with given genesis-state
       - `x/consumer` module InitGenesis constructs client of provider (what abt. rest of nodes on chain?)
  2. **connection handshake**
     - According to ICS 3
  3. **channel handshake**
     - According to ICS 4
     - Also instantiates transfer module for reward distribution to provider chain
# Bullshark
- Build set of causally ordered messages, then consensus proceeds on top of DAG w/ zero message over-head
  - How is building of DAG not a consensus protocol? It is atomic broadcast <-> agreement (consenus)
- asynchronous, but optimized for (common) synchronous case
- **Validity** (fairness) - Every tx delivered by an honest party is eventually delivered
  - Conflicts with Narwhals garbage collection
- Concerns
  - optimize for synchronous case
  - garbage collect old entries (remove infinite storage requirement?)
- Asynchronous worst case liveness
  - Happy path that exploits common-case synchronicity
- Built on top of narwhal (first partially synchronous model )
- Dynamic validator set? How are nodes able to move in / out if verification of each certificate requires signatures from quorum at prev. round? 
- ## Challenges
  - Narwhal - Nodes advance to next round (construct message for round $n + 1$) on receipt of $2f + 1$ certificates
    - Bull-shark this is fine for asynchronous consensus? Cannot guarantee deterministic liveness for synchronous periods?
    - In asynchronous case, leader is determined via VRF encoded in block shares (no-one knows leader before-hand), can parametrize protocol to be probablistically live (after some number of round leader block shld be received)
    - In synchronous case, leader is determined before-hand, and must be deterministically live, 
      - Attack: adversary knows leader, and advances $2f + 1$ messages before leader, so all nodes advance w/o leader block
      - Solution introduce timeout after receiving $2f + 1$ messages, i.e message is guaranteed to come in before timeout ()
  - Bullshark has two votes
    - One **steady-state** - for pre-defined leader
    - One **fallback** - For random leader (same as Tusk), if predefined leader is down or network is asynchronous
  - Bullshark rounds grouped into **waves** of 4 rounds
    - Have steady-state leader
      - Commit after 2 rounds (steady -state synchronous)
    - fallback leader
      - Commit happens after 4 blocks (asynchronous condition)
- ## Model
  - Assume processes $P = \{p_1, \cdots, p_n\}$, where $r\_bcast_k(m, r)$ denotes a reliable broadcast to all nodes, and $r\_deliver_i(m, r, k)$ denotes process $i$ delivering a message that was previously $r\_bcast_k(m, r)$
    - **agreement** - If $p_i$ outputs $r\_deliver_i(m, r, k)$, then all other processes $p_j$ output $r\_deliver_j(m, r, k)$
    - **integrity** - Honst parties deliver messages at most once
    - **validity** - All broadcasted messages are eventually delivered
  - **perfect coin** - Each node $p_i$ has a function $choose\_leader_i : \mathbb{N} \rightarrow P$
    - **agreement** - For $p_i, p_j \in P$, $choose\_leader_i(w) = choose\_leader_j(w)$
    - **termination** - If at least $f + 1$ parties call $choose\_leader_i$ it eventually succeeds
    - **unpredictability** - As long as $< f + 1$ parties call choose_leader, the return is indistinguishable from a random variable (i.e can't determine leader w $< f + 1$ parties) 
    - **fairness** - For all $p_i \in P$, $Pr[choose\_leader_i(w) = p_j] = 1/n$
- ## Problem
  - **Byzantine Atomic Broadcast** (stronger than Byzantine broadcast <-> byzantine agreement) (this is BAB <- > SMR)
    - Satisfies reliable bcast + **total order**
      - **Total Order** - If an honest party $p_i$ outputs $a\_deliver_i(m, r, p_k)$ before $a\_deliver_i(m', r', p_k')$, then all honest parties deliver the messages in that order
    - Asynchronous executions have to relax validity to be non-determinstic (live w/ some probability)
- ## DAG Construction
    - Vertices represent messages, each vertex has references to $2f + 1$ messages from prev. round
    - Each parties view of DAG changes (depending on how messages are delivered at each process via RB), however, _eventually_ (synchronously or asynchronously) all DAGs converge
    - **Vertices contain**
      - Round number
      - Signature (from sender)
      - Txs
      - $f + 1$ Weak + $2f + 1$ strong edges
        - **strong edge** - Reference to vertex from $2f + 1$ (safety)
        - **weak edge** - Reference to vertex from $< r - 1$, such that w/o edge, there is no path to vertex (total-order)
      - $|DAG_i[R]| \leq n$ - the set of vertices RB-delivered by $p_i$ for round $r$
      - $path(u, v), strong\_path(u, v) \in \{0, 1\}$ return whether there is a path between two vertices $u, v$ among all edges (resp. strong edges)
      - $fallback\_leader(r)$ returns the fall-back leader's block from the first round of the current wave
      - $steady_state_leaders(r)$ - return the first / second blocks from this wave where the first returned is the block from the first round of the wave, and the second is from the third round of the wave
    - ### algorithm
      ![Alt text](Screen%20Shot%202023-03-12%20at%207.40.23%20PM.png)
      - state
        - **round** - Round of last vertex broadcasted
        - **buffer** - Set of vertices RB-delivered but not included in a vertex
        - **wait** - Timer corresponding to whether the timeout has elapsed for this round
      - Triggers (advance rounds)
        - On vertex deliver (RB) $v$ 
            - Check $v$ is legal
              - Check source and round 
                - Source has not yet delivered vertex for round
                - Round is current round of latest delivered vertex?
              - Vertex has at least $2f + 1$ strong vertices
            - Try to add to DAG
              - If all vertices w/ strong_edges have not been delivered add to $buffer$
                - Different from Narwhal? In narwhal all delivered vertices (certificates) are added to DA, don't have to deliver earlier (doesn't have notion of delivery, up to SMR)
        - On vertex $v$ added to DAG
          - Iterate through buffer and attempt to add vertices to DAG
          - BAB-deliver $v$ ?
        - On $2f + 1$ vertex RB-delivered?
          - Advance round
        - On timeout
          -  For synchronous case?
        - On advance round
          - Broadcast vertex
          - Start new timer
    - Have to optimize for common-case conditions (have stronger condition for progress other than $2f + 1$ vertex delivers)
      - Look above for why
      - If node delivers $2f + 1$ vertices for $r > round$ node moves forward (not up-to-date node)
    - Voting
      - for wave $w$ starting at round $r$, there is a leader for $r$ and $r + 2$
        - Leader block at $r, r + 2$ are **proposals**
      - Vertices in round $r + 1, r + 3$ with strong edges to **proposals** are votes, only if vertex w/ edges to proposal is marked as a **steady-state** vote
    - Up-to-date nodes
      -  Dont advance to $r + 1$ unless
         -  The timeout for $r$ expires
         -  The node has delivered $2f + 1$ vertices, and the proposal for the current wave
    - ### Protocol
      - **Voting rules**
        - Divide $DAG_i$ into _waves_ (4 rounds) each with 2 steady-state leaders and 1 fall-back leader
          - Synchronous periods (both steady-state leaders committed)
          - Asynchronous periods - Only fall-back leader committed (commit w/ 2/3 prob) so $E(commit) = 6$
        - Does not require external view-change / view-synchronization mechanisms when switching from asynchrony to synchrony
          - round 1 + 2 ensure if leader is honest all parties start round 3 ~ the same time
            - View change not require b.c DAG ensures safety (in each view)
        - **fall-back leaders + SS leaders committed exclusively**
          - Parties assigned w/ voting type at beginning of wave (fallback or steady state)
            - $p_i$ interprets DAG / votes according to type of vertex
            - Keeps track of info in `steady_votes[w]` and `fallback_votes[w]`
              - `steady_votes` - parties that committed second steady-state leader in $w - 1$
              - `fallback_votes` - parties that committed fallback leader in $w - 1$
            - $p_i$ determines $p_j$'s vote type in wave $w$ when it delivers $p_j$'s vertex for $w$ by 
                - If vertex has causal history to guarantee commit of steady-state leader it is `steadystate_vote`
                - Otherwise fall-back
          - To commit leader in $w - 1$ based on vertex $v$ from first round of $w$
            - let $sv = v.strong\_edges$
              - If $|\{v \in sv: v.type = fallback, strong\_path(fallback\_leader(v.wave - 1), v)\}| \geq 2f + 1$, then commit the fallback leader 
              - ^^ analogous condition for second-steady-state leader in $w-1$ leads $v$ to commit a second-steady-state leader
        - **ordering DAG**
          - 
## Order-Fair Consensus
- **zero-block confirmation** - Honest txs can be securely confirmed **even before they are included in any block**
  - **transaction order-fairness** (on top of consistency, liveness)
- POW protocols
  - Can operate in environment where validator set is unknown
- **order-fairness**
  - If sufficiently many nodes receive $tx_1$ before $tx_2$, then $tx_1$ must be executed before $tx_2$
  - Extension of **single-shot agreement** to multiple rounds,
    - I.e given the order of inputs, the final output should reflect
- **receive order-fairness** - If $\gamma$ (fraction likely 2/3) nodes have received $tx_1$ before $tx_2$, $tx_1$ is sequenced before $tx_2$
  - Impossible due to Condorcet paradox, $A, B, C$, orderings $(x, y, z)_A, (z, x, y)_B, (y, z, x)_C$, notice then $x, y$, and $y, z$, but $z, x$? Ordering is not transitive
- **block order-fairness**
  - same as above, except happens before is analogous to block ordering, conflicting orders $x, z$ force $x, y, z$ to be included in the block (in no specific order)
  - Allow symmetricity in order relation
## 
## Implementing ABCI with bull-shark?
 - Look into weak-subjectivity
   - Val-set preferences
 - Potentially CCV + heterogeneous architectures reading
 - zk proofs
## Rollups
- ### Sequencer as a service
  - **saga**
    - Organize validators into sequencers, punish misbehaviour
    - Validators selected to sequence shards via an on-rollup sequencer (think of randao selection of committees)
    - Clients generate fraud proofs and post to DA
  - 
## Gasper
 - Casper FFG + LMD GHOST
    - FFG (provides finality for blocks produced)
        - Denotes certain blocks as `finalized`, agnostic to underlying consensus engine (POW, POS, etc.)
    - LMD GHOST is a fork-choice rule
      - Validators post `attestations` to blocks (denoting a vote)
 - Validators denoted by $\mathcal{V}$
   -  broadcast `blocks` between each other
   - blocks are either
    1. Genesis blocks
    2. Non-genesis, generate state-transitions on top of state at referenced parent     
   - Blocks can conflict with each other, as such, each block in the `blockchain` should have a single parent + child also in the `blockchain`
     - Accepting more than one child-per-parent enables conflicting state-transitions to be committed to state
- Let $M$ be a message and $V \in \mathcal{V}$, then if $V$ sends $M$, $M$ is sent to all validators in the network
  - What are the network assumptions? Is the message guaranteed to be received by all validators? Is there a maximum time for a validator to receive $M$?
  - Messages
    1. Block Proposal (block itself)
    2. Block attestation (vote for block)
    3. activation (adding a validator to the active set) 
    4. slashing (proving a validator in the active set did something wrong)
  - Authenticated link abstraction (messages are signed by sender)
  - Validators may or may not receive message (to _see_ or _does not see_ )
- messages are _accepted_ iff all of the dependencies of $M$ are _accepted_ as well
  - What does _accepted_ mean for a single message? A validator _sees_ the message?
  - Example dependencies? _slashing_ for $V$ depends on committed _proof_ possibly in block (proposal message?)
- **view**  - $View(V, T)$ (parametrized by time $T$), the set of all **accepted** messages a validator has seen thus far
  - $view(NW, T) \supseteq \bigcup_{v \in \mathcal{V}} view(V, T + \Delta)$ - the network view, the set of all messages that have been sent by any validator for $t \leq T$
    - In this case $\Delta$ is the maximum variation accepted by the network between validators and the real time, i.e $\Delta$ is the max time it takes for a val to receive a message after it being sent at $T$
    - Can contain messages that have yet to be accepted by any validator?
    - $\forall v \in \mathcal{V}, Block_{genesis} \in view(v, 0)$, i.e all vals have the genesis block as their view on starting consensus
      - Genesis has no deps. so automatically accepted
- For any $v \in \mathcal{V}$, $view(V)$ contains a DAG of blocks (rooted at $B_genesis$)
  - Denote the relation $B \leftarrow B'$ to denote that $B$ is a parent of $B'$, and thus $B'$ depends on $B$ (is accepted when $B$ is)
    - Blocks only have a single parent (acyclic)
  - _leaf_ block with no children
  - $chain(B, B')$ - denotes a chain of blocks, i.e a sequence $B', B_1, \cdots , B$, where $B' \leftarrow B_1$, and $B_{i} \leftarrow B_{i+1}$, etc.
     - $chain(B)$ - denotes a unique sequence per block of the $chain(B_{genesis}, B)$ (this exists for every block)
  ## Proof Of stake
  - Let $\mathcal{V} = \{V_1 \cdots V_n\}$, where $w(V_i) \in \mathbb{R}_{\leq N}$, where $N$ is the total stake
    - Define $fork : view (V_i) \rightarrow \mathcal{B}$, i,e for any view, $fork$ chooses an arbitrary leaf, and determines a chain to $B_{genesis}$
    - finality: $finality : view (V_i) \rightarrow \mathcal{2^B}$, i.e chooses a set of the blocks in $view(V)$ as canonical
        - Can assume that any $B = fork(view), B \in finality(view)$?
    - **attestations** - Votes for head of chain, embedded in parent block
      - I.e parent determines attestations for child-block?
        - At time of commit of parent, attestations for child-block exist? Don't finalize parent, until child has been seen?
        - Blocks can't be modified, but can have earlier dependency, and include more attestations for different child, thus forking chain?
    - Difference between this and tendermint is **prevote** stage?
      - Only one voting round per block in ethereum? Could this be faster than tm?
    - Define blockchain $p$- slashable if $pN$ stake can be provably slashed by a validator w/ network view
    - Ethereum, no bound on message delays 
      - Can wait arbitrarily long for messages to be received
    - Diff. to tendermint
      - Gasper is asynchronous
      - Tendermint is partially-synchronous
        - i.e assume time after which network is stable
  ## Properties
  ### Safety
   - For all $V, V' \in \mathcal{V}$, $b \in F(V), b \in F(V')$ then $b$ and $b'$ are non-conflicting
     - Conflicting blocks are blocks that bear no dependency relation
    - where $F$ is the finalization function.
    - This implies that $F(V) \subset F(NW)$, i.e a sub-chain(subset with extended parent-child relation)? Proof sketch
      - Suppose $b \in F(V)$ and $b' \in F(V')$, where there is no relation between $b, b'$, then they are conflicting, this is false. As such, for all $v, v' \in view(NW)$, $v, v'$ bear a dependency relation
  ### Liveness
  - Can the set of finalized blocks grow?
     - _plausible liveness_ - regardless of prev. events, it is possible for the chain to grow
     - _probablistic liveness_ - Regardless of prev. events it is probable for the chain to grow
  ## Time
  - Time modeled in _slots_ (12 seconds)
  - epochs - some number of slots
  - Synchrony
    - _synchronous_ - known bound on communication
    - _asynchronous_ - no bound on communication
    - _partially synchronous_ - bound on communication exists and is not known, or is known but only exists after unknown time $T$
  - **GASPER makes no synchrony assumptions in consensus**
    - Assume _partial-syncrony_ in proof of probablistic liveness,
    - (t-synchrony) - network is asynchronous until time $T$, where the communication bound is $t$
  ## Casper
   - _justification_ (prepare) + _finalization_ (commit), concepts introduced via _PBFT_
   - For block $B \in \mathcal{B}$, $height(B) := len(chain(B)) -1$
     - Define a _checkpoint_, a block $B \in \mathcal{B}$, and $height(B) := n*H$, where $H \in \mathbb{Z}$, $n$ is the checkpoint height of $B$, $H$ is a pre-determined parameter for when checkpoints are created
       - $checkpoint-height(B) = \rfloor height(B) / H \lfloor$
   - _Attestation_ - signed message containing checkpoints $A \rightarrow B$, i.e a vote to canonicalize $A$ as _finalized_
     - notice, for _attestation_ (A, B), it is the case that $checkpoint\_height(A) + 1 \leq checkpoint\_height(B)$
     - Each attestation is weighted by stake of validator
   - **notion** - Use stake of validator as opposed to individual nodes as units to prevent against sybil / DDOS attacks
   - checkpoint -> epoch, block -> slot
   - **justification + finalization**
     - Let $G = view(V)$, then there exists $F(G) \subset J(G)$, where $F(G)$ are **finalized** blocks, and **J(G)** are justified blokcs
       - The $B_{genesis}$, is both finalized and justified
       - If a check-point block $B$ is justified, and there are $> 2/3$ stake-weighted attestations for $B \rightarrow A$, and $A$ is a checkpoint-block, then $A$ is justified, and if $h(A) = h(B) + 1$, then $B$ is finalized
   - **slashing conditions**
     - No validator makes distinct attestations $\alpha_1$, $\alpha_2$, where $\alpha_1 = (s_1, t_1), \alpha_2 = (s_2, t_2)$ and $h(t_1)= h(t_2)$, vals only attest to one block per height
     - No val makes two attestations $\alpha = (s_1, t_1), \alpha_2 = (s_2, t_2)$ , where $h(s_1) < h(s_2) < h(t_1) < h(t_2)$
   - Every epoch, vals run fork-choice rule, and attest to one block
   - ### Properties
     - **Accountable Safety** - Two check-points, where neither is an ancestor of the other, cannot be finalized
       - Suppose $A, B \in F(G)$, are finalized, then $V$ has seen sufficient attestations for $A \rightarrow A'$ and $B \rightarrow B'$. Notice $h(A) \not= h(B)$, and $h
     - **plausible liveness** - It is always possible for new blocks to become finalized, provided blocks arebeing created
   - ### Justification / Finalization
     - Fork-choice rule (**LMD-GHOST**) (executed per view, according to latest message containing attestations)
     - Greedily choose path through tree w/ largest number of stake-weighted attestations
   ## Gasper
   - **epoch boundary pairs** - Ideally blocks produced per epoch (checkpoints in Casper), represent as follows $(B, j)$ ($j$ is epoch number, $B$ is block)
   - **committee** - Vals partitioned into _committees_ per epoch (composed of slots), one committe per slot (propose blocks per committee?) 
     - Single val in committee proposes block, all vals in committee attest to HEAD of chain (preferrably most recently proposed block)
   - **justification + finalization** - Finalize + justify **epoch boundary pairs**
   - ### Epoch Boundary Blocks + pairs
     - Let $B$ be a block, $chain(B)$ the unique chain to genesis, then
       -  $EBB(B, j)$, is defined as $max_{B \in chain(B)}(i \leq j, h(B) = i * C +  k), 0 \leq k < C$, i.e the latest block before a certain epoch boundary.
       -  For all $B$, $EBB(B, 0) = B_{genesis}$
       -  If $h(B) = j * C$, then $B$ is an EBB for every chain that includes it (notably $chain(B)$)
       -  Let $P = (B, j)$, then attestation epoch $aep(B) = j$, same block can serve as EBB for multiple epochs (if node was down for some amt. of time, chain forked, and earliest ancestor is several epochs ago)
     - **Remark**
       - EBB serves as a better way to formally model safety under asynchronous conditions, (algo. is only probablistically live)
    - ### Committees
      - Each epoch ($C$ slots), we divide set $|\mathcal{V}| = V$, into $C$ slots (assume $C | V$), and for each epoch $j, \rho_j: \mathcal{V} \rightarrow C$ (selects committees from val-set randomly)
        - Responsibilities of Committee $C_i$ for slot $i$
          - For epoch $j$, denote $S_0, \cdots, S_{C - 1}$ committees, 
    - ### Blocks + Attestations
      - **Committee work**
        - Proposing blocks (single val (potentially more in sharding?)) (block message)
        - All members attest to head of chain (latest block derived from GHOST) (attestation message)
          - Both of above require val to execute FCR on own view
      - **protocol**
        - Let slot $i = jC + k$, designate validator $\mathcal{V}_{\rho_j(k)} = V$ (first member of committe $S_k$), proposer
          - Let $G = view(V)$, compute $HLMD(view(V, i)) = B'$ (head of canonical chain in $G$), block proposed $B$ is
            - $slot(B) = i$
            - $P(B) = B'$ (parent of current block) block has currently been proposed from prev. slot
            - $newAttests(B)$ the set of new attestatations not included for any block in $chain(B')$
            - txs (potentially narwhal certificate?)
        - block $B$ depends on $P(B) \cup newAttests(B) \subset \mathcal{M}_{network}$ 
        - ## Mid of slot messages (gather attestations on proposal)
            - time $(i + 1/2)$ (middle of slot), all vals compute $B = HLMD(view(V, i + 1/2))$, and create an attestation $\alpha$
              - $slot(\alpha) = jC + k$
              - $block(\alpha) = B$ (same block as $P(B')$, where $B'$ was j proposed, or $B = B'$?), where $slot(block(\alpha)) \leq slot(\alpha)$ (GHOST vote) fork-choice
              - **checkpoint edge** - $LJ(\alpha) \rightarrow^{V} LE(\alpha)$, where $LJ, LE$ are EBBs (CASPER vote) for justification + finalization
        - ### Justification
          - Given $B$, define $view(B)$ as the view consisting of $B$ and its dependencies, define $ffgview(B)$ to be $view(LEBB(B))$ (view that Casper operates on) (only finalizes + justifies checkpoints)
            - $view(B)$ looks at continuous LMD view
            - ffgview(B) looks at frozen at latest checkpoint view
          - Let $B = LEBB(block(\alpha))$, where $\alpha$ is an attestation
            - $LJ$ - last _justified pair_ of $\alpha$, i.e last justified pair in $ffgview(block(\alpha)) = view(B)$
            - $LE$  - Last EBB of $\alpha$, $(B, ep(slot(\alpha)))$ (latest block (pair) attested to by $\alpha$)
          - Let $LJ, LE$ be EBB, then there is a **super-majority** link ($LJ \rightarrow^J LE$) if the stake-weighted attestations for the checkpoint edge $> 2/3$ (byzantine quorum (needed to safety arguments)) 
          - **justification** - Represented as follows $(B, j) \in J(G)$ for $G = view(V)$
            - $(B_{genesis}, 0) \in J(G)$, for all views $G$
            - if $(A, i) \in J(G), (A, i) \rightarrow^J (B, j), (B, j) \in J(G)$, for all views $G$
        - ### finalization
          - Once a view finalizes a block $B$, no view will finalize any block conflicting with $B$ (unless the block-chain is $> 1 /3$ slashable$
          - **finalization**
            - $(B_0, 0) \in F(G)$ if $B_0 = B_{genesis}$
            - $(B_0, j), (B_1, j + 1), \cdots , (B_n, j + n) \in J(G)$, and $(B_0, 0) \rightarrow^J (B_n, j+n)$ (likely $n = 1$), then $(B_0, j) \in F(G)$ 
        - ### Hybrid LMD GHOST

## Health Checking services
- 
## IBC Notes
- Provides facilities for interfacing two modules on separate consensus engines
  - Requirements
    1. Cheaply verifiable consensus logic (i.e light client implementations)
    2. finality (assurance that state will not be changed after some point)
    3. KV store functionality 
  - Relayers
    - Request tx execution on destination ledger when outgoing packet has been committed
  - Sending ledger commits to outgoing packets (seq. number etc). receiving ledger receives and verifies commitment
- ### Protocol Structure
- **Client** - Expected interface for ledgers expecting to interface with IBC
  - **validity-predicate** - Algorithm to be executed (specific to **client**) for verifying packet-commitments / assertions of finalized state
    - Verify headers from counter-party ledger (once passed validity predicate, expected to be final), verification depends on state of ledger previously considered final
  - **state** - Most recently finalized state that the client thinks is correct (finalized)
  - **lifecycle**
    - **Creation** - Specify _identifier_, client-type (determines VP), and genesis state (determined by client-type? i.e patricia tree or IAVL tree)
    - **Updating** - Receiver header, verify according to VP + stored ledger state -> if valid, update stored ledger state (signing authority (quorum to expect? etc.)
      - If the unbonding period has passed (i.e - chain no longer has any way of verifying header commitments from counter-party), the light-client is frozen, and in-transit messages are no longer able to be sent / received (unless social intervention takes place)
- **Connections**
  - Encapsulates two **stateful** connection-ends (ledger1 / ledger2), each CE associated w/ light-client of counter-party
    - Verifies that packets have been committed / state-transitions executed (escrowing tokens etc.) (exactly once by sender) and in order of _delivery_ (by receiver)
    - **conection** + **client** define **authorization component of IBC
    - **ordering** ? -> Channels
  - **Data-structures**
 ```
    enum ConnectionState {
        INIT,
        TRYOPEN,
        OPEN,
    }
    interface ConnectionEnd {
        state: ConnectionState
        counterpartyConnectionIdentifier: Identifier
        counterpartyPrefix: CommitmentPrefix
        clientIdentifier: Identifier
        counterpartyClientIdentifier: Identifier
        version: string
    }
 ``` 
- Tracker by ledger1 (state is regarding ledger2?)
  - ConnectionState -> state that connection is in (may be in hand-shake)
  - counterPartyConnectionIdentifier -> key that counterparty stores other connectionEnd under
  - counterPartyPrefix -> prefix that counterparty uses for state-verification on this ledger?
    - What does this mean? What subset of state this connection corresponds to?
  - clientIdentifier -> identifier of client on this ledger (will be client-type asociated with destination ledger)
  - counterPartyClientIdentifier -> opposite of above (what does counterparty think of what client I am running for it)
- **HandShake**
  - Used for establishing connection between two ledgers (notice, the clients of either chain must be established)
    - Establishes identifiers of either ledger, 
  - **parts**
    - **ConnOpenInit** - Executed on ledger A, establishes
      - Connection identifiers on either chain i.e connection_i on A, connection_j on B
      - References identifiers of light clients on either chain (clients must be correct, i.e tendermint-chains require clients identified be tendermint light-clients of counter-party)
      - ledger A stores a connection-end in `TRYOPEN` 
    - **ConnOpenTry** - Executed on ledger B, acknowledges connection initialization on A
      - Verifies that client-identifiers are correct, and that ledger A's light-client has a sufficiently accurate consensusState for ledger B
      - Checks that version is compatible
      - Checks that ConnectionEnd with corresponding parameters has been committed
      - B stores ConnectionEnd w/ parameters in state, with connectionState: TRYOPEN
    - **ConnOpenAck** - Executed on ledger A
      - Relays key associated with ConnectionEnd on B, uses prefix to verify proofs that B stored ConnectionEnd, and verifies proof that light-client on B for A is sufficiently up to date
      - A updates connectionSTate to OPEN
    - **ConnOpenConfirm** 
      - Executed on ledger B
      - Checks that ledger A has stored its connection as OPEN
- ## Channel
  - Provides message delivery semantics to IBC protocol
    - Ordering
    - Exactly once delivery
    - Module permissioning
  - Ensures that packets executed only once, and delivered in order of execution on sending / receiving ledger ledger, and to channel corresponding to owner of message
    - I.e a packet-receipt can't be delivered, until the ack of the packet that spawned that one ... 
  - Each channel is associated with a single connection
    - Multiple channels using single connection share the over-head of consensus verification (i.e only one light-client has to be updated)
  - ## Definitions
    - ChannelEnd
    ```
    ChannelEnd {
        state: ChannelState
        ordering: ChannelOrder
        counterpartyPortIdentifier: Identifier
        counterpartyChannelIdentifier: Identifier
        nextSequenceSend: uint64
        nextSequenceRecv: uint64
        nextSequenceAck: uint64
        connectionHops: [Identifier]
        version: string
    }
    enum ChannelState {
        INIT, 
        TRYOPEN 
        OPEN,
        CLOSED,
    }
    ```
  - counterPartyPort -> Identifies port on counter-party which owns this channel (module permissions)
  - counterpartyChannelIdentifier -> Identifies channel end on counterparty
  - Sequence numbers
    - Identify next sequence number of corresponding packets (i.e which packets to process first)
  - connectionHops -> Specifies the number of connections along which messsages sent on this channel will travel
    - Currently one, but may be more in future 
  - **Channel Opening**
    - `ChanOpenInit`    
      - Executed by a module on ledger A, stores a ChannelEnd with the channel / port identifiers and expected counterparty identifiers
      - State is set to `INIT`
    - `ChanOpenTry`
      - Executed by counterparty module on ledger B, relays commitment of ChanOpenInit packer on A
      - Verifies the port / channel identifiers, and a proof that the module has stored the ChannelEnd as claimed
        - Notice that this verification is unique to the channel (i.e happens at a layer above the Client, therefore there must be an interface to the client to introspect state on counterparty)
        - Stores ChannelEnd for A in state, with state TRYOPEN
    - `ChanOpenAck`
      - Relays CHANOPENTRY on B, to A, 
      - Relays identifier that can be used in counter-party state to look up existence of ChannelENd on B\
      - Sets state as OPEN
    - `ChanOpenConfirm`
      - Marks ChannelEnd on B as open
  - Channel Sends
    - IBC module checks that calling module owns the corresponding port
    - Stores packet commitment in state, stores timeout in state
- ## Client Semantics Specs
  - light-client = validity-predicate + state-root of counterparty
    - Also able to detect misbehaviour through a _misbehaviour predicate_
  - state-machine
    - Single-process signing commitment of state-machine (solo-machine)
    - quorum of processes signing in consensus
    - BFT consensus protocol
  - Clients must be able to facilitate third-party introduction
  - `ClientState` - Unique to each light-client, i.e generally, facilitate a track of `ConsensusStates` each corresponding to unique (monotonically increasing) heights
    - Each `ConsensusState` is provided with enouch information to apply the light-clients `ValidityPredicate` (`stateRoot`, commitment root, validator set updates, quorum signatures, etc.) known as `ClientMessages`
  - `CommitmentProofs`
- ## Connection Semantics
  - 
## Questions
- How to implement IBC-unwinding upstream in `ibc-go`
## Eth2 Notes
 - **TLDR**
   - **POS** - More efficient consensus algo. using stake in network to determine quorum, vs. hash-power
   - **Sharding** - Scale eth, by only having a subset of vals execute / make-available certain state-transitions,
 - **architecture**
   - **beacon-chain** - primary chain (committee of vals)
     - **consensus critical** - Current val-set + changes to the val-set
     - **pointers** - Content addressing IDs of shard-blocks
   - **shard chains** - Everyone stores, downloads + verifies
 - Shard blocks contain user txs, only vals in committees (at slot at which shard block proposed) will make them available, all nodes store beacon blocks tho
 - 
## BID DA ?
- Is underlying chain necessary?
  - Mechanism for co-ordinating signers based on stake-weight between diff. chains?
  - Could be implemented as a remote signer?
-

## Hotstuff / LibraBFT
## Optimal Auction via Blockchain
- Auctions manipulatable by single proposer?
- Centralization of builders as opposed to centralization of proposer
  - This is due to builders being able to bid higher for blocks? Also easier for them to monopolize block creation?
- Second price auction
  - Bids ordered by fee, winner pays second highest fee
- 
## Anoma
- Intent centricity + homogeneous architectures / heterogeneous security
### Typhon
# IDEAS
- Browser operating on block-chain? I.e fully optimized for executing zk-proofs locally, and posting to block-chain networks
- Somehow integrate wallet functionality directly into the system, keys are stored locally?
- Some form of a proof of security?
- How valuable is DeFi in crypto?
  - What is the most valuable application for society?
  - Voting?
  - Secure web browsing?
    - Specifically to prevent against identity-theft, etc.
- Have to launch a token for a crypto protocol to be valuable?
  - Can close-source, force parties to integrate via a fee
  - If code is open-sourced, it can be forked, and must offer some other non-replicable service?
- Can launch token?
  - Code remains open-sourced, etc. 
  - Incentivized to attract value to the platform?
- Browser should be integrated into host OS similarly to ssh agents, etc.
  - How to reliably store keys? Attempt to store in host FS
  - Ideally can execute un-trusted code in browser?
  - How to attract users to platform? Have to build into google?
## Threshold Matchmaker Scheme for aggregating bids + auction winners
 - Matchmaker nodes request consensus for threshold pk, nodes encrypt bids w/ pub-key (released on creation of next block)
 - matchmaker nodes
## Communication
- How to convince people that I am correct well?
   - Take more time in communicating high-level ideas
- Gauge their understanding first
  - Checkpoint frequently
- Narwhal presentation
## Explain things to Mag frequently
- 
## IBC
## ZK
- 

## Twitter API
- Posting tweet -> Post to `../.../users/by/username/$USERNAME`
  - In header must be holding BEARER token
### Oracle Construction
 - Oracle periodically queries tweets from twitter, under specified hashtag
 - retrieves twitter handle, constructs EVM address corresponding to the sender of the tweet
 - expects data to be formatted in twitter using json
### Signers for each tx
- Oracle signers will be the same for all users
## Distributed Protocols w/ Heterogeneous Trust
- 
## Shared Aggregator (Bid DA) thoughts
### **Why Shared Aggregator**?
  1. Aggregate orderflow for a set of rollups in a censorship resistant DA layer
     - Aggregator can be scaled independently of roll-ups.
     - Pass DAG to roll-ups, enabling roll-ups to focus on two things. Rollups can have zero-message over-head consensus (ref: [here](https://arxiv.org/pdf/2201.05677.pdf))
       1. Creating canonical chain from DAG (apply fork-choice rule)
       2. Execute state-transitions in blocks, periodically post proofs to DA layer?
  2. Make building / scaling of blockchains (roll-ups) easy af
     - Currently, validators have to run instances of consensus for all chains that they are validating on, (according to Sunny) between 40 - 60% of all chains have an overlap in their active set, this indicates redundancy in validator sets
     - A shared mempool / causal ordering layer for all orderflow, for all chains, reduces redundancy. Ideally, all vals partcipate in aggregator, then roll-up founders can host their execution / ordering clients (potentially in TEEs or as zk-circuits) with v. little maintenance requirement.
  3. Atomic inclusion guarantees for all roll-ups
- **What should Celestia (or any DA) + shared Aggregator look like**
  - All validators are responsible for two things
    1. Managing a validator instance for the DA
    2. Managing a narwhal instance for the aggregator
  - Roll-up founders use roll-kit (or some SDK) to read DAG from aggregator, apply fork-choice rule to DAG and post commitment to new state + faithful application of fork-choice rule to DA
    - As long as the aggregator is consistent, and DAG is available (for all roll-ups), the roll-up execution clients can potentially be centralized
  - Roll-ups offer token incentives (also slashing conditions) for faith-ful participation in the aggregator / DA.
    - Messages created by aggregator nodes are composed of sub-blocks for each roll-up referencing aggregator DAG, nodes in aggregator may include arbitrary data in header / votes on messages received
### **Concerns**
  - How would roll-ups that require oracle values / threshold encryption / any other data that must be included in votes-extensions / proposal work? Diff. rollups have diff. trust assumptions, i.e Osmosis requires oracle value to be signed by 30 vals, but duality may only require 10 vals.
    - According to Sunny, this was the primary reason for his avoidance of the shared aggregator / deploying Osmosis as a roll-up. How to accomplish this w/o making aggregator aware of execution requirements of roll-ups?
    - **Response**
      - Make aggregator proposal validity rules configurable per validator.
        - Roll-ups can encourage validators to construct messages according to each roll-up's validity rule via token incentives
          - More granular block validity rules will not affect throughput of aggregator significantly
    - **Take-aways**
        - Is there a way to make the aggregator compliant w/ Extend-Vote / PrepareProposal ABCI++ methods? I.e can each sub-proposal of aggregator proposal be configurable by validators? Can votes on aggregator blocks include arbitrary data (threshold key shares, oracle values, etc.), is it possible to do this w/o having all nodes in aggregator be aware of diff. validity rules / vote-extensions per rollups?
  - Is there a way to incentivise participation in aggregator w/o incentives from roll-ups?
  - What state does the aggregator need to track? 
    - Slashing / incentives for validators can be handled by roll-ups, pruning of DAG can be handled by DA (plus inputs from roll-ups)
- **Sequencer Auction** 
  - For fraud proofs?
    - Who is going to be submitting the batch?
    - Possible to have batch submitted to DA by sequencer, and then state-root transition posted in accordance w/ sequencer auction?
## How do rollups work
- Only store batches of transactions on chain, execution on DA is only done for fraud-proofs (in this case, it is unclear what execution is done on-chain?)
- **optimistic**
  - Move computation + state-storage off-chain
  - Transactions + state-roots assumed to be valid until submission of a fraud-proof
  - State-root + transaction must be made **available** by DA
  - Expected that if sequencer (entity responsible for posting batches to DA) goes down, another node can j hop in and continue work (state-storage is where?)
    - How to guarantee that state-storage for rollups is stored somewhere? Responsibility of roll-up operators?
  - **transaction-execution + aggregation**
    - Aggregate txs + state-commitments
      - What if roll-up contract published state-root signed by $> 2/3$ stake of some arbitrary parties?
    - Users verify merkle-proofs given by full-nodes of roll-up in accordance w/ state-root made available by DA
  - **fraud-proofs**
    - Fraud proofs interactive. Simplest case, sequencer submits state-root + batch of txs, challenger challenges assertion
    - **multi-round**
      - Divide the proof randomly, until a single step is chosen, at which point

## Protocol Enforced Proposer Commitments
- Why move PBS into protocol?
  - Protect proposer?
    - Protect proposer from false header relayed by builder? I.e proposer is not responsible for proposing header of invalid block (builder is responsible)
  - Ensure liveness?
    - Force builder to actually reveal block when required
- Contract to be honored atomically for PBS. Contract is delivery of blockspace (must be atomic w/ payment)
    - Payment is not made -> Block content is not published (is this proposer's fault)
    - contract is successfully made, and payment succeeds. Blockspace is delivered to builder
- **MEV-Boost**
  - Contract is not atomic. I.e proposer delivers blockspace, builder does not publish block, proposer is not compensated
- Easy to go-around IP-PBS by ignoring protocol-bids (proposer is not slashed, as bids are only located in mempool? Can be lost due to latency etc.). Instead make arrangements OOP w/ builders
  - Can remove this by having vals commit to inputs to IP-PBS auction in consensus, only bids obeyed, will be those made available by proposers
- **Need mechanism for credible signalling, instead of credibly realising a specific signal**
  - Trustless mechanism for vals / actors to enter into commitments (atomic ones ideally) - Scheduler commitments
- **TLDR**
  - Commitments made between vals / TPA out of protocol, must be made credible by having agreement defined in-protocol
    - **credible** - Meaning that threats can be enforced, i.e violating commitment can be punished, and actors have a rational incentive to faithfully carry out commitment
    - Construct in-protocol eigenlayer, whereby a slashable stake is put-up by both partise
  - Above is not enough, enables maliciousness upper-bound to be set, and actors can disobey credible commitment if payoff is larger than stake
    - Have to move commitment state requirements into the protocol
    - Use POB to facilitate credible commitments in blocks?
      - Each round a set of commitments are made in prev. block, commitments are then set in keeper, and must be set via ABCI queries to be met in proposal simulation
      - 
  - _optimistic block validity_ - Proposer violates commitments, attesters attest to violation, and they are eventually slashed
  - _pessimistic block validity_ - Consider outstanding commitments in validity of block
  - ## Eigenlayer
    - _permission-less feature addition to the protocol layer_
    - **Principal-Agent-problem** - Validators slashed in eigen-layer are not slashed in protocol, and protocol has incorrect view of validator's incentive to act correctly
- **Protocol-Enforced Proposer Commitments**
  - Validator's commitments must be made available, and validator cannot defy commitment
  - [two slot PBS](https://ethresear.ch/t/two-slot-proposer-builder-separation/10980)
  - Make safe two patterns
    1. Validator entered commitment
       - _i._ Validator satisfied commitment (signed PBS header by third party), third-party fulfilled commitment -> payment is processed
       - _ii._ Validator satisfied commitment, third party did not -> payment is not processed
    2. Validator never entered commitment
  - How to differentiate between (1.i and 1.ii)?
    - Use attesters as validity checkers (and slashing for optimistic construct)
- Can have voters slashed optimistically,
  - I.e if attester votes for block violating commitment, then attester is later slashed (same problem exists where cost_of_corruption > stake) rational attesters corrupt
  - 
## Espresso Sequencer Design
- Credible neutrality?
  - How so, achieving utility w/o launching a token?
- Incenvitve alignment w/ L1 validators?
- **Rollup Consituents**
    - Client software (wallet - means of submitting txs to mempool)
    - VM
    - mempool - aggregate txs from client-software
    - Sequencing - Pull txs from mempools, and establish canonical ordering (why does this have to be consensus determined?)
      - Handles co-ordination of independent mempools, (can be done-on-chain, i.e based-sequencing)
        - Based sequencing does not provide same level of soft-commitment?
      - How does this method differ from shared-aggregator?
      - Also insures that instructions (txs in order) are available for clients to query
    - Prover - Receives ordered txs from sequencer and constructs / publishes proof to L1
    - Contract (proof verification / facilitation of fraud-proof disputes)


## Shared Aggregator
- Remove requirement that sequencers produce state-roots for chains they create blocks for
  - roll-up full nodes create state-roots, after txs at aggregator have been committed to DA (aggregator + full-node rollup proof generator = sequencer)
- **Shared Aggregation**
  - censorship resistance + liveness guarantees of decentralized sequencer set
  - Aggregator aggregates txs + posts to DA
  - roll-up nodes reference txs -> update state-root in accordance w/ txs
  - **paying for gas?**
    - Denominated in roll-up token? Aggregator nodes are state-ful (keep track of token balances)
    - What if inclusion in the aggregator blocks was free?
      - Subject to DOS attacks
  - **Inheriting fork-choice rule of sequencer set**
    - Roll-up takes the txs from aggregator and executes as is, how is there a possibility of forks from roll-up perspective if aggregator only publishes output of its own FC rule?
  - **Atomic Inclusion**
  - **Swapping of Shared Sequencer Sets**?
    - Not understanding? MEV extraction would happen at the prover layer?
  - ## Lazy Rollups
    - Rollups publish all txs to a DA
      - Wait for commit of txs, the execute FC rule on txs to select a subset, and update state accordingly
## Data Availability
- Use fraud proofs to convince to light-clients that current state-root believed is incorrect
  - Nearly same-level of security as a full-node
- Suppose proof of state-transition provided is not fully-available (i.e commitment of txs is available but some txs withheld)
  - Val 1 proposes un-available block
  - Someone catches
  - Val 1 releases full-block
  - Other vals are none the wiser, and can slash the catcher (forcing into altruistic act)
- **Solution to Above Problem: Erasure Encoding**
  - Force light-clients to query N chunks of M (full-block) and use erasure coding scheme to determine full-block
# Cryptography
- ## Quadratic Arithmetic Programs [link](https://vitalik.ca/general/2016/12/10/qap.html)
![Alt text](Screen%20Shot%202023-03-17%20at%201.16.32%20AM.png)
- First transform code into QAP (quadratic arithmetic program)
  - Also construct means of deriving _witness_ (solution to QAP) given input to computation
- ### Steps
  1. Flattening
    - Transform code into collection statements as follows
      - Can either by $x = z$, or $z (op) y$ (where op is a field operation)
  2. **Conversion to R1CS (rank-1 constraint system)**
     - Convert flattened statements into a R1CS, collection of sequence of tuple of vectors $(a, b, c)$, where for each tuple a solution $s$ satisfies $s \cdot a * s \cdot b = s \cdot c$
       - One can make this conversion based off of a given circuit
  3. Conversion from R1CS to QAP
     - Use lagrange interpolation to transform a R1CS to QAP
     - Instead of representing each symbol in computation as relation between 3 vectors of length 6
       - Represent
# Scheduler
1. Facilitate synchronization of transactions across cosmos chains
2. Scheduler operates as auction, makes payments to participating blockchains
- Allow multiple participants to bid on future time-slots across block-chains
  - Participating blockchains allow some portion of the block to be filled normally
  - I.e B1, and B2, enable all blocks proposed after $[t_1, t_2]$ to be proposed by entity $A$
    - $A$ then has the ability to auction off components of their own block (how is this different than PBS?)
    - Same centralized entry-point into blockspace (partially avoided by having only part of block built by scheduler)
- ## Actors
  - **Delegators**
    - Grant token delegations to validators
    - If validator is slashed -> they get slashed -> 
  - **Validators**
    - Run val-nodes
      - Incentivised to sign proposals? All proposals? Even if proposal is invalid does val get slashed (possibility of negative reward?)
  - **Proposers**
    - validator node, able to propose any block that adheres to the Prepare / Process Proposal rules
  - **Builders**
    - Potentially interacts with tendermint proposer to construct blocks
    - Incentivised to identify and capture MEV for themselves (only share w/ proposer thru auction)
  - **Searchers**
  - **Clients (users/wallets)**
- Scheduler (proposer, validators, builders)
  - Allow builders to execute set of blocks on separate chains ahead of time 
  - Most valuable opportunities occur JIT (i.e buy-out fn?)
- **System Properties**
  - **Liveness**
    - No actor w/ power $< 1/3$ should be able to stop progress of chain, (why is 1/3+ possible? Always vote no on proposals)
  - **Censorship Resistance**
    - No actor shld be able to stop the auction winner from having their valid blocks published or bids from being submitted to blockchain
      - Look at PEPC commitment design for in-protocol PBS
      - Question: once a chain has committed to specific builder, how does the protocol guarantee that builder doesn't rug? I.e proposer commitment + block are atomic
  - **Bundle Unstealability**
    - No MEV stealing? How is this possible? Only header is published to chain, so rational builders won't send their bundles elsewhere
  - **Latency**
    - Optimistic IBC design? Send proof of votes, etc. before block has actually been committed
    - Builder shld be able to send proposal for $h + 1$ once $h$ is published (not necessarily true that $h$ is committed tho?)
  - **Value Capture**
    - Auction market must be competitive for upcoming blocks
      - Think of incorporating buy-out here
  - **Cartel Creation Resistance**
    - Protocol must punish validator collusion
  - **Monopoly Protection**
    - Single actor cannot acquire all of block-space? How to prevent, order-flow will ultimately determine producers of blocks?
  - **synchronous atomic cross-chain execution**
    - Must be possible to execute atomic transactions across multiple chains at same time 
- ## Auction Design
  - Assumed that some $%$ of MEV captured in block will be bid for block -> that revenue shld be shared w/ participating chains
    - How to make distribution between chains as profitable as possible
    - Possible to eradicate MEV? I.e not necessarily, un-educated orderflow always present
  - Synchronicity determined by over-lapping time-slots
  - ## Questions
    - **Structure of slots sold**
      - I.e all slots are 15 seconds or slots are of any length, and bidders determine which slot they choose
        - Simple example bidder A bids for section of length 15 bidder C bids for next slot of length 5, bidder B bids for section of length 16, then bidder B has to bid higher than bidder A + C (how to structure efficiently)?
    - **How to structure Auction in accordance w/ **System Properties**
  - ## Block Allocation
    - **Latency**
      - Bids must be able to be submitted milliseconds before next block is requested? 
        - How to enforce? Must permit some amt. of time before next proposal so that builders have enough time to relay header, etc.\
      - Potentially hold auction on each chain
        - Can make bids conditional on other bids? Bids have to be projected until end of second chain auction (chain whose auction is not finished)
    - **Liveness v. MEV-stealing**
      - What is revealed to proposer of proposal? If reveal bundles, can other searchers capture?
## DAG stuff
- **DAG transport**
  - Responsible for reliably broadcasting, and establishing a total (causal) ordering of messages broadcast
    - I.e if any nodes receive and _deliver_ the message, and all other nodes must have done the same
  - optimizes throughput, and and endures through all network conditions (asynchronous)
- **Consensus**
  - Responsible for agreement on serial commits of unconfirmed messages
  - Each party uses local DAG to interpret the other partys' views of the network, and achieves agreement when possible (may only be possible in synchronous setting)
- **Key Tenets**
  - **Zero DAG Delay**
    - separate consensus ordering from DAG transmission 
  - **Simple**
- 
## MEV On DAGs
## Blockspace futures
- How is blockspace sold currently.. the presence of a fee-market (a la EIP-1559)
- Blockspace derivatives
  - Allow users to hedge their exposure to flucuations in gas-prices
- I.e - I have an intent to swap (at no particular price)
  - Submitting tx now is subject to the whims of current activity in network, submitting in the future decreases risk
- ## Applications
  - Rollups sell blockspace, but ultimately the cost of their block-space is determined by the cost of blockspace on the L1 (determined by proof-size etc.)
  - 
- ## Blockchain Resource Pricing
  - ### Convexity
# Elliptic Curve Crypto
- ## Finite Fields
- **Field**
  - Consists of a set $\mathcal{F}$, and two operations $+$ and $\cdot$ over the set $\mathbb{F}$ (resp. $\mathbb{F} \backslash \{0\}$), such that the set and the operation form an abelian group (commutative group)
  - Another important property holds (**distributivity**) - for $a,b,c \in \mathbb{F}, a * (b + c) = a*b + a*c$
  - If $\mathbb{F}$ is finite, then the field $\mathbb{F}$ is also finite
  - **Order**
    - Order is the number of elements in the field, there exists a finite field of order $q$ iff $q = p^m$ where $p$ is a prime number (aka. the characteristic of $\mathbb{F}$)
      - If $m = 1$, then $\mathbb{F}$ is a prime field, if $m \geq 2$, then $\mathbb{F}$ is an extension field
- **Binary Field**
  - Fields of order $q = 2^m$
  - Can construct field $\mathbb{F}_{2^m}$ by use of _binary polynomial_ i.e 
$$p(z) = \Sigma_{0 \leq i \leq m-1} a_i z^i$$
  - where $a_i \in \mathbb{F}_2$
  - **Constructing field via polynomial**
    - Set of polynomials of degree $\leq m - 1$, and coefficients in $\mathbb{F}_{2^m}$,
    - Multiplication is modulo unique **reduction polynomial** of order $2^m$
    - Each irreducible polynomial of order $q$ creates a new field that is isomorphic
- **Extension Fields**
  - Let $\mathbb{F}_p[z]$ be the set of polynomials with coefficients in $\mathbb{F}_p$, then each finite field $\mathbb{F}_{p^m}$ is isomorphic to the field of polynomials, with multiplication performed over the irreducible polynomial $f(z) \in \mathbb{F}_p[z]$
- **Subfields**
  - A subset $k \subseteq K$ of a field $K$ is a _subfield_ of $K$ if $k$ is also a field wrt. $+_K$ and $\cdot_K$
  - Let $\mathbb{F}_{p^m}$, has a subfield $\mathbb{F}_{p^l}$ for each positive $l, l|m$, let $a \in \mathbb{F}_{p^m}$, and $\mathbb{F}_{p^l} \subseteq \mathbb{F}_{p^m}$, then $a \in \mathbb{F}_{p^l}$ iff, $a^{p^l} = a$ in $\mathbb{F}_{p^m}$
    - Note the above is determined by the abelian grp structure of $\mathbb{F}_{p^m}$ wrt. $\cdot$
- **Bases of finite Field**
  - The finite field $\mathbb{F}_{q^n}[z]$ can be viewed as a vector space over the sub-field $\mathbb{F}_q$ 
  - Trivial basis $\{1, z, z^2, \cdots , z^{n-1}\}$, let $a \in \mathbb{F}_{p^n}[z]$, then $a = \Sigma_i a_i \cdots z^i$
- **Multiplicative Group of Finite Field**
  - Let $\mathbb{F}_q$ be a finite field, then $\mathbb{F}_q^*$ is a cyclic group, $(\mathbb{F}_q\backslash \{0\}, \cdot)$,
    - Let $b \in \mathbb{F}_q^*$, then $b$ is a generator iff $\mathbb{F}_q^* = \{b^i : 0\leq i \leq q-2\}$
- **Prime Field Arithmetic** (implementation)
  - Represent prime field $\mathbb{F}_p$, let $W$ be the word-length (generally 64-bit)
  - Let $m = \lceil log_2(p) \rceil$, i.e the bit-length of $p$ and $t = \lceil \frac{m}{W} \rceil$ it's word-length
  - Let $a$ be represented as $A[..]$, then
    $$a = A[t - 1]2^{(t -1) * W} + \cdots + A[1]2^{W} + A[0] $$
    - I.e primes reprsented in base $2^W$, and $A[i] \leq 2^W -1$
    - Represent integer of word-length by `uint` in go
    - Assignment $(\epsilon, z ) \leftarrow w$, means
      - $z \leftarrow w \space mod \space 2^W$
      - $\epsilon \leftarrow !bool(w \in [0, 2^W))$
    - let $a, b \in [0, 2^{W *t}]$, i.e both integers of word-legth $t$
    - Then their addition is defined as follows, which returns $(\epsilon, c) \leftarrow a + b$, where $c = C[0] + \cdots + C[t-1]2^{(t - 1) W} + 2^{W * t} \epsilon$
    1. $(\epsilon, C[0]) \leftarrow A[0] + B[0]$
    2. For $0 < i \leq t -1$
       - $(\epsilon, C[i]) \leftarrow A[i] + B[i] + \epsilon$
    3. Return $(\epsilon, c)$
    - Subtraction is defined analogously, i.e it returns $(\epsilon, c) \leftarrow a - b$, where $c = C[0] + \cdots + C[t-1]2^{(t-1)W} - \epsilon*2^{Wt}$
    1. $(\epsilon, C[0]) \leftarrow A[0] - B[0]$
    2. For $0 \leq i \leq t -1$
       - $(\epsilon, C[i]) \leftarrow A[i] - B[i] - \epsilon$
    3. Return $(\epsilon, c)$
- ## Number Theory
    - Let $n \in \mathbb{Z}_{>0}$, then $\mathbb{Z}_n$ (the integers mod $n$) is a group wrt addition
    - Let $\mathbb{Z}_n^X = \{a \in \mathbb{Z}: gcd(a, n) = 1\}$, then $1 \in \mathbb{Z}_n^X$, and the set is closed over multiplication
      - I.e $\mathbb{Z}_n^X = \mathbb{Z}_n$ for prime $n$, and $\mathbb{Z}$ is a field
    - $\phi(n)$ denotes the set of integers that are relatively prime to $n$, notice, by euler's thm. $a^{p-1} \equiv 1 (p)$, then $o(a) | p - 1$
    - **primitive root** mod $p$ is an integer $a$ such that $o(a) = p -1$ (i.e $a$ is a generator for $\mathbb{Z}_p^X$)
      - primitive root always exists, thus $\mathbb{Z}_n^X$ is a cyclic group (always has a generator)
      - 
- ## Groups
  - $(G, +)$, where $G$ is a binary operation
    - $ 0 \in G$, where $0 + g = g + 0$ (identity)
    - Existence of additive inverse, i.e $\exists -g \in G, (-g) + g = g + (-g) = 0$
  - **order** is number of elements in group
    - $g \in G$, then $o(g) := min (k), mg^k = 0$
  - Let $H \subset G$ (where $H$ is a subgroup of $G$), then $o(H) | o(G)$ 
  - **structure theorems**
    - Let $G_1, G_2$ be groups, they are isomorphic, if there exists $\phi : G_1 \rightarrow G_2$, such that $\phi$ is a bijection, and $\phi(g * h) = \phi(g) * \phi(h)$
  - **Fields**
    - Let $K$ be a field, There is a ring homo-morphism $\phi: \mathbb{Z} \rightarrow K$ that sends $1 \in \mathbb{Z} \rightarrow 1 \in K$, if $\phi$ is injective, then $K$ has characteristic 0, otherwise there exists $p$ such that $\phi(p) = 0$, and $p$ is the characteristic of $K$ 
      - $p$ is prime, as suppose $p = ab$, then $\phi(p) = phi(ab) = \phi(a)\phi(b) = 0$, and either $a$ or $b$ contradicts the minimality of $p$, thus $p$ is prime.
    - Let $K$ and $L$ be fields, with $K \subseteq L$. If $\alpha \in L$, then $\alpha$ is **algebraic** if there exists $f(x) = \Sigma_i a_i x^i$, there $f(\alpha) = 0$, and $a_0, \cdots, a_n \in K$ 
    - If every element $k \in L$ is algebraic over $K$, the $L$ is an algebraic extension of $K$
    - The **algebraic closure** of $K$, $\overline{K}$
      - $\overline{K}$ is algebraic over $K$
      - Every non-constant polynomial $f(X)$ with coefficients in $\overline{K}$ has a root in $\overline{K}$ (algebraically closed)
      - i.e any poly in $\overline{K}$ is factorable
    - 
- ## Pairings
  - Elliptic curves are an abstract type of _group_ defined on top of (over a field)
    - Use finite-fields in crypto b.c it is easier to represent in a computer
  - Let $K$ be a field, then $(x ,y) \in E$ (the elliptic curve), where $x, y \in \overline{K}$, which satisfy
  $$E: t^2 + a_1xy + a_3y = x^3 + a_2x^2 + a_4x + a_6$$
  - Where $a_1, \cdots, a_6 \in \overline{K}$, there is also one point $\mathcal{O} \in E$ but does not satisfy the Weierstrass equation
    - _point at infinity_ - needed so that E is a group
## Restaking
 -
- # Algebra
- ## Groups
  - **transfinite induction**
    - Let $I$ be a well-ordered set (i.e totally ordered, and for all $B \subset A, \exists b \in B \ni b' \in B, b \leq b'$), If $P_0$ holds (0 is min of $I$), assume $P_j$ holds for $j < i$, then $P_i$ holds, if $P_j$ holds, then $P_k, k \in I$ holds
  - **group** - Non-empty set $G$ on which a binary operation $(a, b) \rightarrow ab$ is defined such that
    1. $a, b \in G \rightarrow ab \in G$
    2. $a(bc) = (ab)c$
    3. There exists $1 \in G$, where for all $a \in G, a1 = 1a = a$
    4. $a \in G \rightarrow a^{-1}\in G \land aa^{-1} = a^{-1}a = 1$
  - **abelian group** - If binary operation is commutative, i.e $ab = ba$ 
  - Let $a_1, \cdots, a_n \in G$, then $(a_1 \cdots a_n) = (a_1 \cdots a_j)(a_{j+1} \cdots a_n) = (a_1 \cdots a_j)(a_{j + 1} \cdots a_{k+1})(a_{k+1} \cdots a_n) ...$, proof of associativity can be given using induction?
    - Induct on $n$, and since each group will be less then $n+1$, construct equivalent groups
    - Prove associativity with inductive hyp. for $a_1 \cdots a_n$
  - Identity uniqueness, $1, 1' \in G$, where $a1 = 1a = a = a1' = 1'a$, then $1' = 1'1= 1$, similarly w/ inverse $aa' = a'a = 1 = a''a = aa''$, $a' = a'aa'' = a''$
  - ### Subgroups
    - $H \subset G$, and $H$ is a group, then $H$ is a **subgroup** of $G$
    - Let $A \subset G$, then $\langle A \rangle \subset G$, is the intersection of all subgroups $H, A \subset H \subset G$
  - ### Group Isomorphism
    - Let $G, H$, be groups, and $f: G \rightarrow H$, a bijection between them, if $a, b \in G, f(ab)= f(a )f(b)$, and $f$ is an isomorphism, and $G, H$ are isomorphic
  - ### Cyclic groups
    - Let $G$ be a group, $a \in G$, then $\langle a \langle \subset G$, is the set $\{a^i \}$, notice, $\langle a \rangle$ is a group, and is abelian $a^m a^n$ (expand + apply associativity)
    - Thus, $\langle a \rangle \sim \mathbb{Z}_n$  (take $f(b = a ^n) = n$
    - **If $G = \langle a \rangle$, there is exactly one subgroup $H_d$ for each $d | n$, where $n = O(G)$**, 
      - Notice, if $H$ is a subgroup then, $o(H) | o(G)$, reverse direction is possible by considering $\langle a^{n/d}\rangle \subseteq G$
      - Uniqueness? Each subgroup is cyclic so consider generators?
    - For the above group, the following are equivalent
      1. $o(a^r) = n$
      2. $r$ and $n$ are relatively prime, i.e $gcd(r, n) = 1$
      3. $r$ is a unit mod $n$, i.e there exists $s \in \mathbb{Z}_n$, where $rs \equiv 1 (n)$ (group of units is a multiplicative group in $\mathbb{Z}_n$)
    - The set $U_n \subset \mathbb{Z}_n$ of units in $\mathbb{Z}_n$ is a group under mul.
      - $o(U_n)= \phi(n)$
   - $1, 2$ , if $a \in G = \langle b \rangle$, and $gcd(a, o(G)) = k$, then, then $a \in \langle b^k\rangle$m which has order $o(G) / k$
   - Consider $\mathbb{Z}_6$
     - Subgroups -> each have order dividing 6, then $1, 2, 3, 6$, i.e $\langle 0 \rangle, \langle 1 \rangle (\langle 5\rangle), \langle 2 \rangle (\langle 4 \rangle) \langle 3 \rangle$
   - $\mathbb{Z} \backslash \{0 \}$ (what does it look like?)
     - Must be a multiplicative grp. (grp. of units mod $n$) etc.
   - $a,b \in G$, where $ab = ba$, and $o(\langle a \rangle) = m, o(\langle b \rangle) = n$, then $o(ab) = mn$, and $\langle a \rangle \cap \langle b \rangle = 1_G$
     - Notice, if $ab^{mn} = 1$, then $o(ab) | mn$, and if $ab^k = 1$, 
- ## Linear Algebra
    - Study of linear maops on finite-dimensional vector-spaces
    - **Complex numbers** - The set $\mathbb{R} \cup \{i\}$, i.e $\{a + bi: a, b \in \mathbb{R}\}$, naturally, when $b = 0$, $\mathbb{R} \subset \mathbb{C}$
      - Complex numbers are a field (in general, linear algebraic concepts defined over fields)
    - **vector-space**
      - For $x, y \in F^n$, $x + y$ is denoted as the co-ordinate wise addition of the two vectors
      - Vectors have no base-poirt
        - Can consider addition, as the vector obtained by traversing the first (or the second), from an arbitrary base-point, and traversing the second from the end-point of the first traversal
        - Co-ordinate-wise Multiplication of vectors has no real-geometric intuition (apart from dot-product)
      - **vector-space** - A set $V$, with an addition, that is **associative, commutative, and invertable** (i.e there exists an identity as well (both additive, and for scalar mult.))
        - **Distributive property** - for $a , b \in F$, and $v \in V$, $(a  + b)v = av + bv$
        - **multiplicative identity** - $1v = v$
      - Set of polynomials is a vector-space (i.e basis are $1, x, x^2, \cdots$), and co-efficients are vectors
    **Subspaces**
        - Let $V$ be a vector space, a subset $U \subset V$ is a subspace, if $U$ is also a vector space (i.e additive-identity, closure, etc.)
          - Check that $0 \in U$, for $u, v \in U, u + v \in U$, for $a \in F, a u \in U$
        - Check for additive closure, scalar multiplication closure, (additive) identity
          - distributivity / associativity / commutativity under addition follow, as $u, v \in U \subset V$, and as such the properties hold
          - additive inverse follows from scalar closure w/ $a \in F, a = -1$, then $-v \in U$
    **Sums and Direct Sums**
        - Let $U_1, \cdots, U_n \subset V$, and are subspaces, then $U_1 + \cdots + U_n$ is the set $\{v \in V: v = u_1 + \cdots + u_n, u_i \in U_i \}$, natually the direct sum is a subspace of $V$ (as long as $U_i$ are subspaces of $V$,
        - **Direct Sum**
          - Let $V$ be a vector space, if there exists subspaces $U_1, \cdots, U_n$, where $V = U_1 \oplus \cdots \oplus U_n$, and for each $v \in V$, there is a unique representation in terms of $u_1 \cdots, u_n$ then $V$ is their direct sum
            - Can show that $V$ is not a direct sum, but showing a vector w/ non-unique representation
        - Let $U_1 \cdots U_n$ be subspaces of $V$, then $V = U_1 \oplus \cdots \oplus U_n$ if the following conditions hold
          - $V = U_1 + \cdots + U_n$
          - The only way to write $0_V = u_1 + \cdots + u_n$, is by taking $u_i$ to be 0
          - **Proof**
            - Suppose $V = U_1 \oplus \cdots \oplus U_n$, then naturally, $V = U_1 + \cdots + U_n$, and $0 = 0 +\cdots + 0$ (to write this another way violates hyp. (0 representation must be unique))
            - Supoose $V = U_1 + \cdots + U_n$, and $0 = 0 + \cdots + 0$ (is unique), then fix $v \in V$, where $v = u_1 + \cdots + u_n$, and $v = v_1 + \cdots + v_n$
            $$v - v = (u_1 - v_1) + \cdots + (u_n -v_n) = 0$$
            - and $u_i - v_i \in U_i$, and must be 0, otherwise hyp. is contradicted
        - **Questions**
          - Prove that the intesection of a collection of subspaces of $V$ is a vector spaces
            - $0 \in \bigcap_i U_i$, fix $a, b \in \bigcap_i U_i$, then $a + b \in \bigcap_i U_i$, i.e $\forall i, a, b \in U_i \rightarrow a + b \in U_i$, similarly w/ scalar multiplication
          - Consider $U_2 \cup U_1$, then it is a vector space if $v \in U_1, u \in U_2$, then $v + u \in U_1 \cup U_2 \rightarrow v,u \in U_1 (U_2)$, and $U_1 \subseteq U_2$
          - $U + U = U$
          - Sum of sub-spaces associative, as their addition is
          - Additive identity for subspace addition, is $0$, only $0$ has additive inverse?
          - If $U_1, U_2, W \subseteq V$, and $U_1 \oplus W = U_2 \oplus W = V$, does $U_1 = U_2$?
            - Yes, fix $u_1 \in U_1$, consider $u_1 + W \subset V$, then $u_1 + W \subset U_2 + W$, notice $u_1 \not\in W$ (then the representation of $u_1 \in V$ is not unique), thus, $u_1 \in U_2$ (a similar case follows for the converse)
    - **Finite Dimensional Vector Spaces**
        - **Linear Combination** - Let $v_1, \cdots, v_n \in V$, then $a_1v_1 + \cdots + a_nv_n$ is a linear combination (where $a_i \in F$)
          - **span** - The set of all linear combination of $v_1, \cdots, v_n$
          - Span of any list of vectors $H = v_1, \cdots, v_n$ is a subspace of $V$
            - $0 \in span(H)$ (take all $a_i = 0$)
            - Fix $a, b \in span(H)$, then $a + b  = (a_1 + a_1')v_1 + \cdots + (a_n + a_n')v_n$, and $a + b \in span(H)$
            - scalar multiplication (triv.)
        - if $span(H) = V$, and $|H| = n$, then $V$ is a $n$-dimensional space
        - **linear idependence** - If $H = (v_1, \cdots, v_n)$, and the only way to express $0 \in span(H)$, is with $a_i = 0$, then $H$ is linearly independent
          - In which case, for $v \in span(H)$ there is a unique representation of $v$
        - Any list of vectors containing $0$ is linearly dependent (coefficient of 0 in linear combination can be non-zero)
        - **lemma**
          - If $(v_1, \cdots, v_n)$ is linearly dependent in $V$ and $v_1 \not= 0$, then there exists $1 < j \leq n$
            - $v_j \in span(v_1, \cdots, v_{j-1})$
            - If the $j$th term is removed from $(v_1, \cdots, v_n)$, the span of these vectors is the same
          - Notice, because $(v_1, \cdots, v_n)$ are linearly dependent, there exist $a_1, \cdots, a_n$ (not all zero), where $a_1v_1 + \cdots + a_nv_n = 0$
            - Fix, $a_j$ to be the last coefficient that is non-zero, then $v_j = -\frac{1}{a_j}(a_1v_1 + \cdots a_{j-1}v_{j-1})$, and $v_j \in span(v_1, \cdots, v_{j-1})$
          - Consider $(v_1, \cdots v_{j-1}, v_{j+1}, \cdots v_n)$, fix $v \in span(v_1, \cdots, v_n)$, then $v = a_1v_1 + \cdots a_jv_n + \cdots a_nv_n = a_1v_1 + \cdots + (a'_1v_1 + \cdots a'_nv_n) + \cdots a_nv_n \in span(v_1\cdots v_{j-1}, v_{j+1}, \cdots v_n )$
        - In any finite dimensional vector space the length of any linearly independent list is leq the length of any spanning set
          - **proof**
            - Consider $(u_1, \cdots, u_m)$ is a linearly independent set, and $(w_1, \cdots, w_n)$ is a spanning set of $V$. Consider $(u_1, w_1, \cdots, w_n)$, as $span(w_i) = V$, this list is linearly dependent ($u_1 \in span(w_i)$), as such by the **linear dependence lemma** (above), we can obtain a set by removing a $w_i$ where $span(u_1, w_1 \cdots w_{i+1}, \cdots w_n) = V$. Suppose we have done this for $j -1 < m$ steps. Then we can consider $u_j, u_1, \cdots, u_{j-1}, w_i \cdots$. Because the prev. list is lin. dep. however $u_1, \cdots, u_j$ are linearly ind. we must remove one of the $w$s, and we have the same list. If $m > n$, than this process can continue until there are no more $w$'s to remove, in which case the original list is lin. dep. (a contradiction) $\square$
          - Any vector-space contained in a finite-dim vector-space is also finite-dimensional
        - **Basis**
          - a **basis** - Is a set of vectors that is linearly independent, and spans $V$
            - Can reduce any list of vectors that spans $V$ to a basis (apply **linear dependence lemma** if list of vectors is linearly dependent)
            - Every set of linearly independent vectors can be expandedt to a basis of $V$
              - Choose vectors that are not in $span(v_1, \cdots, v_{j-1})$, and recurse 
                - Eventually, the vectors will all be linearly independent (no vector is in the span of any prev.)
          - **Suppose $V$ is finite dimensional, and $U \subseteq V$
          - Suppose $V$ is finite-dimensional and $U$ is a sub-space of $V$. Then there is a subspace $W$ of $V$ such that $V = U \oplus V$
            - I.e must show that $V = U + V$ (for $v \in V, \exists u \in U, w \in W, v = u + w$), and representation of $0$ is unique (can also show $U \cap W = \{0\}$
            - Consider $U \subset V$, as $V$ is finite-dimensional, and $U \subset V$, there exists $(u_1, \cdots, u_n)$, that spans $U$. By the linear-dependence lemma, we may reduce this spanning set to basis of $U$ (i.e a linearly independent set of vectors spanning $U$). Denote this basis as $(u_1, \cdots, u_n)$, we may expand this set of linearly independent vectors to a basis of $V$, denote the vectors $w_1, \cdots, w_m$, consider $W = span(w_1, \cdots, w_m)$, naturally $V = U + W$ (the vectors form a basis). Furthermore, as the vectors form a basis of $V$, to suppose that the representation of $0$ is non-unique is a contradiction
        - ## Dimension
          - Any two bases of $V$ have the same length
            - Apply contradiction, assume existence of bases $b, b'$ both span $V$ and are linearly independent, so $len(b) \leq len(b')$, and the other dir. follows, thus they are equal.
        - **dimension** - The dimension of a vector space $V$ is the length of any basis of $V$
        - If $V$ is finite dimensional, and $U \subset V$ is a subspace, then $dim U \leq dim V$
          - Let $b_u, b_v$ be bases of $U, V$ respectively. Naturally, $U \subset span(b_v)$, and $b_u$ is linearly independent in $V$, thus $len(b_u) \leq len(b_v)$
        - If $V$ is finite-dimensional, then every spanning list in $V$ with length $dim(V)$ is a basis of $V$.
          - Must show that $b_v$ is linearly independent.
          - Suppose $b_v$ is a spanning set in $V$, with length $dim V$. If $b_v$ is not a basis, then $b_v$ is not linearly independent, in which case we can remove a vector, and still have a spanning set, thus a basis of $V$ must have length $\leq dim V - 1$ (a contradiction).
        - If $V$ is finite dimensional, then every linearly ind. set of vecs w/ len $dim V$ is a basis of $V$
          - show $span(b_v) = V$, use contradiction otherwise, must add vector, show that len $dim V + 1$, however, there exists spanning set of length $dim V < len(b_v)$ a contradiction -> every linearly ind. list must have lenght \leq dim V
        - If $U_1, U_2 \subset V$, are subspaces of fin. dim. $V$, then $dim(U_1 + U_2) = dim U_1 + dim U_2 - dim (U_1 \cap U_2)$
        - ## Linear Maps
          -  **Linear Map**
             -  Let  $V, W$ be vector spaces, $T: V \rightarrow W$, is a linear map, if it is 
                1. Additive - $T(v + w) = T(v) + T(w)$
                2. homogeneous - $T(hv) = hT(v)
             - Let $\mathcal{L}(V, W)$ be the set of all linear maps from $V$ to $W$
             - For any basis $(v_1, \cdots, v_n)$ of $V$, $Tv_1, \cdots, Tv_n$ (defines a basis of the range of $T$)
               - I.e the image of any vector $v = a_1v_1 + \cdots + a_nv_n$, is defined by $a_1T(v_1) + \cdots + a_nT(v_n)$, thus for any $w = T(v)$, can be expressed as a $T(v_i)$ linear combination of $v_1, \cdots, v_n$
             - For $S, T \in \mathcal{L}(V, W)$, define $(S + T)(v) = Sv + Tv$, and $(aS)(v) = a(S(v))$ (i.e it is a vector space over $F(W)$, using identity is $0 \in \mathcal{L}(V, W)$, where $v \in V, 0(v) = 0_W$
               - fix $S, T \in \mathcal{L}(V, W)$, then $(S + T)(v + w)$ = $S(v + w) + T(v + w) = Sv + Sw + Tv + Tw = Sv + Tv + Sw + Tw = (S + t)v + (S + T)w$
               - associativity + commutativity follow from $+$ over $W$, similarly w/ multiplicative properties
             - Multiplication of operators? I.e composition, ... define $U, V, W$ vector spaces, and $S \in \mathcal{L}(U, V)$, and $T \in \mathcal{L}(V, W)$, then $S * T = S \circ T$
             - I.e range space of first map, must be a subspace of input space of second map operatione is not commutativee
         - **Null Space**
           - For $T \in \mathcal{L}(V, W)$, $null(T) \subseteq V, v \in V, T(v) = 0_W$
           - Let $T \in \mathcal{L}(V, W)$, then $null(T) \subseteq V$
             - Identity $O_V \in null(T)$, i.e $T(0) = T(0) + T(0)$,  $T(0) = 0_W$
             - Additive identity -> trivial
             - Scalar multiplicative closure -> trivial
           - If $T \in \mathcal{L}(V, W)$, then $T$ is injective, iff $null(T) = 0$
             - Forward dir. $T(v) = T(w) \rightarrow v = w$, let $a \in null(T)$, then $T(a) = T(0) = 0$, and $a = 0$, thus $null(T) = \{0\}$
             - If $null(T) = \{0\}$, then suppose $T(v) = T(w)$, then $T(v - w) = 0$, and $v - w = 0_V$, and $v = w$
           - $range(T) \subseteq W$, 
             - 0, $T(0) = 0_W$, thus $0_W \in range(T)$
             - fix $v, w \in range(T)$, then $T(\hat{v}) = v, T(\hat{w}) = w$, and $T(\hat{v} + \hat{w}) = v + w$
             - Scalar multiplicative closure -> simple
           - **surjective** - A map $T \in \mathcal{L}(V, W)$, where $range(T) = W$
           - $dim(V) = dim(null(T)) + dim(range(T))$
             - fix some basis $n$ of $null(T)$, then $(n_1, \cdots n_m, u_1, \cdots u_n)$ is a basis for $V$ (as any lin. ind. set of vectors can be expanded to a basis of $V$). All that is left to show now is that $T(u_1), \cdots, T(u_n)$ is a basis for $range(T)$, notice, for $w \in range(T)$, $v \in V, T(v) = T(n_1, \cdots, n_m + a_1u_1 + \cdots a_mu_m) = T(a_1 u_1 + \cdots a_mu_n)$, and $w = a_1T(u_1) + \cdots + a_nT(u_n)$, suppose that $T(u_1), \cdots, T(u_n)$ linearly dependent, then there exists $a_1T(u_1) + \cdots a_nT(u_n) = 0$, and $v = a_1u_1 + \cdots a_nu_n \in null(T)$, and $v = a_1n_1 + \cdots a_nn_n$, thus $(n_1, \cdots, u_n)$ is linearly dependent, a contradiction.
           - If $V, W$ are finite dimensional, and $dim V > dim W$, no $T \in \mathcal{L}(V, W)$ can be injective
             - $dim V = dim null(T) + dim range(T) \leq dim null(T) + dim W$, and $dim null(T) > 0$
           - ## Matrix Of Linear Map
             - Let $(v_1, \cdots, v_n)$ be a basis of $V$, $T \in \mathcal{L}(V, W)$, then $Tv_1, \cdots, Tv_n$ is a basis for $range(T)$
               - **A matrix is a visualization of $T(v_i)$ in terms of a basis of $W$**
             - Let $w_1, \cdots, w_n$ be a basis of $W$, the column vectors are the coefficients, then the matrix of any linear map is constructed as follows,
               - Suppose $T(v_i) = a_{1,i} w_1 + \cdots + a_{m, i}w_m$, then $T(v) = b_1T(v_1) + \cdots + b_nT(v_n)$ (expand the vectors in a basis of  $W$, and solution presents), 
             - $\begin{bmatrix} a_{1,1} & \cdots & a_{1, n} \\ \cdots & \cdots & \cdots \\ a_{m,1} & \cdots & a_{m, n} \end{bmatrix}$
             - How to define matrix multiplication? Consider $U, V, W$ (vector spaces), notice $S \in \mathcal{L}(U, V), T \in \mathcal{L}(V, W)$, $ST \in \mathcal{L}(U, W)$, let $u_i, v_i, w_i$ be bases of $U, V, W$ respectively, then for $u \in U, u = a_1 u_1 + \cdots + a_k u_k$, 
               - $TSu_k = T\Sigma_n a_{i, k} v_i = \Sigma_i a_{i, k} T(v_i) = \Sigma_i a_{i, k} \Sigma_j b_{j, i} w_j = \Sigma_i \Sigma_j b_{j,i} a_{i, k} w_j$, notice 
                 - In the above $S(u_k) = a_{1, k}v_1 + \cdots + a_{n,k}v_n$ ($dim V = n$), similarly, $T(v_i) = b_{1, i}w_1 + \cdots b_{m, i}w_m$
                 - Input matrix is expressing $T(u_i)$ in basis of $V = (v_k)$
                 - Second matrix is expressing $S(v_k)$ in basis of $W = (w_l)$ (thus, columns of outer = rows of inner)
               - Given above, notice $Mat(TS)$, each column represents the set of scalar multiples of basis vectors $w_i \in W$, of $T(v_i)$ (where $(v_i)i \in basis(V)$)
                 - Then for column $k$, row $j$, group terms multiplying $w_j$, i.e $\Sigma_i b_{j, i} a_{i,k}$
            - **Invertibility**
              - Let $T \in \mathcal{L}(V, W)$, then $T$ is invertible if there exists $S \in \mathcal{L}(W, V)$, such that $ST = 1_{\mathcal{L}(V, V)}$, and $TS = 1_{\mathcal{L}(W, W)}$
              - A linear map is invertible iff it is injective and surjective
                - Let $T \in \mathcal{L}(V, W)$, and it is invertible, i.e $S \in \mathcal{L}(W, V)$ exists where for all $v \in V, ST(v) = v$. Then for $v_1, v_2 \in V$, where $T(v_1) = T(v_2)$, $S(T(v_1)) = v_1 = S(T(v_2)) = v_2$. WTS $range(T) = W$. Fix $w \in W$, then $S(w) \in V, T(S(w)) = w$.
                - Suppose $T$ is injective, and surjective. Then let $S : W \rightarrow V$, be the map such that for $w \in W, S(w) = v, T(v) = w$. Naturally, $TS = 1_W$. Consider $v \in V, ST(v)$, $T(S(T(v))) = (TS)T(v) =  T(v)$, and $ST(v) = v$ (injectivity of $T$)
              - $V, W$ are **isomorphic** if there is an injective + surjective map between $V \rightarrow W$
            - Suppose $dim(V) = 1$, then $T \in \mathcal{L}(V, V), Tv = av$
              - Let $\{v\} \subset V$ be a basis for $V$, as such $Tv = w \in V$, and $w = kv$ ($v$ spans $V$), thus for $w \in V, Tw = aTv = akv$
            - Suppose that $V$ is fin. dim, and $U \subset V$, and $S \in \mathcal{L}(U, W)$, then there exists $T \in \mathcal{L}(V, W)$, where $T(u) = S(u), for u \in U$
              - Consider $T = S | U$ (i.e $u \in U, S(u) = T(u)$), and $v \in V \backslash U, T(v)  = 0$, then $V = U \oplus V$ (prove linear independence straightforward)
            - $T \in \mathcal{L}(V, \mathbb{F})$, $u \in V \backslash null(T)$, then $V = null T \oplus \{au : a \in \mathbb{F}\}$
              - Notice, $dim V = dim null T + dim (range T)$, let $n_1, \cdots, n_k$ be basis of $null(T)$. Notice that $dim(V) = k + 1$, and $n_1, \cdots, n_k, u$, $u \in U$ is a linearly independent set of vectors of length $k + 1$, thus it is a basis.
            - $U, V, W$ finite dimensional, then $dim(null(ST)) \leq dim(null(S)) + dim(null(T))$
              - $v \in null(T) \rightarrow v \in null(ST)$, wb case where $range(T) \subset null(S)$
        - ## Polynomials
          - Let $\lambda \in \mathbb{F}$, and $p \in \mathcal{P}(\mathbb{F})$, then $\lambda$ is a **root** of $p$, iff $p(z) = (z - \lambda)q(z)$, where $q \in \mathcal{P}(\mathbb{F})$
            - if $z = \lambda$ solution is obvious, suppose $\lambda$ is a root, then subtract $p(z) - p(\lambda) = p(z) = a_0 + a_1z + \cdots a_mz^m - a_0 + a_1\lambda + \cdots a_m\lambda^m = a_1(z - \lambda) + a_2(z - \lambda)^2 + \cdots$ and factor
          - Suppose $p \in \mathcal{P}_m(F)$ (a poly of degree $m$), then $p$ has at most $m$ roots
            - Induction on $m$, assume $m-1$, then prev lemma states that if $p$ has a root $p = (z \lambda)q(z)$, where $deg(q) = z-1$
        - ## Eigen-stuff
          - ### Invariant subspaces
            - Let $T \in \mathcal{L}(V)$, where $V = U_1 \oplus \cdots \oplus U_n$, behaviour of $T$ is uniquely determined by behaviour on subspaces (every $v \in V$ is combination of vectors in subspaces)
              - require $T(U_i) \subset U_i$, i.e $T \in \mathcal{L}(U_i)$ <- may not be the case, if so called a **invariant subspace**
            - $null(T) \subset V$ is invariant, $range(T)$ invariant
            - If $U \subset V$ is one-dim, and invariant $dim(U) = $, $ u \in U, Tu \in U$, then $Tu = \lambda u$ (i.e $u$ is an eigenvector) (all $u$ in $U$ are eigenvectors)
              - $u$ is eigenvector, $\lambda$ is eigenvalue, happens when $(T - I)u = 0$ (where $u \not = 0$) and $T - I$ is not surjective
              - i.e $T - I$ is not invertible, set of eigenvectors is $null(T - I)$
            - Eigenvectors for distinct eigenvalues are linearly independent
              - Let $T \in \mathcal{L}(V)$, where $\lambda_1, \cdots, \lambda_n$ are distinct eigenvalues, and $v_1, \cdots, v_n$ are their corresponding eigenvectors, they are independent
                - Choose $k$ to be the smallest integer such that $v_k \in span(v_1, \cdots, v_{k-1})$, then $v_k = a_1v_1 + \cdots + a_{k-1}v_{k-1}$, and $T(v_k) = \lambda v_k = \lambda_1 a_1 v_1 + \cdots \lambda_{k - 1} a_{k-1}v_{k-1}$, then $\lambda v_k = \lambda_k (a_1 v_1 + \cdots a_{k-1}v_{k-1})$, and $0 = \lambda_k v_k - (\lambda_1 a_1 v_1 + \cdots \lambda_{k - 1} a_{k-1}v_{k-1}) = (\lambda_k - \lambda_1)a_1 v_1 + \cdots$, and $a_i$ must be 0, as $v_1, \cdots v_{k-1}$ are lin ind.
            - Each vector-space of $dim(V)$ as at most $dim(V)$ distinct eigenvalues
              - Length of basis (maximal length of lin. ind. list of vectors) must be $dim(V)$ apply above lemma
          - ### Polynomials over Operators
            - Operators can be applied to powers $range(T) \subset dom(T)$, i.e $T^4$ makes sense, whereas, $S \in \mathcal{L}(V, W)$, $S^4$ does not make sense
              - $T^0$ is $I$
            - 
# Algorithmic Game Theory
- ## Lecture 1
  - ### Origin
      - Computers 
        - Orignally thought of purely in terms of problem solving (Data structures, complexity of algorithms over those data-structures, etc.)
        - Internet -> now humans interact w/ algos / DSs = game theory?
      - Difference from pure Game-theory
        - Setting -> Internet facilitated interaction = auctions, networks, 
        - Purely quantitative -> seek hard upper / lower bounds on approximation, optimization problems,
        - Adopts reasonable constraints on actors in each game (polynomial-time)
  - ### Algorithmic Mech. Design
    - Optimization problems, where value to be optimized is unknown to designer, must be determined through self-interested participants in game 
      - How to structure game? Auction -> what is the value of a good -> participants bid on good to determine value
      - _self interested behavior yields desired outcome 
    - Auction Theory
      - **first price auction**
        - Good is auctioned
        - Highest bid is price of good
        - Participants incentivized to under-bid (prisoner's dilemma?)
      - **second-price auction**
        - Good is auctioned
        - Second-highest bid is price of good, however, winner is highest bidder
        - Participants may as well bid the maximum they are willing to pay for the good'
          - **proof**
            - Suppose for player $i$, $b_i$ is player i's bid, and $s_i$ is the value of the good to player $i$, $\hat{b}$ is the highest price of the other players. If $b_i > s_i$, then if $\hat{b} > b_i, s_i$, player $i$ may have just bid $s_i$(she loses anyway), and the same outcome occurs, if $b_i, s_i > \hat{b}$, then she will pay $\hat{b}$ (so she may have just bid $s_i > \hat{b}$), in the case that $b_i > \hat{b} > s_i$, she must bid $s_i$, otherwise she pays more than she would like for the good.
            - In the case that $b_i < s_i$
          - **Social Welfare Problem** - Good is allocated to individual w/ has the highest subjective value for the good
      - To what extent is _incentive compatible efficient computation less powerfuil than classical efficient computation_?
      - 
    - ## Lecture 1 Reading
      - **prisoner's dilemma**
        -  Two prisoners on trial for crime $p_1, p_2$, and each faces a max of $5$ if they lie and the other doesnt, if they both lie they serve $2$ years, if one tells the truth and the other doesn't they liar serves $5$ and the truthful prisoner serves $1$
          - Ultimate equillibrium -> both prisoners confess. WLOG $p_1$ remains silent, in which case, if $p_2$ remains silent he is better off confessing, a similar case holds if $p_1$ confesses
          - What if time for snitching is greater than time for lying? Then if $p_1$ is silent, there is an incentive for $p_2$ to remain silent (why would they do more time?)
      - **tragedy of the commons**
        - **pollution game** (extension of prisoners dilemma to multiple players)
          - $n$ players, each player has choice to pass legislation to control pollution or not. Pollution control has cost of $3$, each country not polluting adds cost of $1$ to legislation. 
            - Equillibrium -> no players pass legislation to control pollution, for $k$ players don't pass, cost is $k$ for not passing and $k+3$ for passing, once 
            - Consider case of $2$ players -> trivial both pay $1$, consider case of $3$ -> again trivial all pay $1$ (in worst case where all don't pass still pay $3$), in case of $4$ players, if you pay $3$ it is cheaper for all others to pay $1$ (max will be $3$) and you will pay $6$, so better for you to pay $1$
            - Alternative -> where cost of legislation remains $3$
        - $n$ players, have to share bandwith of max 1, player $i$ chooses $x_i \in [0,1]$
          - Want -> maximize used bandwith, Consequence -> more of bandwith used by all players -> deteriorating connection
          - model value for $i$, by $max(0, x_i(1 - \Sigma_i x_i))$
          - Fix player $x_i$, and $t = \Sigma_{j \not= i}x_j < 1$, then $f(x) = x(1- t- x)$ -> maximize to get $x = \frac{1-t}{2}$
            - Then $x_i = \frac{1 - \Sigma_{j \not= i}x_j}{2}$, assuming all $x_i$ are equal, one has $x = 1/(n + 1)$
            - Total usage is $\frac{1}{n + 1}(1 - \frac{n - 1}{n + 1}) = \frac{1}{n + 1}^2$
            - If total used is $1/2$ total value is $1/4$ (much bigger) but ppl overuse the resource
        - **Coordination game**
          - Multiple stable outcomes
          - **Routing Congestion**
      - ## Games, Strategies, Costs, and Payoffs
        - **game**
          - Consists of $n$ players, where player $i$ has $S_i$ strategies, and to play, each player chooses $s_i \in S_i$, notice $S = \Pi_i S_i$ determines the game (i.e the set of all possible combinations of strategies for each player)
          - For each $s \in S$, player $i$'s outcome depends on $s_i$, must define **preference ordering** over outcomes
            - I.e  total ordering that is reflexive + transitive over $S$ -> relation unique to player $i$
              - **weak preference** -> $S_1, S_2 \in S$, then $S_1 \leq_i S_2$ if $i$'s outcome is at least as good with $S_2$ as with $S_1$
              - Define $u_i : S \rightarrow \mathbb{R}$ (notice map $S$ and not $S_i$ as player $i$ must be aware of other players' strategies)
            - Standard form -> define / order outcomes for all players + strategies
        - **solution concepts**
          - **Dominant Strategy Solution**
            - If each player has a unique best strategy independent of strategies chosen by other players -> pollution game, prisoner's dilemma
            - Let $s_i \in S_i$ be the strategy chosen by $i$, and $s_{-1} \in \Pi_{j \not=i}S_j$ be the strategies chosen by the rest of the players
              - Let $s, s' \in S$, then $s is DS, if $\forall i, u_i(s_i, s'_{-i}) \geq u_i(s_i', s'_{-i})$, i.e for each player, there is a strategy $s_i$ which maximizes utility regardless of the other strategies
          - **Vickrey Auction**
            - Each player $i$, has value for item $v_i$, value for not winning $0$, value for paying price $p$, $v_i - p$
            - Game is only one round, bids are sealed bid
            - Naive mechanism -> take highest bid is not **DS**
              - Bid is conditioned upon strategies of other players... How to make **DS**?
            - **vickrey auction**
              - Highest bidder, wins item, pays price of second highest bid
          - **Pure Strategy Nash Equillibrium**
            - Let $s, s' \in S$, one has $u_i(s_i, s_{-i}) \geq u_i(s'_{i}, s_{-i})$
              - I.e given a strategy $s$, no player $i$ can change their strategy to $s'_i$ and obtain a higher payoff
                - Can have multiple diff nash equillibria, i.e a **DS** is a nash-equillibria
        - **Selfish Routing**
          - Can you achieve an optimal solution if all commuters co-ordinate when determining congestion of routes for their commute?
            - Worst case, everyone takes $5 min$ road, although a $6 min$ road is available
          - Consider a suburb $s$, and train-station $t$ (**pigou**) -> selfish behaviour may not produce socially optimal outcome
            - Suppose there are two roads to $t$, one skinny and fast, and the other wide + slow
            - Suppose there are $n$ drivers, and $x$ choose to take skinny road, where time taken from skinny is $c(x) = \frac{x}{n}$, and time taken from wide is $1$
              - Then if all drivers take the skinny road, the time taken is $1$, thus the equillibrium is $1$ in a selfish case
              - For optimized case, minimize $n - x - x^2 / n$, to get $x = n/2$
          - **Braess's Paradox**
            - Consider suburb $s$, and train-station $t$, and $n$ drivers
![Alt text](Screen%20Shot%202023-04-11%20at%2011.20.06%20PM.png)
            - Each path has one wide + short road, i.e $c(x) = 1 + x$, and the roads are equal, thus an equal number of travellers shld cross
            - Introduce 0 cost path between them, then, optimal route is to take $s \rightarrow v \rightarrow w \rightarrow t$, 
              - i.e always choose variable path when faced w/ a decision (now the time taken is 2h instead of 1.5)
              - Solution w/o cross-road strictly better
      - ## Lecture Notes
        - Four groups $(A, B, C, D)$, each with 4 teams
          - Phase 1: all four teams in each group play each other (6 games) -> top two teams advance to phase 2
          - Phase 2: knockout tourny -> winning > losing
        - Players want to win medals -> mechanism designer wants players to try
        - **pairing for quarterfinals**
          - Top team in A plays worse team in C, C -> B, B -> D, D -> A
            - A has upset, worst team in tourny is top, best team bottom
            - Winners of C want to avoid bottom of A, so try to lose match
-  ## Lecture 2
  - **Nash equillibrium**
     - Consider $s \in S$, then $s$ is a nash-equillibrium, if $\forall i, u_i(s_i, s_{-i}) \geq u_i(s'_i, s_{-1})$
       - I.e player's move is uniquely determined from other players' moves, and vice-versa -> who makes the first move?
       - If a player is incentivized to make first move, the strategy is **DS**? I.e optimal move is irrelevant of other player's moves?
  - **Mixed Strategy Nash**
    - **pure strategy** - Each player deterministically chooses strategy
    - **mixed strategy** - Players choose strategies at random, and determine outcome via expected value of strategy + utility of strategy (think of opponents as dice)
      - **risk-neutral** -> Assume players intend to maximize upside, and ignore possible down-side
    - **Nash Thm**
      - Any game w/ finite set of players + finite set of strategies has nash equillibrium
      - Force players to have mixed strategy
    - **pricing game** (game w/o nash eq.)
      - Two players sell product to 3 buyers
        - Each buyer wants to buy 1 unit, w/ max price of 1
      - Sellers specify price $p_i$ that buyers A, C must pay
        - Buyer B up for grabs, on tie defer to seller 1
      - Strategies
        - Sellers sell for 1 (naturally will have to sell for $\geq 0.5$ (otherwise even if they win they make less than 1))
          - i.e its a race to $0.5$? Yes, players can always undercut
        - Other strategy keep at 1
        - Infinite number of strategies?
    - **correlated equillibrium**
      - Two players at intersection at once
        - Crossing = 1, crashing = -100, stop = 0,
        - Nash equillibria -> 1 / 2 let car cross while other stop
      - Coordinator chooses actions of players
    - Define $P : \times_i S_i \rightarrow [0,1]$, a prob dist, where $p(s)$ is the prob of strategy $s$ being chosen, and $s_i$ is the strategy for player $i$
      - TLDR: correlated equillibrium when expected utility of $s_i$ cannot be increased by switching to a diff strategy $s'_i$
      $$\Sigma_{-i}p(s_i, s_{-i})u(s_i, s_{-i}) \geq \Sigma_{-i}p(s_i, s_{-i})u(s'_i, s_{-i})$$
- ## Finding Equillibria
  - ### Complexity Of Finding Equillibria
    - **Two-person-zero sum games**
      - Sum (over both players) of payoffs for all strategies is zero (i.e one player wins, other loses)
      - Consider $p, q$, and $A$ a matrix representing the payoffs for each action, i.e $A : S \rightarrow S$ (linear operator), only need to specify winnings for one player in this case
        - I.e. consider the matrix representing the amt paid to $p$ by $q$, and let $\hat{p} \in [0,1]^{dim(S)}$ represent the probabilities of each strategy for $p$, and $\hat{q} \in [0,1]^{dim(S)T}$ analogously, then the expected payout is $\hat{q}A\hat{p}$ (i.e expected value of strategies chosen by p (conditioned on q)), product w/ probs of strategies for $q$
        - Suppose strategy for $q$ is known (probability distributions), then the resulting payoff matrix becomes $qA$, i.e for each strategy of q, the expected payout for $p$, and $p$ must choose its own distribution to maximize payout 
        - Devolves to linear program as follows
          - Consider $A$, a matrix mapping $A = Mat(T)$, where $T \in \mathcal{L}(S_p, S_q)$, where $S_p$ is the space of mixed strategies for $p$ (i.e a prob distribution over $S_p$)
          - and $S_q$ is the vector space $\mathcal{L}(\mathcal{S_q}, \mathbb{R})$, i.e $\hat{q}$ is a mapping from the space of expected values paid from q -> p according to a given strategy chosen to $p$
        - **above-game has a nash equillibrium (if the strategy space is finite)**
        - **any choice of strategies from each player determines the other** (if in nash-equillibrium)
          - Player $q$ will want to minimize all entries in $pA$, i.e 
          - i.e choose $p$ such that $p\cdot A_i$ (i-th row of $A$), or in other-words, for each strat chosen by $q$, $p$ wants to choose a mixed strategy that minimizes the dot-product (expected-value from strategy) for $q$
          - row player chooses strategy, such that $(pA)_i = v_{i, p}$, choose $p$, such that $max_p(min_i (v_{ip}))$
            - Maximize profit
          - Column player, minimize loss (defined analogously)
    - ## Finding Nash Equillibrium
      - **Best Response**
        - Choose strategy $s \in S$, where $s_i$ is strat for $i$, then have all players iteratively determine $max_{s'_i \in S_i}(u_i(s'_i, s_{-i}))$ (assumes that other strategies are held static)
    - ## Games w/ Turns
      - **Ultimatum game**
        - Player $p_1, p_2$, $p_1$ is selling a good (at no particular price), and offers a price to $p_2$ who has value $v - p$, nash eq. $v$? 
          - In multi-turns equillibrium is at $v/2$
          - Game has multiple equillibria (buyer buys at any price under $v$), buyer only buys at $p \leq m$, etc. 
    - ## Bayesian Games (games w/o perfect info)
      - Players don't know other player' values / strategies
      - Bayesian first price
        - If not-bayesian, $p_i$ with highest valuation of item pays second highest
    - ## Co-operative Games
      - Games where players co-ordinate strategies?
      - **Strong Nash Equillibrium**
        - Given strategy $s \in S$, players $i \in A$, can choose strategy vectors $s_A$ (assuming that) $\forall i \in A, u_i(s_{A_i} s_{-A}) > u_i(s_i, s_{-i})$
        - $s$ is a strong nash-equillibrium, if no group $A$, can change stragegies to obtain a better outcome
        - **stronger than nash-eq.**
      - **transferrable utility**
        - total value is finite, and shared among $N$ players, for each $A \in N$ $c(A)$ is the cost (utility) of that group in the game for strategy $s_A$
        - Let $c(N)$ be the total cost, then a _cost-sharing_ is a partition of $c(N)$ among $i$, such that $\Sigma_i cs_i = c(N)$
          - Let $A \subset N$, then $A$ is in the **core** iff, $\Sigma_{i \in A} x_i \leq c(A)$, i.e leaving $A$ is not beneficial
            -  Strict inequality means that another set is out-of-core
        - **shapley-value**
          - Consider $(p_1, \cdots, p_N)$ (a random ordering of the players), then $c(p_i) = C(N) - C(N-i)$ (marginal cost for player $i$), the **shapley-core** is determined by assigning cost to each player equal to the expected value of their marginal cost over all random orderings
    - ## Aside (minimax algo)
      - Algorithm for determining (maximizing minimum gain) (or minimizing maximum loss) used in two player zero sum game
        - I.e solution
      - Construct a tree of moves (i.e root is the first player's move, second level are set of third player's moves, etc.)
        - **back-tracking algo**
      - Two players 
        - **maxizer** - maximize minimum win
        - **minimizer** - minimize maximum loss
      - ## Evaluation Function
        - 
    - ## Markets
      - $A$ of divisible goods
## CNS Questions
- Given a set of channels for a chain
  - Each channel has unique counter-party (channel-id / port on counter-party)
    - WTS channel-1 on A, and channel-2 on B are connected?
      1. Query the client-state associated w/ channel-1 on A -> how to determine which chain's state the client is light-client of?
         - Each channel is associated w/ unique client (client-id idx), then for each channel on a chain, identify client-id
         - Identify `client-id` on `A`, call this `client`
         - Notice, `client` is a light-client of some chain, if we have that chain in DB + RPC urls for chain, check that the client is indeed a valid LC of chain `B`
         - We now know, transfer-channel `A`'s client is an LC of `B`, `A`'s counter-party has `counter-party-channel-id` + port, and is in our DB, if it exists we can make the association
  - Implementation         
    - Client has `ClientState` + `ConsensusState` 
- ## Connections
  - For each channel in the DB, query the client-state associated with-it, if the channel for that client is in DB, check the chain associated with the channel, if that is in the DB, then make RPC query the counter-party chain
  - 
