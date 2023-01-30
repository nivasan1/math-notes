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
    - What is the ideal separation of the
## Patterns
- Pattern for asynchronous calls to the DB
    - Have DB take stream as argument
    - Use value from stream as a parameter for the request
        - If value is not satisfied, then don't commit, if it is then commit
- Return value of commit to the caller
    - So they can handle the revert logic, in case the commit fails
- In case of val-reg <> sentinel
    - There is no need 
## Readings
### IBC Paper
### Shared Sequencer Set
### Heterogeneous Paxos
### Narhwal + Tusk
- Separate tx dissemination from ordering
  - Storage of causal histories of txs
- Assuems computationally bounded adversary to $f < n /3$
    - Does this mean that liveness persists when there are several computationally bounded adversaries? I.e $> n / 3$ faulty processes?
        - This is naturally false, as otherwise a byzantine quorum cannot be reached
- **Mempool Separate from Consensus**
- **Narwhal-HS**
    - Broadcast txs in batches (blocks)
    - Consensus on hashes of blocks from mempool
- Create a random coin **Tusk** for asynchronous consensus
### Narwhal
- DAG-based mempool abstraction
  - Structured, persistent, BFT distributed storage for partially ordering txs
- **Block** - list of txs + digest of prev. block
    - Blocks gossipped / stored in rounds
### Properties
- **happened-before** relation - 
    - If block $b$ contains a certificate to block $b'$, then $b' \rightarrow b$
- **Aside**
    - $$\frac{N - f}{2} + f = \frac{N + f}{2} < N - f \rightarrow N + f < 2N - 2f \rightarrow N > 3f$$
        - Reasoning, an irrefutable byzantine quorum (more than half of all correct processes + all faulty processes) must be less than or equal to the number of correct processes
        - Assuming $N = 3f + 1$, then $2f + 1$ represents a byzantine quorum
    - Block finalization for all blocks in round $r$ happens at $r + 1$, once a block receives a certificate, and that block contains certificates of all valid blocks in round $r$
        - Can be the case that some nodes don't receive all certificates from $r$, and don't include them in the block they propose, while others do?
- **Integrity** - Any certificate $d$ generated by a $write(d, b)$, for any w $read(d)$ from arbitrary correct processes, the returned block is either the same or non-existent
    - In this case, the block either exists in the node's cache or it doesn't
- **Block-Availability** - Any $read(d)$ that happens after a successful $write(d, b)$ eventually succeeds
- **2/3-Causality** - A successful $B = read\_causal(d)$, where $B$ contains at least $2/3$ of the blocks written before $write(d, b)$ was invoked. 
    - Is this referencing chain-forks? I assume dis-honest parties
    - Can it be the case that any $read_causal(D)$ can have diff returns from diff nodes?
        - If they are not honest
- **1/2-Chain Quality** - At least $1/2$ of the blocks in the returned set $B$ of a succesful $Read_causal(d)$ invocation were written by honest parties.
### What does this mean?
- Consensus only needs to order block-certificates
### Intuition
- **Gossip** - Double transmission, node receives tx -> sends to all other nodes etc.
    - Leader then includes tx in block (double broadcast)
- Solve this by broadcasting blocks instead of txs, consensus happens on hashes of blocks
    - Block already exists / is ordered
    - **Integrity-Protected** - Hash of block is content-addressed (consensus forges agreement on a unique id of block)
        - How to ensure that the block is available?
