
# DS Notes
## Notes on Go
### Memory
 - **Memory Operation**
     - Kind - data read, data write, synchronizing op.
     - location in program
     - location of variable accessed
     - values read / written by op.
 - **goroutine execution** - A set of memory operations executed in a go-routine
     - All memory operations must correspond to a correct sequential execution
 - **go program excecution** - A set of go-routine exections, together with a map M between writes, and reads, mapping read values to when they were written
 - **synchronized before** - Subset of W, where if W(r) = w, and r, w are both synchronized memory operations, then w *happens before* r.
 - A **send** on a channel is synchronized before the completion of the corresponding **receive** from that channel.
    - Closure of channel is also synchronized before the corresponding send
 - **Locks**
     - muxtex.lock is synchronized before a call to mutex.unlock, mutexes start unlocked
     - RWMutex - For any call to l.RLock on a sync.RWMutex variable l, there is an n such that the nth call to l.Unlock is synchronized before the return from l.RLock, and the matching call to l.RUnlock is synchronized before the return from call n+1 to l.Lock.
         -   i.e, a call to lock, synchronizes after all Rlocks have been unlocked
 - Don't be clever
 - **Garbage Collection**
 -

## Fault Tolerant Virtual Machines
- Two ways to replicate service in fault tolerant manner
    - Primary / Backup
        - Backup is replicated service, primary serves requests
        - In event of Primary failure, single back-up is chosen 
        - Primary recovers from failure, rejoins concensus as backup
    - State Machine approach 
        - Primary and replicas start in specified state, execute state-transitions on receiving atomic txs
        - Co-ordinate committed state between replicas to ensure application non-determinism does not result in failed replication
    - Transmit fully committed state between replicas continuously
        - Consider extremely large network bandwith
- Replicate VM running in hypervisor on primary and replica
    - Hypervisor simulates actions of VM, primary records and transmits state-transition executors
        - Well defined in this case (syscalls, I/O, file manipulation, etc.)
    - Take care to transmit / replay non-deterministic state-transition executors exactly on replicas.
    - Hypervisor controls delivery of all inputs, replicate hypervisor on replicas, transmit delibery inputs into hypervisor (device specific data, I/O, etc.) to replicas along with non-deterministic data.
- Considerations - Any OS using x86-64 bit instructions can be simulated atop VMware instance.
    - No data is lost if a backup replaces primary.
- Architecture
    - All network / device commands sent to primary
    - Primary / replica share virtual disk
    - primary transmits data to replicas, which replicate action exactly.
    - Replicas / Primaries maintain logs of excecuted / incoming requests for crash recovery
- Deterministic Replay
    - Considerations
        - Correctly capture all inputs (disk reads, network connections, device interrupts) and all non-determinstic data (clock-cycles, virtual interrupts, etc.) transmit to replicas.
        - Applying state transitions to backups in correct order
        - performance is maximized
   - Deterministic entries logged in sequential order to a log
       - Non-determinstic entries are logged, with instruction counter where occured is logged.
