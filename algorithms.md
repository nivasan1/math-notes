# Data-Structures
- ## Heap
  - Stored as an array,
``` go
    // node in the heap is analogous to an array index 
    type HeapNode interface {
        Parent() HeapNode
        LeftChild() HeapNode
        RightChild() HeapNode
    }

    type heapNodeImpl struct {
        i int
    }

    func (h heapNodeImpl) Parent() HeapNode {
        // parent is node / 2
        return heapNodeImpl{
            i: h.i >> 1
        }
    }

    func (h heapNodeImpl) LeftChild() HeapNode {
        return heapNodeImpl{
            i: h.i << 1 
        }
    }

    func (h heapNodeImpl) LeftChild() HeapNode {
        return heapNodeImpl{
            i: h.i << 1 + 1
        }
    }

    // can be ordered (min/max-heap)
    type Heap[T comparable] interface {
        Insert(T)
        Remove(T)
        Root()
        // capacity
        Length()
        // number of nodes in heap
        HeapSize()
    }
```
  - ### Properties
      - **max-heap**
        - For each node $i$, $A[Parent(i)] \geq A[i]$
      - **min-heap**
        - For eahc node $j$, $A[Parent(i)] \leq A[i]$
  - **Height** - number of edges on the longest down-part path from node to a leaf
    - Number of elements $[2^{height}, 2^{height + 1}]$
  - **max-heapify**
    - 
# Algorithms
- ## Minimax
  - Goal, given two players $p_1$, $p_2$, with a 
    - For each step in game (WLOG assume $p_1$ goes first), the maximizer $p_1$, chooses the largest value among the set of steps that $p_2$ (the minimizer can play), on even steps the $minimizer$ chooses the minimum the maximizer's moves
    - i.e, the function takes a set of terminal steps, and a boolean of whether the player is a maximizer
    ```go
        // given a set of terminal scores, and whether the final turn is made by the minimizer / maximizer 
        func minimax(scores []int, maximizer bool) int {
            // leafs must be power of 2 (perfect binary tree)
            if !IsPow2(len(scores)) {
                return -1
            }
            // base-case 
            if len(scores) == 1 {
                return scores[0]
            }
            // minimaxed_scores is the scores chosen by the min/max imizer
            minimaxedScores := make([]int, 0)
            // every entry in the array represents a leaf
            j := 0
            var fn func(int, int) int
            for i := 0; i < len(scores); i += 2 {
                if maximizer {
                    fn = min
                } else {
                    fn = max
                }
                minimaxedScores = max(scores[i], scores[i+1])
                j++
            }
            return minimax(minimaxedScores, !maximizer)
        }

        func isPow2(exp int) bool { 
            if exp == 1 {
                return true
            }
            if exp % 2 != 0 {
                return false
            }
            return isPow2(exp >> 1)
        }
    ```
## Divide-And-Conquer
- **Divide**
  - Divide the problem into sub-problems, where each sub-problem is a smaller instance of the larger problem
- **Conquer**
  - Conquer the sub-problems by solving them recursively, or directly
- **combine**
  - Aggregate the solutions to the subproblems into a solution to the larger problem at hand
## Sorting
- `InsertionSort`
  - Takes incremental approach
    - For each element in the array at index `i`, insert into the proper place in `arr[:i+1]`(go)
- `MergeSort`
  - Takes divide-and-conquer approach
  - Divide array into two sub-arrays, sort each array, and merge components together
    - `Merge(A, p,q,r)`
      - Where $p \leq q < r$, and `A[p:q]` sorted, `A[q+1:r]` sorted
      - Merges `A[p:q]` and `A[q + 1:r]` into a sorted list
    - Div + conquer algorithms take
        $$T(n) = a(T(n / b)) + D(n) + C(n)$$
    - If the prob is divided into $b$ chunks, and division of the problem takes $D(n)$, and combining of the probs takes $C(n)$
