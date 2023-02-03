
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
## Theorem Proving in Lean
- Two ways a computer can help in proving 
    - Computers can help find proofs
        - Automated Theorem Proving
    - Computers can help verify that a proof is correct 
        - Resolution Theorem Provers, Tableau theorem provers, FS 
- *interactive theorem provers*
    - Verify that each step in finding a proof is verified by previous theorems / axioms
## Dependent Type Theory
### Simple Type Theory
 - Set theory - construction of all mathematical objects in terms of a set
    - Not suitable for formal / automated theorem proving b.c all objects are classified in terms of sets?
    - Why is this not suitable?
- Type Theory - Each object has a well-defined type, and one can construct more complex types from those
    - If $\alpha, \beta$ are types, then $\alpha \rightarrow \beta$ is the set of all functions mapping objects of type $\alpha$ into objects of type $\beta$, $\alpha \times \beta$ represents the set of all pairs, $(a, b), a : \alpha, b : \beta$
    - $f x$ denotes the application of a function f to x, 
    - $f \rightarrow (f \rightarrow f)$ (arrows associate to the right), denotes the set of all functions mapping $f$ into functions from $f$ into $f$
        - let $h : f \rightarrow (f \rightarrow f)$, then $h$ is a function taking an element $\alpha : f$, and returning a function that returns a function of $f \rightarrow f$ that is determined by $\alpha$
            - Interesting b.c $g : \mathbb{N} \rightarrow \mathbb{N} \rightarrow \mathbb{N}$, may be interpreted as $g(a, b) = c$, where $g(a, b) = h_a(b) = c$ i.e, we are restricting $g$ on one of its inputs (g may represent a parabolic cone, but we are restricting the cone to a line $x = a$ and retrieving a parabola along $x = a$)
        - $p = (a,b) : \alpha \times \alpha, p.1 = a : \alpha, p.2 = b : \alpha$
        - Each type in lean is a type itself, i.e $\mathbb{N} : Type$, and $\mathbb{N} \times \mathbb{N}: Type$ (may mean that $\times$ is a mapping of types into the same type? (what is the type of types (is there a base type?)?))
        - Let $a : \alpha : Type (u) $, then $Type (u) : Type (u + 1)$ Type of type is always a universe of $u + 1$ of the type that elements are in
            - Type hierarchy Functions between types of same type hierarchy are same type hierarchy as type, i.e $Type 1 \rightarrow Type 1 : Type 1$
            - ^^ with cartesian product
        - Types analogous to sets in set theory?
        - $list : Type_{u_1} \rightarrow Type_{u_1}$, functions can be poly-morphic over types, i.e they can be applied to elements of any type hierarchy
        - same thing w/ prod $\times : Type_{u_1} \rightarrow Type_{u_2} \rightarrow Type_{max(u_1, u_2)}$
        - Step of type in hierarchy is known as the universe of the type
### Function Abstraction and Evaluation
 - *Function Evaluation* - Let $f : \alpha \rightarrow \beta$, then $f x : \alpha$ yields an element $b : \beta$, in this case the element $\beta$ is determined by $f$ and $\alpha$
 - *Function abstraction* - In this case fix $a : \alpha$, and $b: \beta$, then the expression $fun x : \alpha, b$, yields a function characterized by $\alpha, \beta$ that yields an object of type $\alpha \rightarrow \beta$
    - In the example above, $x$ is a *bound variable*, replacing $x$ by any other object $: \alpha $ yields the same abstraction, an element of type $\alpha : \beta$
    - Objects that are the same up to *bound variables* are known as *alpha equivalent*
    - lamda expressions are just another way of defining functions, instead of defining the set of ordered pairs that compose the function, one can just describe the cartesian product type that f is a part of (types that f operates on) and their relation
 - 
### Introducing Definitions
- Definition is a diff form of a function definition
- Keyword `def`, brings an object into local scope, i.e `def foo : (N x N) := \lamda x, x + x`, defines an object that is an element of $\mathbb{N}\times \mathbb{N}$
    - Notice, a `def` does not always define a function
- Just like variables can be bound across a lamda function abstraction, variables can be bound in the `def` statement, and used as if they were bound as well, (in this case, the object defined will be a function type)
- `Type*` v. `Type u_1, Type u_2, ...`, `Type*` makes an arbitrary universe value for each instantiation. 
    - ` a b c : Type*` - `a : Type u_1`, `b : Type u_2` (largely used for functions that are type polymorphic), ... 
    - `a b c : Type u_1` - a b c are all in the same type universe
- **QUESTION** - WHAT DOES THE SYMBOL $\Pi$ mean, seems to always appear in $\lambda$ function definitions where there are polymorphic type arguments?
    - $\Pi$ type - The type of dependent functions, 
