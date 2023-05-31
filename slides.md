## Languages, Relations, etc.
- An **alphabet**, $\Sigma$ represents a collection of symbols from which you can construct **strings**
  - An example alphabet, being $\{0,1\}$
- A **language** $\mathcal{L}$ over $\Sigma$ represents a collection of strings over $\Sigma$
  - An example language being $\mathcal{L}_n = \{0,1\}^n$ (the set of all integers $< 2^n - 1$)
  - An example string $s \in \mathcal{L}_4$, $s = (1011)$, $s$ is equivalent to $13 \in \mathbb{Z}_{15}$
- Rather than expressing a language $\mathcal{L}$ by enumerating all $x \in \mathcal{L}$, we can define $\mathcal{R} : \Sigma^* \rightarrow \{0,1\}$
    - then $\mathcal{L}_{\mathcal{R}} = \{x \in \Sigma^*: \mathcal{R}(x) = 1\}$
    - Determining whether $x \in \mathcal{L}$ is known as a **decision-problem**
# Interactive Proofs
- **Interactive Proof**
  - Let $f: \{0,1\}^n \rightarrow \{0,1\}$, a **k-message interactive proof system** for $f$, is a probablistic alg. of runtime $poly(n)$, $\mathcal{V}$, and a deterministic prover $\mathcal{P}$, where both $\mathcal{V}, \mathcal{P}$ are given input $x \in \{0,1\}^n$, and $\mathcal{P}$ computes $f(x)$, each party then alternates sending $m_i$ (the output of some internal state-machine (non-deterministic for $\mathcal{V}$)), then at the end of the protocol $\mathcal{V}$ outputs $0,1$ depending on whether $\mathcal{V}$ agrees that $f(x) = y$
    - Denote $out(\mathcal{V}, r, x, \mathcal{P})$ the outcome of the protocol, according to some random input $r$, notice, we may then determine $\mathcal{V}_r$ as a deterministic algorithm
  - **Definition**
    - Let $(\mathcal{V}, \mathcal{P})$ be a pair of verifier / prover alg., then
      - **completeness** - For $x \in \{0,1\}^n$, $Pr_r[out(\mathcal{V}, x, r, \mathcal{P}) = 1] \geq 1 - \delta_c$
        - Intuitively, given a deterministic prover, this determines the rate of false negatives for any $r$
      - **soundness** - For any $x \in \{0,1\}^n$ and any deterministic prover strategy $\mathcal{P}'$, if $\mathcal{P}'$ sends $y \not= f(x)$ at the start of the protocol, then $Pr_r[out(\mathcal{V}, x, r, \mathcal{P}') = 1] \leq \delta_s$
# Ok... but why
- Let's say that Alice (the prover) and Bob (the verifier), want to agree on a complicated language $f$
  - Alice has a really good computer, and Bob has a weak one, but Alice and Bob have a secure channel to communicate
  - Alice and Bob can interact via a prescribed IP for $\mathcal{L} = \{x \in \{0,1\}^*, f(x) = 1\}$, Alice can do all of the work, and Bob (with sufficient prob.) can agree on $\mathcal{L}$
## Graphs + Iso-morphisms
- A graph $G = (V, E)$, where $V = (v_1, \cdots, v_n)$, and $x \in E, x = (v_i, v_k), v_i, v_k \in V$
  - Intuitively, a graph is a collection of vertices $V$, and a set of ordered pairs (edges) of those vertices $E$
    ![Alt text](Screen%20Shot%202023-05-30%20at%2011.13.23%20PM.png)
- Two graphs $G_1 = (V_1, E_1), G_2 = (V_2, E_2)$ are iso-morphic, if there is a function $\phi: V_1 \rightarrow V_2$, where $\forall v_1, v_2 \in V, (v_1, v_2) \in E_1 \iff (\phi(v_1), \phi(v_2) \in E_2$
  - In the above example, $\phi(v_1) = v_1', \phi(v_4) = v_4', \phi(v_3) = v_2', \phi(v_2) = v_5', \phi(v_5) = v_3'$
# Graph Non-Isomorphism IP
- Let's say that Alice + Bob want to agree on the language of graphs that are not iso-morphic to $G_1$
- Then for some graph $G_2$ (Alice and Bob both know $G_1, G_2$)
  - Alice knows whether $G_1 \cong G_2$, Bob does not
- **protocol**
  - Round 1. Bob sends $H \cong G_b$, where $b \leftarrow \{0,1\}$
  - Alice, sends $b' \in \{0,1\}$ to bob as follows
    - If $G_1 \cong G_2$ - Alice chooses $b'$ randomly
    - If $G_1 \not \cong G_2$ Alice chooses $b'$ according to which $G_b \cong H$
  - Bob accepts if $b = b'$
- **proofs**
  - **completeness** - If $G_1 \not \cong G_2$ (i.e $G_1 \in \mathcal{L}_{G_1}$), $\delta_c = 0$, i.e Alice is always able to distinguish $G_1, G_2$
  - **soundness** - If $G_1 \cong G_2$ (i.e $G_1 \not \in \mathcal{L}_{G_1}$), $\delta_2 = 1/2$, i.e Alice chooses $b'$ randomly, so $Pr_{b' \leftarrow \{0,1\}}[b' = b] = 1/2$
- 
# Interlude to Polynomials + Second Interactive Proof
- A polynomial $f(x) = a_0 + a_1x + a_2 x^2 + \cdots + a_n x^n$, has **degree** $n$ (assume $x \in \mathbb{F}_q$, $q$ prime)
  - This means that there are $n$ possible values of $x$ for which $f(x) = 0$ (can prove by induction on $deg(f)$)
- This means that there are only $n$ possible values $x$, where $f(x) = g(x)$, where $f, g$ are polynomials over ($\mathbb{F}_q$, $q$ prime)
  - Take $h(x) = f(x) - g(x)$, $deg(h) \leq max(deg(f), deg(g)) - 1$, and there are only $deg(h)$ possible values for which $f(x) = g(x)$
  - This means that if we choose $\mathbb{F}_q$ to be large, it becomes very unlikely to randomly find an $x$ where $f(x) = g(x)$
- **reed-solomon codes**
  - Given $\{x_0, \cdots, x_k\}$, the **Lagrange Basis Polynomial**  is the **unique** polynomial, $P_{x_i}(X) = \frac{X - x_0}{x_i - x_0} \cdots \frac{X - x_k}{x_i - x_k}$, where $P_{x_i}(x_j) = 1$ iff $x_j = x_i$ and $P_{x_i}(x_j) = 0$ otherwise
  - **Lagrange Interpolating Polynomial** - Given $(x_i)$ (nodes), and $(a_i)$ (targets), $P(X) = \Sigma_i a_i P_{x_i}(X)$
    - **unique** polynomial satisfying $P(x_i) = a_i$
## Interactive Proof
- Suppose Alice + Bob have $(x_i)$ (nodes), and $(a_i)$ (values), and want to know that they have the same $(a_i)$ values
  - Round 1. Alice + Bob both construct LIP for $(a_i)$ and $(x_i)$ ($P_{Alice}, P_{Bob}$), Bob sends some $r \leftarrow \mathbb{F}_q$ to Bob
  - Round 2. Bob sends $\alpha = P_{Bob}(r)$ to alice, Alice accepts iff $\alpha = P_{Alice}(r)$
- **completeness** - If Alice and Bob both have the same $(a_i)$, then $P_{Alice}(r) = P_{Bob}(r)$ (LIP is unique for $(a_i)$), and $\delta_c$ is 0
- **soundness** - If Alice and Bob do not agree on $(a_i)$, where $|(a_i)| = k$, then $Pr_{r \leftarrow \mathbb{F}_q}[P_{Bob}(r) = P_{Alice}(r)] \leq \frac{k}{\mathbb{F_q}}$
# Non-interactive Proofs + Fiat-Shamir Transformations
- What if the IP between Alice / Bob could be a single round?
  - I.e Alice sends Bob $\pi$, and Bob was convinced (with $\delta_c = 0$, and $\delta_s$ as small as possible?)
- In most IPs, Bob sends Alice a **challenge**, a random value that determines the rest of the IP
  - Intuitively, this challenge forces Alice to think on his feet, 
- What if each challenge from Bob was generated by Alice?
  - This is not secure, Alice could generate each challenge from Bob, and construct her messages knowing the challenges... :(
- ## Fiat-Shamir Transformation
  - **EVERY IP CAN BE TRANSFORMED INTO A NON-INTERACTIVE PROOF** (and the $\delta_c, \delta_s$ from the IP are retained)
    - I.e a proof that requires only one round of communication (Alice sends Bob $\pi$)
  - **hash-chaining**
    - Each challenge sent by bob is the output of applying a random oracle seeded by previous messages, 
    - I.e $m_1 = \mathcal{R}(x)$ (first challenge is uniquely determined by input $x$ to IP), $m_i = \mathcal{R}(m_{i - 1})$, here $\mathcal{R}$ = sha-256 (or some other shared random oracle)
## Zero-Knowledge
  - Verifier learns nothing from $\mathcal{P}$ apart from validity of statement being proven
    - Existence of **simulator** - Given inputs to be proved, produces distribution over transcripts indistinguishable from the distribution over transcripts produced when $\mathcal{V}$ interacts with honest prover
  - Let $\mathcal{P}$, $\mathcal{V}$ be a PS, then it is **zero-knowledge** if $\forall, \hat{\mathcal{V}}$ (poly. time verifier), there exists a PPT $S$, where $\forall x \in \mathcal{L}$, the distribution of the output $S(x)$ is indistinguishable from $View(\mathcal{P}(x), \hat{\mathcal{V}}(x))$ (distribution of all transcripts from execution of $\mathcal{P}, \mathcal{V}$)
    - **perfect zero-knowledge** - $S(X), View_{\hat{\mathcal{V}}}(\mathcal{P}(x), \hat{\mathcal{V}}(x))$ are the same (transcripts determined by randomness from $\mathcal{V}$)
    - **statistical zero-knowledge** - the **statistical distance** is negligible, i.e $1/2 \Sigma_{m \in \mathcal{M}}|Pr[S(x) = m] - Pr[View_{\hat{\mathcal{V}}}(x) = m]|$ 
      - i.e given a poly. number of samples from $\mathcal{L}$, the verifier is unable to determine if the distributions are diff.
    - **computational  zero knowledge** -  **statistical distance** can also be defined as max. over all algorithms $\mathcal{A} : D\rightarrow \{0,1\}$ ($D$ is random variable), then $|Pr_{y \leftarrow D_1}[\mathcal{A}(y) = 1] - Pr_{y \leftarrow D_2}[\mathcal{A}(y) = 1]|$
  - **honest** v. **dishonest** verifier zero-knowledge
    - Above definition, requires existence of simulator for all verifiers $\hat{\mathcal{V}}$ (even malicious verifiers)
    - Can also have **honest verifier**, i.e works for prescribed verifier strategy
  - **plain zero-knowledge** v. **auxiliary input zero-knowledge**
    - If $\hat{\mathcal{V}}$ is dis-honest, and may return responses to $\mathcal{P}$ according to some auxiliary input $x$, and a simulator exists $S(x, z)$ (for auxiliary input $z$), then the protocol is satisfies **auxiliary zero-knowledge**
    - Distinction of plain v. auxiliary irrelevant after applying fiat-shamir transform
## Interlude to Group Theory + DLP
  - **group** - Non-empty set $G$ on which a binary operation (group law) $(a, b) \rightarrow ab$ is defined such that
    1. $a, b \in G \rightarrow ab \in G$
    2. $a(bc) = (ab)c$
    3. There exists $1 \in G$, where for all $a \in G, a1 = 1a = a$
    4. $a \in G \rightarrow a^{-1}\in G \land aa^{-1} = a^{-1}a = 1$
  - Group law can be written in two ways
    - Additive groups - $a, b \in G, a + b \in G$
    - Multiplicative groups - $a, b \in G, ab \in G$
  - $\mathbb{Z}_5 = \{0,1,2,3,4\}$ (additive group)
    - $-2 = 3$
  - $\mathbb{Z}_5^* = \{1,2,3,4\}$ (multiplicative grp)
    - $2^{-1} = 3, 4^{-1} = 4$, $1^{-1} = 1$
  - ## Discrete Logarithm Problem (basis of pub-key crypto)
    - Exponentiation in $G$ written, $a \in \mathbb{N}$, $b \in G$, $b^a = b * b \cdots * b (a-times) \in G$ (multiplicative), $b + b + \cdots (a-times) + b \in G$
    - Given $b, b^a \in G$, it is impossibly hard to determine $a \in \mathbb{N}$
# Schnorr Protocol for ZK of DLOG
  - $\mathcal{P}$ (Alice) and $\mathcal{V}$ (Bob) agree on a group element, $g \in G$, and $h = g^w$ (Alice knows $w$, Bob does not)
  - **protocol**
    - $\mathcal{P}$ sends $a = g^r, r \leftarrow^R \{0, \cdots, n - 1\}$ to $\mathcal{V}$
    - $\mathcal{V}$ sends $e \leftarrow^R \{0, \cdots, n - 1\}$ to $\mathcal{P}$
    - $\mathcal{P}$ sends $z =(ew + r)$ to $\mathcal{V}$ checks that $ah^e = g^{z}$
  - Completeness - 
    - $g^z = g^{ew} * g^r = ah^e$, thus $\delta_c = 0$ 
  - Soundness
    - Trust me its low :)
    - Proof requires definition of a $\Sigma$-protocol (this will be defined in part 2.), largely what I want to show here is an example of a simulator
  - Zero-knowledge -
    - Have to fix poly. time simulator $S(h)$, where $e, z \leftarrow \{0,\cdots, n - 1\}$, and $a = g^z(h^e)^{-1}$
    - Notice, transcript of protocol between $\mathcal{P}, \mathcal{V}$ on $h$ is $(a, e, z)$ where $\mathcal{P}$ generates $a = g^u$ at random, $\mathcal{V}$ generates $e$ at random (selection is independent)
    - Alternatively $S(h)$ generates $e, z$ at random, 
# Arithmetic Circuits
- Binary-tree-esque structure, where leaves are the inputs to the circuit, nodes are either multiplication, addition gates, or output gates
## Circuit Satisfiability
- Recall that $\mathcal{L} = \{x  \in \Sigma^* : \mathcal{C}(x) = 1\}$
  - One way to define language, is for $\mathcal{P}$ to prove the **circuit evaluation** of $\mathcal{C}(x) = 1$, then $\mathcal{V}$ knows that $x \in \mathcal{L}$
    - This leads to much deeper circuits (height of binary-tree) -> bad for reasons to come
  - Instead can consider instaces of **circuit satisfiability**
    - Instead of proving evaluation of circuit, $\mathcal{C}(x) = 1$
    - Prove instance of circuit-satisfiability for $\mathcal{C}$, which is 
      - there exists a **witness** $w$, such that on $x$, and $y = 1$, $\mathcal{C}'(x, w) = y$ (where $\mathcal{C'}$ is instance of circuit-satisfiability)
  - IP for $\mathcal{C'}$ (IP for circuit-satisfiability of $\mathcal{C}$) can satisfy **knowledge-soundness**
    - This intuitively means, that if $\mathcal{V}$ accepts on the IP, then $\mathcal{P}$ **knows** a witness $w$
- How are these different?
  - Suppose that Alice + Bob, have a hash-fn $h : \Sigma^* \rightarrow \mathbb{F}_q$, and a desired output $y$,
  - **circuit-satisfiability** - proof only guarantees existence of **witness** $w$, where $h(w) = y$
    - The IP for this proof is trivial, the input-space is infinite, but the output-space is finite (there are infinitely many witnesses)
  - **knowledge-soundness** - Not only does this prove that a witness exists, but it also proves that $\mathcal{P}$ knows a witness $w$
## SNARKS + ZK-SNARKS
 - Using GKR + a polynomial commitment scheme we can get a SNARK for any instance of circuit-satisfiability
   1. $\mathcal{P}$ publishes commitment to MLE of $x \| w$ (intuitively, $\mathcal{P}$ has committed to a specific witness, but hasn't shown $w$ in full)
      - Succint - the opening commitment size is signifincantly smaller than $w$
   2. Evaluate GKR on $\mathcal{C}(x,w)$ (Non-interactive)
      - Notice, $\mathcal{V}$ only needs to open commitment to MLE of $x \| w$ at $log(len(x) + len(w))$ points
 - How to get ZK?
   - Can use specific form of polynomial commitment (KZG), to fully hide the witness $w$
   - $\mathcal{P}$ has created an IP for circuit-satisfiability of any circuit $\mathcal{C}$ while hiding the witness $w$!!!
 - How does a ZK-rollup work?
   - Public input $x$ is the set of transactions (or commitment to them)
   - Private input is execution trace of transactions (likely generated by the sequencer)
     - Notice, the verifier on the DA does not have to know abt. these
   - proof that $\mathcal{C}(x, w) = y$ (where $y$ is resulting state-root), is posted to + verified on the rollup contract on the DA
 - Why use a ZK-SNARK?
   - witness (execution-trace) is huge, sending this is costly, we want this to be as small as possible so it can fit on the blockchain
