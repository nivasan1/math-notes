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
    - Left off here: `https://github.com/SimplyVC/panic/blob/40cdb9f87723a75ed364fc76a006fdcc8343fdd1/alerter/src/monitors/node/cosmos.py#L398`
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
## Tests
### Monitor
- If the node is a `mev_tendermint_node` 
    - Check that the `is_peered_with_sentinel` field is set correctly
- If the node is not a `mev_tendermint` node
    - Check that the field is not set
### Transformer
### Alerter