### Local Definitions
- What does $(\lambda a, t_2) t_1$ mean? Naively, this replaces all occurances of $a$ in $t_2$ (if $a$ is not present $t_2$ is alpha-equivalent to itself before)
    - Nuance: $\lambda a, t_2$, $a$ is a bound variable, and $t_2$ must make sense in isolation
- Local definitions, we could more generally define the above statement as follows `let a := t_1 in t_2`, that statement means that every syntactic match of `a` in `t_2` is replaced by `t_1`
    - More general as $t_2$'s meaning can be determined by the local assignment of `a`
### variables and sections
 - Defining a new constant is creating a new axiom in the current axiomatic frame-work
    - Can assign value of a proof to true, use that proof in another proof. 
    -  Bertrand Russell: it has all the advantages of theft over honest toil.
- **Difference between variables and constants**
    - variables used as bound variables in functions that refer to them i.e (function definition / lamda abstraction)
    - Constants are constant values, any function that refers to a constant is bound to the constants evaluation
- sections limit scope of variables defined in the section
## Namespaces
- Analogous to packages in go
- `namespace ... end`
- can nest namespaces, exported across files
## Dependent Types
 - Dependent types
    - A type that is parametrized by a different type, i.e generics in go / rust, 
        - Example $list \space \alpha$, where $\alpha : Type_{u}$ (a polymorphic type)
        - For two types $\alpha : Type_u, \space \beta : Type_{u'}$, $list \space \alpha$ and $list \space \beta$ are different types
- Define function $cons$, a function that appends to a list
    - Lists are parametrized by the types of their items ($: Type_{u}$)
    - $cons$ is determined by the type of the items of the list, the item to add, and the $list \alpha$ itself
        - I.e $cons \space \alpha : \alpha \rightarrow List \space \alpha \rightarrow List \space \alpha$
            - However, $cons : Type \rightarrow \alpha \rightarrow List \space \alpha \rightarrow List \space \alpha$ does not make sense, why?
                - $\alpha : Type $ is bound to the expression, i.e it is a place-holder for the first argument (the type of the list / element added)
- **Pi type** - 
    - Let $\alpha : Type$, and $\beta : \alpha \rightarrow Type$, 
        - $\beta$ - represents a family of types (each of type $Type$) that is parametrized by $a : \alpha$, i.e $\beta a : Type$ for each $a : \alpha$
        - I.e a function, such that the type of one of its arguments determines the type of the final expression
    - $\Pi (x : \alpha, \beta x)$ - 
        - $\beta x$ is a type of itself
        - Expression represents type of functions where for $a : \alpha$, $f a : \beta a$
            - Type of function's value is dependent upon it's input
    - $\Pi x : \alpha, \beta \space x \cong a \rightarrow \alpha$, where $\beta : \alpha \rightarrow \alpha$, 
        - That is, $\beta : \lambda (x : \alpha) \beta \space x$
            - In this case, the function is not dependent, b.c regardless of the input, the output type will be the same
        - dependent type expressions only denote functions when the destination type is parametrized by the input
            - Why can't a dependent type function be expressed in lambda notation?
    - **cons definition**
        - $list: Type_u \rightarrow Type_u$ 
        - $cons: \Pi \alpha : Type_u, \alpha \rightarrow list \alpha \rightarrow list \alpha$ 
            - $\beta$ is the type of all cons-functions defined over $Type_u$ (universe of all types?)
            - $\alpha : Type_u$, then $\beta : \alpha \rightarrow \alpha \rightarrow list \alpha \rightarrow list \alpha$ 
 - $\Pi$ types are analogous to a bound $Type$ variable, and a function that maps elements of that $Type$ into another type,
    - the $\Pi$ object is then the type of all possible types dependent upon the typed parameter
- **Sigma Type**
    - Let $\alpha : Type$, and $\beta : \alpha \rightarrow Type$, then
    $\Sigma x : \alpha, \beta x$ denotes the set of type 
- **Question: Stdlib list.cons dependent type results in ?**

- Is there any difference between generic types?
    - 
## Propositions and Proofs
- Statements whose value is true or false represented as such $Prop$
    - $And : Prop \rightarrow Prop \rightarrow Prop$
    - $Or : Prop \rightarrow Prop \rightarrow Prop$
    - $not : Prop \rightarrow Prop$
        - Given $p$ we get $\neg p$ 
    - $Implies : Prop \rightarrow Prop \rightarrow Prop$
        - Given $p, q$ we get $p \rightarrow q$
- For each $p : Prop$, a $Proof : Prop \rightarrow Type$, that is $Proof p : Type$ 
    - An axiom $and_commutative$, is represented as follows `constant and_comm : \Pi p q : Prop, Proof (implies (And p q) (And p q))` 
        - Come back to this
    - $Proof$ is a dependent type? 
- Determining that $t$ is a proof of $Prop p$ is equivalent to checking that $t : Proof(p)$
    - Notationally, $Proof p$ is equivalent to $p : Prop$
    - i.e a theorem of type $Proof p$ is equivalent to $thm : p$ (view p as the type of its proofs),
- Type Prop is sort 0 (Type), and $Type_{u}$ is of $Sort u + 1$
- Constructive - Propositions represent a data-type that constitute mathematical proofs
- Intuitionistic - Propositions are just objects (either empty or non-empty), implications are mappings between these objects
## Propositions as Types
- Using proposition in hypothesis is equivalent to making the propositions bound variables in a function definition (proving implications) 
    - Otherwise can use `assume` keyword to avoid lamda abstraction
- Definitions <> theorems
- axiom <> constant
- $\Pi$ and $\forall$ defined analogously
## Propositional Logic
- Bindings 
    1. $\neg$
    2. $\land$
    3. $\lor$
    4. $\rightarrow$
    5. $\leftrightarrow$
## Conjunction
 - `and.intro` - maps two propositions to their conjunction
    - Why is this polymorphic over Prop? Proof type ($p \rightarrow q \rightarrow p \land q$) is dependent upon $p, q$ 
 - `and.elim_left : p \land q -> p` - Gives a proof of $p$ given $p \land q$, i.e $] (`and.right`)
 - `and.elim_left` defined similarly (`and.left`)
 - `and` is a **structure** type
    - Can be constructed through anon. constructor syntax $\langle ... \rangle$