- **recurrence** - Function defined by the function on smaller inputs
  - **substitution method** - Guess bound, and use mathematical induction to prove guess, i.e $T(m) \leq f(n)$, and prove via induction
  - **recursion-tree method** - Create tree where each node has the constant time value of the recursion step, and sum (usually will be some log. times the constant time step)
  - **master method**
    - Provides bounds for recurrences of form $T(n) = aT(n/b) + f(n)$
  - ## Maximum Subarray Problem
    - Given a timeseries w/ price data, find a pair of points, $t_1, t_2$, where $t_1 < t_2$, and $p(t_2) - p(t_1)$ is maximized
    - Solution, transform array of prices into price-changes -> now problem is find the sub-array with the maximal positive price-change
      - Can find this problem recursively
        - Find maximal sub-array in `arr[low:mid]` and `arr[mid + 1 : high]`
        - then merge both sub-arrays
  - ## Solovay-Strassen
    - Perform weird way of dividing matrices, leading to soln with $T(n) = 7T(n/2) + n^2$ (trick, realizing that shorting recursion tree pays off) (do more matrix additions instead of widening recursion tree)
  - ## Substitution
    - Generate function $f(n)$, and prove that $T(n) \leq f(n)$ for all $n$ by inducting on $n$ 
    - Can also use algebraic manipulation
      - $T(n) = 2T(\sqrt{n}) + lg n$ -> tricky b.c of exponents in $n$, change $n \leq 2^m$ (approximate n by a power of $2$)
        - then $m = log_2(n)$, and $T(2^m) = 2T(2^{m/2}) + m$
        - Have $S(m) = T(2^m)$, then $S(m) = 2S(m/2) + m$, them $S(m) = mlogm$, and $m = lg n$, then 
        - $T(n) = S(m) = mlgm = lg\space mlg\space lg\space m$
  - ## Recursion Tree
    - Each node represents cost of step (without recursive steps)
## Graphs
- Two ways of representing
  - **adjacency list** - For each vertex list other vertices connected
  - **adjacency matrix** - Useful for densely connected graphs (not wasting space on sparse graphs)
![Alt text](Screen%20Shot%202023-04-16%20at%202.32.15%20PM.png)
- **Questions**
  - Given an adjacency list representation of a graph, how long does it take to compute the out-degree (resp. in-degree) of every vertex?
    - Directed graph -> sum of lengths of each $\Sigma_{v \in V} len(adj[v]) = |E|$
      - For non-directed $2|E|$ (each edge in $adj(v)$, is also in $adj[u]$ )
    - Simple 
      - out-degree $len(adj(v))$
      - in-degree
        - For adj. matrix -> $O(V)$
        - For adj. list -> $O(V^2)$ (for each other vertex, search thru all possible edges)
        - 
    - Consider adj-matrix of complete bin-tree on $7$ vertices (7x7) matrix for only 5 edges -> much simpler to store adj. list representation
    - Let $G = (V, E)$, then $G^T = (V, E^T)$, where $E^T = \{(v, u) : (u, v) \in E\}$, i.e directed graph w/ edges reversed
      - For adjacency matrix -> compute matrix transpose $O(V^2)$ operation
      - For adjacency list -> similar complexity
- ## BFS + DFS
  - ## BFS 
    - Given graph + source vertex, computes min distance to each other vertex
    - Produces **breadth-first tree** with $s$ (source vertex) as vertex
      - Discovers all vertices at distance $k$ before discovering vertices at distance $k + 1$
    - **shortest paths**
      - Let $\delta : V \times V \rightarrow \mathbb{Z}$ denote the shortest number of edges traversed between $\delta(u, v)$
        - $s, u, v \in V$, where $\delta(s, u) = n$, and $(u, v) \in E$, then $\delta(s, v) \leq \delta(s, u) + 1$
      - BFS computes shortest paths from $s$ to $v \in V$ for all $v$, by induction on each recursion, 
        - For first time, $n = 1$ -> trivial, for $u \in V, (u, v) \in E$, $\delta(s,  u) = 1$
        - Suppose holds for all $u \in V, \delta(s, u) \leq n$ -> follows from above thm
  - ## DFS
    - Same as BFS but exhaust children first
  - ## Flows
    - 