- **Availability** - Hashes of blocks need represent available blocks (can't verify signature otherwise)
    - Achieve this by broadcasting blocks to all nodes, nodes gossip block (or certificate / hash of block) to other nodes to prove they have it available
    - Once byzantine quorum of nodes have broadcasted a block, all nodes can assume that they have it available and they proposer receives a certificate of the block w/ > 2f+1 signatures 
    - Once this occurs, the certificate is re-broadcast and included in next blocks by all nodes that receive it
- **Causality** - Propose a single certificate for multiple mempool blocks
    - Each certificate proposed by leader proves availability of all blocks in causal history before it
- **Chain Quality** - Each proposal requires signatures of $> 2/3$ nodes from prev. round, that way, nodes can at most be 1 ahead / all other node will be permitted eventually to catch-up (liveness property)
    - Prevents a dishonest validator from spamming network with blocks to be committed, each block requires certificates of >2f + 1 blocks from prev round
- **scale-out** - Mempool-block producers can arbitrarily scale-out
- Multiple blocks broadcast and certificates formed each round. All blocks in next round contain certificates that proposer of block recognizes
    - Not all proposers have to have all blocks (but at least > $(N + f) / 2$ nodes have persisted any block (otherwise there would be no certificate))
- Each block must include a quorum of certificates from past round
    - This provides censorship resistance, at least quorum of honest nodes must have received certificates for their blocks at round $r$
- 
![Alt text](Screen%20Shot%202023-01-24%20at%2010.57.56%20PM.png)
- As above, each node builds a block containing certificates of blocks from prev. rounds
- Certificates broadcast and included in next round
    - For each certificate, at least an honest majority of producers will include certificate in next round
## Narwhal Core Design
- Nodes maintain local-round (incremented by maintenance of BFT clock)
    - Reliable Broadcast ()
    - Reliable Storage
    - Threshold Clocks
- Node receive
    - Txs from clients asynchronously and batch into blocks 
    - Receive $N - f$ certificates of availability for blocks built in round $r$, and move to next round
- Valid blocks are
    1. Signed by the creator, and are the first block sent by the creator for round $r$
    2. Contain the round number $r$ of the current round, if a block is received with a highter $r$ than what is stored locally, the validator advances its local round
    3. Contains $2f + 1$ certificates for round $r - 1$
        - Validity of certificates is dependent upon the block digest, and $2f + 1$ signatures of the validators signing the certificate
    - Once the above is met, the node stores the block, and signs the digest, round #, sender, and re-broadcasts (this is the **acknowledgement**)
        - Creator receives these
- Creator aggregates acknowledgements from $2f + 1$ vals, with digest, round #, and creator pub-key, and rebroadcasts as a **certificate**
    ## Security argument for certificate 
    - $2f + 1$ signatures $\rightarrow$ > $f + 1$ honest vals have checked + stored the block
        - It is available? Depends upon the eventually-synchronous communication assumption?
    - Quorum intersection prevents equivocation? Nodes cannot propogate another certificate from creator?
    - Use induction from causality between blocks
- **Use in Consensus**
    - Eventually synchronous blockchains are not live in asynchronous periods
        - Narwhal is asynchronous
        - As long as vals have stored blocks for higher round consensus proceeds
## Garbage Collection
- How to know which blocks in DAG can be garbage collected, potentially have to store $N^r$ blocks where $r$ is the round number
## Practical System 
- On receiving a certificate for $r + 1$, the validator pulls all $2f + 1$ blocks w/ certificates, and those blocks are avaialable
    - Blocks are only finalized once a certificate for the block certifying them is received by a validator
    ## Scale out Architectures
    - Can use many computers per validator
        - Each computer is denoted as a `worker`
    - Each worker streams transaction batches to other validators
        - Upon receiving certificates for transaction batches, primary (validator node) aggregates and sends a certificate for all worker blocks to other validators
    - Primary broadcasts blocks, where each `tx` is the digest of a worker block
        - Same guarantees for avaialbility?
- **Question**
    - If a validator receives a certificate for a block, but the block is not available when it requests the block, how is this handled?
## Tusk
- Theoretical starting point is `DAG-rider`
- Tusk, asynchronous consensus algorithm
- Includes a VRF coin in each tusk block
    - Upon receiving a tusk-block, creates an ordering from the DAG received by TUSK
- Each validator interprets its local DAG, based on the shared random coin
    - Validators divide random coin into `waves`
- Rounds
    1. First round all validators propose blocks
    2. Validators vote on proposed blocks by including certificates in the blocks they propose
    3. Validators propose blocks finalizing blocks from round 1, also receive value of random coin, and choose block from random leader at this round

## Implementing narwhal core?
## Hotstuff / LibraBFT
## Bullshark Paper
## Gasper
## Filecoin
## Anoma
- Intent centricity + homogeneous architectures / heterogeneous security
- 
### Ouroboros Paper
### Gasper
### Celestia Research