## Disjunction
- `or.intro_left` - $Prop \rightarrow p \rightarrow p \lor q$ (constructs disjunction from single argument)
    - i.e - first argument is the non-hypothesis $Prop$, second argument is a proof of the proposition
    - Dependent type is Proposition of non-hypothesis variable
- `or.intro_right` - defined analogously
- `or.elim` - From $p \lor q \rightarrow (p \rightarrow r) \rightarrow (q \rightarrow r) \rightarrow r$, 
    - To prove that $r$ follows from $p \lor q$ must show that if follows from either $p$ or $q$
- `or.inl` - Shorthand for `or.intro_left`, where the non-hypothesis variable is inferred from the context
## Negation
- $false : Prop$
- $p \rightarrow false : Prop$ - this is known as negation, it is also represented as $\neg p \cong p \rightarrow false$
    - May be contextualized as the set of functions $Proof (p) \rightarrow Proof(false)$? In which case $Proof \rightarrow Proof : Prop$?
        - Reason being $Prop: Sort_0$, set of dependent functions of type $\alpha : Sort_i \rightarrow \beta : Sort_0$, is of type $Sort_0$ (read below in universal quantifier)
    - Interesting that this function type is not an element of $Prop \rightarrow Prop$? This must carry on for other types as well? I.e $x : \alpha$, $y : Type$