- FT protocol
    - **Consideration** - backups are able to pick up exactly where primary left off in execution, and in a way that is consistent with primary state / outputs
    - Outputs consistent
        - Each output operation received by primary is logged to WAL, gossiped to all replicas, and only then is the output sent from primary
        - Backup will be able to guarantee exact output that primary would have if all logs are exactly replayed on primary and replica![](https://i.imgur.com/Vfv2Niu.png)
- Failure Detection
    - Use UDP heartbeat messages between replica and primary. Network also keeps track of log entries v primary execution, if out of sync replace primary
    - Must ensure that only one primary is executing on Network,
        - Otherwise data corruption in replicas is possible
    - To become primary, use atomic test-and-set operation on shared storage between replica and primary (guarantee sequential ordering).
- Practical implementation of FT 
    - Logging Channel 
        - Primary maintains log buffer
        - Writes updates to buffer, flushes whenever possible (i.e inactivity, system resources available, etc.)
        - Replica reads from log buffer whenever it is non-empty, 
    - Replica acks all logs that it receives from log channel, primary sends outputs upon receiving ack for corresponding log
- Operation on FT VMs
- Disk I/O
## Raft
 - **Strong Leader** - Log entries only flow from leader to other servers
 - **Leader Election** - Randomized timers to elect leaders
 - **Membership Changes** - During changes of active peers (nodes) in concensus, it requires the intersection of the new / old set to be a majority of both
 - ![](https://i.imgur.com/5Mm2nBJ.png)
 - **Architecture of Replicated State Machine** - Enables set of distributed nodes to come to concensus on order of tx, write sequential order to log,  apply txs from log to state, commit state, and send state to client.
     - **Safety** - The result returned to client is always valid, in the presence of byzantine nodes.
     - **Liveness** - Always operational as long as a majority of nodes are live
     - **Timing independent** - The nodes do not depend on timing for effective operation.
- **Implementation**
    - **Leader** - Designated each round, charged with managing replicated log, ensures replicas agree on log and commit to state. Receives and transmits client requests to replicas
    - Sub-problems 
        - **Leader Election** - A new leader is chosen when curLeader fails
        - **Log Replication** - Leader accepts log entries from clients, and replicats across replicas.
        - **Safety** - If a server executes a log entry at log index n, the log entry must be the same across all nodes.
- **Operation** 
    - At all times any server is in one of three states
        - **leader** - one leader
        - **follower** - issue no requests, only respond to leader / candidates
        - **candidate**
   - The leader processes all requests from clients, (clients may contact follower but will be directed to leader)![](https://i.imgur.com/uzOlorL.png)

   - Time is divided into unbounded **terms**, each term begins with an **election**, in which candidates attempt to become leaders
       - If candidate becomes leader, it serves as leader for rest of term
       - Elections ending in split votes, and a new term is begun
 - Each server stores a **current term** number, to denote the term that the server is in.
     - Servers are able to distinguish between stale leaders
     - All communications between nodes include the current term number for the node. 
         - If a server's current term is less than another node's it's **currentTerm** is updated.
- Raft servers communicate via RPC, the interface is as follows
    - RequestVote - initiated by Candidates during elections
    - AppendEntries - Initiated by leaders to replciate log-entries
        - RPCs are retried if they time-out
        - RPCs are issued in paralell by servers
- On startup servers begin as followers
    - Remain in follower state as log as it receives valid RPCs from a leader or candidate.
- If followers receive no communication over a period of time, an **election timeout** is triggered.
    - Assume no visible leader is available, and begin election to choose a new leader
 - Beginning an election
     - Follower increments current term, transitions to candidate state
     - Votes for iself
     - Issues requests in paralell to other servers
 - Winning the election
     - Wins if server receives votes from a majority of servers in cluster for same term.
     - Server votes for at most one candidate per term. 
         - First come first serve basis
     - Once candidate becomes leader, the node issues periodic **heartbeat** AppendEntries RPC request
- Candidate receives **heartbeat** from other leader
    - If the term is >= currentTerm, then the candidate becomes a follower, and responds to the appendEntries RPC
    - If the term is < currentTerm, the candidate rejects RPC, and continues sending RequestVotes RPC
 - Candidate neither wins nor loses the election
     - Candidate times out, increments term, and begins election again as candidate
 - Election timeouts randomized to prevent split-votes (150-300 ms)
 - **Log Replication** - 
     - Each client request contains a command to be executed,
          - Leader appends command to log, and issues appendEntries RPC in paralell.
     - Once entry is safely replicated, the leader commits the state transition, and returns the result to the client
     - Logs are organized as follows
         - StateMachineCmd
         - Term number
         - integer index of log in list
     - Executed logs are called committed, all committed logs will eventually be executed by all of the servers
     - A safely replicated log has received successful requests from a majority of the servers.
- Leader keeps track of latest committed log index, sends this to servers in subsequent AppendEntries requests
    - Nodes commit all state up to the latest committed index from the RPC
- Log matching proporty
    - If two entries in diff logs have hte same index and term, they store the same command
    - If two entries in in different logs have hte same index and term, all preceding logs are identical.
- AppendEntries - Along with the entries to be committed in the request, the leader sends the first entry w/ index < newCommitIndex, to followers
    - If this entry does not exist in a follower, the follower rejects the entry, and leader fixes this
- Leader brings conflicting logs of followers to consistency
    - Find latest log index where entries agree, remove followers logs after that point, and change AppendEntries to match
    - For all followers
        - The leader maintains a nextIndex, the index of the next log entry to leader will send to the follower
- **Log Matching Algorithm (Leader)**
    - On startup nextIndex for all followers is set to (self.log.len()) + 1
    - For each failing AppendEntries RPC
        - The leader decrements the nextIndex by one and tries again
        - Follower can also return index of first conflicting entry in failure response
- The leader's log is append-only
- **Safety** (Restriction on electable servers)
    - Leader Completeness property (Leader's log contains all entries from previous term).
- Election Restriction
    - Leaders cannot conclude that an entry has been committed once it has been stored on a majority of the servers
        - Leader sends append Entries to majority of servers, and crashes before it sends next heartbeat
    - RequestVote RPC, clients reject RPC if their committedIndex is higher than the sender's
        - Compare log[lastCommittedIndex], if the term of the last committed index > than the receiver, the sender's log is more up-to-date
 - Cluster Changes
     - 
# ZooKeeper
# Celestia
## Erasure Coding
 - Given *k* symbols, add *n - k* symbols of *k* bits, to retrieve a code of *n* symbols, from this, *(n - k) / 2* symbols are recoverable.
     - *RS(255, 223)* is a code with *223* data symbols, add *32* padding symbols, 16 symbols are recoverable from the msg
## LazyLedger
 - Modular block-chain network, with a unified **data-availability layer**
     - This enables **modular blockchains** 
     - Celestia is only responsible for ordering txs
     - All Applications store relevant data in a NMT on the DA layer, 
         - Applications query by **NID** (namespace ID), and receive the messages relevant to them from the most recent block, (**where is application state cached? Do lightnodes have to recreate all messages in order to maintain their state?**)
  - Scaled by decoupling execution from consensus, and introducing **data availability sampling**

# Distributed Systems Reading
 - **Distributed Systems** fundamentally different from **Concurrent** systems in that, **distributed systems** require co-ordination between processes executing in paralell.
 - **Client-Server** computing - A *2-party* interaction, in which a centralized **server** responds to requests from a **client**
     - Generalization of this concept is **multi-party** computing.
     - **peer-to-peer** - represents the **client-server** model, replaced with a non-canonical server (any client can be the server to another client)
 - **system-model** - Generalize non-important technical details, and represent as **objects** within the model i.e (**process** for a computer with an operating system, networking interface, cryptographic identification credentials, etc., **links** for an arbitrary inter / intra- networking protocols between **processes**)
     - **system-model** - Composed of several **objects** (generalizations of technical details) and their interactions
     - **system models** give us the tools to build abstractions / protcols from the **objects**, i.e (consensus, atomic commitment, identity verification, etc.)
## Information Dissemination
 - Break participants in network into **publishers**, **subscribers**
     - **publishers** - Publishers aggregate data, and send **events** to participants that have voiced their interest in receivng messages pertaining to information aggregated
     - **subscribers** - Subscribers have voiced their concern to one or multiple **publishers** that they would like to receive some notification of **events** pertaining to the data that publishers are producing
     - Subscribers and publishers must agree on the events receieved (how do they identify a valid publisher? How does events / published data appear? ) 
     - **Forms** - channel-based, subject-based, content-based, type-based
## Process Co-ordination
 - Multiple Processes may be involved in the computation of a single product
     - Each process must return the same result, or have some consensus on their relevance to the product produced by each process
## Distributed Storage / Databases
 - Multiple **processes** may be tasked with storing a shared sequence of data
     - This data may be shared among all nodes (each node maintains the same data)
         - Mutations to this data must then be communicated to all processes, so the end result is the same
         - How are mutations communicated, what does the data look like? 
         - Requests of the data from any process must be the same
    - This data may be split among each process (**sharding**) 
        - Mutations involving multiple **shards** (partitions) must be co-ordinated
        - processes must be in agreement of the partition
            - I write key x, which process receives this write?
            - What happens if a shard is lost? Can we replace this?
## Fault Tolerance Through Replication
 - Centralized service fails... what happens?
     - Solve this by having the service replicated among multiple processes, more tolerant to failure
 - Replication breeds co-ordination
     - Why do we replicate... to make a service more available
           - Ok... then each replica must provably act as if it is the centralized service, replica A, and replica B respond the exact same for any service the centralized server provides
 - How do we provably do this? State machine replication
     - Each replica is a state-machine, responds to a set of messages
     - Each replica is in the same state at any time, (co-ordinate state between replicas
     - Replicas receive the same set of requests in the same order (**total order broadcast**)
         - Replicas agree on the order in which they send / receive messages from all processes replicating service
 - COMPLEXITY SHOULD BE IMPLEMENTED AT HIGHER LEVELS OF THE COMMUNICATION STACK
## Asynchronous Event-Based Composition Model 
 - Each Process hosts some number (*>= 1*) of **components**
     - **component** - receives events (produced internally or externally) and produces events for other **components**
         - Characterized by name, properties, and interface
         - Components represent layers in a stack (Application -> consensus -> networking)
         - Each component is internally represented as a state-machine, which reacts to external events defined as follows 
             $$\langle co, Event, Attributes \rangle$$
         - where *co* is the component, *Event* is the event, and *attributes are the arguments*
## API
 - **Requests** - Invocation of service in a diff component 
 - **Indication** - Indication to some component that at a condition has been met at some other service
 - ![](https://i.imgur.com/AyB4eai.png)
 - **Requests** (input) trigger **indications** (output) 
 - ![](https://i.imgur.com/cHGP8yh.png)
- ![](https://i.imgur.com/RfWxGyb.png)
 - Components are composed of multiple modules
     - Interfaces can be composed of **Indications**, these can be expected to be events produced by the component (implementer of interface / module), consumed by other components and **requests** (methods of the interface)
## Forms of distributed algorithms
 - _fail stop_

## basic abstractions
**distributed system model**
 - _processes_ - i.e nodes in a distributed system
 - _links_ (i.e network connections)
 - _failure detectors_ 

Consider _processes_ as automatons, and _messages_ passed between the automatons as triggering state changes,
![Alt text](Screen%20Shot%202022-12-11%20at%202.40.54%20AM.png)

 - *deterministic* algorithms always have a single outcome according to the same set of inputs (each state transition is a function)
- Assume that all process state-transition (sending of events, invocations of requests, etc.) may be associated with timestamps that are provided by a globally shared clock among all nodes, (i.e all nodes are syncronized)
## Safety and Liveness 
 - Any property of a *DS* must be satisfied across all interleavings of events (determined by scheduler)
  - **SAFETY** - A property that once it is violated at time *t* will never be satisfied again , i.e to prove an algorithm is unsafe, amounts to identifying a time _t_ at which the safety property is broken.
    - In other words one may prove correctness for a *safety property* by assuming that a safety property is violated at some time _t_ and reaching a contradiction
    - Generally associated with correctness, (the wrong thing doesn't happen)
  - **Liveness** - Eventually something good happens. A property of a _DS_ such that at any time _t_ there is some _t' >= t_ for which the good thing will happen.
    - Proving liveness properties may amount to constructing the time _t'_ from _t_ at which the property will eventually be satisfied
### Process Failures
 - *crash-fail* - This process abstraction is one in which, at some time _t_ a process does not execute any state-transitions, nor does it send any messages
    - Simplest failure abstraction process is _crash-stop_
    - **resilience** ratio _f/N_ of _faulty processes_ to all processes
 - *omission-fault* - An otherwise _correct process_ (executes state-transitions faithfully given the correct inputs), may omit a message sent to it, and may result in an inconsistent state with the rest of the network
 - *crash-recovery* - If a process is allows to crash, recover, and resume correct execution
    - Correctness in this case, assumes a finite number of recoveries (i.e the process isn't dead and constantly restarting)
    - Upon restarting how will the process rejoin?
        - Storing and reading state from stable storage?
        - Rejoining with fresh state? 

- *arbitrary faults* - Some set of the _faulty processes_ are under the control of an adversary, and may co-ordinate to take down the network.
### Cryptographic Abstractions
 - **Hash Functions** - A function $$ H : \{0,1\}^n \rightarrow \mathbb{M}$$, where $$\mathbb{M}$$ is the message space, $$ \forall x, y \in \{0,1\}^n, H(x) \not= H(y)$$
    - Easy to compute

- **Message Authentication Code (MAC)** - One may concieve of this as follows, $$MAC \in \Pi^2 \times \mathbb{M}$$, essentially, it is an identifier for each message sent between two processes, such that it is infeasible for another process to generate $$MAC$$ given $$m \in \mathbb{M}$$, (think of this as  the hash of the message, encrypted via the receiver's public key), 
    - One may consider a function $auth_q : (p,q,m) \rightarrow (p,q,m,q) \in \mathbb{A}$, where $a$ is the authenticator for the message $m$, this function is unique to the sender $q$
    - The receiver may then invoke $verify_q : (p,q,m,a) \in \mathbb{A} \rightarrow \{True, False\}$, this function is uniquely available to receiver, and determines if the authentication code is valid or not
    - Easy to Compute
 - **Digital Signature** - Verifies the authenticity of the message, verifiable by all $p \in \Pi$, more general than a _MAC_
    - In comparison to a _MAC_ or a hash function, evaluation of digital signatures is much more computationally complex
## Link (Network) Abstractions
 - *fair-loss links* - Messages may be lost, probability of message loss is non-zero
    - Can implement message responses, so that senders are able to re-transmit until verified receipt from receiver
        - *FLL1* - If process $p$ sends a message $m$ an infinite number of times, then $q$ (receiver) delivers $m$ an infinite number of times
        - *FLL2* - If process $P$ sends a message $m$ a finite number of times, then $m$ is delivered a finite number of times (any message is duplicated at most a finite number of times by the network) 
        - *FLL3* - If process $q$ delivers a message $m$ with sender $p$, then $m$ was prev. sent to $q$ by process $p$ 
- Link abstractions implemented as follows 
    - Define $\langle Send\rangle$ Request and $\langle Deliver \rangle$ Indication
        - Consider process $p$ with components $A$ and $B$ (notice the communication layer is a module that may be implemented by several components of a process)
            - *Send* (indicates request) - denotes the action of sending the message to another component (may be a process or seperate networking layer)
            - *Deliver* (indicates indication) - denotes the action of the networking component, implementing the algo. defined in the module the component implements (actually sending the message) 
- *Stubborn Links* - Abstraction built on top of *fair-loss links*, any message sent by $sl1$ to $sl2$  is delivered by $sl2$ an infinite number of times 
    - *Stubborn Delivery* - If a correct process $p$ sends $m$ to correct process $q$, $q$ delivers $m$ an infinite number of times
    - *No Creation* - Same as $fll2$
```go
    type msg struct {}

    // analgous to module in go 
    type link interface {
        // symbolizes a request 
        func request_Send(message msg, to link)  
        // symbolizes an indication
        func indication_Deliver(message msg, from link) chan struct{} 
    }
    // stubbed for time being (implementation is considered as a given i.e OS networking interface) 
    type FairLossLink struct {
        indication Chan chan struct{} 
    }
    // FLL1 - if msg is sent an infinite number of times to q, then q delivers m an infinite number of times
    // FLL2 - if msg is sent a finite number of times to q, then msg is delivered a finite number of times
    func (p *FairLossLink) request_Send(message msg, q link) {}

    // FLL - if q delivers msg to p, then p sent msg to q
    func (q *FairLossLink) request_Deliver(message msg, p link) {
        q.indicationChan  <- struct{}{}
    }


    type Sent struct {
        q link
        m msg
    }
    // stubborn link implementation, this abstraction is built on top of the FairLossLink, and provides Stubborn Delivery and No Creation guarantees
    type StubbornDelivery struct {
        // underlying fll used for lower-level networking abstractions
        fll *FairLossLink 
        sent []Sent 
        startTime time.Duration
        indicationChan chan struct{}
    }

    // instantiation of the link i.e 
    func (p *StubbornDelivery) start() {
        for {
            select {
                case <-time.After(startTimer):
                    // reset timer
                    for _, sends := range p.sent {
                        fll.request_Send(sends.m, sends.q) 
                        select {
                            // check for q's delivery of message, and trigger our own indication
                            case <-q.indication_Deliver(sends.m, p):
                                // this delivery is a little diff. as we send the deliverer and the msg to caller
                                p.indication_Deliver(sends.m, p)
                        }
                    }
                    
                default:
            }
        }
    }

    // if process p sends m, it is delivered an infinite number of times
    func (p *StubbornDelivery) request_Send(m msg, q link) {
        sent = append(sent, Sent{
            q: q,
            m: m,
        })
    }

    // Deliver indication, this is triggered by the underlying fll 
    func (p *StubbornDelivery) request_Delivery(m msg, q link) chan struct{} {
        p.indicationChan <- chan struct{}
    }
```
- *SLL1* - Each $p$ send sends $m$ via $p$'s $fll$ an infinite number of times, $p$'s $fll$ ensures $fll1$ suggesting that $m$ is delivered by $p$'s $fll$ an infinite number of times, and transitively $p$ delivers $m$ an infinite number of times
- *SLL2* - trivial given that $p$ uses $fll$ for all sends
 - *Performance of SLL* - Bad. Can be made better by removing $m$'s from $p.sent$, that way each message is only re-transmitted by $fll$ until it is $fll$ delivered
    - Up to $target$ process $q$ to deliver $m$ to $p$ 
- *Reliable Delivery* - If a correct process $p$ sends a message $m$ to a correct process $q$, then $q$ eventually delivers $m$
    - *No Duplication* - No message is delivered by a process more than once
    - *No Creation* - If some process $q$ delivers a message $m$ with sender $p$, then $m$ was prev. sent to $q$ by process $p$ (same as $fll3$ )
```go
type PerfectLink struct {
    sll *StubbornLink
    indicationChan chan struct{}
    deliveredMsgs map[msg]struct
}

// send along underlying sll, guarantees that m is delivered by q at least once
func (p *PerfectLink) request_Send(m msg, q link) {
    p.sll.request_Send(m, q) 
}

// p does not have to reference each link q that it has sent messages to for guaranteed delivery 
func (p *PerfectLink) start() {
    for {
        select {
            case (q, m), ok :=  <-p.sll.request_Deliver():
                request_Indication(q, m)
        }
    }
}   

// delivery of messages is triggered automatically by sll
func (p *PerfectLink) request_Indication(m msg, q link) {
    if _, ok deliveredMsgs[m]; !ok {
        <-indicationChan
    }
}

```
 - Think of *Deliver* as an *ACK* packet from the recipient of the message
### Link Abstractions from Crash-Recovery
*Logged Perfect Links* - *Perfect Links* does not carry over to *crash-recovery* (deliveredMsgs forgotten on crash-restarts)  must persist them to storage
     - Every Delivered message must be logged before the indication is sent (caller can't indicate w/o being able to recognize delivery from stable storage) 
     - Every Send request is logged before being sent to the abstraction layer
### Link Abstractions in Byzantine Process Abstractions
 - Trivially, a byzantine link may prevent any process from communicating with another (we assume that this is impossible for the abstraction) 
- *fair loss* - *fair loss* (transitively *stubborn delivery*) may be assumed wrt. Byzantine processes 
    - *No creation* and *No Duplication* may not be assumed, however, these require crypto-graphic primitives to be used for *Authenticated Links*
```go
type AuthPerfectP2PLinks struct {
    sll *StubbornLink
    deliveredMsgs []msg
    indicationChan chan struct{} 
}

// relies on underlying fll of sll property of fair loss
func (p *AuthPerfectP2PLinks) request_Send(m msg, q link)  { 
    // generate a MAC encrypt data w/ p'q pubk and q's privk
    a := auth(p, q, m)
    p.sll.request_Send([m, a], q) 
}

func (p *AuthPerfectP2Plinks) start()  {
    for {
        select {
            case [m,a], p, q, m := <- p.sll.request_Deliver():
                p.request_Deliver([m,a], p, q, m)
        }
    }
}

func (p *AuthPerfectP2Plinks) request_Deliver([m,a] msg, q link) {
    if _, ok := p.deliveredMsgs[m];  p.verifyAuth(m, a, q) && ok {
        p.deliveredMsgs = append(p.deliveredMsgs, m) 
        <-indicationChan
    } 
}

```
 - *Reliable Delivery* - guaranteed by *fair-loss* and *sll* re-transmission
- *No Duplication* - No duplicates verfies that the sender exists (i.e priv-key is known to node) 
- *Authenticity* - If correct process $p$ delivers $m$ with sender correct $p$,  $m$ was prev. sent by $p$ (i.e $p$ can't arbitrarily send messages on its own) 
## Timing Assumptions
### Asynchronous System
 - Makes no assumptions regarding timing of events
 - *Logical Clock* - timing events correspond to receipt of messages (i.e each *deliver* marks an instant of time)
    1. Each process $p$ maintains a counter $l_p$, $l_p$ is initially 0
    2. Whenever an event occurs at a process $p$, increment $p$ by 1
    3. When process $p$ sends a message, it adds a timestamp to the message $t_p$, where $t_p = l_p$ when the process is sending the message
    4. When a process $p$ receives $m$ with timestamp $t_m$, $l_p = max\{l_p, t_m\} + 1$
 - *happens-before* - relation defining the causality of events, let $e_1, e_2, e_3$ be events, then $e_1$ *happens-before* $e_2$ 
    1. $e_1, e_2$ correspond to events that occurred at $p$, and $e_1$ occurred before $e_2$
    2. $e_1$ corresponds to process $p$'s transmission of $m$ to $q$ and $e_2$ corresponds to the receipt of $m$ at $q$
    3. $e_1$ *happens-before* $e_3$ and $e_3$ *happens-before* $e_2$ (transitivity)
 - Notice in a *logical-clock* if $e_1$ *happens-before* $e_2$ then $l_p(e_1) < l_p(e_2)$, in otherwords, *happens-before* is a means of approximating time in an *asynchronous system* 
    - Converse is not true. Suppose $t(e_1) < t(e_2)$, where $t$ is the timestamp given by a logical clock, then $e_1$ and $e_2$ may have occurred at different processes $p,q$, and they do not correspond to a $link-layer$ event between $p,q$.
 - Impossible to achieve consensus, even if a single process fails
## Synchronous systems
 - Assumptions
    - *synchronous computation* - Every process has a bound on the computation necessary to achieve any step of consensus. I.e each process will ultimately reach a state-transition within the same bound. 
    - *synchronous communication* - There is a known upper-bound on the time for message transmissions (possibly less general than prev. assumption?) 
    - *synchronous clocks* - Every process is equipped with a local bound that is within some bound of a global clock
        - allow each message to be sent with a timestamp
## Partial Synchrony
 - Assume that system is synchronous after some $t$, where $t$ is unknown
## Failures
### Failure Detection
- Assuming synchronous / perfect links. A node can send / receive regular heart-beats, and tell a node is faulty if no response is received over some interval (timeout will be greater than max. communication time)
### Perfect Failure Detection
- Perfect failure detector: $\mathbb{P}$, for each process, outputs the set of processes that $\mathcal{P}$ detects to have crashed. Proceses $p$ detects that a process $q$ has crashed by emitting the event $\langle Crash, q\rangle $, once $q$ is detected it cannot be undetected.
     - *Strong Completeness* - A failure detector eventually detects every faulty process
     - * strong accuracy* - A failure detector never detects a non-crashed process (assumes the crash-stop process abstraction)
#### Exclude On Timeout
 - For all processes, start a timer, send messages to all processes, for each response label sender as live, 
    - On timer start again, processes not marked as live are deemed *detected*
    - This assumes *Perfect Links*
        - No message is delivered by $q$ to $p$, unless $p$ sent the message to $q$ previously
#### Leader Election
 - A set of *crash-stop* processes must co-ordinate to determine a node which has not crashed
    - This node will by default be assumed to co-ordinate the rest of the group's activities until the next round of elections
 - **Specification**
    - Election of leader is represented as an event $\langle le, Leader | p \rangle$, where process $p$ is the elected leader
         - Two properties are satisfied by this abstraction
         - *Eventual Detection* - Either there is no correct process. Or some process is eventually elected as the leader
         - *Accuracy* - If a process has crashed, then all previously elected leaders have crashed 
### Algorithm: Monarchical Leader Election
- Assumes a *Perfect Failure Detector* (crash-stop processes, perfectly synchronous network)
    - All *Faulty Nodes* (crashed) will eventually be detected
    - No non-faulty nodes are detected
- Let $\Pi$ denote the set of all nodes in the network, let $rank: \Pi \rightarrow \mathbb{N}$ (i.e each node is given a ranking prior to node starting) 
    - Init, (`leader: uint64`, `suspected: []uint64`)
    - On $\langle \mathcal{P}, Crash, p\rangle$, set $suspected := suspected \cup \{p\}$, 
    - On $leader \not= maxRank(\Pi \backslash suspected) $, set $leader := maxRank(\Pi \backslash suspected)$
- $Eventual Detection$ - As $\mathcal{P}$ is a perfect failure detector, there is some time where $suspected$ contains all faulty nodes, at which point a leader exists indefinitely, or there is no leader (all nodes are faulty) 
- $Accuracy$ - Suppose $p$ is elected, where for some $q \in \Pi \backslash suspected$, and $rank(q) > rank(p)$, then trigger 2 is detected, and $p$ will not be leader
### Algorithm: Eventually Perfect Failure Detection
 - Assumes a partially-synchronous system, assumes a crash-stop process abstraction
    - Can't set timeout as there is no bound on communication
- Components
``` go
type EventuallyPerfectFailureDetector interface {
    // suspect a process to have crashed
    func IndicationSuspect(p Process) 
    // restore a previously crashed process
    func IndicationRestore(p Process)
}
```
- Question: What if node crashes-restarts infinitely at every timeout? This node can be elected leader incorrectly? 
    - Answer - algo assumes crash-stop process abstraction
- Inuitition - For each process, there is no known bound on communication
    - Initially set timeouts for each node v. low
    - Send regular heartbeats to each one
        - If a node does not Deliver within timeout, mark *suspected*
    - If link delivers a message from a  *suspected*  node, *restore* node, and begin sending messages to the node
- Properties
    - *Strong completeness* - Eventually, every process that crashes is permanently suspected by every correct process
        - i.e as timeout increases, timeout will be set at $max_{correctProcesses}(communication_delay)$
    - *Eventual Strong Accuracy* - Eventually, no correct process is suspected by any correct process
    
**Algorithm: Increasing Timeout** 
- Implements eventually perfect failure detector
- Init (`alive := []uint64{}`, `suspected := []uint64{}`, `timeout := initTimeout`)
- StartTimer, on timeout
    - if $alive \cap suspected \not= \emptyset$ (we have delivered a message from a previously suspected process)
        - set $timer *= 2$ (increase timer, we have incorrectly suspected a correct process) 
    - if $p \in \Pi$ and $p \not \in alive \cup suspected$ (a node we haven't suspected yet, has not delivered a message within the timeout)
    - Send a message to any nodes that does not have an outbound heart-beat (if a node prev. delivered a heartheat send one again)
- On $\langle link, Deliver, q \rangle$
    - $alive := alive \cup \{q\}$
- As all nodes are crash-stop, faulty nodes will be expected to have an outbound heartbeat indefinitely,
    - At some point they will not be added to *alive*,
### Eventual Leader Election
 - Cannot perform perfect leader election with *EventuallyPerfectFailureDetector*
    - Only eventually guarantees a unique leader
- Can be implemented for crash-recovery and arbitrary fault processes
- Properties
    - *Eventual Accuracy* - There is some time after all processes trust some correct process
    - *Eventual Agreement* - There is some time after which all processes trust the same correct process

**Algorithm: Monarchical Eventual Leader Election**
- Similar to **Monarchical Leader Election**
    - Depends on Eventually perfect failure detector
- Algo
    - Init $suspected, leader$, where $rank: \Pi \rightarrow \mathbb{N}$
    - On $\langle EPFD, Suspect, q\rangle$, $suspect := suspect \cup \{q\}$
    - On $\rangle EPFC, Restore, q \rangle$, $suspect := suspect \backslash \{q\}$
    - Invariant, $leader := max_{rank(q)}(q \in \Pi \backslash suspected)$
- **Accuracy** - Follows from *Eventual Accuracy* of EPFD
- **Agreement** - Follows from shared rank fn, and *Eventuall Accuracy** (all nodes at some point detect all faulty processes)

**Algorithm: Elect Lower Epoch**
- Can be implemented with partial-synchrony, and crash-recover process abstraction
    - Does not assume existence of a failure detector
    - Assumes at least one correct process
        - *crash-recover correctness* - At least one process in each correct execution, either does not crash, or crashes and recovers
- Algorithm 
 - Init, set / store $epoch := 0$, $candidates := nil$, where `candidates := []struct{process_id, epoch_of_last_message_delivered}`
    - Trigger a recovery event
- On recovery, increment and store epoch, set $leader := max_{p \in \Pi}(rank(p))$, trigger $\langle ELP, Trust, p$, for all $p \in \Pi$
    - $\langle fll, Send| p, [Heartbeat, epoch]$
    - startTimer
- On $\langle fll, Deliver, q, [Heartbeat, epoch]\rangle$
    - if $candidates[q].epoch < message.epoch$, $candidates[q].epoch = message.epoch$
- On Timeout
    - set `newLeader := select(candidates)`, if `newLeader != leader`, set `leader := newLeader`,
        -  trigger $\langle \Omega, Trust, newLeader\langle$
        - update delay (set a longer delay than prev.)
    - for all $p \in \Pi$
        - trigger $\langle fll, Send | p,[Heartbeat, epoch]\rangle$, where $p$ is the executing process
    - reset candidates
    - start again
- Questions, what is select?
    - Chooses least epoch from received messages, ties-broken by process rank
- **Accuracy** - faulty process's epoch will eventually be greater that correct processes, and they will not be a candidate. Eventually, only finitely crashing / recovering processes will be candidates
## Byzantine Leader Election
 - Assumes an eventually synchronous system
 - nodes report mis-behaviour according to some application specific rule-set that must be completed after some timeout
    - Cryptographic proof can be submitted that the work was ultimately completed
- If the task isn't completed, the node is no longer the leader and a new one is selected
    - To adhere to the eventually synchronous system model, a timeout can be increased at each node for each new leader, to prevent false detections
- Properties
    - *Indication* $\langle bld, Trust| p\rangle$, Indicates that $p$ is new leader
    - *Request* $\langle bld, Complain, p \rangle$, Receives a complaint about process $p$
    - *Eventual Succession* - If more than $f$ correct processes that trust some process $p$ complain about $p$, then every correct process eventually trusts a different process than $p$ (assume that there are less than $< f$ faulty nodes).
    - *Putsch Resistance* - A correct process does not *trust* a new leader, unless at least one correct process has complained against the previous leader
    - *Eventual Agreement* - There is a time after which no two correct processes trust different processes

**Algorithm: Rotating Byzantine Leader Detection** 
- Assumes that $n > 3f$, where $N = |\Pi|$, and $f$ represents the number of faulty processes
- Module maintains increasing round number
    - Leader for round $leader_r := p \in Pi, rank(p) \equiv r (N)$
- Algorithm
    - On Init
        - Set $round := 0$
        - Set empty $complainList$
        - Set $complained := FALSE$
        - Trigger $\langle \Omega, Trust, leader(round)\rangle$, $leader: round \rightarrow |\Pi|$ (trust leader according to predicate above)
    - On $\langle bld, Complain| p\langle$ 
        - If $p == leader(round)$ (when we trigger a complaint for current leader) **do**
        - Set $complained := TRUE$
        - For $p \in \Pi$
            - $\langle apll, Send| p, [Compain, round]\rangle$, where $q$ is this node
    - On $\langle, apll, Deliver, p [Complain, r] \rangle$, and $r == round$, and $complainList[p] == nil$ **do**
        - Set $complainList[p] = struct{}$
        - if $len(complainList) > f$ **do**
            - Set $complained == TRUE$
            - for all $p \in \Pi$
                - $\langle apll, Send|p, [Complain, round]\rangle$
        - if $len(complainList) > 2f$ **do**
            - set $round++$
            - Set $complainList := nil$
            - $complained = False$
            - Elect new leader
- All messages sent are signed by sender
    - Message forgery is impossible
    - Can check for double messages per round
- What happens if $< 2f$ *Complaints* are needed to change leaders?
    - Suppose $f$ byzantine processes
    - all byz. processes complain abt. current leader
        - Greater than $f$ nodes are required to remove current leader, requires at least 1 correct processes 
- *Eventual Succession* - Suppose that there are $N > 3f$ nodes, and $> f$ of them have complained about their current leader. In which case, assuming a $pll$, where all sent messages are eventually delivered to the destination, each node in the network will eventually complain, and broadcast their responses back to the senders. Thus at some point, all nodes will eventually have $> 2f$ *complaints*, and will change their leader.
- *Putsch Resistance* - Suppose that there are $N > 3f$ nodes in the network, where $f$ is the number of faulty processes. Suppose that $p$ trusts a new leader, while no other correct process has complained about the current leader. As such, no node will have $> f$ complaints to themselves send a complaint about the leader, and $p$ will not have received $> 2f$ complaints needed to elect a new leader. 
- *Eventual Agreement* - Assuming a *crash-stop* and a *partially-synchronous* process abstraction, and the prev. 2 properties. For each node that transitions to a new round, all other nodes will eventually follow. Furthermore, Assuming $N -f > 2f$ correct processes, no node will transition, unless another node has complained about their current leader. Thus, there will reach a time at which a correct-leader is elected, and the delay between complaints, will be greater than the correct-process's max communication delay.
## Distributed System Models
- *Components*
    - *Link-Abstractions* - Perfect links, stubborn links, authenticated perfect links
    - *Process-Abstractions* - crash-stop, crash-recover, byzantine
- *Models* 
    - *Fail-stop*
        - crash-stop
        - pll
        - Perfect leader detector (assumes synchronous network conditions)
    - *Fail-noisy
        - Same as *fail-stop* but with an eventual failure detector / leader elector
    - *Fail-silent* 
        - Same as prev. no failure detection / leader-election
    - *Fail Recovery*
        - Same as prev.
        - crash-recover process abstraction
    - *Fail-Arbitrary*
         - authenticated perfect links
         - Eventual Leader Detector (partial synchrony)
         - Byzantine processes
    - *Randomized*
        - state-transitions of processes are not functions, i.e there are a set of possible output states, and their values are random variables
- *Quorum* 
    - A majority of processes i.e $\lfloor \frac{N + 1}{2}\rfloor$
    - Any two *quorums* overlap in at least one process
    - *Byzantine Quorum*
        - Suppose there are $N$ total processes, and $f$ of those are byzantine
        - a regular quorum $\frac{N}{2}$, may not be enough as $\frac{N}{2} - f$, may be achieved without a quorum of the $N - f$ correct processes $\frac{N-f}{2} > \frac{N}{2} - f$, 
        - To achive *byzantine quorum* at least $\frac{N + f + 1}{2}$ processes are needed, that way $\frac{N + f+ 1}{2} - \frac{2f}{2} > \frac{N-f}{2}$, and any
          intersecting *byzantine* quorum, has at least 1 correct processes in their intersection
- In any *Byzantine System* a quorum must be able to be achieved
    - Thus the number of correct processes, must be able to achieve a *byzantine-quorum*, in otherwords $N -f > \frac{N + f}{2}$, or $N > 3f$
    - Byzantine quorum must be able to be achieved without the votes of any byzantine nodes (system trivially fails otherwise)
- *performance*
    - #of messages
    - #of communication steps
    - size of messages * communication steps (in bytes)
    - Performance generally quantified as follows $O(g(N))$, where $N$ is the number of processes
## Questions
- Explain under which assumptions the *fail-recovery* and *fail-silent* models are similar
    - *fail-silent* - crash-stop, pll, no failure-detection
    - *fail-recovery* - crash-recover process abstraction, eventual failure-detection
    - Similarity
        - Heartbeat messages may be ignored / forgotton by processes that crash
            - *Fail-Recovery* - Assumes that only a finite number of messages will be ignored (otherwise, each process is faulty)
            - *crash-recovery* - Assumes that each process (on crashes) will store / retrieve their epoch numbers
                - If they do not do this, algorithm fails
- Retain message order with *pll*?
    - Attach sequence number to each message sent by a process
        -  process interal seq. num starts at 1
            - Incremented for each message
        - Each process stores, `last_msg` the last sequence number of a processed message
            - On receipt of $\langle pll, Deliver, [seq_num, message]\rangle$, set `last_msg = seq_num` iff `seq_num = last_msg + 1`, 
            - otherwise, store received messasges in `stored_msgs`
            -  check `stored_msgs` (ordered queue of messages received, ordered by `seq_num`), if `seq_num[0] == last_msg + 1`, process and remove, until `seq_num[0] > last_msg + 1`
        - Properties
            - If $p$ sends $q$ first $m_1$ and then $m_2$, $q$ delivers $m_1$ before $m_2$
- Implementation of *perfect failure detector* possible under these conditions?
    - Processes may commit an unbounded number of omission faults
        - No. Each message sent to $q$ from $p$ may be omitted by $q$, $q$ would detect $p$, violating *accuracy*
    - Processes may commit a bounded but unknown number of omission faults
        - Let $d$ represent the bound on the number of omission faults. Assuming a synchronous system model
        - Then $p$ can send $q$ d messages (each message is sent and a timer is started that is equal to the communication delay)
            - If after $d$ messages, $q$ does not respond, $p$ will *detect* $q$
    - Processes may commit a limited but known number of omission faults, and then crash
        - Same as above, $q$ after crash will be detected
    - Properties
        - *Strong Completeness* - All faulty processes are detected
        - *Accuracy* - The fd does not detected any non-faulty processes
- In a *fail-stop* model, is there a time period after which, if any process crashes, all correct processes suspect this process to have crashed
    - By the synchronous timing assumption, each $p \in \Pi$, sends messages to each processes at $t_p \in (t - \delta, t + \delta)$, 
    - There is also a bound on communication, call this `MAX_COM`
    - as such, at `t = MAX_COM + 2\delta`, each process will have reached their timeout, and will not have received a message from $q$, detecting that $q$ has crashed
        - This assumes synchronous communication
    - In an *Eventually-Perfect* failure detector, this is not possible, as there is not maximal communication delay for all processes
- Safety v. Liveness
    - Safety (bad things don't happen)
        - Proofs involve an *invariance argument*
    - Liveness (good things happen eventually)
        - Proofs involve a *well-foundedness* argument
    - Denote a program $\pi$, where $\mathcal{A}_{\pi}$ denotes the set of *atomic actions* (state-transitions executed atomically), $Init_{\pi}$ a predicate that the initial state satisfies
        - An execution of $\pi$, denoted $\sigma = s_0s_1 \cdots $, where $s_0 \rightarrow s_1$, is the application of some $a \in \mathcal{A}_{\pi}$ on $s_{i-1}$
    - Terminating execution
        - There exists $N \in \mathbb{N}$, where for each $n \in \mathbb{N}$, $s_n \in \sigma$, $s_n = s_N$ (the states reach some equilibrium after a finite number of transitions) 
    - *property*
        - For any history, $\sigma \in P$, suggests that $\sigma$ has the property $P$, this can be expressed as follows $\sigma |= P$
    -![Alt text](Screen%20Shot%202022-12-24%20at%209.41.46%20PM.png)
    ## Buchi Automaton
     - Above is a buchi automaton
        - Accepts a sequence of program states $\sigma$, (i.e - represents a property)
     - Accepts executions that are in an accepting state infinitely often
     - Arcs between states -> *transition predicates*
     - automaton is reduced if from every state there is a path to an accepting state
        - Above is an example of a *reduced* buchi automaton
    - *Transition Predicate*
        - $T_{i,j} \in \{True, False\}, T_{i,j} \iff |\{s \in S : q_j \in \delta(q_i,s)\}|\not= 0$, a transition predicate $T_{i,j}$ is true iff, there exists some symbol (state) that causes a state-transition between $q_i$ to $q_j$
    - In otherwords, a *safety* property is a property such that, after the property is violated, there is no set of executions states that will 'un-violate' the property
    - *Liveness* - It is impossible to specify a time $t$ at which the property is violated
![Alt text](Screen%20Shot%202022-12-24%20at%2010.06.08%20PM.png)
1. Liveness, there is no time $t$ or state of execution, at which the property can be determined to be violated
2. Safety, if a process is detected before it crashes, this property is violated
3. Safety, the set of correct process is known before-hand, so we may determine that this property is violated at some execution
4. Safety
5. Safety
6. Liveness
- Let $\mathcal{D}$ be an *eventually-perfect* failure detector, suppose $\mathcal{D}$ is not eventually-perfect, can $\mathcal{D}$ violate a safety property of $M$
    - No, as $\mathcal{D}$ only eventually satisfies its properties, at any point of execution, it can be the case that the property is fulfilled
- Let $\mathcal{D}$ be a failure detector, specify an abstraction $M$ where a liveness property of $M$ is violated if $\mathcal{D}$ violates its properties
    - Eventual monarchical leader election, relies on eventually perfect failure detector. If $\mathcal{D}$ violates it's accuracy property, and $p$ does not detect $q$, but $rank(q) = maxRank(\Pi)$, the *accuracy property is violated*
## Atomic Transactions
- **Transaction** - sequence of accesses to data-objects, that should execute "as if" it ran with no interruption from other transactions. It completes in two states
    - **Commit** - All alterations will be present for subsequent accesses to same data elements
    - **Abort** - All accesses (mutations) executed during the tx, are reverted to the state they were in before tx
- **Serializability** 
    - Any set of txs should be executed as if they were executed sequentially
    - All accesses should be executed only on state from prev. committed txs
- Extensions required to initial def. of **Transaction** to be useful, specifically
    - Along with data-accesses, txs must be composed of **sub-transactions**
        - tx forms a tree (root is parent tx, non-leaf nodes are sub-txs, and leaves are data-accesses)
        - sub-txs can abort
        - sibling sub-txs are executed serializably, executed as if only state of non-aborted sub-txs was committed
### I/O Automaton Model
 - Similar to finite-state automaton,
    - Can have infinite state set
 - Actions take on either *input*, *output*, *internal*
    - **input** - Events detectable by the environment that trigger state-transitions within the automaton (executing process)
    - **output** - Events detectable by the environment that the automaton triggers, that act as *inputs* to other automatons
    - **internal** - Events not detectable by the env. 
- Automaton models multiple components? Or an env. consists of multiple automatons?
    - Introduce composition operator on a set of automatons, combines their execution into a single automaton
- Non-deterministic
    - Only relevant events in the system are non-internal
    - **behaviors** - subsequences of executions (sequences of actions) consisting of non-internal actions
- Used for writing specifications of concurrent systems
    - Specify desired behaviors as i/o automatons, and proofs of safety involve proving that across all executions desired behaviors are eventually met (liveness) or are never deviated from (safety)
### Action Signatures
 - **Event** - ocurrance of an act
 - An **Action Signature**, $S$, is an ordered triple of pairwise disjoint sets of actions, define $in(S), out(S), int(S)$, to represent the sets of actions within $S$
    - Denote the external actions $ext(S) = out(S) \cup in(S)$, 
    - locally controlled actions $acts(S) = int(S) \cup out(S)$
### Input/Output Automaton
 - An I/O automaton $A$ is defined as follows, $A = (sig(A), states(A), start(A), steps(A))$
    - $sig(A)$ is the set of $A$'s action signatures, 
    - $states(A)$ is the set of all states, $|states(A)|$ is not necessarily finite
    - $start(A) \subseteq states(A)$ (possibly more than 1 start state -- non-deterministic)
    - $steps(A) \subseteq states(A) \times acts(sig(A)) \times states(A)$ a transition relation
        - Property - $\forall s' \in states(A), \forall \pi \in in(sig(A)), \exists s \in states(A) \ni (s', \pi, s) \in steps(A)$
        - i.e - at every state in the automaton and for each possible **input** action, there is a resulting state in $states(A)$
    - $steps(A)$ can also be interpreted as a transition function $\delta: states(A) \times acts(A) \rightarrow states(A)$
- **execution fragment** - $s_0\pi_0s_1\pi_1 \cdots s_n\pi_n$ denotes an execution of the automaton (possibly infinite), where $(s_i, \pi_i, s_{i+1}) \in steps(A)$
- **composition**
    - *strongly-compatible* action signatures
        - Let $S_i$ be a set of action signatures, they are strongly-compatible if, for all $i, j$
            1.  $out(S_i) \cap out(S_j) = \emptyset$
            2. $int(S_i) \cap acts(S_j) = \emptyset$
            3. no action is in $acts(S_i)$ for infinitely many $i$
    - The composition of an action signature $S = \Pi_i S_i$ is defined as follows 
        - $in(S) = \bigcup_i in(S_i) - \bigcup_i out(S_i)$
        - $out(S) = \bigcup_i out(S_i)$
        - $int(S) = \bigcup_i int(S_i)$
    - The composition of I/o Automata $A = \Pi_i A_i$
        - $sig(A) = \Pi_{i}sig(A_i)$ 
        - $states(A) = \Pi_i states(A_i)$
        - $start(A) = \Pi_i start(A_i)$
        - $steps(A)$ is the set of all tuples $(s', \pi, s)$ such that for $i \in I$, if $\pi \in acts(A_i), (s_i, \pi, s'_i) \in steps(A_i)$, otherwise $s_i = s'_i$ 
            - Fix some state $s \in states(A)$, and $\pi \in in(sig(A))$, denote $J$, where for each $j \in J, \pi \in in(sig(A_j))$ (first property of action signature composition), then there exists $s' = (s'_i)_{i \in I} \in states(A)$, defined as follows for $i \in J, (s_j, \pi, s'_i) \in steps(A_j)$, otherwise $s'_j = s_j$, and  $(s, \pi, s') \in steps(A)$. Thus $step(A)$ is a valid transition relation.
### Correspondences Between Automata
 - Let $A, B$ be two automata, then $A$ implements $B$ if $finbehs(A) = finbehs(B)$ A's set of all possible finite sequences of external actions is a subset of $B$'s
    - $finbehs$ represents the set of all finite behaviors (set of external actions from all finite exections) of an automaton 
    - Consequence: $A$ can replace $B$ in a composition, and the resulting composition implements the original one 
 - Proving implementation
    - Let $A, B$ be two automata with the same external action signature, $ext(A) = ext(B)$, if a map $f: states(A) \rightarrow 2^{states(B)}$ exists where
        - for each $s_0 \in start(A)$, $\exists t_0 \in start(B) \in f(s_0)$
        - Let $s'$ be a reachable state of $A$ (there is a finite execution from a start state that ends in state $s'$), and $t' \in f(s')$ is a reachable state of $B$, then
        if $(s', \pi, s) \in step(A)$ then $(t', \gamma, t) \in step(B)$ where
            - $\gamma | ext(B) = \pi$
            - $t \in f(s)$

        then $A$ is an implementation of $B$. 
        - What does this mean intuitively? 
            - For each state $s$ in $A$ (non-reachable states are essentially irrelevant) and state-transition $\pi$ from $s$, there is an analogous state transition in $B$
            - Question: What does this map look like?
        - Proof
            - Let $\beta \in finbehs(A)$, let $\alpha = s_0\pi_0 \cdots$, where $beh(\alpha) = \beta$, then $\alpha' = f(s_0)\pi \cdots$ is an execution of $B$, where $\beta = beh(\alpha')$, and $\beta \in finbehs(B)$
### Serial Systems and Correctness
### Reliable Broadcast
 - Client-Server - Each client only sends a single request to a single server
 - Broadcast Communication - All nodes send each message to several nodes
 - broadcast guarantees
    - *best-effort* - Delivery among all correct processes, if the sender does not fail
    - *reliable* 
        - *all-or-nothing* - don't send unless all processes will deliver
        - *totally-ordered* - sending / processing follows a total order
        - *terminating* -
### Best Effort Broadcast
- Assumes sender does not fail
- **Properties**
    - *Validity* - If a correct process broadcasts $m$, then every correct process eventually delivers $m$ (liveness)
    - *No Duplication* - No message is delivered more than once
    - *No Creation* - If a process delivers $m$ with sender $q$, then $q$ prev. sent the message to the process
- **Algorithm**
    - Obv.
### Regular Reliable Broadcast
- Assume Fail-Stop / Fail-noisy process abstraction
- Adds agreement to *best-effort* broadcast
    - **Agreement** - If $m$ is delivered by a correct process, then $m$ is eventually delivered by all correct processes 
- Algorithm
    - Init
        - Initialize $correct: \Pi$, `received_messages: map[process_id]message`
        - (side-note) - Delivery of message is triggered in destination process
    - On $\langle beb, Deliver|p, [DATA, s, m]\rangle$
        - Intuitively, this means that process $p$ sent us a broadcast, that $p$ had received from $s$
        - if !$m \in received\_messages[s]$ (process has not seen this message yet)
            -  $\langle rb, Deliver| s, m\rangle$ (deliver the broadcast from $s$)
            - set $received\_messages[s] \cup \{m\}$
            - if $s \not\in correct$
                - trigger $\langle beb, Broadcast| [DATA, s, m]\rangle$
    - on $\langle \mathcal{P}, Crash, s\rangle$
        - set $correct = correct \backslash \{s\}$
        - for $m \in received\_messages[s]$
            -  $\langle rb, Broadcast, [DATA, s, m]\rangle$ 
    - on $\langle rb, Broadcast| m\rangle$
        - trigger $\langle beb, Broadcast| [DATA, s, m] \rangle$
- *validity* - follows from $beb$
- *No Creation* - follows from $beb$
- *No Duplication* - Follows from use of $received\_messages$
- *Agreement* - Follows from validity?
    - Don't see why the above is necessary? 
- *Performance* - Worst case is $O(N)$ communication steps, and $O(N^2)$ messages passed
### Eager Reliable Broadcast
- Same as above
    - Re-broadcast each received (delivered) message on receipt
- Have to assume that the process crashed (no way to detect otherwise)
### Uniform Reliable Broadcast
- Set of delivered messages by faulty processes is a subset of Those delivered by correct processes
    - Possible that *best-effort* broadcast fails? (under the assumption of a pll link abstraction) -> requires underlying link to fail
### Algorithm: All-Ack Uniform Reliable Broadcast
- Assumes fail-stop process abstraction
- Depends on
    - *PerfectFailureDetector* $\mathcal{P}$
    - *BestEffortBroadcast* $beb$
- *Properties*
    - Same as reliable broadcast
    - *Uniform Agreement* - If message $m$ is delivered by any process (correct or faulty), $m$ is eventually delivered by all other nodes
- *Algorithm*
    - Upon $\langle Init \rangle$
        - Set $correct = \Pi$
        - Set $delivered = \emptyset$
        - Set $ack[m]  = \emptyset$
        - Set $pending = \emptyset$
    - Upon $\langle beb, Deliver, p| [DATA, s, m]\rangle$ (we have received a message from $s$ abt a message originally sent by $p$)
        - Set $ack[m] = ack[m] \cup \{p\}$ 
        - if $(s, m) \not \in pending$
            - Set $pending = pending \cup \{(s,m)\}$ 
            - trigger $\langle beb, Broadcast| self, [Data, s, m]$
    - Upon $\langle \mathcal{P}, Crash, p\rangle$
        - Set $correct = correct \backslash \{p\}$
    - Upon $\langle urb, Broadcast, m$
        - Set $pending = pending \cup \{(self, m)\}$ 
        - broadcast message w/ $beb$
    - Upon $(s,m) \in pending \wedge (correct \subseteq ack[m])$ 
        - Set $pending = pending \backslash \{(s,m)\}
        - Trigger $\langle urb, Deliver, m$
- Properties
    - *uniform agreement* - Suppose $p$ has delivered $m$, then $ack[m] \supset correct$. There are two cases, if $p$ is correct, then by *validity* of $beb$, as $p$ $beb$ delivered the ACK, all other correct processes will eventually deliver the ACKs that $p$ has received (fail-stop process abstraction, means that $correct_t \subset correct_{t'}, t < t'$), and they will also $urb$ deliver $m$. 
- *Performance*
    - *Worst-case* no processes crash, in which case $p$ broadcasts $m$ to all processes, and all other processes must ACK the message, this involves $O(N^2)$ message complexity, and $O(N)$ rounds (each process must send a message)
    - *best-case* - all processes fail except sender, $O(N)$ messages required, $O(1)$ communication step
### Algorithm: Majority-Ack Uniform Reliable Broadcast
- Assumes fail-silent process abstraction
    - Assumes a majority of correct processes, $N - f > f$, 
    - Processes don't wait for all correct processes to ACK, only a majority (i.e)
### Stubborn Best Effort Broadcast
- Analogous to p2p links / stubborn links
- Used for crash-recover process abstractions
- *Properties*
    - *Best-effort validity* - If a process that never crashes broadcasts $m$, then every correct process delivers $m$ an infinite nukmber of times
    - Notice, *No-Duplication* is not satisfied
## Logged Broadcast
 - broadcast specifications for the *fail-recovery* model
## Aside: Patricia-Merkle Trees
- Fully deterministic
    - trie w/ same $(key, value)$ bindings -> guaranteed to have the same root hash
### Merkle Tree 
- Tree, where every Node contains the hash of its children
    - changing parent must mean changing children
    - Leaf nodes contain hash-value of elements
#### Proofs of Inclusion
- Given a leaf element $x$, a prover given elements in *co-path*, can iteratively hash the necessary values, to determine the root node of the tree
    - Siblings of each node parent path (of requested element) in tree
- Constructing root-hash from children 
### Merkle Trees As Signatures
- Faster
# Cryptography
## Secret Key Encryption
### Encryption
- **Shannon Cipher**
    - Let $\mathcal{K}, \mathcal{M}, \mathcal{C}$ represent the key, message, and cipher spaces, 
    - A shannon cipher $\Epsilon = (E,D), E: \mathcal{M} \times \mathcal{K} \rightarrow \mathcal{C}, D: \mathcal{C} \times \mathcal{K} \rightarrow \mathcal{M}$, where on message $m$ and key $k$, $D(E(k.m)) = m$
    - The above is the classification of the *correctness property* of a Shannon Cipher
    - **Example** -
        - *One-Time Pad* 
            - $\mathcal{K} := \mathcal{C} := \mathcal{M}$, and $E(k, m) := k \oplus m$ (decryption is defined analogously)
            - correctness $D(E(k,m), k) = D(k \oplus m, k) = k \oplus m \oplus k = m$
        - *variable length one time pad*
            - same as before w/ variable length keys / messages (keys truncated or padded to size of message)
        - *Substitution cipher*
            - $\mathcal{M} := \mathcal{C} := \Sigma$, $\mathcal{K} := \{f \in \Sigma \times \Sigma, \forall x,y \in \Sigma, f(x) != f(y)\}$, i.e keys are permutations of $\Sigma$, and encryption / decryption are applications of $f$ (resp. $f^{-1}$) to the characters of the message 
    - Notice, given the encrypted cipher, most messages are still translations of the original message (not v. secure)
- **Perfect Security**
    - Shannon Ciphers do not guarantee that given $c \in \mathcal{C}$ it is `hard` to determine $m$, in fact if the adversary is aware of $\Epsilon$ they are aware of the message, key, and cipher space, as well as their relations.
    - **Perfect Security For Shannon Ciphers** is defined as follows
        - Given $m_0, m_1 \in \mathcal{M}$, and $\kappa \in \mathcal{K}$, where $\kappa$ is a uniformly random variable over $\mathcal{K}$, $\forall c \in \mathcal{C}, Pr(E(\kappa, m_0) = c) = Pr(E(\kappa, m_1) = c)$
        - Why is this relevant?
        - **Alternate Formulations**
# Game Theory
 - *Prisoner's Dilemma* - Two prisoners $p_1, p_2$ are faced with two decisions $d_1, d_2$, and a common valuation function $\pi$, where $\pi(d_1, d_1) = 4,4$, $ \pi(d_1, d_2) = 1,5$, and $\pi(d_2, d_2) = 2, 2$
    - In this case, the authorities have the ability to convince either prisoner to screw the other
    - Prisoners go w/ route that is more advantageous to themselves / more likely to be done by the other player as well.
- *Tragedy of the Commons* - 
### CROSS CHAIN DEX AGGREGATOR
- Scheduler (encoding arbitrary logic into scheduler)
## EVM
- 
## Cryptography
 - 
### Scheduler
#### Proposed Solution
#### Suave
 - Users should be empowered with pre-confirmation privacy and entitled to any MEV they create. Txs should be private and available to all builders
 - All builders must have the same information (ACROSS ALL CHAINS ) when building a block. All participating chains must concede the builder role to SUAVE
>> **What of the problem of cross-chain asynchrony?** (not header)
>>  - here, the executors will only be able to partially execute preferences that are designated across multiple chains ($proposal_1 \rightarrow proposal_2 \cdots $)
 - **Advantages**
    - Block-builders operating on single domain always disadvantaged in comparison to those operating on multiple
    - Aggregating preferences / views / information advantage in a single auction
    - Computation of sensitive data in a single enclave for all chains
        - Ultimately this problem has to be solved, but theoretically SUAVE will solve it 
- **Universal Preference Environment** - Unified chain + mempool for preference expression + settlement
    - Single place where searchers send their `preferences` (bundles generalized to an arbitrary chain)
    - Single place where these `preferences` are bid upon / chosen to be included in blocks
- **Optimal Execution Market** - Executors listen to mempool for preferences and bid to get the largest / most profitable set of preferences executed together
- If SUAVE is able to permit permissionless and secure execution of state-transitions across all chains, why wouldn't SUAVE become the chain of all chains?
    - Subsequent deployments of chains
- **Decentralized Block Building**: Not really sure what this part is?
    - Seems like the executor role? Not really sure why this is not the executor role
- *preference* - Signed message type that is a payment to the executor that satisfies the conditions met in the preference
    - **Preference Expression Can Be Arbitrary** - Preferences are just a language used to express conditions across an arbitrary number of block-chains
    - It can be possible that executors specify a set of preference languages accepted?
- 
- IDEA 
    - blockchain that sources any binary to be executed in a trusted environment
        - Potentially arbitrary replication of any service / data? (BFT Zookeeper)
        - How to make the idea of SUAVE generalizable enough for an arbitrary application?
## Data Intensive Apps Book
### Foundations
 - Removing duplication of data w/ same meaning in DB - normalization
    - Two records store data w/ the same meaning ($trait - philanthropy$), as trait changes, any appearance of philanthropy will change
        - Instead store $trait - ID, ID -> philanthropy$, change value at ID once !!
 - Normalization - Rquires a *many-to-one* relationship
- Document databases - joins are weak
    - 
- JSON data model has better localilty 
    - multi-table requires multiple queries + join
    - JSON - All relevant data is in one place (just query JSON obj.)
- What about for larger highly-coupled data-sets
    - I.e several JSON objects make use of ID field defined separately?
        - How to decouple these objects?    
            - RELATIONAL MODEL - I assume this is generally much larger scaled than document-based
- *one-to-many* - relation is analogous to a tree, where edges are relations
    - JSON naturally encapsulates as a single object + sub-objects?
- **normalization requires many-to-one** relationships  
    - I.e multiple tables must have rows whose values are enumerated in keys
        - The keys referenced are contained in a single table
- Normalization / many-to-one - does not fit well in document databases
    - Joins are weak, in document based model you just grab the object it self
        - Data that is referential of other data is not useful in document-based data
- General practice
    - Identify entities of objects used (data-structures in code)
    - Identify relationships between these objects
    - if data is self referential (one-to-many) -> use document-based
    - Otherwise use relational (generally easier to work-with )
- **network-model**
    - document -> each object has a single parent
    - network -> each object has n-parejts 
        - Supports many-to-many relationships thru access-paths (follow references from parent to leaf) -> unbounded size of queries
            - Can't specify direct pointers to non-child entities
- **relational**
    - Similar to network databases -> path to entities are automatically determined by table-relationships (query optimizer)
        - Much more user friendly for highly referential data
- **document-based**
    - Do not require a schema for entries   
        - Unstructured tree-like data that can be loaded all at once (schema-on-read, schema is interpreted after reads)
        - **relational is schema on write**
- 
- 
## CLRS Book
## OSes
## Databases Book
## Transactions Book
## CELESTIA?
- 
## SGX Research?
### OS Book (code review)
### Irvine x86 Book 
### SGX API Gramine (code review?
### Paxos
### Lib P2P research
### Heterogeneous Paxos
- Environment of `blockchains` is `heterogeneuous`
    - What does this mean?
    - Consensus involves
        - **Learners** - Processes that all receive the same set of messages from **acceptors**, and come to the same state from these messages (from the same start-state)
        - **acceptors** - Processes that emit events to all **learners** in the network
            - **acceptors** and **learners** can fail, must make assumption that there is quorum of **learners** in network
            - Failure restricted to processes that make externally visible actions (sending messages to learners), thus only acceptors can fail
- Homogeneity in Consensus
    - **Acceptor Homogeneity** - Nodes that make external actions (are susceptible to failure) are limited to $f$. These can be substituted and the outcome of consensus is the same
        - What if diff. acceptors have diff. failures / roles in consensus
- What is a learner? What is an **acceptor**
    -
## Tusk / Narwhal
## Anoma
## Gasper + L2 solns.
## Decentralized Identity
- Lack of identity prevents **under-collateralized lending**, **apartment lease**, etc.
- Accounts hold non-transferrable **soulbound tokens**, represent commitments, credentials, affiliations etc.
  - **Quadratic funding?**
  - Decentralized key management?
  - Under-collateralized lending / credit-scores
    - Perhaps tracking financial worthiness of someone on chain (by tracking an account and its growth over-time), incentivising users to invest in groups led by certain individuals
- Can accrue SBTs through certain behaviors, and stake reputation on chain 
### Circom / ZK
# ZK
# Differential Privacy
## Databases
## Data-mining
# Git Notes
- `branch`
    - Collection of commits, each `HEAD` retains references to the index / objects associated with the state of the latest commit on that branch
- `tags`
    - Maintains immutable references to object state / index of a particular history of the project (immutable snapshot of head of some branch) 
    - `git tag -l`
    - `git switch -c <new> <tag_name> ` - Checkout state of some tag, and create a new branch head off of this state
- All objects in history are *content-addressable*
    - Commits are identified by the `sha-1` hash of their contents
- `git branch <branch>`, Create a new branch named branch, with the HEAD of the new branch as the head of the current branch
    - `git branch -d` delete a branch
- `git switch` - Preferred alternative to `git checkout` (checkout references commits whereas switch references branch HEADs)
## Object Database
- Stores **object**, in a content-adddressed format (objects are indexed by the sha-1 hash of their contents), These are the possible variants of an object
    - `blob` - binary large object, basically represents the individual changes to files 
    - `tree` - multiple blobs, stored in a tree structure (the directory structure that the blobs reference)
    - `commit` - A `tree` of all the changes from the last commit, a reference to the previous commit
    - 
## Market-Protocol Fit
- Crypto-networks not startups
  - Don't have ability to iterate and reach product-market fit
- Crypto-startups rely on _headless branding_ and incentive structures to evolve
- **product market fit** - Assembling small-team (capable of iterating) to find + fill market demand
- **market-protocol fit** - Distribute token -> create narrative + product innovation to activate token holders?
  - Attract users with token allocation (give them incentive to advertise product) -> token-holders push narrative aligned with broad product vision
  - 
## Anoma Reading
- counterparty discovery, solving, and settlement?
  - What is counterparty discovery (transaction ingress)?
    - Somehow a solution to POF
  - solving? Matching intents into txs?
- Intent centricity + homogeneous architecture / heterogeneous security
- Programmable v scripted settlement?
  - Bitcoin - bitcoin script (not turing complete) (scriptable)
  - Ethereum - turing complete (programmable)
- Deciding with whom + what to settle
  - Forces centralized authority to organize settlement. Builders in PBS?
    - Somehow decentralise the building env.
- **Anoma** - intent-centricity, decentralised counter-party discovery, outsourcing of searching (block-building / execution) to solvers.
## PBS Reading
 - Before PBS (proposer introspect mempool and have full control of what goes into proposal)
 - **PBS** [article](https://notes.ethereum.org/@vbuterin/pbs_censorship_resistance)
   - Builders build _exec block bodies_ (txs), and encrypt / send commitment to proposer
     - Pre-confirmation privacy (prevent mev-stealing)
   - Proposer signs commitment
 - Status quo for censorship resistance in eth pre-merge
   - Extremely hard to censor
   - Have to raise base-fee above $max_payment / gas_cost$ and hold there
     - To do this attacker will have to spam blocks / make them full above target to raise base-fee significantly
 - **builder censorship**
   - Builders win by 
     - Attracting unsophisticated order flow (order-flow generating MEV)
     - Sophisticated MEV discovery
   - Let $M$ be what non-censoring builders are for the block w/o censorable tx
     - $P = X - 150k * base_fee$, $P - A$
     - Then builder can bid $M + P$ (for including censorable tx)
     - Censoring builder earns $A$ of MEV for censoring, then they bid $M + A$ (to make a profit), pay $A - P$ than other builders, but lose $P$ profits
 - Much easier in this case, cost is scaled w/ block finality
 - Potentially can scale number of blocks proposed per slot (replicate larger space) to make it harder to censor
 - ## Multiple Pre-confirmation PBS Auctions in Paralell
   - Builders can't determine final ordering when building blocks?
 - Censorship arguments assuming that adversary has no control over the client (or at least 2f +1 of them)
 - Builder of Primary block, always advantaged? Potentially, can censor inclusion of tx (as long as it is aware of auxiliary builders) (also has info. adv.) and force auxiliary builders to pay
   - tx-execution costs
 - 

## Censorship Resistance in On-chain Auctions
- 
### Proposer Enforced Commitments
- PBS Pros
  - Protecting proposer 
  - Ensuring liveness
  - How are the above satisfied? Seems like they are strictly negative guarantees
### Intent Centricity
 - **Intent** - part of a tx that requires another part for valid state-transition
 - Intent either settled by defined, or not at all
   - Anomia specifies intents _declaratively_?
   - _imperative_ intents - 
 - _validity predicates_ - used by application developers to specify invariant
   - _safer by construction_
### Homogeneous Architecture, Heterogeneous Security
- Protocols Analysed along 2 dimensions
 - **Architecture**
   - Abstractions + relations constituting system
     - **Homogeneous Architecture** - all applications adhere to the same architecture (EVM, CosmWasm)
     - **Heterogeneous Architecture** - Celestia, all applications adhere to arbitrary architectures, with some commonality between them (shared DA, XCMP, etc.)
 - **Security**
    - Whom to interact + trust
      - **Homogeneous Security** - same security parameters for all applications
      - **Heterogeneous Security** - Different security parameters for all applications
- Anoma = homogeneous arch. + heterogeneous security?
  - homogeneous arch. => easy interactions between applications
  - _benevolent monopoly_ - git / TCP
## Architecture
- Nodes take on multiple roles
  - Node can specifically gossip intents
  - Nodes can search for solvers
- Roles have diff. network assumptions
    ### Intents 
    - Define partial state-transitions
    - Fully complete state-transitions are subsets of state-transitions
      - i.e intents that have no need, additional data provided by solvers
    - Intents are partial, have specific set of conditions that must be met / data that must be accessed (declarative)
      - Solvers attempt to match these conditions with other intents or with access to data, what is need for zk-proof?
 - Applications defined declaratively?
   - Can add new conditions to the existing set
- ![Alt text](Screen%20Shot%202023-02-06%20at%2011.19.00%20AM.png)
- Intents gossipped at _intent gossip_ layer
  - Multiple intents matched into tx
- Intent (intent gossipped) -> discovery (intent given to solver) -> (tx) (intent matched with others) -> consensus (tx included in proposal) -> execution -> finalization (state-root included in next block header)
## Solver
- Observe all intents and apply _solving algorithms_ to determine optimal matching of intents
## Transactions
# Ferveo
## IBC Notes
- Handle authentication + transport of data between 2 blockchains
- **IBC TAO** - Provides necessary logic for Transport,     authentication, ordering logic of packets
  - composed of _core_, _client_, _relayer_
- **IBC/app** - 
  - Defines handlers for ICS modules
- **relayers** - specification in ICS-18
  - off-chain process
  - Responsible for reading state of source, constructing and sending datagram to destination to be finalized
  - Relayer sends packets to channels
  - Each side of relayer (chains) have light-clients to validate proofs included in packet
- **client** - responsible for tracking consensus state, proof specs,  for counterparty
  - Client can be associated with any number of connections
- **connections** - Responsible for facilitating verification of _IBC state?_ sent from counterparty
  - Associated with any number of channels
  - Encapsulates two _ConnectionEnd_ objects, represent counterparty light clients for each chain
  - Handshake - verify that light-clients for each _ConnectionEnd_ are the correct ones for the respective counterparties
- **channels** - Module on each chain, responsible for communicating with other channel (send, receipt, ack, etc.)
  - Packets are sent to channel, can be uniquely identified by `(channel, port)` 
  - Channel encapsulates two _ChannelEnd_ (established through handshake)
  - `ORDERED` channel, packets processed by order of send
  - `UNORDERED` channel, packets processed by order of receipt
- **port** - IBC module (_channel_) binds to any number of ports
  -  module (_channel_) port handles is denoted by **portID** (`transfer`, `ica`, etc.) unique to the channel
### Connections
- Connections established by a 4-way handshake
  1. ConnOpenInit - made by source, sets state of source to `INIT`
  2. ConnOpenTry - made by destination, sets state of destination to `TRYOPEN`
  3. ConnOpenAck - made by source, sets state of source to `OPEN`
  4. ConnOpenConfirm - made by destination, sets state of destination to `OPEN`
#### `ConnOpenInit` -
 - Relayer calls `ConnOpenInit` on chain A (chain initializing connection) 
   - Relayer sends a `MsgUpdateClient` to chain A, contains consensus state of chain B
   - Chain A consensus state updated to `INIT`
   - Relayer sending `MsgUpdateClient`, sends the protocol version to be used in connection
  - Generates the connectionID + connectionEnd for counterparty
    - Stores data associated with the counterparty client
#### `ConnOpenTry`
  - Spawned from chain A, message call on chain B
  - Sends data stored on chain A abt. connection to chain B
    - Verification logic on chain A is dependent upon light-client state on chain B
      - Light client on chain B stores latest state-root + next validator set of chain A
 - Relayer submits `MsgUpdateClients` to both chain A + chain B corresponding to light client data from verification in chain B
#### `ConnOpenAck`
 - Same as `ConnOpenTry` but on chain A
#### `ConnOpenConfirm` 
 - chain B acknowledges all data stored correctly on chain A and itself
## Channels
 - Application to application communication
   - Channel <> channel communication through connections + clients
   - Separation between transport (tendermint) + application (application)
     - channels namespaced by portIDs, 
    - **Establishing Channel**
      1. `ChanOpenInit`
         - Relayer calls this on chain A, which calls `OnChanOpenInit` (defined as callback in host module), sets chain A into `INIT` state
         - Application version proposed
         - Channel requests to use a specific port
      2. `ChanOpenTry`
         - Similar as above just calls application call-backs to initialize channels
      3. `ChanOpenAck` 
      4. `ChanOpenConfirm`
    - Channel handshake requires the capabilities-keeper of the app to hold a capability for the requested port
## Ports
 - Dynamic capabilities
## Clients
- Applications implement ICS-26 standard for application interface + call-backs
- Tracks consensus state across chains
  - Identified by chain-wide unique identifier
## ICS20
- ics20 channel binds to specific port
  - denom representation is `<hash of portId/channel>/denom`
## Questions
- Should routing logic be implemented as part of the acknowledgement?
  - Perhaps?
    - packet-unwind atomic across all channels
      - Later concern, 
## Implementation
**Sender chain unwind check function**
- if denom is native
    - we route it directly to (channel-id, port-id)
- If denom is not-native
    - Burn the voucher
    - Retrieve the global-identifier of the destination
    - Create packet to send voucher back one hop, attach global-id to packet

**Receiver chain unwind check function**
- if packet has global-id in meta-data
    - If the chain is the source
        - Send the token to the (channel-id, port-id) associated with the global-identifier
    - Otherwise
        - Read global-id from metadata, attach to packet sent to next chain in sequence
- if not
    - Continue packet receipt as normal
### Over-ride
**Sender chain unwind**
  - `sendTransfer` override, 
    - Check if the sending chain is source 
      - If source - chain wil be escrowing tokens
    - In this case we are always acting as the sink chain for each unwind?
- 
## Check out
-  https://decentralizedthoughts.github.io/2022-11-24-two-round-HS/
# Distributed Algorithms
- ## Ch 2
  - The network is represented as follows $G = (V, E)$, where $|V| = n$ (number of nodes in network), and each $i \in V$ is a process
    - Each process maintains $in\_nbrs_i, out\_nbrs_i \subset V$, where $in\_nbrs$ are sets of edges ending at $i$, and $out\_nbrs$ are sets of edges starting from $i$
    - Let $dist(i, j)$ be the min. number of edges from $i$ to $j$, let $diam(V)$ represent the max of $dist(i,j)$ over all pairs of $i, j \in V$
    - Let $M$ be a language of messages, sharesd between all processes
    - For each **process**
      - $states_i$ - represents the (possibly infinite) set of states
      - $start_i \subset states_i$ - the set of starting states of a process
      - $msgs_i$ - message generation mapping $states_i \times out\_nbrs_i \rightarrow M \cup \{null\}$
      - $trans_i$ - _state-transition_ mapping $2^M \times in\_nbrs_i \times states_i \rightarrow states_i$, i.e, for each state, we have a set of vectors (representing the inbound messages, possibly ordered) for each $in\_nbr$ which map to an ultimate state after processing all messages (should be indpendent of order of $in\_nbr$?)
- A round is the following
  1. Apply msg generation function to current stat 
  2. Apply transition function to current state + all in bound messages (why the above before below?) (deferred execution)
- **failures**
  - *stopping failure* - Process can fail at any point in round, including in middle of _step 1_ (process does not send all messages to all required parties)
  - *byzantine failure* - Process exhibits arbitrary state-transition logic
  - *link failure* - Process may place message in link, but link fails to deliver message to recipient
- Messages from $in\_nbrs$ analogous to inputs, multiplicity of start-states corresponds to input variables
- **execution**
  - Execution $\alpha$ represented as follows,
    - $C_0, M_0, N_0,C_1, \cdots, C_n , M_n, N_n$, where $C_i$ is the state assignment for all processes at round $i$, $M_i$ is the set of outbound messages, and $N_i$ is the set of inbound messages for all processes
    - For two executions $\alpha \sim^i \alpha'$, iff the state assignment of $i$ in $\alpha'$'s global state assigments are the same as in $\alpha$'s, and the sets of received / sent messages is the same for process $i$ for all rounds in either execution, these executions are **indistinguishable** for $i$
- **proof methods**
  - **invariant** - property held by all processes at every round, 
  - **simulation relation** - relationship between algorithm, that for every execution, a set of states eventually results
- ## Ch 5
  - **consensus** - Each process starts w/ value, on termination for all processes, each process must decide the same value
    - Subject to **agreement** (all processes decide same value), and **validity** (agreed upon value is restricted depending on inputs)
    - **co-ordinated attack problem**
        - Reaching consensus in network where messages may be lost
  - ### **Deterministic Coordinated Attack**
    - Suppose there are $G_1, \cdots, G_n$ generals, each attacking a single army from a different direction.
    - They each have messengers, which are able to communicate messages between them within a bounded amt. of time, 
      - The communication channels are pre-determined and knowm beforehand
      - Messengers are unreliable, can lose / not deliver messages, but if delivered, will always deliver w/in time known
    - **Case - When messengers are reliable**
      - Consider network where each node is a general, and channels are messengers
      - Each general sends messages to other generals through following messages (Attack?, source, destination)
        - Each general, on receipt of $n$ messages from different generals will decide, if there is one non-attack, all generals will not attack
      - On receipt of message, where destination is not the receiver, general forwards message to destination
      - Proof:
        - All messages reach destination reliably, complexity is $diam(G)$ rounds (general may not have channel to all generals)
    - In synchronous case where messengers are not reliable, agreement + validity is impossible
    - **Tx Commit (When Messages unreliably sent, is impossible)**
        - Processes are indexed $1, \cdots, n$, each process starts w/ $in \in \{0,1\}$, and must `decide` on $out \in \{0,1\}$. Decisions may be determined by a halting state
        - Properties
        - **agreement** - No two processes decide on different values.
        - **validity**
            - If all processes start w/ 0, $0$ is the only decision value
            - If all processes start w/ $1$, and all messages are delivered, $1$ is the only output value
        - **termination**
            - All processes eventually decide
        - ### **proof**
            - Let $G = (V, E)$, where $V = \{1,2\}$, and $E = \{(1,2)\}$, no algorithm solves the co-ordinated attack problem.
                - Suppose $A$, solves the problem.
                - For each input $i \in \{0,1\}$, there exists a start state $s_i \in states_i$, where $s_i \in \{s_1, s_0\}$, in which case, for a fixed set of successful messages, i.e $s \in M_{i-1} \rightarrow s \in N_i$, there is a single execution. Otherwise, the message generation function is executed in a faulty manner (is deterministic, and all messages are delivered faithfully).
                - $M_0$ is determined from $C_0 = \{s_i, s_i\}$
                - Let $\alpha$ be the execution of $A$ where $C_0 = \{1, 1\}$, then processes decide (within $r$ rounds, lets say) by **termination**, and by **agreement + validity** they both decide $1$, inputs are both 1
                - Let $\alpha_1$ be the execution of $\alpha_1$, where all messages after $r$ are not delivered, i.e $N_k = \emptyset, k \gt r$, thus $\alpha \sim^{1,2} \alpha_1$
                - Let $\alpha_2$ be the same as $\alpha_1$, except the outbound message from $p_1$ at round $r$ is not delivered, thus $\alpha_1 \sim^1 \alpha_2$, as the set of inbound messages + outbound messages is the same for $p_1$ in both $\alpha_1$ and $\alpha_2$, however, for $p_2$ the executions are not indistinguishable.
                - Furthermore, for $p_2$ / $p_1$, the set of inbound messages after that round are $\empty$, so the set of executions proceeds as before, except $p_2$ may possibly be in a different state.
                - Imples that for $\alpha_1$ and $\alpha_2$, $i$'s state assignment + in / out-bound messages are the same
                - In $\alpha_2$, $p_1$ decides $1$, and by agreement / termination, $p_2$ decides $1$ as well (can keep same decision as long as one process decides)
                - Consider $\alpha_3$, which is the same as $\alpha_2$ except that the last message from $p_2$ at round $r$ is not delivered, and $\alpha_2 \sim^2 \alpha_3$
                - Similarly $p_2$ decides $1$ in $\alpha_3$, since $\alpha_2 \sim^2 \alpha_3$, and $p_2$ decided $1$ in $\alpha_2$
                - Continue process of iteratively removing messages until no messages are sent (rely on termination / agreement / validity to continue decision)
                - Thus, when both processes start with $(1,1)$, and no messages are sent, the processes decide on $1$, call this execution $\alpha'$
                - Then consider, $\alpha''$ where $(s_1 = 1, s_2 = 0)$, and no messages are delivered, notice $\alpha' \sim^1 \alpha''$, thus $p_1$ decides $1$, and $p_2$ decides $1$ by agreement / termination (as well as weak validity),
                - Finally consider $\alpha'''$, where $(0,0 )$ is the start state, and no messages are delivered, in this case, $p_2$ decides $0$ by validity, however $\alpha'' \sim^2 \alpha '''$, and the decisions are contradictory. $\square$
        - **For arbitrary n processes**
            - Suppose no algorithm exists for $A$, then prove the same result for $n$ processes.
            - Suppose otherwise, then there exists an algorithm solving commit for the deterministic synchronous case. In this case, partition the network into two groups, $A$ and $B$
            - Where $|A| = n$, and $|B| = 1$, then all processes in $A$ have the same decision, and similarly with $B$, Consider case when all have the same input $1$, all must decide by round $r$, and have same decision, let $\alpha$, be this execution. 
            - Then let $\alpha_1$ be the execution, where all outbound messages for $k > r$ are not delivered
            - Follow same approach as above, except w/ A / B as in the case of the two process proof
    - **Tx Commit (randomized)**
        - Weaken agreement condition to allow for $\epsilon$ probability of disagreement (parametrized by # rounds)
        - **model**
          - **communication pattern**
            - Good communication pattern: $\{(i, j,k), (i,j) \in E, 1 \leq k \leq r\}$, i.e for each round, the set of messages that are faithfully delivered
            - Adversary composed of 
              1. Assignment of inputs to all processes, (global state assignment at start )
              2. communication pattern
        - For each adversary, a random function is determined over a unique probability distribution $B$,   
          - **agreement** 
            - $Pr^B[processes\space disagree] \leq \epsilon$
          - **termination** - All processes decide within $r$ rounds.
        - **algorithm**
          - Defined for complete graphs
          - Algorithm presented where $\epsilon = \frac{1}{r}$, define information flow partial order $\leq_{\gamma}$, for communication pattern $\gamma$
            1. $(i, k) \leq_{\gamma} (i, k')$ for all $i, 1 \leq i \leq n$, and $0 \leq k \leq k'$ (information at same process is monotonically increasing w/ time)
            2. $(i, j,k) \in \gamma$, then $(i, k-1) \leq_{\gamma} (j, k)$ (information flow monotonicity between messages)
            3. If $(i, k) \leq_{\gamma} (i', k'), (i',k') \leq_{\gamma}  (i'', k'')$ then $(i, k) \leq_{\gamma} (i'', k'')$ (transitivity of information flow)
          - For _good_ communication pattern (defn. above) $\gamma$, 
            - $information\_level_{\gamma} (i, k)$
              - $\forall i,level(i,k) = 0$
              - For $k > 0$, $\exists j \neq i, (j, 0) \not\leq_{\gamma} (i,k), level_{\gamma}(i, k) = 0$
              - For $k > 0$, $\forall j \not= i, l_j = max\{level_{\gamma}(j, k') : (j, k') \leq_{\gamma} (i, k)\}$, $level(i, k) = min_j (l_j) + 1$
            - I.e on receipt of messages from all parties at round $i$, $p_i$ has $level_{\gamma}(p_i, i) = i + 1$
          - For any good communication pattern $\gamma$, any $k, 0 \leq k \leq r$, and $i, j \in V$, 
          $$|level_{\gamma}(i, k) - level_{\gamma}(j, k)| \leq 1$$
            - Proof: For $k = 0$, $level_{\gamma}(i, 0) = level_{\gamma}(j, 0) = 0$. suppose $k = n$, and the hyp. holds, then for $k = n + 1$. If both processes have received each other's messages then $level_{\gamma}(i, n + 1) = max(\{level(j, k'), (j, k')\leq (i, k)\}) + 1 = level(j, n) + 1$, a similar case follows for $j$. WLOG,say $j$'s message has not been delivered, but $i$'s has, then $level_{\gamma}(j, n + 1) = max(\{level(i, k'), (i, k') \leq (j, n + 1)\}) + 1 = level(i, k) +1$, where $k$ is the last round that $i$ had delivered a message, which is necessarily the same as $i$'s currently, and the theorem holds.
          - Question: How does process $i$ know of $j$'s level in the prev. round? It doesn't? It does, levels are gossipped thru messages.
          - 
          - **Algorithm**
            - Informal: Each process $i$ keeps track of it's level in a local variable, process $1$ chooses a random value $r \in [1, r]$, value is piggy-backed on all messages, initial values of each process piggy-backed on all messages. After $r$ rounds each process decides $1$ if $level(i, r) \geq r$, and initial values of all processes = 1
            - **formal**
              - Messages are of the following form $(L, V, k)$, where $L$ is an assignment to each process an integer $L_i \in [0, r]$, $V_i \in \{0, 1, undefied\}$ and $k \in [1, r]$ or is undefined.
                ``` go
                    type ProcessState struct {
                        val [0,1, nil]
                        level int
                    }
                    // state for each node in participation
                    type RandomAttackState struct {
                        rounds int
                        decision [nil, 0, 1]
                        key [1, r] // must be set by process 1
                        processStates []ProcessState
                        processIndex
                    }

                    func init(processIndex, numProcesses, initialVal int) RandomAttackState {
                        state := RandomAttackState {
                            rounds : 0,
                            decision: nil,
                            processIndex: processIndex
                        }
                        // generate random key if processIndex == 1
                        if processIndex == 1 {
                            state.key := random(1, r)
                        }
                        state.processStates := make([]ProcessState, numProcesses)
                        // for each other process in consensus, initialize initial view
                        for j := 0; j < numProcesses; j++ {
                            pState := ProcessState{val: nil, level: -1}
                            // our initial state
                            if j == i {
                                pState.val = initialVal
                                pState.level = 0
                            }
                            state.processstates[j] = pState
                        }
                        return state
                    }
                ``` 
                ``` go
                    type Msg struct {
                        //sender process index
                        processIndex int
                        // sender's view of network
                        processStates []ProcessState
                        // sender's view of random value
                        key int
                    }

                    func (r *RandomAttackState) trans(inboundMsgs []Msg) {
                        // increment round
                        r.rounds ++
                        // iterate over received messages from prev. round
                        for _, msg := range inboundMsgs {
                            // all random keys must be the same
                            if msg.key == nil {
                                r.key = nil
                            }
                            // check for non-nil initial values from msg, and update our own
                            for i, processState := range msg.processStates {
                                if processState.val != nil {
                                    r.processStates[i] = processState.val
                                }
                                // update level values
                                if processState.level > r.processStates[i].level {
                                    r.processStates[i].level = processState.level
                                }
                            }   
                        }
                        // stort processStates by level (ascending), and update current level
                        r.level = sort.min(r.processStates, func(i,j ) {
                            r.processStates[i].level < r.processStates[j].level
                        }).level + 1
                        // decide if current round = r
                        if r.rounds == r {
                            // check if our level > key
                            if r.key != nil && r.level > key {
                                // check that all other decisions are 1
                                for _, processState := range r.processStates {
                                    if processState.val != 1 {
                                        r.decision = 0
                                        return
                                    }
                                }
                                r.decision = 1
                            } else {
                                r.decision = 0
                            }
                        }
                    }
                ```
            - **Theorem**
              - Random attack solves random attack, with $\epsilon < 1/r$
                - **validity**
                  - Case: all inputs are zero. All nodes trivially output zero, and agreement is held
                  - Case: all inputs are 1, and all messages are faithfully delivered, by lemma 5.3, for any complete communication pattern, all nodes have the same level at each round, in which case, at round $r$, all nodes have the same round $r \geq key$, and the same input, so agreement is solved w/ prob. disagreement $0 <\epsilon$ ( for all $r$)
                - **agreement**
                  - Consider an adversary $B$, with communication pattern $\gamma$, let $l_i = level_{\gamma}(i, r)$, then if $key < min_i(l_i)$, all processes decide according to their shared $vals$,
                    - Can a process have all values of $1$ and other processes don't? Then all processes would have level(0), would would be unable to commit
                  - On the contrary if $k > max_i(l_i)$, no processes commit, all decide $0$
                  - Finally, if key = $min_i(l_i)$, then some processes commit, and other's dont, with prob. $1/r$
    - **Lower Bound On Agreement**
      - Any $r$-round algorithm for co-ordinated attack, has probability of disagreement $1/r + 1$
        - Given adversary $B$, with communication pattern $\gamma$, define, $prune(B, i)$
          1. If $(j, 0)\leq_{\gamma} (i,r)$, then $input(j)_{B'} = input(j)_B$ - intuitively, the input in $B'$ is nonzero for any node, as long as $i$ hears from it in $B's$ communication pattern
          2. $(j, j', k) \in \gamma '$ iff it is in the comm. pattern under $B$, and $(j', k) \leq_{\gamma} (i, k)$
    - **problems**
      - 

- ## Ch 6
# Algebra
- ## Prereqs
  - Version of set theory used built from 3 undefined notions, 1. class, 2. membership, 3. equality. 
    - **class** - Collection $A$ of objects, s.t given object $x$, it is possible to determine if $x \in A$ or $x \not \in A$
      - Equality relation over class is same as usual, reflexive $A = A$, symmetric $A = B \rightarrow B = A$, transitive $A = B \land B = C \rightarrow A = C$
      - **extensionality** - Classes that contain the same objects are equal $[x \in A \iff x \in B] \iff A = B$
      - **set** - A class $A$ is a set iff there exists a class $B$, where $A \in B$ (A is an element of the class), 
      - **proper class** - A class that is not a set
      - a
# Cryptography
- **Information Theoretic Approach**
  - How much info abt. the plain-text is revealed from cipher-text, **perfect security** -> no info
  - ^^ is impossible w/o shared secret as large as the plain-text
  - Encryption key == decryption key, how to share keys between users over insecure channel?
- **Complexity Theoretic**
  - Enforce that it is impossible for information revealed abt. plaintext from ciphertext to be efficiently extractable
  - Allows adversary to know encryption key, but not know decryption key?
- ## Fault Tolerance / Zero-Knowledge
    - Mutual simultaneous commitment, i.e signatures from two parties are atomic
    - **trusted third parties**
      - Voting
        - *privacy* - Parties shld be able to come to agreement on outcome (majority) w/o learning anything abt counterparty preference in process
        - *robustness* - Each party has equal influence in outcome
- ## Zero Knowledge Proof
  - ZKP systems exist for all languages in $\mathcal{NP}$
- ## Probability
  - Function space $2^l$, denote this as $P_l$
  - **random variable** - $f : P_l \rightarrow \mathbb{R}$
    - Also can be defined as folows $f : P_l \rightarrow \{0,1\}^*$, that is, a function from the sample space to the set of arbitrary length binary strings
  - **statement** - $Pr[f(X)]$, i.e the probability that $f : \{0,1\}^* \rightarrow \{0,1\}$ holds for arbitrary value of $X$, i.e $\Sigma_{x \in X} Pr[X = x] * \chi_x(f(x))$
    
    ariables, i.e $Pr[B(x_1, \cdots, x_n)] = \Sigma_{x_1, \cdots, x_n} (\Pi_{i}Pr[X = x_i]) * \chi(B(x_1, \cdots, x_n))$
  - ### **inequalities**
    - **Markov** - Given random variable $X: 2^n \rightarrow \mathbb{R}$, there exists a relation between the deviation of a value $v$ of $X$ from the expected value of $E(X)$ of $X$, and the prob. that $X = v$
        $$E(X) = \Sigma_v Pr[X = v] * v \rightarrow Pr[X \geq v] \leq E(X) / v$$
        - Proof
        $$E(X) = \Sigma_x Pr[X = x] * x = \Sigma_{x < v} Pr[X = x] * x + \Sigma_{x \geq v} Pr[X = x] * x$$
        $$\geq \Sigma_{x < v} Pr[X = x] * x + v * Pr[X \geq v] \geq v * Pr[X \geq v]$$
      - Implies, $Pr[X \geq r * E(X)] \leq \frac{1}{r}$ (apply Markov thm. w/ $v = r * E(X)$)
    - **chebyshev** - Stronger bound for deviation of value of random variable from expectation. 
    $$Var(X) := E[(X - E(X))^2]  = E(X^2) - E(X)^2$$
      - Inequality
    $$Pr[|X - E(X)| \geq \delta] \leq \frac{Var(X)}{\delta^2} \rightarrow Pr[|X - E(X)| \geq \delta] = Pr[(X - E(X))^2 \geq \delta^2] \leq \frac{Var(X)}{\delta^2}$$
    - **Independent Random Sampling**
      - Let $X_1, \cdots, X_n$ be pairwise independent random variables w/ the same expectation, denoted $\mu$ and variance $\sigma^2$, then for $\epsilon > 0$
      $$Pr[|\frac{\Sigma_i X_i}{n} - \mu| \leq \epsilon] \leq \frac{\sigma^2}{\epsilon^2n}$$
    - Intuition
      - Expectation is linear so.. $E(X_1 + \cdots + X_n) = E(X_1) + \cdots + E(X_n)$, and $E(\sigma_i X_i/ n) = \Sigma_i E(X_i)/ n = \mu$, thus $E(\Sigma_i X_i / n) = 1/n E(\Sigma_i X_i) = 1/n \Sigma_i E(X_i) = \mu$, and one has $Pr[|\frac{\Sigma_i X_i}{n} - E(\frac{\Sigma_i X_i}{n})|] \leq \frac{Var(\frac{\Sigma_i X_i}{n})}{\epsilon^2}$
    $$Pr[|\frac{\Sigma_i X_i}{n} - \mu| \leq \epsilon] \leq \frac{Var(\frac{\Sigma_i X_i}{n})}{\epsilon^2} = \frac{E((\Sigma_i X_i - \mu)^2)}{\epsilon^2n^2}$$
    - Expand and apply linearity
    - **chernoff bound**
      - Let $p \leq 1/2$, and let $X_1 \cdots X_n$ be totally independent random variables in $\{0,1\}$. Then for all $0 \leq \epsilon \leq p(1-p)$
      $$Pr[|\frac{\Sigma_i X_i}{n} - p| > \epsilon] < 2 * e^{-\frac{\epsilon}{2p(1-p)}n}
- ## Computational Model
  - **Complexity Class $\mathcal{P}$**
    - A language $L \in \mathcal{P}$ is **recognizable** in poly time, if $\exist$ a deterministic turing machine $M$ and polynomial $P$, where
      - on input string $x$, $M$ halts after steps $\leq P(x)$
      - $M(x) = 1$ iff $x \in L$ 
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
- **Integrity** - let $d$ be a certificate generated by a $write(d, b)$, for any $read(d)$ from arbitrary correct processes, the returned block is either the same or non-existent
    - In this case, the block either exists in the node's cache or it doesn't
      - At least a byzantine-quorum of  nodes have received the certificate for this block, and the block itself, and will have cached it
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
## Anoma Notes
![Alt text](Screen%20Shot%202023-01-24%20at%2010.57.56%20PM.png)
- As above, each node builds a block containing certificates of blocks from prev. rounds
- Certificates broadcast and included in next round
    - For each certificate, at least an honest majority of producers will include certificate in next round
## Presentation
 - 
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
## Storage requirements v. high
## Tusk
- Theoretical starting point is `DAG-rider`
- Tusk, asynchronous consensus algorithm
- Includes a VRF coin in each tusk block
    - Threshold random value (given 2f+1 signatures include random value in block etc.)
- Each validator interprets its local DAG, based on the shared random coin
    - Validators divide random coin into `waves`
- Rounds
    1. First round all validators propose blocks
    2. Validators vote on proposed blocks by including certificates in the blocks they propose
    3. Validators produce shared random value, determine potential commit
       1. Commit `anchor` if there are $f+1$ votes for anchor in next round
          - Intuition - guaranteed path to next anchor
- Ordering anchors
  - After anchor is committed, vals order history of anchor to garbage collection point
  - Validators may not all commit anchor (depends on view of $r + 1$), may be diff. between vals.
  - 
- Zero-message overhead consensus
  - Validators interpret local view of DAG
- 
- Block validity depends on having certificates of $2f + 1$ blocks from prev. round, why?
- Build POS-system from this?
## DAG-Rider
## Bull-Shark
- 
## Topos
- 
## Reliable Broadcast
- Narwhal + Bullshark are asynchronous reliable broadcast protocols
- Designed for asynchronous model
  - $n$ parties $f < n /3 $ threshold adversary
  - Leader has input $v$
  - A party that terminates must output a value
- **validity** - If the leader is non-faulty then all non-faulty parties  will output the leader's output
- **agreement** - If some non-faulty party outputs a value, then eventually all non-faulty parties output the same value
  - Leader can be faulty
- **High-Level**
  - **validity** - Leader broadcasts value once to all nodes
    - Each node echoes the value
    - Nodes wait for $n - f$ echoes before broadcasting vote for the value of the echoes
      - If there exist votes for diff. values
        - Each vote implies $n - f$ echoes for each value, thus $2n - 2f > 4f$, thus there is at least 1 node that echoed different values (false)
  - **agreement** - Parties send vote after seeing $n - f$ echoes, or seeing $f + 1$ votes
    - If any party sees $n - f$ votes, then there are at least $n - 2f$ votes from non-faulty parties -> $> f + 1$ votes, and those will eventually reach all other processes
    - Parties decide after seeing $f + 1$ votes
- Potential optimization
  - Leader sends input to all parties
  - Send echo on receiving echo from $f + 1$ parties
    - Or send echo on receipt of value from leader
  - deliver on $n - f$ echoes
  - If leader is non-faulty, then all non-faulty processes eventually deliver
    - **agreement** - Suppose two processes decide on different values
      - Then there exist $f + 1$ processes that sent conflicting echoes
        - Contradiction
    - If leader is non-faulty, then all non-faulty processes deliver the leader's input
      - In above case, can any process not deliver leader's value?
        - No, there are only $f$ faulty processes, can't manipulate message, need at least 1 non-faulty echo of non-leader value
      - Can any node not deliver at all? (This can happen)
        - If $n$ delivers, there are at least $f + 1$ echoes for the value delivered
          - Consider faulty leader with 4 processes
          - All non-faulty processes, will eventually echo
            - Will then eventually deliver
      - Then no node delivers?
        - $\{A\}$
## DAG + BFT
- Decouple data-dissemination from meta-data ordering
  - Make all possible inputs to consensus available first, then create order + fork-choice rules on top of DAG
    - I.e causal dependencies of data + data itself is made available independent of consensus
    - Consensus exists to apply-fork choice to DAG + make paths canonical
- BFT Consensus - Given $n$ validators, $f$ of which are byzantine - agree on an infinitely growing sequence of transactions
  - DAG is formed, message is a vertex, causal dependency between message is an edge
- Given DAG of messages (i.e block proposals as messages, and votes as causal dependency)
  - Have consensus logic be zero-communication overhead interpretation of local view, i.e create total order over DAG
  - How to have validators reach **agreement** on local view?
- ## Round Based (Aleph)
  - Each message is a vertex, for each round, every validator sends a message that contains references to $n - f$ messages from the previous round
    - ![Alt text](Screen%20Shot%202023-02-12%20at%204.53.48%20PM.png)
    - Validator must have seen $n - f$ messages from previous round
  - ## Non-equivocation
    - Relies on _reliable broadcast_, all messages (vertices) from honest validators are eventually delivered, all honest validators eventually deliver the same vertices
      - Each vertex may not have to reference all vertices in the prev. round
    - If any two validators have a vertex from a validator at round $r$, then all validators having that vertex, have the same vertex stored
	- ## Chain Quality
    	- At least $>f$ of the vertices at round $r$ were from honest-parties, can be up to the fork-choice rule to determine invalid blocks?
   - ## Scalability + Throughput (Narwhal)
     - data-dissemination shld be reliable + decoupled from ordering
       - Potentially sequences > 100k tps
	  - Implementation
    	  - Each participant is composed of **workers** + **primary**
      	  - **worker** - aggregate txs into batches, send digest of batch to primary
          	  - How are certificates generated? Workers actually send certificates of digests to primary?
      	  - **primary** - aggregate digests from workers, add to vertex, and broadcast to form DAG
			- **Reliable Broadcast**
    			1. Validator sends to all other primaries message (digests from workers + $n - f$ attestations to messages (certificates) from previous rounds)
      		1. On receipt of message, validator replies with signature if
         		1. Validator has not received message from sender in current round
         		2. Validator's workers have persisted all digests in message
         	1. Validator aggregates signatures into **certificate** and broadcasts back to all validators
         	2. Validator only moves to next round iff it has $n - f$ certificates + corresponding messages
         - **Purpose of Quorum Certificates**
           - **non-equivocation**
             - Byzantine vals cannot get quorum certificates on two blocks in a round. At least one non-byzantine validator must not be following protocol
           - **data availability**
             - Quorum certificate requires that $n - f$ vals must have data available, and data will be available for later rounds
           - **history availability**
             - Every certified block contains references to $n - f$ certified blocks. For a block to be certified it must be available, thus all causal histories (once certified) are available.
      - Separation between data-dissemination + ordering
        - Guarantees network speed throughput for txs + blocks
        - Consensus may proceed slowly (Partially synchronous), but block production will continue
  -  ## Bullshark
		- Two versions
			- Asynchronous - 2 round fast-path during synchrony
			- Partially synchronous 2 round protocol
		- Does not need a view-change nor a view-synchronization mechanism
		- **Block Commits**
    		- Decide which anchors to commit, then totally order all vertices in the DAG (order causal histories of committed anchors)
    		- Each odd round, a predefined block (anchor) is chosen to be committed, along with its entire causal history
      		- 	For the block to be committed, it must have $f + 1$ descendents (in the validator's current view)
      		- In _Tusk_ the anchor is chosen via a shared random coin (shares of the random coin are contained in the $2f + 1$ signatures needed for a certificate)
      	- Each descendent of anchor counts as vote for commit
          	- Commit anchor if there are $f + 1$ votes
      - If validator commits anchor $A$, then all future anchors have a path to A?
          - Let $round(A) = r$, then for $r + 2$, each vertex has $n - f$ ancestors in $r + 1$, and there are $f + 1$ vertices in $r + 1$ that descend from $A$, thus there must exist a path to $A$ from any anchor of rounds later than $A$
          - If there is no path from a future anchor $A'$ to $A$, then $A$ will not be committed in any view
      - Ordering anchors
        - When an anchor is committed for round $i$, the node checks of there is a path to anchors $i - 2n$, where $1 \leq n \leq k$, where $i - 2k$ is the round of the latest anchor
          - If there is a path to an earlier anchor, the earlier anchor is ordered before

  - ## Typhon (Anoma Consensus)
    - **workers** - Batch + erasure code txs, broadcast signed hash of batch to primary
    - **primary** - Participate in DAG construction with signed hashes of worker batches + certificates of prev. header blocks
    - Chimera chains can have atomic batches across both involved chains in participant narwhals
    - **headers**
      - Signed worker hashes (from all workers of $P$)
      - signed quorums per learner (certificates)
        - Certificates of blocks created by other workers
      - Availability for prev. availability certificate
    - Primaries braodcast availability votes on receipt of headers from vals
      - Workers of receiver must make worker batches of header available
    - ## Integrity Protocol
      - Workers not involved
      - Primaries broadcast Integrity votes for each other primary
        - Headers reference ancestor header from primary, may not sign conflicting headers per ancestor
      - 
# Decentralised Thoughts
- ## Consensus + Agreement
	- **Agreement**
		- Suppose there is a set $P$ processes, with inputs $v_1, \cdots, v_n \in V$,
		- **agreement** - For all honest $i, j \in P$, $v(i) = v(j)$, where $v$ represents a decision predicate
		- **validity** - If all honest processes have decided on $v$, then $v$ is a valid value
    		- Classic: If all honest parties have the same input value, then this is the decision value
    		- Weak: If all parties are honest and have the same value then this is the output value
    		- External: 
		- **termination** - All honest parties must eventually decide on a value
		- All parties honest and synchronous?
			- Requires 1 round
			- Node sends value to all nodes (only if valid), 
			- Can also just terminate after $\Delta$ (termination, validity, agreement)
				- Asssumes synchronous reliable broadcast
		- Change network assumption (synchronous, partial synchrony, asynchronous) and adversary threshold (crash-stop, crash-recover, byzantine)
		- For lower bounds use **weak validity** -  if all parties are honest and all have the same input value v, then v must be the decision value.
			- Does not require _decision_ of processes, only required to prove validity of state-machine of single process? Why is this easier?
	- **uniform / non-uniform agreement**
		- **uniform** - When all (including faulty processes) have agreement
		- Assume crash or omission fault (impossible with byzantine)
		- **non-uniform** - same as **agreement** under above conditions
	- **Broadcast**
		- Assumes existence of designated party with input $v$
		- Keep **Agreement** rules except
		- **validity** - If leader is honest then $v$ is the decision value
	- **Agreement -> Broadcast**
    	- Agreement protocols assume that each node has its own input
  		- Assume synchronous model
    		- Can't assume reliable broadcast 
      		- All messages are eventually delivered after $\Delta$
    	- Let $A$ be a protocol satisfying agreement.
    		- Leader receives input $v$
    		- Leader broadcasts $v$ to all nodes
      		- Synchronous + atomic broadcast assumption?
      	- Nodes perform $A$ on input $v$
      - Termination + agreement from $A$, validity - Leader receives $v$, all nodes receive $v$, b.c A is an _agreement_ protocol all nodes have same input $v$ and thus decide on $v$
        - This depends on **classic** validity of $A$
   - **Broadcast -> Agreement**
     - 
- ## Communication Models
	- **Synchronous** - All messages are delayed at most by a pre-determined $\delta$, all messages are delivered
	- **Asynchronous** - Each message is eventually delivered, but after an arbitrary finite delay
    	- Asyncrhonous consensus is impossible with just one faulty process in fail-stop
	- **Partial Synchrony** - Assumes a known finite time bound $\delta$, and an event _GST_
    	- The adversary can cause _GST_ to happen after any arbitrary delay
    	- Any message sent at $x$ will be delivered at $\delta + max(_GST_, x)$
      	- I.e the network acts asynchrously until _GST_, and synchronously after
      - Alternative - there is a finite (unknown) upper-bound on delay $\delta$
   - Why synchrony is bad?
     - Protocols assuming this may overestimate $\delta$ (safety but non-performant)
     - Protocols may under-estimate and not be 
   - Partial Synchrony
     - Protocol is safe under asynchronous periods
     - Prove liveness + termination after _GST_
## Threshold Adversaries
- **Threshold Adversary** - Adversary that controls some $f$ nodes
  - $n > f$ - Adversary controls all but one node, (dishonest majority)
    - WRT threshold adversaries, want to lower-bound the number of nodes needed to prove security properties
  - $n > 2f$ - dishonest minority
  - $n > 3f$
- Paxos (assumes adversary controls $2f < n$), Ben-Or (asynchronous consensus) - Uses weaker definition of termination, to account for FLP impossibility
- ### Bounded Resource Threshold Adversary
  - Frame thresholds in terms of above, where $n$ is the total supply of resource, and $f$ is share of supply controlled by adversary
    - Nakamoto consensus - CPU cycles
    - POS - tokens 
      - Advantage - slashing for dishonest / potentially malicious actors
      - Disadvantage - Potentiall large boot-strapping problem, when chain starts, value of coin is low, and actors can easily manipulate supply
        - Solution - eth-merge, via bootstrapping first w POW -> POS
## Power of Adversary
- Assumptions
  - Communication Model (how long adversary can delay messages)
  - Threshold Adversary (what percentage of nodes in the network are controlled by the adversary ($n > f$, $n > 2f$, $n > 3f$), bounded resource models,dynamic, permissionless)
  - Adversary Power (Passive, Crash, Omission, Byzantine)
- **Type of Corruption**
  - Passive: Follows protocol like all honest nodes, can learn all possible information from its _view_
    - I.e all nodes controlled by adversary can aggregate views to approximate network information
  - Crash: Once a party is corrupted, it stops sending and receiving messages
  - Omission: Can selectively choose to deliver sent messages
    - Process does not know it has failed
  - Byzantine: Adversary has full power to control part and take arbitrary action on corrupted party
## Asynchronous Consensus (FLP Lower Bound)
- **High-Level**
  - LF - Any protocol solving consensus in the synchronous model that is resilient to $t$-crash-failures, must have an execution with at least $t + 1$ rounds
  - **synchronous-consensus** - is slow
  - **Asynchronous Consensus without randomness is impossible**
    - possible in constant expected number of rounds
- **liveness of consensus is not guaranteed in any asynchronous BFT system**
   - No asynchronous consensus protocol can tolerate even a single un-announced **process death**
   - Assume reliable broadcast
    - All sent messages eventually delivered exactly once
    - Byzantine failures not considered
      - Requires even more assumptions than process-death does
 - Can only hope that desired properties are held under a bound of malevolent parties
   - Similar to _transaction-commit_ (consensus) problem
 - **atomic broadcast**
   - For any message sent simultaneously to all participants, $m$, if $m$ is eventually delivered by some **non-faulty** process, then all processes eventually deliver $m$
   - Messages may be delivered out of order (can be processed in order), 
 - Claim: All asynchronous commit protocols, have a window in which the protocol may wait forever for a message, or a single failed process can cause the protocol to wait indefinitely
 - ### Consensus Protocols
  - Let  $P - \{n_1, \cdots, n_n\}$ be a set of asynchronous processes with, _internal state_
    - A program counter
    - Internal storage
    - $x_p, y_p \in \{b, 0, 1\}$, where $x_p$ is the input and $y_p$ is the output for process $n_p$
  - Output register starts as $b$, it is write-once. Output state determined by determinisitic transition function
## Partial Synchrony
 - 
## PBFT
## Paxos
- **Objective** - Obtain a total-order over a set of `decrees` on which each member of the _synod_ agrees
- **terms**
  - Voting over _decree_ is determined via Ballots
    - $B_{dec}$ - decree on which ballot is made
    - $B_{qrm}$ - A quorum of priests tasked with voting on ballot
    - $B_{vot}$ - The set of priests that voted for the decree
    - $B_{bal}$ - Ballot order
- Decrees are passed iff $B_{qrm} \subseteq B_{vot}$, i.e all priests in the decree's ballot voted for decree
- **conditions**
  - Let $\mathcal{B}$ be a set of ballots
  - *B1* - Each ballot $B \in \mathcal{B}$ has a unique round #
  - *B2* - Quorums of any two ballots must have one priest in quorum
  - *B3* - Let $B, B' \in \mathcal{B}$, where $B_{bal} < B'_{bal}$, and $A \in B'_{qrm}$, if $A \in B_{vot}$, then $B'_{dec} = B_{dec}$
    - Intuition - Ballot is an aggregation of votes for a decree?
    - Can be possible for quroums of ballots for same decree to be different?
    - Voter may not necessarily be in $B_{qrm}$
- **Votes**
  - $v_{pst}$ - Priest casting vote
  - $v_{dec}$ - Decree voted on
  - $v_{bal}$ - Ballot number of vote casted
## Heterogeneous Paxos
- Given 2 chains running above, it is possible for both chains to agree on a total-order of messages subject to constraints of either chain (under no trust assumptions of each other)
- **System Model**
  - system is _closed-world_, with fixed set of _acceptors_, _proposers_, and a fixed set of _learners_
  - _proposers_ + _acceptors_ can send messages to other _acceptors_ + _learners_
  - **Liveness** - A _live_ acceptor eventually sends every message required by the protocol
  - **Safety** - A _safe_ acceptor will not send messages unless they are required by the protocol, and will only send messages only in the order the protocol specifies
  - _learners_ - Set conditions on which they agree with quorum of learners, don't send messages, so they can't be faulty
- **Network** - Network is partially synchronous, for each message, after $GST$, the message is delivered by all parties after $\Delta$ (known and fixed)
  - Authenticated, acceptors send messages to all learners + acceptors (faulty can send diff, but can equivocate), for any 
- **consensus**
  - Proposers propose values, notice $acceptors \subseteq proposers$, acceptors receive proposals, send to learners
  - learners receive values from acceptors, and eventually decide on a single proposed values, if a learner decides all other learners must decide on the same value
    - validity
    - agreement
    - termination
- **learner graph**
  - DAG, with learners as vertices
    - Edge -  condition underwhich vertices agree
    - Vertices - Correspond to learner, labelled with conditions for termination
  - **Quorum**
    - Set of acceptors sufficient to make learner decide (perhaps $2f + 1$ acceptors?)
    - Each learner in graph $a$, has a set of quorums $Q_a$
      - Why are there multiple quorums per learner?
      - Quorum can potentially be non-byzantine? This is characterized by adversary threshold
      - Upper bound of quorums per learner is determined by total nodes + adversary threshold
    - Let $\mathcal{L}$ denote a predetermined set of _live_ acceptors
  - **safe set**
      - Edge between learners $a, b$, are represented as a set of _safe sets_
        - A set of acceptors, some faulty and some not faulty (according to an adversary model), with the constraint, that if the set of non-faulty acceptors listed in the safe set are non-faulty, the learners demand agreement
  - Tolerable failure scenarios are characterized by a _safe set_? Set of acceptors that can withstand failure scenario?
  - Consider safe-sets as an intersection of quorums?
    - 
  - **labels** - 
    - Label must be mapped to a quorum of acceptors
- **agreement**
  - Notice, if $a$ agrees with $b$, and $b$ agrees with $c$, then $a$ agrees with $c$
  - **Condensed Learner Graph** - If $a - b \cap b - c \subseteq a - c$, in this case, agreement (according to safe-sets) is transitive
  - $a - b \subseteq a - a$ - I.e the safe sets between two learners is a subset of the power-set of the acceptors $a$ (resp. $b$) considers correct.
- **Consensus**
  - **Heterogeneous Execution Validity** - Execution is valid if all decided values (learners) were proposed in that execution
    - Different from from traditional validity? Validity - If all honest learners have same input, then all learners decide on input
  - **Protocol Validity** - Protocol valid if all possible executions are valid
- **Entanglement** - Learners $a$, $b$ are entagled, if their failure assumptions match the failures in an execution
  - I.e A safe set in their execution exactly details the failures in an execution
- **Execution Agreement** - For learners $a, b$, have agreement, if all decisisons for either learner are the same
  - What abt for learners who decide more than once? Learners decide on same value every-time (unless failure assumptions over acceptors for learners is incorrect)
- **Protocol Agreement** - For all possible executions of protocol, all entangled learners have agreement
- **Accurate Learners** - Learner entangled with itself
  - Unique to learner, if one of the quorums under which the learner terminates is an accurate representation of the network
  - Defines when a learner is accurate, i.e will not decide diff. values
  - Suppose learner is not accurate, then there are more failed acceptors than initially expected, in which case, a quroum of acceptors may be reached (some will be faulty), and will act accordingly to bolster a quorum of acceptors for another decision value
- **termination**
  - Learner has termination if it eventually decides
  - **Protocol Termination** - For all possible executions of protocol, all learners with safe and live quorums eventually decide
- **Heterogeneous Paxos** - Guarantees validity and agreement in asynchronous network, and termination under partial synchrony
- ## PROTOCOL
  - Proceeds in phases `1a`, `1b`, `2a`
  - **Messages**
    - Proposers send `1a` messages to acceptors, `1a(val, ballot_number)`, assume that proposers maintain incrementing `ballot_number` as a map of request number to value
    - Acceptors, on receipt of `1a` messages from proposers, send `1b` messages to other acceptors, `1b(1a)`, i.e 1b messages reference 1a messages
      - Acceptor $A_a$, on receipt of `1b` messages for a ballot number of $b$ from a quorum of learner $a$, sends a `2a` message, where `2a(learner, ballot_number)$, where $ballot_number$ is the ballot_number for which $A_a$ received acks from a quorum of $a$ (learner referencing quorum)
    - Learners decide on receipt of `2a` messages from a quorum of its acceptors, all `2a` must have the same ballot number
- Question `WellFormed(), b(), V()` conditions?
  - Conditions under which it is possible for an acceptor to send a diff. 2a with a diff leader (referencing a diff. quorum)?
  - Conditions under which it is possible to send `2a` with different values. I.e if learners $a, b$ may not have to agree, or prev. `2a` message is invalidated
- Question, how is ballot_number determined? Each proposer can send multiple `1a` with incrementing ballot_number? Cause live-lock?
- **Intuition**
  - Messages corresponding to PrepareCommit for each learner, executed independently (with preference toward having learners decide on shared value(preference to agreement between learners))
- Algorithm is conceptually similar to `Byzantine Paxos`
- **Valid Learner Graph**
  - For learner $a$, define $Q_a$ as the set of quorums for $a$. If for all $q \in Q_a$, there is a non-live acceptor $\alpha \in q$, then $a$ is not guaranteed to terminate. 
    - Decision dependent upon quorum may not ever be reached
- Agreement guaranteed, when for $a, b \in \mathcal{L}$, there exists $\alpha \in Q_a \cap Q_b$, where $\alpha$ is a safe acceptor
  - I.e for $a, b \in \mathcal{L}$, $\exists s \in a-b, \forall q_1 \in Q_a, \forall q_2 \in Q_b, s \cap q_1 \cap q_2 \not= \emptyset$
- **messaging**
  - *live acceptor* - Echo all received / sent messagse in the network, i.e when a live acceptor receives a message, all other acceptors will eventually receive it
  - *safe acceptors* - On receipt of a message, act according to protocol and send message if necessary atomically
    - Sends message to itself immediately
    - Receive no messages while sending or receiving
- $Sig : \mathcal{M} \rightarrow \mathcal{P}$, $Sig(m) = l$, where $l$ is the proposer / acceptor that sent $m$
- Messages sent by Acceptors reference all messages received since the last time they sent a message
- $Trans(m) = \{m\} \cup \bigcup_{m' \in m.refs} Trans(m')$
- $Get1a(x) = max_{m \in Trans(x)} ballot_number(m)$
- Learner decides when it has received `2a`s from a quorum of acceptors
- Connected learners
  - For all safe-sets in the edge between $a, b$, no acceptor has yet been proven byzantine
  - Always agree
- From $m$, an acceptor may recognize byzantine behaviour of an acceptor through a message's transitive closure, in this case $Caught(m) = \{m', m'' \in Trans(m), Sig(m') = Sig(m'), m' \not\in Trans(m) \land m \not\in Trans(m')\}$
  - In this case, neither of the messages is ordered before the other, this is false, as one of the messages signed by $b$, must be ordered before the other
- For each message $m$, define $Con_a(x) = \{b \in \mathcal{L}, \forall s \in a - b \land s \cap Caught(b) = \emptyset \}$
  - If all of the safe sets in $a - b$ are compromised (no safe quorum is in $a, b$'s intersection, the nodes need not agree)
- 
## Anoma Consensus 
- Protocol allows set of blockchains $S$, $|S| > 1$, to decide on atomic transactions across either chains
  - Atomic txs carried out on chimera chains
- Protocol includes (acceptors, learners, proposers)
  - Blocks agreed upon in rounds
- Blocks are proposed by proposers with ballot number (`1a` message)
- Acceptors receive proposals (`1a`s) and send `1b` messages to other learners
  - Learners send `2a` messages to learners when they are well-founded, i.e has received a quorum of `1b` and participated in `1b` for ballot
- Single learner, 
  - Decides once seen quorum of `2a` messages
- ## Chimera Chains
  - Chimera chain may be identified as subchain of either main-chain
    - Included genesis-block in chimera chain + acks from either chain abt. the genesis block
- ## Consensus For Chimera Chains
  - ## Consensus Rounds
    - Four Rounds
      1. Proposing chimera block
      2. Acknowldeging proposed block
      3. Consensus over proposal
      4. Termination
    - 

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
## Two-Phased Commit
- **scenario**
  - Data stored (replicated or sharded) among multiple services
  - Want to atomically commit txs (data-operations on entries across clusters). How to do this?
- **response**
  - Cannot make operations atomic w/o responses from other nodes (i.e tx is cross cluster, one applies other does not = bad)
  - **prepare**
    - Nodes promise to carry out operation (if possible)
  - **commit**
    - Nodes carry out
- What happens if only prepare?
  - Suppose some nodes get required prepares, but other nodes don't?

## PBFT
- **model**
  - Asynchronous network
  - 
## Gasper
 - Mental model
   - Finality separated from block-production
   - Casper is analog of tendermint. i.e justification (pre-vote) -> finalization (pre-commit)
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
     - **question**
       - Is it ever possible for conflicting checkpoints to be justified?
         - Unequivocally, yes
       - Say that for some vals, the attestations voting for $B_1 \rightarrow B_2$ are not included by B_2's epoch end
         - In which case, B_3's epoch begins w/ vals attesting to LJ(B) = (B_1, 2) (i.e carry into epoch 3)
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
   - ### Dynamic Validator Sets
     - Consider $b$, then $dynasty(b) = |\{h \in chain(B_{genesis}, B), finalized(h)\}|$
       - If deposit submitted at $b, dynasty(b) = d$, then validator $\mathcal{v}$ start-dynasty is block where $dynasty(b) = d + 2$
       - Similar for withdrawals (i.e unbonding period starts at (first) block w/ $d + 2$)
     - **rear / forward-validator sets**
       - $\mathcal{V}_f = \{v : DS(v) \leq d < DE(v) \}$ - vals who may have entered active set this block, but cannot leave this epoch
       - $\mathcal{V}_r = \{v : DS(v) < d \leq DE(v)\}$ - vals who have entered active set in prev. block but can leave this epoch
     - Notice, $\mathcal{V}_f(d) = \mathcal{V}_r(d + 1)$
     - Super-majority now defines as $2/3$ of $\mathcal{V}_f(d) / \mathcal{V}_r(d)$ 
       - I.e consider block at epoch $e$'s finalization, then to finalize $e$, super-majority for $e \rightarrow e'$ (finalization of $e$), and $e'' \rightarrow e$ (justification of $e$) are the same
        ![Alt text](Screen%20Shot%202023-08-13%20at%2010.30.32%20PM.png)
      - Possible safety violation if stitching mech. does not work
   ## Gasper
   - **epoch boundary pairs** - Ideally blocks produced per epoch (checkpoints in Casper), represent as follows $(B, j)$ ($j$ is epoch number, $B$ is block)
   - **committee** - Vals partitioned into _committees_ per epoch (composed of slots), one committe per slot (propose blocks per committee?) 
     - Single val in committee proposes block, all vals in committee attest to HEAD of chain (preferrably most recently proposed block)
   - **justification + finalization** - Finalize + justify **epoch boundary pairs**
   - ### Epoch Boundary Blocks + pairs
     - Let $B$ be a block, $chain(B)$ the unique chain to genesis, then
       -  $EBB(B, j)$, is defined as $max_{B \in chain(B)}(h(B) = i * C +  k \leq jc), 0 \leq k < C$, i.e the latest block before a certain epoch boundary.
       -  For all $B$, $EBB(B, 0) = B_{genesis}$
       -  If $h(B) = j * C$, then $B$ is an EBB for every chain that includes it (notably $chain(B)$)
       -  Let $P = (B, j)$, then attestation epoch $aep(B) = j$, same block can serve as EBB for multiple epochs (if node was down for some amt. of time, chain forked, and earliest ancestor is several epochs ago)
     - Nuance not found in Casper b.c Casper assumes live block-production, GASPER does not
       - There can be scenarios where no checkpoint is justified / finalized for several epochs
     - 
     - **Remark**
       - EBB serves as a better way to formally model safety under asynchronous conditions, (algo. is only probablistically live)
       - Reason being that there is a difference between GASPER / CASPER in which a block may appear as a checkpoint more than once, i.e block tree linearly increasing as new committees propose blocks, nodes may not have been online to finalize / justify checkpoints tho
     - 
    - ### Committees
      - Each epoch ($C$ slots), we divide set $|\mathcal{V}| = V$, into $C$ slots (assume $C | V$), and for each epoch $j, \rho_j: \mathcal{V} \rightarrow C$ (selects committees from val-set randomly)
        - Responsibilities of Committee $C_i$ for slot $i$
          - For epoch $j$, denote $S_0, \cdots, S_{C - 1}$ committees
            - At $d(s) - 1$ a large number of vals joined (green), and the existing validator set purple exits
            - Purple vals cause a fork w/o getting slashed, i.e they all voted to finalize $s$ incrementing dynasty in one fork, then green enters
            - In other fork, they don't reach super-majority until next block
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
            - Only nodes in Committee sign these attestations
              - The $LE$ here is the latest checkpoint block in $chain(B)$, in which case block needs 1 epoch for justification, and 1 more for finalization
                - 2 epochs in total
        - ### Justification
          - Given $B$, define $view(B)$ as the view consisting of $B$ and its dependencies, define $ffgview(B)$ to be $view(LEBB(B))$ (view that Casper operates on) (only finalizes + justifies checkpoints)
              - How does super-majority calculation work if only a commitee votes on blocks?
              - I.e for final block in epoch, not possible to have >2/3 stake voting for SJ link between LJ(B) -> B
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
              - All are adjacent, i.e $B_0 \in chain(B_n)$
        - ### Hybrid LMD GHOST
          - How to determine last justified block in view? We want to make this well-defined
            - $LJ(B) = LE(ffgview(B))$ (i.e frozen at beginning of epoch)
            - $B_j$ changes as new blocks / attestations come in? Want to find version that does not change in middle of epoch
            ![Alt text](Screen%20Shot%202023-08-26%20at%2010.15.19%20PM.png)
          - Intuition sibling blocks can include diff. attestations, suppose one proposer didn't include necessary attestations in block, while other did
        - 
        - ### Slashing conditions
          - No validator makes two distinct attestations $\alpha_1, \alpha_2$, where $ep(\alpha_1) = ep(\alpha_2)$
            - notice, no two attestations are for the same height / epoch
          - No makes two distinct attestations $\alpha_1, \alpha_2$ where
            - $$aep(LJ(\alpha_1)) < aep(LJ(\alpha_2)) < aep(LE(\alpha_2)) < aep(LE(\alpha_1))
          - validator rewards
            - Proposer reward - including attestations in block
            - attester reward - validator rewarded for attesting to block that becomes justified
        - ### Safety
          - In $view(G)$ if $(B_F, f) \in F(G)$, and $(B_J, j) \in J(G)$ where $j > f$, $B_F$ must be an ancestor of $B_J$, or blockchain is $(1/3)$-slashable
            - Suppose so, let $(B_F, f) \rightarrow_J (B_{J'}, j')$, and consider $(B_{F''}, f'') \rightarrow (B_J, j)$
            - Notice, $j > j'$ (otherwise there is a contradiction), since $B_{J} \not= B_{J'}$, similarly for $B_{F''}$, thus $f'' > f$, violating S2
        - **safety**
          - Any pair in $F(G)$ stays in $F(G)$ as view is updated (i.e finalized blocks are not reverted)
            - Follows from def. of finalization
          - If $(B, j) \in F(G)$ then $B$ is in the canonical chain of $G$
            - Notice, all justified checkpoints sprout from latest finalized block, 
            - Must show that no finalized blocks conflict
              - Suppose so, $(B_1, f_1), (B_2, f_2)$ conflict, then one is justified and apply above theorem
      - ### Liveness
        - **plausible**
          - Suppose $slot = i = j * C$, thus $ep(slot) = j$, and first block for epoch $B$, is also EBB $EBB(B, j) = LEBB(B) = B$, thus all votes in epoch have attestation $LJ(B) \rightarrow B$, and $B$ is justified by slot $j + 1$
          - Similar scenario follows to finalize $B$ in slot j + 1
        - **probablistic**
          - assumptions
            - 2/3 honest vals
            - Synchronous messages (i.e messages are delivered w/in $\delta$ of $T$ (time of send))
          - High probability of high weight block in first slot of epoch
          - If high-weight block is found in first slot, subsequent slots increase weight of blocks descending -> high prob of justification (attestations are included in the subsequent blocks)
          - high justification prob -> high finalization prob
      - ### Attestation Inclusion Delay?
        - Prevent attestations being included immediately (want to distribute attestation reward equally amongst vals w/ diff compute circumstances)
      - ### Shard Transitions
        - Packages of txs that attest to data w/in shard
        - Shard data included in beacon-chain state via a **cross-link**
        - Enable not all validators to be responsible for storing all data at all times
          - More scalable architecture
          - Requires nodes storing data to make it available (higher risk of censorship / lower cost-of-quorum attack)
      - Each committee associated w/ a diff shard
      - **block-structure**
        - 
## Why rollup centric architecture?
- Several components to current DApp infra
1. What is the definitive reference to know what the state of the DApp is at any point in time
   1. Where do I definitively check to know how many tokens I have now. Historical state is not relevant here (only on case-by-case basis, and that can be centralized)
   - Where is the final layer for persistence
2. What is the infra required for reliably replicating txs?
   1. tx-ingress + attestation (sequencing). Problem here is Byzantine Atomic Broadcast (i.e BB on order of inputs) (BAB different from SMR?)
   2. tx-execution. What is the process of checking that the proposed final state (assuming well-defined ordering of inputs, and availability of initial state) is correct?
3. w
- One advantage
  - Apps are independently scalable
- Better gas-metering
  - Specific operations introduced
- What happens to ABCI++?
  - Prepare / Process (handled)
  - Vote-Extensions?
    - Signed data from validators based on the incoming proposal (would have to delegate to the sequencer set)
- What is purpose of launching a token then? 
## DA
- **Intuition**
  - Why implement data-availability? (why pre-req for scaling?)
  - More data on L1 -> fewer nodes can participate -> make light-clients able to reliably verify state-transitions
  - I.e consensus + execution proving, w/ sub-linear time message consumption
    - Only need prev. state-root + current-header + attestation to txs
    - Ensure that participating nodes are making the data-available tho (this is to ensure that at least 1 full-node will eventually verify all txs, etc. )
- Make it possible for light-clients to receive and verify fraud proofs of invalid blocks
  - DA proofs also useful for sharding
- Light-clients only verify blocks in accordance w/ consensus-rules (not tx-validity rules)
- merkle-trees / sparse-merkle trees
- **UTXO**
  - Each tx produces outputs that can only be referenced by a future tx once (notes / nullifiers)
- **merkle-trees + SMTs**
  - **SMTs** (use for key-value store (i.e map / state))
    - Pre-determined (extremely large size) capacity, majority of nodes are not filled
    - Default-value determined by level in tree
      - Level 0: default is 0
      - Level 1: default is $H(0, 0) = L_1$
      - Level 2: default is $H(L_1, L_1)$
      - ...
    - SMT enables root-calculation in $O(k * log(n))$ time?
      - Initialize all values to 0
        - Add in $k$ values, and determine hashes up the ladder (log(n)) steps for each value
      - there are $log(n)$ levels,
    - Also enable log(n) non-inclusion proofs
  - **merkle-trees**
    - Use for list of items
- **erasure-code / RS-codes**
  - Given $k$ bits, expand to message of $n >> k$, s.t message can be recovered from $< n$ bits (potentially $k$)?
  - **reed-solomon code**
    - Given $x_1, \cdots, x_n$ generate Lagrange interpolating poly. (over $i = 1, \cdots, n$) where $P(i) = x_i$, has degree $n - 1$
    - Extend $x_1, \cdots, x_n$ to $x_1, \cdots, x_n, x_{n + 1}, \cdots x_{2n}$, where $P(i) = x_i, i > n$, notice, poly can be recovered from any $k$ symbols
  - Can extend code multi-dimensionally
  - **intuition**
    - Concerned abt losing message? Broadcast more bits, and retain higher prob. of message recovery
- **model**
  - chain: $H = (h_0, \cdots, h_n)$ (chain of headers), where  $h_1.prev \rightarrow h_0$, $T_i \in h_i$ (root of txs merkle-tree for $h_i$)
    - Given $S_{i - 1}$ (state after applying all $T_k, k \leq i -1$ in sequence on top of $S_0$), $transition(T_i, S_{i - 1}) = \{S_i, err\}$
      - where $transition(T, err) = err$ (i.e once entered $err$ state, impossible to exit)
- **goal**
  - Convince light-clients of $validity = transition(T_i, S_{i - 1})$ in sub-linear time
    - Trivial w/ linear time, apply all txs. Not reasonable for light-clients? Have to do this verification each block -> full-node
  - Goal eliminate honest-supermajority assumption for tx-validity?
    - Underlying consensus still requires super-majority assumption
- **nodes**
  - Full nodes - vote on blocks, etc. execute all txs in blocks to determine final state
  - Light clients - Only consume headers + apply fork-choice to intermediate blocks (validate consensus-logic)
- **threat model** (strongest form of adversary)
  - blocks can be arbitrarily created (and relayed to light clients)
  - full-nodes may relay bad blocks / withhold information
  - each light-client connected to at least a single full-node
  - Limit threat that dishonest majority of nodes can have
## Fraud Proofs
- **block structure**
  - prev-hash of parent
  - dataRoot - attestation to (tx, intermediate-state-root) in block
  - state-root - root of SMT for state of block-chain
  - dataLength (# of txs)
- **execution-trace**
  - UTXO
    - Keys in map are tx out-put IDS (i.e hash of tx -> outputs)
  - Account-based
    - Keys map to store-values
- Can execute txs
  - Given set of all keys / tx-outputs accessed, and merkle-proofs of inclusion for those keys / values in SMT
  - Can also re-construct new state given siblings up to root (of all children?)
- **data-root**
  - Attestation to list of following form $(tx, inter-state)$
- **proof of invalid ST**
  - light-client accepts a block
  - altruistic full-node creates fraud-proof (i,e shares involved (+ proofs of inclusion)) apply txs on prev-inter-state-root, and check for validity of intermediate state-root
## DA proofs
- **soundness**
  - If light-client accepts block as available, then at least 1 full-node has the full block contents
- **agreement**
  - If an honest light-client accepts a block as available, then all other light-clients will eventually accept the block as available
- Strawman
  - block constructed consisting of $k$ shares, extends to $2k$ shares using RS code
  - light-clients receive block attesting to shares,
    - query
    - For node to make data-unavailable, they must be hiding 50% of the shares
    - thus 1/2^n prob of not encountering query in censored portion
  - What if the node incorrectly constructs the extended data?
    - Only way to verify is to reconstruct original poly. and check
    - Requires all shares anyway
  - **Use 2d-RS code so its easier to verify RS code construction**
      ![Alt text](Screen%20Shot%202023-08-26%20at%207.19.26%20PM.png)
    - Construct a 2d RS code, i.e given $n$ shares, split into matrix of size $\sqrt{n} \times \sqrt{n}$, and extend each row horizontally via RS
      - Extend each column vertically via RS, and extend either horizontally / vertically using RS on extended data'
    - $data_root_i = root(r_1, \cdots, r_k, c_1, \cdots, c_k)$
      - then further extend, s.t each row_root / column_root has $2k$ elements in tree
  - **random sampling in 2d scheme**
    - For any share to be unrecoverable $(k + 1)^2$ shares must be un-recoverable
      - Notice, only half of row / column must be available to re-generate column / row (which also generates values in any intersecting column / rows)
    - **protocol**
      - light-client receives header $h_i$, and $row_root_1, \cdots, row_root_n, col_root_1, \cdots, col_root_n$, checks construction of data_root
      - LC makes queries for random shares in matrix, and checks inclusion proof across row / column roots (does this for $< (n + 1)^2$ iterations)
      - After making first query, LC retrieves $k$ shares from column or row, and reconstructions to ensure data is available
- **fraud proofs**
  - full-nodes can publish to accepting light-clients
- **intuition**
  - Purpose of DA is to enforce that light-clients have the ability to verify execution of transactions
    - To do so
- ## Rollup intuition?
  - Worried abt execution / hosting?
    - I.e I want a Dapp (software that is reliable + verifiably executed)
      - Components (what determines inputs?)
      - How is the execution verified?
        - Validity (need provers, etc.)
        - Fraud Proofs (also complicated)
    - Cloudflare-esque offering for chain-building
      - Why not build on the EVM? utilities are limited, non-existent infra for other shit, i.e governance, token issuance, etc.
## Celestia
- Minimized state on-chain
  - Simply used as a framework for providing data-availability
    - I.e first stage toward making ecosystem amenable to rollup-centric roadmap
- If data-availability is a commodity, what is advanatage of rolling up to ethereum?  
  - Light-client security?
    - Higher prob / more light-clients that are verifying headers, etc. (higher chance of getting fraud proof if one exists?)
- Liveness preserving
- **functional escape velocity**
  - blockchains = maximally simple, infra, shld be unchanging, 
  - layer 2s exist for complex functionality
  - layer 1 needs **functional escape velocity** to permit layer 2 protocols
    - functionality required for optimistic rollups
    - functionality required for zk-validity rollups
  - Need VM (not turing complete, must be able to terminate)
  - 
## Packet bill-board (makes sense)
  - Node operators run sync-chain node + node for all other chains they are validating on?
    - Node operators forced to post packets for each of their chains to sync-chain, also forced to reap packets from sync-chain to other chains
  - Other design (host auction for paths / channels on-chain)
    - 
## Lib p2p
- Peers
  - Each peer subcribes / publishes to a **topic** (consider as sub-net of network)
- **design goals**
  - Reliable, all messages published to a topic are broadcast to all subscribers
  - Speed, messages are delivered quickly 
  - Efficiency bandwidth of network must not be affected by large volume of messages
  - Resilience, peers join + leave network w/o disrupting
  - scale
  - simple
- Discovery
  - DHT (kademlia)
- **Peering** (gossipSub)
  - **connection types**
    - full-message - few connections between each peer (sparsely connected **mesh**)
      - Limit network connection / bandwidth consumption
    - meta-data only
      - densely connected
      - Which messages are available, maintain full-message connections
  - Connections are bi-directional
- Peers keep track of which nodes are subscribed to which feeds
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

## Potential Attacks
- **POW v. POS**
  - Question: Is it possible for POS to have the same security properties as POW w/o deleting network resources...  i.e stake?
    - BFT based POS
    - Chain-based POS
  - Do not require substantial computational effort (feature, not bug?) 
- **Finality**
  - Bitcoin - Block is considered finalized after 5 blocks mined on top, i.e adversary has to create $> 6$ blocks in time it takes network to mine $1$
  - POS - 
    - **Absolute Finality**
      - Block can never be reverted upon finalization -> very hard
        - What happens when set of validators never signing blocks is majority, and validators now receiving block at height earlier (they may have never received this)
      - Account for difficulty with **economic finality**
        - Tendermint -> set genesis validators -> every block post-updates (for next 2 heights), every block must be signed by 2/3 of current validator-set
    - **economic finality**
      - $> 2/3$ must be able to sign block, (current validator set is static for block, thus no other block can be committed, unless > 1/3 of staked validators double sign)
- **Long Range Attacks**
    - User forks from main chain (most likely at ancestor of main-chain), and creates blocks that differ from the main-chain's and eventually over-takes it
      - Unfeasible in POW, i.e cost is prohibitive as user goes farther back
  - **weak-subjectivity**
    - Two nodes to consider (new nodes, re-connecting nodes)
      - Node coming online has no way to determine what the main-chain is (unless they are given a genesis state of the chain, and history of blocks)
    - 
  - **costless-simulation**
    - **nothing at stake** - Validator has nothing to risk when making consensus decision (soluton: force bond)
      - DS -> participate in multiple forks at once
    - 
- **short-range**
  - Re-organize blocks in history of HEAD
- ### Attacks
- **Double Spend**
  - Finalize block w/ spend in one fork
  - Create fork before that block (but later over-taking it), and convince validators to agree on both?
    - Double spend can't be in same history?
- **Sybil**
  - Only applies if each entity has the same weight in voting, i.e one user pretends to be many
- **Race Attack**
  - Takes advantage of block delay for finalization, i.e mine only until tx is finalized, spend, then divert mining power to main chain where spend is no longer canonical
- ## Long-Range Attacks
  - **Simple**
    - Single validator forks genesis (stake will not change in fork branch, and so frequency of proposals is same), adversary fakes timestamps
  - **Posterior Corruption**
    - Multiple validators participate in fork, can be done if a val. on main chain unstakes (no longer disincentive to not participate), 
  - **Stake-Bleeding**
## Martin Van Steen Reading (Traditional Concepts)
- **software architecture**
  - Decomposition of task into sub-components
- **architectures**
  - **layered**
  - **object-based**
  - **resource-centered**
  - **event-based**
### Layered Architectures
- 
# Ethereum Reading
## Core Protocol (Serenity)
- **networking**
- **beacon**
- **roll-out**
## Prysm Implementation
## Looking Forwards
### DAS
### Sharding
### Use of KZG Commits
## Improving Tendermint p2p?
- **concerns**
  - What are factors to consider
    - **bandwidth**
    - How to benchmark?
## Celestia
- Minimize on-chain state
## Purpose of a Rollup?
- Simpler to manage?
  - Maintenance of fraud-proof submission (optimistic)
  - Prover decentralization?
    - How to incentivize multiple nodes to submit validity proofs
- What can be abstracted here?
  - Examples of users
    - MakerDAO
    - DYDX
    - Osmosis
    - Lens
    - Zorra
    - Farcaster
    - 1 inch
- Separate tx execution from ordering / tx-aggregation
  - Ideal properties of sequencer
    - Scalable
    - Censorship-resistance
      - At odds w/ above
  - ePBS
  - PEPC?
- rollup nodes have no introspection into PEPC commitments?
  - IDK? Where to co-ordinate this?