- Elimination rule $false.elim : false \rightarrow Prop$? I assume that this is dependent upon the context? But it maps false to a Proof of any proposition
- 
- Think more about what $or.intro_<>$ means (how is the function defined? Is it dependent? Correspondence between $\Pi$ and $\forall$
- Think more about $false.elim$ (same questions as above)
# Logical Equivalence
- `iff.intro: (p -> q) -> (q -> p) -> p <-> q`
    - I.e introductioon 
- `iff.elim_left` - produces $p \rightarrow q$ from $p \leftrightarrow q$ 
- `iff.elim_right` - Similar role
- `iff.mp` - Iff modus ponens rule. I.e using $p \leftrightarrow q$, and $p$ we have $q$
- `iff.mpr` - `iff.mp` but contraverse
## Auxiliary Subgoals
- Use `have` construct to introduce a new expression in under the context and in the scope of the current proof
- `suffices` - Introduces a hypothesis, and takes a proof that the proof follows from the hypothesis, and that the hypothesis is indeed correct
## Classical Logic
- Allows you to use `em `, which maps `\Pi (p : Prop), p \rightarrow Proof (p \or \neg p `(abstracted over the proposition p)
    - Tricke when to know to use $\Pi$, when writing the expression, and the source type for the map is too specific, can generalize over the type of the source type (similar to a for-all statement)
- Also gives access to `by_cases` and `by_contradiction`
    - both of which make use of $p \lor \neg p$ (law of the excluded middle)
## problems 
- $(p \rightarrow (q \rightarrow r)) \iff (p \land q) \rightarrow r$
    - forward direction $p \rightarrow (q \rightarrow r) \rightarrow  (p \land q) \rightarrow r$
        - assume $hpqr$ and $hpaq$
    - reverse direction
- $(p \lor q) \rightarrow r \iff (p \rightarrow r) \land (q \rightarrow r)$
    - reverse direction is easy $(p \rightarrow r) \land (q \rightarrow r) \rightarrow (p \lor q) \rightarrow r$,
        - apply `or.elim` 
            - assume $hprqr:  (p \rightarrow r) \land (q \rightarrow r)$
            - assume $p \lor q$
            - use $hprqr.left / right$
    -  forward direction $(p \lor q) \rightarrow r \rightarrow (p \rightarrow r) \land (q \rightarrow r)$
        - assume $hpqr :(p \lor q) \rightarrow r$
        - apply and
            - assume p / q 
            - construct $p \lor q$
- $\neg(p \iff \neg p)$
# Quantifiers and Equality
## The Universal Quantifier
- How is this similar to $\Pi$
    - Let $a : \alpha : Type$, and denote a predicate over $\alpha$, $ p : \alpha \rightarrow Prop$, thus for each $a : \alpha$, $p a : Prop$, i.e is a different proof for each $a$
        - Thus $p$ denotes a dependent type, (parametrized over $\alpha$)
    - In these cases, we can represent that proposition as, 
        - A proposition that is parametrized by a bound variable $a : \alpha$ 
    - Analogous to a $\Pi$ function from the variable being arbitrated over. Thus the syntax of evaluation still exists .ie
        - $ p q : \alpha \rightarrow Prop$, $s : \forall x : \alpha, p x \land q x \rightarrow ... $, then for $a : \alpha $, $s a : p a \land q a \rightarrow ...$
        - I.e we define an evaluate propositions involving the universal quantifier similar to how we would functions (implications)
- $(\lambda x : \alpha, t) : \Pi x : \alpha, \beta x$, 
    - In this example, if $a : \alpha$, and $s : \Pi x : \alpha, \beta x$, then $s t :\beta t$
- To prove universal quantifications
    - Introduce an assumption of $ha : \alpha$ (initialize arbitrary bound variable in proposition), and prove that proposition holds once applied
- Instead of explicity having to create the propositons by providing bound variables 
    - i.e $s : \forall p, q : Prop, p \lor q \rightarrow p$, this is equivalent to $Prop \rightarrow Prop \rightarrow Prop_{determined by prev types}$ (i.e we need to instantiate the bound variables w/ instances of the propositions / bound variables we intend to use)
    - Alternatively, we implicitly define the bound variables as follows, $s : \{p q : Prop\}, \cdots$, then we can use $s$ out of the box, and the bound variables will be inferred from the context
- example $(h : ∀ x : men, shaves (barber( x)) ↔ ¬ shaves (x, x)) :false := sorry$
    - or.elim on $shaves barber barber
    - have instance of $men$, i.e $barber : men$, instantiate $h barber$, and apply law of excluded middle to $shaves barber barber$
- Let $\alpha : Sort i, \beta : Sort j$, then $\Pi x : \alpha, \beta : Sort_{max(i, j)}$
    - In this case, we assume that $\beta$ is an expression that may depend on type $x : \alpha$
    - This means that, the set of dependent functions from a type to a Prop, is always of the form $\forall x : \alpha, \beta : Prop$
        - This makes Prop impredicative, type is not data but rather a proposition
## Equality relation
- **Recall** - a relation over $\alpha$ in lean is represented as follows, $\alpha \rightarrow \alpha \rightarrow Prop$
- $eq$ is equality relation in lean, that is, it is an **equivalence** relation, given $a b c : \alpha$, and $r : \alpha \rightarrow \alpha \rightarrow Prop$
    - transitive: $r ( a b ) \rightarrow r ( b c ) \rightarrow r ( a c )$
    - reflexive: $r ( a b) \rightarrow r (b a)$
    - symmetric: $\forall a : \alpha, r (a a)$
- $eq.refl \_$
    - infers equalities from context i.e
    - $example (f : α → β) (a : α) : (λ x, f x) a = f a := eq.refl \_$
        - Lean treats all **alpha-equivalent** expressions as the same (the same up to a renaming of bound variables)
            - That means either side of the equality is the same expression
- Can also use $eq.subst {\alpha : Sort_u q, b : \alpha, p : \alpha \rightarrow Prop} : a = b \rightarrow p a \rightarrow p b$
    - i.e - equality implies alpha-equivalence, but has to be asserted and proven via `eq.subst`
-
## Equational Proofs
- Started by key-word $calc$, attempts to prove whatever is in context,  
- `rw` applies reflexivity 
    - `rw` is a tactic - Given some equality, implication can tell the term-rewriter to use `rw <-` to rewrite in opposite direction of implication (or logical equivalance .ie mpr)
## Existential Quantifier
- Written $\exists x : \alpha, p x$, where $\alpha : Sort_u, p : \alpha \rightarrow Prop$, 
    - To prove, $exists.intro$ takes a term $x : \alpha$, and a proof of $p x$
- $exists.elim$, suppose that it is true that $\exists x : \alpha, p x$, where $p : \alpha \rightarrow Prop$, and that $q : p x \land r x$
    - `exists.elim` - Creates a disjunction over all $x : \alpha$, i.e $\lor_{x : \alpha}, p(x)$,
    - Thus, to prove $q$ without identifying the $x : \alpha$, where $p x$ is satisfied, we must prove that $\forall x, q(x)$, assuming $p(x)$, i.e any $x : \alpha$, satisfying
- Similarity between $\exists$ and $\Sigma$
    - Given $a : \alpha$, and $p : \alpha \rightarrow Prop$, where $h : p a$
        - $exists.intro (a, h) : \exists x : \alpha, h$ 
        - $sigma.mk (a, h) : \Sigma x : \alpha, p(x)$
    - First is an expression(Type), characterized by an element of $\alpha$, and a proposition defined by that element
    - Second is similar, an ordered pair of $x$, and a proposition determined by $x$
# Tactics
## Entering Tactic Mode
 - Two ways to write proofs
    - One is constructing a definition of the proof object, i.e introducing terms / expressions, and manipulating those to get the desired expression
    - Wherever a term is expected, that can be replaced by a `begin / end` block, and tactics that can be used to construct the 
 - Tactics
    - `begin` - enters tactic mode
    - `end` - exits tactic mode
    - `apply` - apply the function, w/ the specified arguments
        - Moves the current progress toward goal forwards, but whatever is needed in the next argument, and adds the final construction to the ultimate progress toward goal
        - Each call to apply, yields a subgoal for each parameter
    - `exact` - specifying argument / expression's value
        - Variant of apply. Specifies that the provided term shld meet the requirements of the current goal, i.e $hp : p$, $exact (hp) $ 

## Basic Tactics
- `intro` - analogous to an assumption
    - Introduces a hypothesis into current goal
    - Goal is accompanied by current hypotheses / constructed terms , that exist in the context of the current proof
    - `intros` - takes list of names, introduces hypotheses for each bound variable in proof
- When using `apply` for a theorem / function
    - parameters are passed on the next line (after a comma)
        - Or on the same like w/ no comma
        - Each new-line parameter should be indented (a new `goal` is introduced)
- `assumption` - Looks through hypothesis, and checks if any matches current goal (performs any operations on equality that may be needed)
    - Notice, goal is advanced as proof-terms / tactics are introduced
- `reflexivity`, `transitivity`, `symmetry` - Applies the relevant property of an equivalence relation  
    - More general than using, `eq.symm` etc. , as the above will work for non-Prop types as well
- `repeat {}` - Repeats whatever (tactics) is in brackets
- Apply tactic - Orders the arguments by whatever goals can be solved first, 
    - `reflexivity` / `transitivity` - Can introduce meta-variables when needed
    - If solutions to previous subgoals introduce implicit terms, those can be automatically used to solve subsequent goals
- `revert` - Moves a hypothesis into the goal, i.e 
``` 
thm blagh (p : Prop) : q := ...
```
becomes
``` 
thm blagh (p q : Prop) : p -> q
```
- `revert` contd.
    - Automatically moves terms from the context to the goal. The terms implicitly moved from the context, are always dependent upon the argument(s) to `revert`
- `generalize` - Moves term from goal / context that is determined, to a generalized value i.e 
    ```
        thm ... : 5 = x ---> generalize 5 = x, (now proof is x : \N, x = x) //can be proven by reflexivity
    ```
## More Tactics
- `left` / `right` - analogous to `or.inl` / `or.inr`
- `cases` - Analog to `or.elim`
    - Used after a cases statement: `cases <disjunction> with pattern_matches`
        - I.e this is how the two cases of a disjunction are de-constructed
    - Can be used to de-compose any inductively defined type
        - Example being existentially quantified expressions
    - With disjunction, `cases hpq with hp hq` 
        - Introduces two new subgoals, one where `hp : p` and the other `hq : q` 
- **TIP** - PROOF SYSTEM WILL IMPLICITLY DEFINE VARIABLES IN CONSTRUCTOR
    - All tactics will introduce meta-variales as needed if expressions that depend on those meta-variables can be constructed, 
    - Meta-variables will be constructed whenever possible (possibly implicitly)
- `constructor` - Constructs inductively defined object
    - Potentially has the ability to take arguments as implicit?
- `split`
    - Applies following tactics to both sub-goals in the current context
- `contradiction` - Searches context (hypotheses for current goal) for contradictions
## Structuring Tactic Proofs
- `show` - keyword that enables you to determine which goal is being solved 
    - Can combine w/ tactics
    - Can combine with `from ()` keyword to enter lean proof terms
- It is possible to nest `begin` / `end` blocks with `{}`
## Tactic Combinators
- `tactic_1 <|> tactic_2` - Applies `tactic_1` first, and then `tactic_2` next if the first tactic fails
    - Backtracks context between application of tactics
- `tactic_1;tactic_2`  - Applies `tactic_1` to the current goal
    - Then `tactic_2` to all goals after
## Rewriting
- `rw` - given any equality
    - Performs substitutions in the current goal, i.e given $x = y$, replaces any appearances of $x$ with $y$, for example $f x$ (current-goal) -> $f y$ (goal after rewrite)
    - By default uses equalities in the forward direction, i.e for $x = y$, the rewriter looks for terms in the current goal that match $x$, and replaces them with $y$
        - Can preface equality with $\leftarrow$ (`\l`) to reverse application of equality
    - Can specify `rw <equality> at <hypothesis>`  to specify which hypothesis is being re-written
- 
## Simplifier
- 
## Interacting with Lean
## Inductive Types
- Every type other than universes, and every type constructor other than $\Pi$ is an inductive type.
    - What does this mean? This means that the inhabitants of each type hierarchy are constructions from inductive types
        - Remember $Type_1 : Type_2$, essentially, this means that an instance of a type, is a member of the next type hierarchy 
            - Difference between membership and instantiation? Viewing the type as a concept rather than an object? 
                - _UNIQUE CONCEPT_ - viewing types as _objects_
                    - Similar to this example
                        ```go
                            // the below function is dependent upon the type that adheres to the Interface 
                            func [a Interface] (x a ) {
                                // some stuff
                            }
                        ``` 
                    - In this case, the function is parametrized by the type given as a parameter
                        - In this case, the type `a` is used as an object?
                - 
- Type is exhaustively defined by a set of rules, operations on the type amount to defining operations per constructor (recursing)
- Proofs on inductive types again follow from `cases_on` (recurse on the types)
    - Provide a proof for each of the inductive constructors
- Inductive types can be both `conjunctive` and `disjunctive`
    - `disjunctive` - Multiple constructors
    - `conjunctive` - Constructors with multiple arguments
- All arguments in inductive type, must live in a lower type universe than the inductive type itself
    - `Prop` types can only eliminate to other `Prop`s  
- Structures / records  
    - Convenient means of defining `conjunctive`  types by their projections
- Definitions on recursive types
    - Inductive types are characterized by their constructors
        - For each constructor, the
- recursive type introduced as follows: 
    ```
    inductive blagh (a b c : Sort u - 1): Sort u 
    | constructor_1 : ... -> blagh
    ... 
    | constructor_n : ... -> blagh
    ```
- Defining function on inductive type is as follows
    ```
    def ba (b : blagh) : \N :=
    b.cases_on b (lamda a b c, ...) ... (lamda a b c, ...) 
    ```
    - Required to specify outputs for each of the inductive constructors
    - In each case, each constructor for the inductive type characterizes an instance of the object by its diff. constructed types
- How to do with `cases` tactic? (Hold off to answer later)
    -
- In this case, each constructor constructs a unique form of the inductive type
- `structure` keyword defines an inductive type characterized by its arguments (a single inductive constructor)
```
structure prod (α β : Type*) :=
mk :: (fst : α) (snd : β) 
```
- In the above case, the constructor, and projections are defined (keywords for each argument of constructor in elimination)
- recusors `rec / rec_on ` are automatically defined (`rec_on` takes an inductive argument to induct on)
- Sigma types defined inductively
```
inductive sigma {α : Type u} (β : α → Type v)
| dpair : Π a : α, β a → sigma
```  
- What is the purpose of this constructor?
    - In this case, name of constructor indexes constructor list
    - Recursing on type?
      - How to identify second type?
    - Dependent product specifies a type where elements are of form $(a : \alpha, b \space:\space \beta \space \alpha)$
      - $sigma \space list$? $list \space : Type_u \rightarrow Type_u$
        - Denotes the type of products containing types, and lists of those types?
- Ultimately, context regarding inductive type is arbitrary
    - All that matters are the constructors (arguments)
      - Leaves user to define properties around the types?
- difference between $a : Type\space*$, and $a \rightarrow ...$, the second defines an instance of the type, i.e represents an inhabitant of the type
  - ^^ using type as an object, vs. using type to declare membership
  - What is the diff. between `Sort u` and `Type u`?
    - `Sort u : Type u`, `Type u : Type u+1`
- _environment_ - The set of proofs, theorems, constants, definitions, etc.
  - These are not used as terms in the expression, but rather functions, etc.
- _context_ - A sequence of the form `(a_i : \a_i) ...`, these are the local variables that have been defined within the current definition or above before the current expression
- _telescope_ - The closure of the current _context_ and all instances types that exist currently given the current environment
- 
## Inductively Defined Propositions
- Components of inductively defined types, must live in a unvierse $\leq$ the inductive types
- Can only eliminate inductive types in prop to other values in prop, via re-cursors
  - 
## Inductive Types Defined in Terms of Themselves (Recursive Types)
-  Consider the natural numbers

```
inductive nat : Type 
    | zero : nat
    | succ : nat -> nat
```
- Recursors over the `nat`s Define dependent functions, where the co-domain is determined in the recursive definition
    - In this case, $nat.rec\_on (\Pi (a : nat), C n) (n : nat) := C(0) \rightarrow (\Pi (a : nat), C a \rightarrow C nat.succ(a)) \rightarrow C(n)$, i.e given $C 0$, and a proof that $C(n) \rightarrow C(succ(n))$
- Notice, each function $\Pi$-type definition over the natural numbers is an inductive definition
    - Can also define the co-domain as a $Prop$, and can construct proofs abt structures that are mapped to naturals via induction
- Notes abt inductive proofs lean
    - What is `succ n`?
    - Trick: View terms as `succ n` as regular natural numbers, and apply theorems abt the naturals accordingly
## Mathematics in Lean
### Sets
- Given $A : set \space U$, where $U : Type_u$, and $x : U$, $x \in A$ (`\in` lean syntax), is equivalent to set inclusion
    - $\subseteq$ (`\subeq`), $\emptyset$(`\empty`), $\cup$(`\un`) $\cap$(`\i`)
- $A \subseteq B$, is equivalent to proving the proposition $(A B : set U), x : \forall x : U, x \in A \rightarrow x \in B$ (i.e intro hx, intro hex, and find a way to prove that $x \in B$),
    - **Question** - How to prove that $x \in A$? Must somehow follow from set definition?
- Similarly for equality $\forall x : U (x \in A \leftrightarrow x \in B) \leftrightarrow A = B$
    - *axiom of extensionality*
    - Denoted in lean as `ext`, notice in lean, this assertion is an implication, and must be applied to the `\all` proof
- Set inclusion is a proposition
- $x \in A \land x \in B \rightarrow x$ and $x \in A \cap B$ are definitionally equal
- **Aside** - `left / right` are equivalent to application of constructor when the set of 
- Lean identifies sets with their logical definitions, i.e $x \in \{x : A | P x\} \rightarrow P x$, and vice versa, $P x \rightarrow \{x \in \{...\}\}$
- Use `set.eq_of_subset_of_subset` produces $A = B$, from
    - $A \subseteq B$
    - $B \subseteq A$
- Indexed Families
- Define indexed families as follows $A : I \rightarrow Set \space u$, where $I$ is some indexing set, and $A$ is a map, such that $A\space i := Set \space u$, 
    - Can define intersection as follows $\bigcap_i A \space i := \{x | \forall i : I, x \in A \space i\} := Inter \space A$,
        - In the above / below definitions, there is a bound variable `i`, that is, a variable that is introduced in the proposition, and used throughout,
    - Union: $\bigcup A \space i := \{x | \exists i : I, x \in A \space i\} := Union \space A$, notice, $x \in \bigcup_i A \space i$, is equivalent to the set definition in the lean compiler
        - *I dont know if this is true in all cases*? May need to do some massaging on lean's part
- *ASIDE* - For sets in lean, say $A := \{x : Sort u | P \space x\}$, where $P : Sort_u \rightarrow Prop$, $x \in A \rightarrow P \space x$
    - In otherwords, set inclusion implies that the inclusion predicate is satisfied for the element being included
- *Back to Indexed Families*
- Actual definition of indexed is different from above, have to use `simp` to convert between natural compiler's defn and practical use
- Notice
    - $A = \{x : \alpha | P x\} \space: set\space \alpha := \alpha \rightarrow Prop$, and $P x$ implies that $x \in A$
        - The implication here is implicit, largely can be determined by `simp`?
- Can use `set` notation and sub-type notation almost interchangeably
    - `subtypes` are defined as follows $\{x : \mathbb{N} // P x \}$, thus to construct the sub-type, one has to provide an element $x : \mathbb{N}$, and a proof of $P x$
- **Question**
    - In lean, how to show that where $A = \{x : \alpha| P x \}$, how to use $x \in A$ interchangeably with $P \space x$ 
        - Is this possible? Does this have to be done through the simplifier?
    - Can alternatively resort to using `subtype notation`
        - That is, to prove $\forall x : A, P \space x := \lambda \langle x, hx \rangle, hx$
            - i.e use the set as a sub-type, instantiate an element of the sub-type
                - Explanation - `sub-type` is an inductively defined type, of a witness, and a proof
- Interesting that given set $U =\{x : \mathbb{R} | \forall a \in A, a \leq x\}$, the term $(x \in U) a := a \in U \rightarrow a \leq x$
    - Assume that $A \subseteq \mathbb{R}$ and $U \subseteq \mathbb{R}$
- How to use split?
    - Break inductive definition into multiple constructors?
- Definition of `subtype` 
```
structure subtype {α : Sort u} (p : α → Prop) :=
(val : α) (property : p val)
``` 
equivalent to
```
inductive subtype {α : Type*} (p : α → Prop)
| mk : Π x : α, p x → subtype
```
- **Question**
  - How are they the same?
    - The second definition is the same as the first, why?
  - Object denotes a type (collection of elements)?
    - Possible that val may be arbitrary?
  - I.e subtype inductive definition is composed of a dependent function from some $\alpha$ into props, how to ensure that predicate is satisified?
    - Is this up to implementation?
## Defining Naturals
- What abt cases where constructors act on element being defined? I.e nat
    ```
    inductive nat : Type
    | zero : nat
    | succ : nat → nat
    ```
    - `succ` takes element of `nat`
- Recursor is defined as a dependent function $\Pi (n : nat), C n$, where $C : nat \rightarrow Type*$
  - handle when case is $nat.zero$ and $nat.succ \space n$
  - When $nat.zero$ there are no parameters, can simply specify some value of target type $Type*$ i.e $Prop$
  - Case for $nat.succ$, requires $\Pi (a : nat), C \space a \rightarrow C (nat.succ \space a)$
    - Why is this different from previous examples?
      - In this case, the parameter is an element of the type being defined, as such $\Pi (a : nat), C (succ a)$ does not make sense without assuming that $C (a)$ is defined
- `motive` is a function from the inductive type, to the type being defined
## Recursive Data Types
 - List
 ```
 inductive list (α : Type*)
| nil {} : list
| cons : α → list → list
 ```
- 
# INDUCTIVE TYPES + INDUCTION IN LEAN
 - Recap - Lean uses a formulation of _dependent types_
    - There are several type hierarchies denoted, $Type \space i$, where $i = 0$ implies that the Type is a proposition.
        - There are two mechanisms of composition of types, the first $\Pi x : \alpha, \beta x$ this permits for the construction of functions between types
            - Notice, it is possible that $\beta : \Pi x : \alpha, Type_i$, in this case, the above function represents a dependent type
```
 list.rec :
  Π {T : Type u_3} {motive : list T → Sort u_2},
    motive nil → (Π (hd : T) (tl : list T), motive tl → motive (hd :: tl)) → Π (n : list T), motive n
```
- Assumes an implicit `motive :list T → Sort u_2`
- Takes proof that motive holds for base case
- Takes a definition of a function mapping `hd : T` (element for use in constructor of recursively defined element), `tl : list T` (element for which assumption holds), and a definition for `motive (hd :: tl)` (constructor of succesor of assumption)
## Defining data-structures in lean
 - `list`
 - `binary_tree`
   - Think about making `node : (option_binary tree) (option binary_tree) binary_tree`?
 - `cbtree` (countably branching tree) 
 - **Question**
   - Second constructor takes a function to get its set of children?
     - Can be defined inductively over the naturals
     - Generalized to any number of children per node
 - `heap`?
   - Define sorted types?
## Tactics on Inductive Types
 - 
# STRUCTURES + CLASSES (TYPE CLASSES)
## Type Classes
- Originated in haskell -> associate operations on a class?
    - Receivers + methods? Interfaces?
- Characterizes a _family_ of types
    - Individuals types are _instances_
- Components
    1. Family of inductive types
    2. Declare instances of type-class
    3. Mark implicit arguments w/ `[]` to indicate elaborator should identify implicit type-classes
- Type classes similar to interfaces, use cases similar to generic functions over interface
## Order Relations in Lean
### CROSS CHAIN DEX AGGREGATOR
- Scheduler (encoding arbitrary logic into scheduler)

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
