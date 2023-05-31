## Public Key Crypto
 - Notice, for $p, q \in \mathbb{Z}$, where $(p, q) = 1$, $\phi(pq) = \phi(p)\phi(q)$
   - Proof -> $(a, m) = 1 \rightarrow \exists b \in \mathbb{Z}_m ab \equiv 1 (m)$
     - Notice, $\exists s, t \in \mathbb{Z}, sa + tm = 1 (m) \rightarrow sa \equiv 1 (m)$
   - $(a, m) = 1 \rightarrow a^k \equiv 1 (m)$, notice, for all $k, (a^k, m) = 1$
     - For $k = 1$ the theorem holds, suppose it holds for $n$, then, consider $sa^{n+1} + tm = a$, then $(a^{n+1}, am) = a$, and $(a^{n + 1}, m) = d \rightarrow d | a$, thus $d = 1$
    - If $(a, m) = 1$, and $(a, n) = 1$, then $(a, mn) = 1$
   -  $(k, mn) = 1$, iff $(k, m) = 1$, and $(k, n) = 1$
      -  Reverse - above
      -  Forward - triv
      - Fix $k \leq mn, k = rm + b$, where $r \leq n - 1$, and $b < m$
        - If $(b, m) = 1$, then $(k, m) = 1$ -> otherwise contra using $(k, m) | rm \land (k, m) | b$
        - Notice if $(r, n) = 1$, then $(k, n) = 1$ (similar argument as above), i.e $l | rm \rightarrow l | n \lor l | m$
        - As such there are $\phi(n)$ choices for $r$, and $\phi(m)$ choices for $b$
- ### RSA
  - Features
    - $D: \mathcal{C} \rightarrow \mathcal{M}$, $E: \mathcal{M} \rightarrow \mathcal{C}$, where $\forall M \in \mathcal{M}, D(E(M)) = M$
    - $E, D$ are _easy_ to compute
    - Publicity of $E$ does not comprimise $D$
  - Let $N = pq$, then $(m^{ed}) \equiv m (pq)$, where $N, e$ are the public-key, $N, d$ are the private-key
    - Notice $m^{\phi(N) + 1 = k\phi(p)\phi(q) + 1= (p - 1)(q - 1) + 1} \equiv m (N = pq)$, if $(m, n) = 1$
  - Then $ed = k\phi(N) + 1$, in other-words $ed \equiv 1 (\phi(N))$
- ## Algorithms
  - Multi-precision numeric package
    - I.e store arbitrarily long numbers using (base as `2^64`)
    - Addition / subtraction $O(n)$ where $len(int) = n$
    - Multiplication $O(n^2)$
  - ### Powering Algorithms
    - Given some $g \in G$, we wish to compute $g^n$    
      - Naive: requires $n - 1$ multiplications, i.e $g * g \cdots * g$
      - Faster: $n = \Sigma_i \epsilon_i 2^i$ (where $0 \leq i < log_2(n)$), store $1, g^2, g^4, \cdots$ in memory, then $g^n = \Pi_i \epsilon_i g^{2^i}$
        - This requires only $log_2(n)$ operations
      ``` go
        func Exp(base, exp int) int {
            return exp_(base, exp, 1)
        }

        func exp_(base, exp, accum int) int {
            if exp == 0 {
                return accum
            }
            if exp % 2 == 0 {
                return exp_(base, exp >> 1, accum * accum)
            }
            return exp_(base, exp - 1, accum * base)
        }
      ```
  - ### Euclidean Algorithms
    - **Typical Algorithm**
        ``` go
            func GCD(a, b int) {
                if a < b {
                    a, b = b, a
                }
                if b == 0 {
                    return a
                }
                return GCD(b, a % b)
            }
        ``` 
    - **Lehmer**
      - ...
    - **Binary**
  - ## Euclid Extended Algorithm
    - Let $n, m \in \mathbb{Z}, d = (n, m) \rightarrow \exists s, t, sm + tn = d$
      - EEA - gives the parameters $s, t$ for the **bezout's equality** above
    ``` go
        func ExtendedEuclidean(a, b int) (u, v, d int) {
            // initialize aux variables
            var (
                v_1 = 0
                v_3 = b
                t_1 = 0
                t_3 = 0
            )
            // switch if necessary
            if a < b {
                a, b = b, a
            }
            u = 1
            d = a
            // short circuit if possible
            if b == 0 {
                return u, 0, a
            }
            for v_3 != 0 {
                t_3 = d % v_3
                t_1 = u - (d / v_3) * v_1
                u = v_1
                d = v_3
                v_1 = t_1
                v_3 = t_3
            }
            return u, (d - a * u) / b, d
        }
    ```
- ## Basic Defn.
  - ## Shannon Cipher + Perfect Security
    - **Shannon Cipher**
      - $\Epsilon = (E, D)$ is a pair of functions, where $E : \mathcal{K} \times \mathcal{M} \rightarrow \mathcal{C}$, and $D : \mathcal{C} \times \mathcal{K} \rightarrow \mathcal{M}$
      - Where the following **correctness property** is satisfied, i.e $\forall k \in \mathcal{K}, \forall m \in \mathcal{M}, D(k, E(k, m)) = m$
      - In this case $\Epsilon$ is defined over $\mathcal{K}, \mathcal{M}, \mathcal{C}$ -> these define the concrete spaces of objects that the protocol takes as inputs, i.e $\mathbb{Z}_{p}, 2^{256},\cdots$
    - Using the above SC, $\Epsilon$ Alice + Bob communicate securely by secretly sharing $k \in \mathcal{K}$ (their shared key), and communicating $c = E(k, m) \in \mathcal{C}$ in plain-text 
      - **Concerns**
        - Can Eve intercepting $c$ learn anything abt. $m$ without knowing $k \in \mathcal{K}$?
        - Can Eve tamper with $c$, and make the message to Bob un-intelligible?
    - **one-time pad**
      - Let $\mathcal{M} = \mathcal{K} = \mathcal{C} = 2^L$ (i.e bit-strings of length $L$), and for $m \in \mathcal{M}, k \in \mathcal{K}, c = E(k,m) = m \oplus k$, and $D(k,c) = c \oplus k$
        - Naturally correctness is satisfied, i.e $\forall k \in \mathcal{K}, m \in \mathcal{M}, D(k, E(k, m)) = D(k, m \oplus k) = m \oplus k \oplus k = m \oplus 0^L = m$
    - **substitution cipher**
      - $\mathcal{M} = \mathcal{C} = \Sigma$, $\mathcal{K} = \{f : \Sigma \rightarrow \Sigma: \forall a \in \Sigma, f(f(a)) = a\}$, and $c = E(k, m), c[i] = k(m[i])$, and $D(c, k) = m', m'[i] = k(c[i])$
        - Thus $m' = D(k, E(k, m)), m'[i] = k(k(m[i])) = m[i]$ -> correctness satisfied
    - **Perfect Security**
      - i.e for $c = E(k, m)$ -> how much abt. $m$ can Eve know if she intercepts $c$?
      - Assume that $k \in \mathcal{K}$ is drawn uniformly at random from $\mathcal{K}$, i.e $Pr[X = k] = \frac{1}{|\mathcal{K}}$
      - Want to make it so that attacker's choice of $m$ is independent from $c$
      - ### Definition
        - Let $\Epsilon = (E, D)$ be a SC. Suppose $k \in \mathcal{K}$ is a uniformly random variable sampled from $\mathcal{K}$, then $\Epsilon$ is **perfectly secure** if
          - $\forall m_0, m_1 \in \mathcal{M}$, and $\forall c \in \mathcal{C}$, $Pr[E(k, m_0) = c] = Pr[E(k, m_1) = c]$
      - Let $\Epsilon$ be a PS SC, then the following are equivalent
        - $\Epsilon$ is perfectly secure
        - For every $c \in \mathcal{C}$, $\exists N_c$, such that $\forall m \in \mathcal{M}$, $|\{k \in \mathcal{K}: E(k, m) = c\}| = N_c$
        - For each $m \in \mathcal{M}$, $E(k, m)$ has the same distribution as $\mathcal{K}$
        - Proofs
          - Forward -  Suppose $\Epsilon$ is a PS SC, fix $c \in \mathcal{C}$, fix $P_m = Pr[E(k, m) = c]$ notice $\forall m_0, m_1 \in \mathcal{M}, P_{m_0} = P_{m_1}$, and $N_c = P_m |\mathcal{K}|$
          - Reverse - Fix $c \in \mathcal{C}$, and $m_0, m_1 \in \mathcal{M}$, then $Pr[E(k, m_0) = c] = \frac{N_c}{|\mathcal{K}|} = Pr[E(k, m_1) = c]$
          - Fix $k \in \mathcal{K}$, and $c \in \mathcal{C}$, then $\forall m \in \mathcal{M}, Pr[E(k, m) = c] = P_c = N_c / |\mathcal{K}|$
      - One time pad is PS SC
        - Fix $c \in \mathcal{C}$, and $m_0, m_1 \in \mathcal{M}$, then if $k \in \mathcal{K}$ is sampled randomly the probability that $Pr[E(k, m_0) = c] = Pr[m_0 \oplus k = c] = Pr[k = m \oplus c]$, thus fix $N_c = 1$
    - **Negligible, super-poly, poly-bounded**
      - **negligible** - $f : \mathbb{Z}_{\geq 1 } \rightarrow \mathbb{R}$, if for all $c \in \mathbb{R}$, $\exists N$, where $n \geq N \rightarrow |f(n)| < 1/n^c$, i.e $f$ decreases faster than any polynomial in $n$
      - $f : \mathbb{Z} \rightarrow \mathbb{R}$ is negligible iff $lim_n f(n)n^c = lim_n f(n) lim_n n^c = lim_n 1/n^c lim_n n^c = 0 * lim_n n^c = 0$
        - Reverse - Suppose $lim_n f(n)n^c = 0$, 
    - Is $\frac{1}{n^{log(n)}}$ negligible?
      - Fix $c \in \mathbb{R}$, and choose $N > 2^c, log(N) > c$, then $n \geq n \rightarrow \frac{1}{n^{log(n)}} < \frac{1}{N^{log(N)}} < \frac{1}{n^c}$, thus it is negligible
    - Let $\Epsilon = (E, D)$ be SC defined over $(\mathcal{K}, \mathcal{M}, \mathcal{C})$, then $\Epsilon$ is PS iff for any $\phi : \mathcal{C} \rightarrow \{0,1\}$, $\forall m_0, m_1 Pr[\phi(E(k, m_0))] = Pr[\phi(E(k, m_1))]$
      - Forward - Suppose $\Epsilon$ is PS, fix $C \subset \mathcal{C}$, where $c \in C \rightarrow \phi(C)$, then $Pr[\phi(E(k, m_0))] = \Sigma_{c \in C} Pr[E(k, m_0) = c] = \Sigma_{c \in C} Pr[E(k, m_0) =c] = Pr[\phi(E(k, m_1))]$
      - Reverse - 
        - Suppose $\forall m_0, m_1, Pr[\phi(E(k, m_0))] = Pr[\phi(E(k, m_1))]$, suppose $\Epsilon$ is not PS, then $\exists c \in \mathcal{C}$ where $Pr[E(k, m_0) = c] \not= Pr[E(k, m_1)]$, and define $\phi(c') = 1 \iff c' = c$ (contradiction)
    - Also equivalent $Pr[M = m | E(K, M) = c] = Pr[M = m]$
      - Apply bayes and that each value is uniformly distributed
    - **Shannon's Theorem**
      - Let $\Epsilon = (E, D)$ be shannon-cipher, $\Epsilon$ is PS iff $|\mathcal{K}| \geq |\mathcal{M}|$
        - Suppose $|\mathcal{K}| < |\mathcal{M}|$, WTS, fix $k \in \mathcal{K}$, then $\exists m_0, m_1$, where $Pr[c = E(k, m_0)] \not= Pr[c = E(k, m_1)]$ (i.e $m_0, m_1$ under $k$ are distinguishable)
        - Let $S = \{D(k, E(k, m)), m \in \mathcal{M}\}$, thus, there exists $m_0, m_1$ where $E(k, m_0) = E(k, m_1)$, then consider $Pr[M = m | E(K, M) = c] = Pr[M = m]$
        - Alternatively, fix $k \in \mathcal{K}, m \in \mathcal{M}$, then consider $S = \{D(k', c = E(k, m)), k' \in \mathcal{K}\}, |S| = |\mathcal{K}| \leq |\mathcal{M}|$
          - Since $(E, D)$ is Shannon-Cipher, $D(k, E(k, m)) = m$, if $m' \in \mathcal{M}\backslash S$, then $D(k, E(k, m')) \in S$ (contradiction), and $c \not= E(k, m')$ (thus $(E, D)$ is not perfectly secure)
  - ## Computational Ciphers + Sematic Security
    - Shannon's Thm -> $|\mathcal{K}| \geq |\mathcal{M}|$ (space of bit-sequences length of keys > length of messages)
      - **semantic security** - Force indistinguishability under computationally bounded adversaries (lessen requirement from perfect-security) (also lessen requirement of shannon-cipher? Equality of message probablistic, concurrrently send multiple messages?)
    - **computational cipher** - Let $\Epsilon = (E, D)$ (definition is analogous to shannon-cipher), $E$ is a probablistic algo.
      - **correctness**, let $c \leftarrow^{R} E(k, m) \rightarrow m = D(k, c)$
        - Thus **CC** -> **SC**, but not vice-versa
    - **semantic security**
      - For all predicates $\phi : \mathcal{C} \rightarrow \{0,1\}$, $|Pr[\phi(E(k, m)) = 1] - Pr[\phi(E(k, m')) = 1] \leq \epsilon|$ (where $\epsilon$ is negligible)
    - **attack games** - Consider a game between $\mathcal{P}$ (adversary), and $\mathcal{V}$ (challenger) multiple rounds of interaction, advantage is probability space that $\mathcal{V}$ incorrectly accepts the final value output from $\mathcal{P}$
    - ### Semantic Security Attack Game
      - Define two experiments $b \in \{0,1\}$
      - Experiment $b$
        - $\mathcal{P}$ sends $m_0, m_1 \in \mathcal{M}$ to $\mathcal{V}$
        - $\mathcal{V}$ computes $k \leftarrow^R \mathcal{K}, c \leftarrow^R E(k, m_b)$, and sends $c$ to $\mathcal{P}$
        - $\mathcal{P}$ outputs $\hat{b} \in \{0,1\}$
    - **semantic security advantage** - Let $W_b$ be $\hat{b}$ in experiment $b$, then $|Pr[W_b = 1] - Pr[W_0 = 1]|$
      - $(E, D)$ is **semantically secure** iff $SSadv[\mathcal{P}, \mathcal{E}] \leq \epsilon$ (where $\epsilon$ is negl.)
      - Can consider $\mathcal{P}$ as evaluating any $\phi$ (predicate on $c$)
- ## Computational Security
  - 
- ## New Directions in Crypto.
    - Initially - Key must be known between each user
        - Attacks
        - **cipher-text only** - Attacker only has cipher text of a message
        - **known plaintext attack** - attacker has cipher-text + plain-text mappings -> want to determine $S_k$ -> encryption function
        - **chosen plaintext attack** - Attacker can send own plain-text, and receive cipher-text of that plain-text (hardest to over-come)
        ![Alt text](Screen%20Shot%202023-05-07%20at%2010.01.43%20PM.png)
            - Above diagram details conventional (shared-key) crypto. i.e transmitter and receiver have secure channel to communicate key, and open channel to communicate message
    - **public-key**
        
        ![Alt text](Screen%20Shot%202023-05-07%20at%2010.02.55%20PM.png)
        - **pk distribution** -> signatures, i.e receivers know who the transmitter was that sent message (using only public info)
        - **pk cryptosystem** -> More complex - Secure channel using only public information -> only transmitter / receiver can verify
        - Definitons
- **problems**
  - Suppose Alice / Bob send messages over a channel, where Eve intercepting each bit observes $b$ with prob. $p$, and $1 - b$ with prob. $1 - p$
- ## One Way Functions
- ## PRGs
- ## Computational Security
  - 
# Proofs, Arguments, and Knowledge
- Suppose Alice / Bob, have files $a_i \in \{0,1\}$, $b_i$ and wish to know whether the files are equal
  - Simplest protocol: send all bits, $O(n)$ complexity (arbitrarily large)
- Simpler protocol, choose $\mathcal{H}$ a set of hash functions, where
  - $\forall x, y, Pr_{h \in \mathcal{H}}[h(x) = h(y) | x \not= y] \leq negl(x)$
- For example, take $h_r(a) = \Sigma_i a_i r^i \in \mathbb{F}_p$
  - then if $a_i \not= b_i$, $Pr[h_r(a) \not= h_r(b)] = 1 - \frac{n}{p} \leq 1 - 1/n$ (notice, this hash function is not actually secure)
- If $p_a, p_b \in \mathbb{F}_p[X]$, then $p_a(x) = p_b(x)$ for at most $n$ distinct $x$
  - Notice $deg(p_a - p_b) \leq n$
# Definitions + Technical Prelims
- **Interactive Proof**
  - Let $f: \{0,1\}^n \rightarrow \mathcal{R}$, a **k-message interactive proof system** for $f$, is a probablistic alg. of runtime $poly(n)$, $\mathcal{V}$, and a deterministic prover $\mathcal{P}$, where both $\mathcal{V}, \mathcal{P}$ are given input $x \in \{0,1\}^n$, and $\mathcal{P}$ computes $f(x)$, each party then alternates sending $m_i$ (the output of some internal state-machine (non-deterministic for $\mathcal{V}$)), then at the end of the protocol $\mathcal{V}$ outputs $0,1$ depending on whether $\mathcal{V}$ agrees that $f(x) = y$
    - Denote $out(\mathcal{V}, r, x, \mathcal{P})$ the outcome of the protocol, according to some random input $r$, notice, we may then determine $\mathcal{V}_r$ as a deterministic algorithm
  - **Definition**
    - Let $(\mathcal{V}, \mathcal{P})$ be a pair of verifier / prover alg., then
      - **completeness** - For $x \in \{0,1\}^n$, $Pr_r[out(\mathcal{V}, x, r, \mathcal{P}) = 1] \geq 1 - \delta_c$
        - Intuitively, given a deterministic prover, this determines the rate of false negatives for any $r$
      - **soundness** - For any $x \in \{0,1\}^n$ and any deterministic prover strategy $\mathcal{P}'$, if $\mathcal{P}'$ sends $y \not= f(x)$ at the start of the protocol, then $Pr_r[out(\mathcal{V}, x, r, \mathcal{P}') = 1] \leq \delta_s$
    - and IP is valid if $\delta_s, \delta_c \leq 1/3$
- **Argument System**
  - IP where **soundness** only desired to hold against polynomially bounded prover - **computational soundness**
- **Intuition**
  - Why error tolerance $1/3$?
    - Valid IP can be transformed into IP with perfect Verifier, i.e $\delta_c = 0$
  - Why restrict $\mathcal{P}$ to be deterministic? Suppose $\mathcal{P}'$ exists, where with $p < 1$ prob. $out(\mathcal{V}, x, r, \mathcal{P}') = 1$, then set $\mathcal{P}_r$ (deterministic) as $\mathcal{P}$
- **Schwartz-Zippel**
  - Let $\mathbb{F}$ be a field, and $g : \mathbb{F}^m \rightarrow \mathbb{F}$, be a non-constant $m$-variate poly. of total deg $d$, then $Pr_{x \leftarrow S^m}[g(x) = 0] \leq d/|S|$
    - Take $S = \mathbb{F}$, then $Pr[p(X) = g(X)] = d/|\mathbb{F}|$, i.e $g - f \in \mathbb{F}^m[X]$, and $deg(g - f) \leq d$
- **Low degree and Multi-linear extensions**
  - Notice, given an input set $I = \{0, 1, \cdots, n-1\}$, and a function $g : I \rightarrow \mathbb{F}_p$, one can construct the lagrange interpolation poly. $f$ over $\mathbb{F}_p$, of degree $n - 1$, where $g(x) = f(x)$
  - One can also construct the low-degree extension, $\tilde{g} : \{0,1\}^v$, where $v = log(n)$
    - $g$ is multi-linear poly. - that is $deg(\tilde{g}) = v$ (product of $g_x : \{0,1\} \rightarrow \mathbb{F}_p, deg(g_x) = 1$)
      - Lower degree = fewer field mult. = faster evaluation
  - Univariate extension looks like this $P_x = \Pi_{y \in \mathbb{Z}_n \backslash x} \frac{X - y}{x - y}$, then $P_x(z) = 0 \iff z \not= x, P_x(z) = 1 \iff z = x$, then $f_g(X) = \Sigma_{x \in \mathbb{Z}_n} g(x)P_x(X)$
    - Notice, $deg(f_g) = n - 1$
- **multilinear poly** - Let $g(x_1, \cdots, x_n) = \Sigma_i a_i \Pi_i x^{j_i}, j_i = 1$, i.e $g(x_1, x_2) = x_1 + x_2 + x_1x_2$ is multi-linear, $g(x_1, x_2) = x_2^2$ is not
- **extension**
  - Let $f : \{0,1\}^n \rightarrow \mathbb{F}$ be a function, then the multi-linear extension, $g : \mathbb{F}^n \rightarrow \mathbb{F}$ is an extension, if $g(x) = f(x)$, i.e for $g$, take $x$ as $0_{\mathbb{F}}, 1_{\mathbb{F}}$
    - Extension is **distance-amplifying** - according to **schwartz-zippel**, if $f, f' : \{0,1\}^n \rightarrow \mathbb{F}$ dis-agree anywhere, then $g, g' : \mathbb{F}^n \rightarrow \mathbb{F}$ dis-agree w/ prob $1 - d/|\mathbb{F}|$ (make size of $\mathbb{F}$ extremely large, and randomly sample evaluations)
    - Utility, if $f, f'$ are the same, then expect $g, g'$ to be the same, otherwise, expect them to differ in $|\mathbb{F}| - d$ points
- ### Let $f : \{0,1\}^v \rightarrow \mathbb{F}$ has a unique multi-linear extension over $\mathbb{F}$
  - **existence** - Let $f : \{0,1\}^v \rightarrow \mathbb{F}$, then $\tilde{f}(x_1, \cdots, x_v) = \Sigma_{w \in \{0,1\}^v}f(w) \chi_w(x_1, \cdots, x_v)$, where for $w = (w_1, \cdots, w_v), \chi_w(x_1, \cdots, x_v) = \Pi_{1 \leq i \leq v} (x_iw_i + (1 - x_i)(1 - w_i))$
    - $\tilde{f}$ extends $f$
    - $\chi(w)$ is defined as the multi-linear lagrange basis poly.
    - Notice for $\chi_w(w) = 1$, and $\chi(y) = 0$, $w \not = y$
    - Furthermore $\chi_w$ is multi-linear, sum of multi-linear is also multi-linear
  - **uniqueness**
- **problems**
  - 
- ## Interactive Proofs
  - ### Sum-check Protocol
    - Given $v$-variate poly. $g : \{0,1\}^v \rightarrow \mathbb{F}$, prover / verifier want to agree on $\Sigma_{0 \leq i \leq v} \Sigma_{b_i \in \{0,1\}} g(b_1, \cdots, b_v)$ (sum of evaluations of $g$ across all possible inputs)
      - Given $g$, verifier can evaluate $g$, $2^v$ times (worst-case), prover = verifier
    - **protocol**
      - Round 0. $\mathcal{P}$ sends $C = H_g$ to $\mathcal{V}$
      - Round 1. $\mathcal{P}$ sends $g_1(X_1) = \Sigma_{x_2, \cdots, x_v \in \{0,1\}} g(X_1, x_2, \cdots, x_v)$ (univariate)
        - $\mathcal{V}$, checks that $C = g_1(0) + g_1(1)$, and that $deg(g_1) = deg_1(g)$, where $deg_i(g) = deg(g(X_1, \cdots, X_v))$ (in variable $X_1$, i.e fix all other variables to be fixed values in $\{0,1\}$)
        - $\mathcal{V}$ sends $\mathcal{P}$, $r_1$
      - Round $j$. where $1 < j < v$
        - $\mathcal{P}$ send $g_j = \Sigma_{v_{j+1}, \cdots, x_v \in \{0,1\}} g(r_1, \cdots, r_{j-1}, X_j, x_{j+1}, \cdots, x_v)$
        - $\mathcal{V}$ checks that $g_{j - 1}(r_j) = g_j(0) + g_j(1)$, and that $deg(g_j) \leq deg_j(g)$
        - $\mathcal{V}$ sends random $r_j$ to $\mathcal{P}$
      - Round $v$
        - Same as $j$, except that $g_v(r) = g(r_1, \cdots, r_v)$
    - **intuition**
      - Notice, both $\mathcal{P}, \mathcal{V}$ agree on value of $g$, thus given $g_1$ from $\mathcal{P}$, and that $g_1(0) + g_1(1) = C$, how to prove that $g_1$ actually is evaluated correctly? $\mathcal{V}$ if doing brute-force, would have to evaluate $2^{v - 1}$ variables in $g$?
        - Instead re-cursively apply sum check, i.e start again with $g_1 = g$, and continue
    - **correctness**
      - **completeness** - If $\mathcal{P}$ evaluates $g$ correctly, and sends $C$, the protocol is always correct
      - **soundness** - Protocol gives false positive with error $dv/|\mathcal{F}|$
        - Notice, if in any of the rounds, $\mathcal{V}$ accepts an incorrect evaluation, then $\mathcal{P}$ can extrapolate the incorrect evaluations to later, rounds (sum-check with $g$ controlled by $\mathcal{P}$), prob that $Pr[g_i(x) = s_i(x)] = deg_i(g)/\mathcal{F}$, thus take union over all rounds to get $dv/|\mathcal{F}|$
  - ## Application of sum-check: $\#SAT \in IP$
    - **boolean formula** - Formula over $n$ variables, with $2^n$ nodes, and $log(n)$ height. Represented with input in leaves, each parent is product of $\land, \lor$ over children
    - $\#SAT$ - Given boolean formul $\phi : \{0,1\}^N \rightarrow \{0,1\}$, determine number of satisfying values, in other words, $\Sigma_{x \in \{0,1\}^n} \phi(x)$
    - Determine **extension** of $\phi$ and apply sum-check, then $\tilde{\phi} : \mathbb{F} \rightarrow \mathbb{F}$, $\mathbb{F}$ must be chosen so that the error prob -> $deg(\phi)n /|\mathbb{F}|$ is negligible
    - Determining extension from $\phi$ is **arithmetization**
      - $x \land y := xy$, $x \lor y := x + y - xy$
  - ## GKR
    - Notice for $\#-SAT$ although the verifier runs in poly. time, the $\mathcal{P}$ prover must still evaluate the sum in time-exponential in the inputs (likely impossible for reasonable size)
    - $\mathcal{P}$ and $\mathcal{V}$ agree on a log-space uniform arithmetic circuit of **fan-in** two (i.e the underlying boolean formula, leaf-nodes can have more than one parent (can be inputs to more than one parent ))
      - Log-space uniform -> implies that $\mathcal{V}$ can gain accurate under standaing w/o looking at all of $\mathcal{C}$, thus complexity can be logarithmic in $gates(\mathcal{C})$, and logarithmic in $inputs(\mathcal{C})$
      - $\mathcal{P}$ prover complexity linear in $gates(\mathcal{C})$ (significant improvement to $\#-SAT$)
    - **protocol**
      - **intuition** - Circuit represented as a binary tree, with each top-level being an arithmetic (multi-variate poly.) in the gate-outputs from the level-beneath, goal, prover sends all evaluations, then iteratively applies sum-check at each depth (correctly verify that gate values at each level are evaluated), until the inputs are checked ($O(1)$ check per input by $\mathcal{C}$)
      - $\mathcal{P}$, $\mathcal{V}$ agree on LSU circuit $\mathcal{C}$ -> arithmetic circuit represented as $g : \mathbb{F}^n \rightarrow \mathbb{F}$, where $size(\mathcal{C}) = S$, and $d = depth(\mathcal{C})$ (layers), $S \leq 2^d$?
        - $0$ is output, $d$ is input layer, let $S_i$ be the number of gates at layer $i$, where $S_i = 2^{k_i}$
        - $W_i : S_i \rightarrow \mathbb{F}$ - I.e a function mapping a gate at layer $i$ to its output
          - Dependent upon the inputs to circuit? I.e actually a ML poly. in inputs $x_i$?
        - Let $in_{i, 1}, in_{i, 2} : S_i \rightarrow S_{i + 1}$, where $in_{i, 1}$ returns the left child of $a$, and $in_{i, 2}$ returns right child of $a$, notice, inputs to gates at $i$ will be at layer $i + 1$
    - ### Algorithm
      - Protocol has $d$ iterations (one for each layer of circuit)
      - Let $\tilde{W_i} : \mathbb{F}^{k_i} \rightarrow \mathbb{F}$ -> MLE (multi-linear lagrangian extension of $W_i$), means that it is distance encoding, so $\mathcal{P}$ sends $\mathcal{V}$, $\tilde{W_i}(r)$ for some random $r \in \mathbb{F}$
        - Then $\mathcal{V}$ chooses $r_i \in F^{k_i}$ to be evaluated, and $\mathcal{P}$ sends $\tilde{D_i}(r)$, verifier checks that $\tilde{W_i}(r) = \tilde{D_i}(r)$
        - However, does $\mathcal{V}$ evaluate $\tilde{W_i}(r)$ itself? Requires evaluation at all layers $1 \leq j \leq i$ exponential run-time? No, recursively checks that $\tilde{W_i}$ by reducing to claim abt $\tilde{W_{i + 1}}(r)$ until reduced to claim abt. inputs
      - How to reduce evaluation of $\tilde{W_i}(r)$ to $\tilde{W}_{i + 1}(r)$?
        - $\tilde{W}_i(z) = \Sigma_{b,c \in \{0,1\}^{k+1}} \tilde{add}_i(z,b,c)(\tilde{W}_{i + 1}(b) + \tilde{W}_{i + 1}(c)) + \tilde{mult}_i(z, b, c)(\tilde{W}_{i + 1}(b)\tilde{W}_{i + 1}(c))$
        - Notice, above is still a MLE, (composition of addition / multiplication of MLEs from lower layer)
      - Thus apply **sum-check** to $\tilde{W}_i$
        - i.e start with $f_{r_i}(b,c) = \Sigma_{b,c \in \{0,1\}^{k + 1}} \tilde{add}_i(r_i, b, c)(\tilde{W}_{i + 1}(b) + \tilde{W}_{i+1}(c)) + \tilde{mult}_i(r_i, b,c)(\tilde{W}_{i + 1}(b)\tilde{W}_{i+1}(c))$
          - i.e at each round sum is over $2^{k + 1}$ values, and takes $2$ rounds (fix $b$, then $c$), then have to evaluate $\tilde{W}_{i + 1}(b), \tilde{W}_{i + 1}(c)$ (rely on next round, but how to take $b^*, c^*$ into accout for random value?)
      - Reduce verification to single point, let $l : \mathbb{F} \rightarrow \rightarrow F^{k + 1}$, where $l(0) = b^*$, and $l(1) = c^*$ (unique), then evaluate $q : \mathbb{F} \rightarrow \mathbb{F} = \tilde{W}_{i + 1} \circ l$, $\mathcal{P}$ sends $q$ to $\mathcal{V}$, and checks that for random $r^* \in \mathbb{F}^{k + 1}$, $q(r^*) = \tilde{W}_{i + 1} \circ l (r^*)$
      - Next iteration starts with $r_{i + 1} = l(r^*)$
      - **GKR** -> see gkr.png
        - Round 0: $\mathcal{P}$ sends $D : \{0,1\}^{k_0} \rightarrow \mathbb{F}$ (outputs of circuit), $\mathcal{V}$ computes $\tilde{D}(r_0) = m_0$, where $r_0$ is randomly sampled from $\mathbb{F}^{k_0}$
        - Round $0 < i \leq d - 1$
          - Let $f_{r_i}(b, c) = \tilde{add}_i(r_i, b, c)(\tilde{W}_{i + 1}(b) + \tilde{W}_{i + 1}(c)) + \tilde{mult}_i(r_i, b, c)(\tilde{W}_{i + 1}(b)\tilde{W}_{i + 1}(c))$
          - $\mathcal{P}$ claims that $m_i = \Sigma_{b,c \in \{0,1\}^{k_{i + 1}}} f_{r_i}(b, c) = \tilde{W}_i(r_i)$
            - $\mathcal{V}$ / $\mathcal{P}$ perform sum-check to verify $m_i$, and $\mathcal{V}$ is forced to evaluate $b^*, c^* \in \mathbb{F}^{k_{i + 1}}, \tilde{W}_{i + 1}(b^*), \tilde{W}_{i + 1}(c^*)$
          - then $\mathcal{V}$ determines $l : \mathbb{F} \rightarrow \mathbb{F}^{k_{i + 1}}$, $l(0) = b^*, l(1) = c^*$, and expect $\mathcal{P}$ to send $q = \tilde{W}_{i + 1} \circ l$
            - $\mathcal{V}$ verifies $q$, by evaluating $q(0) = \tilde{W}_{i + 1}(b^*)$ (similarly for $c^*$)
          - then round $i + 1$ starts, where $m_{i + 1} = q(r_{i + 1} = l(r^*))$, $r^*$ is randomly sampled
- # How to transform IP to PVPQ
  - Given an $IP$, $\mathcal{P}, \mathcal{V}$, how to construct a publicly verifiable protocol (that is non-interactive)?
  - **IP**
    - $\mathcal{P}$ sends $m_0$ to $\mathcal{V}$, $\mathcal{V}$ sends $(m_1 \leftarrow M_i(m_i))$ to $\mathcal{P}$ i.e $\mathcal{V}$'s response is application of non-deterministic algorithm (random in variable $M$)
    - What if $\mathcal{P}$ posted trace w/ random evaluations? How to determine that each random value is not dependent upon previous ones chosen by $\mathcal{P}$, if $\mathcal{P}$ knows set of random values.. they can construct solutions before-hand and post incorrect traces
  - **example**
    - Let $\mathcal{P}$ be a dis-honest prover, and $s$ be the correct poly. that should be agreed on. If $\mathcal{P}$ knows what $r_1$ should be, then $\mathcal{P}$ can send, $g$, where $C = g_1(0) + g_1(1)$, where $g_1(r_1) = s_1(r_1)$
  - **Fiat-Shamir Transform**
    - **hash-chaining** - Every random-oracle output is derived from the $\mathcal{P}$ input from prev. round (which is determined from randomness from prev. round recursively)
      - i.e $r_1 = R(i, x, r_{i - 1}, g_{i - 1})$ -> value at $r_i$ uniquely determined by input, prev. randomness, and response from $\mathcal{P}$ to randomness from prev. round
        - I.e prevents $\mathcal{P}$ from guessing forward, and back-propagate to acct. for randomness
  - **adaptive-soundness** - Security against $\mathcal{P}$ that can choose input to first round (GKR (out-puts of circuit))
- ## Computer Programs -> Circuits
  - Given computer program -> turn into arithmetic circuit -> delegate execution via NIP (GKR w/ hash-chaining)
  - **Machine Code**
    - Random Access Machine - 
      - $s$ cells of _memory_, where each cell stores $64$-bits of memory
        - Can only store data
      - $r$ number of registers, i.e instructions can perform operations on these
      - $l$ instructions, the set of operations that can be performed on registers
  - ## Circuit Satisfiability Problem
    - Given $\mathcal{C}$, takes two inputs, $x$ (input) $w$ (witness), determine whether $\mathcal{C}(x, w) = y$ (outputs)
      - **problem** - Given $\mathcal{C}$, $x, y$, determine whether or not there exists a witness $w$, such that $\mathcal{C}(x, w) = y$
    - More expressive than circuit evaluation
    - **Succint Arguments**
      - $\mathcal{P}$ sends $w$ to $\mathcal{V}$, then $\mathcal{P}, \mathcal{V}$, evaluate GKR on $\mathcal{C}(x, w)$
        - Instead of sending $w$ in full, send $commit(w)$ to $\mathcal{V}$, and have $\mathcal{P}$ open commitment at random points
        - Final step of GKR requires evaluation of $\tilde{u}$ (MLE of $(x, w)$)
  - ## Transformation
    - high-level
      - Specify **trace** of RAM $M$, i.e $T$ steps, where each step has values of each register in computation ($O(1)$) registers
    - **details**
      - $\mathcal{C}$ takes transcript of execution of $M$ on $x$ as input, transcript represented as follows
        - list of tuples $(t, m_1, \cdots, m_r, a_t)$
          - $t$ is the current time-step of the machine
          - $m_i$ are the values of the registers of the machine
          - $a_t = (loc, val)$ - $a_t$ is meta-data abt the memory operation perfomed at $t$ (if any)
            - $loc$ is memory location read / written to
            - $val$ - is value read / value written
      - Checks
        - Must check that values in memory are read / written to correctly (**memory-consistency**)
          - I.e value read is the latest value written
        - Must check that $(t, m_1, \cdots, m_r, a_t) \rightarrow (t + 1, m'_1, \cdots, m'_r, a_{t + 1})$ follow correctly from state-transition defined by $\mathcal{C}$ (**time-consistency**)
      - Circuit construction
        - Represent transition function, as a small circuit that takes $l(i)$ (i.e $i$-th element of list), and checks that $l(i + 1)$ follows correctly (**time-consistency**)
        - **memory-consistency** - Order $l(i)$ according to $a_i.loc$, and time, check that for each read $a_t.val = a_{t'}.val$ where $t'$ is the latest time-step at which a write occurred to $a_t.loc$
      - **transition-fn**
- ## Succint Arguments
  - ## Arguments of Knowledge + SNARKs
    - **knowledge-soundness**
      - $\mathcal{P}$ establishes that $\exists w, \mathcal{C}(x, w) = y$ exists, and that $\mathcal{P}$ knows such a $w$
    - SNARK - Succint, non-interactive, argument of knowledge
      - I.e knowledge-sound argument for arithmetic circuit-satisifiability
  - ## First Argument
    - **polynomial commitment** - Prover commits to a poly. $\tilde{w}$, and later can open to any evaluation of the poly. $\tilde{w}$
    - High-level
      - $\mathcal{P}$ sends commitment $\tilde{w}$ to $\mathcal{V}$ at beginning of the protocol, and executes GKR on $\mathcal{C}(x, w)$ 
    - What does GKR need to know abt $w$
      - Let $w, x \in \{0,1\}^n$, can reprsent input $z = x \| w$, can construct $\tilde{z}(r_0, \cdots, r_{log(n)}) = (1 - r_0)\tilde{x}(r_1, \cdots, r_{logn}) + r_0 \tilde{w}(r_1, \cdots, r_{logn})$
      - $\mathcal{P}$ only has to open commitment to $\tilde{w}$ at $r_1, \cdots, r_{logn}$
    - ### Knowledge Soundness
      - 
- ## Zero-Knowledge Proofs and Arguments
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
  - ### Graph Non-Isomorphism Proof
    - **graph isomorphism** - Let $G_1, G_2$ be graphs, and $\pi : V_1 \rightarrow V_2$, then $G_1 \cong G_2 \iff (e_1 = (v_1, v_2) \in E_1 \iff e_1' = (\pi(v_1), \pi(v_2)) \in E_2)$
    - **protocol**
      - $\mathcal{P}, \mathcal{V}$ begin with $G_1, G_2$
      - Round 1: $\mathcal{V}$ randomly chooses permutation $\pi : \{1, \cdots, n\} \rightarrow \{1, \cdots, n\}$ and $b \in \{1, 2\}$, and sends $\pi(G_b)$ to $\mathcal{P}$
        - Notice $\pi(G_b) \cong G_b$, thus $\mathcal{P}$ if $G_1 \not \cong G_2$ can efficiently determine which of $G_1, G_2$, $G_b$ is isomorphic to
        - Otherwise, if $G_1 \cong G_2$, then $\mathcal{P}$ cannot determine what $G_b$ is, and has $1/2$ chance at guessing
      - Two cases
        - Fix $\hat{\mathcal{V}}$, and $S(x)$ which on graph non-isomprphism correctly sends $b$ to verifier
        - On iso-morphism, randomly sends $b'$ back to $\mathcal{V}$ (using same distribution as $\mathcal{P}$)
    - Not zero-knowledge against dis-honest verifiers
      - $\hat{\mathcal{V}}$ can know that $H \cong G_1 \lor H \cong G_2$, and can send $H$ to $\mathcal{P}$ + random $G_b$ depending on response from $\mathcal{P}$, can learn which $H$ is IM to.
  - ### Additional Intuition
    - Given axioms + inference rules, and $x$ input, a proof is $\pi = (x, m_0, \cdots, m_n)$, where each $m_i$ is derived from $x \cup_{j < i} m_j$
    - **soundness** - Can't prove incorrect statements (i.e $x \not \in \mathcal{L}$, but $\mathcal{P}$ convinces $\mathcal{V}$ that $x \in \mathcal{L}$)
    - **completeness** - If $x \in \mathcal{L}$, $\mathcal{P}$ can prove this to any $\mathcal{V}$
  - ### Quadratic Residue proof
    - $\mathcal{P}$ + $\mathcal{V}$ know $x \in \mathbb{Z}^*_p$, $\mathcal{P}$ knows $s \in \mathbb{Z}^*_p$ where $x \equiv s^2 (p)$ (quadratic residue)
    - Round 1. $\mathcal{P}$ sends $r \leftarrow \mathbb{Z}^*_p, r^2$ to $\mathcal{V}$, $\mathcal{V}$ sends $b \leftarrow \{0,1\}$
    - Round 2. if $b = 0$, $\mathcal{P}$ sends $r$, otherwise $rs$, then $\mathcal{V}$ performs the following check, $z = x^br^2 = p$, where $p$ is the value sent from $\mathcal{P}$
    - **intuition**
      - **soundness** - Less than $1/2$ (can be increased by repeating experiment)
        - The case where $\mathcal{P}$ is acting correctly naturally satisfies the above.
        - Suppose $x \not\in QR_n$, and $\hat{\mathcal{P}}$ is not acting according to the protocol
          - If $u^2 = y \in QR_n$ (value sent to $\mathcal{V}$ in round 1.), then if $b = 1$ (prob 1/2), then then if $z^2 = xu^2$, then $(zu^{-1})^2 = x$ (contradiction), so the prover fails
          - If $y \not \in QR_n$, then with prob. $1/2$, $b = 0$, and the prover obv. fails
      - 
      - **completeness** - Triv.
    - Is it zero-knowledge? How to properly define the simulator?
      - $S(x)$ defined as follows
        - Fix $b' \leftarrow \{0,1\}$, $r \leftarrow \mathbb{Z}_m^*$
        - if $b' = 0$, then $x' = r^2$
- ## Schnorr's $\Sigma$-Protocol for knowledge of DLog
  - ### Schnorr Identification Protocol
  - Solve
    - Prover has knowledge of Dlog of grp. element
    - Prover commits to group element w/o revealing grp. element to verifier
  - Consider set of relations $\mathcal{R}$, where $(h,w) \in \mathcal{R}$ specify set of instance-witness pairs
    - Example, given $\langle g \rangle = \mathbb{G}$, then $\mathcal{R}_{DL}(\mathbb{G}, g)$ is the set of $(h,w)$, where $h = g^w$
  - $\Sigma$-protocol for $\mathcal{R}$ is a 3-message PC protocol, where $\mathcal{P}, \mathcal{V}$ know $h$ (public input), and $\mathcal{P}$ knows $w, (h,w) \in \mathcal{R}$
    - Protocol consists of 3-messages, $(a, e, z)$
    - Perfect completeness
  - **special soundness** - There exists PPT $\mathcal{Q}$, where when given $(a, e, z)$, and $(a, e', z')$ (accepting transcripts), where $e \not= e'$, $\mathcal{Q}$ outputs, $(h,w) \in \mathcal{R}$
  - **attempt protocol**
    - $\mathcal{R}_{DL} = \{(h,w) : h = g^w\}$
    - $\mathcal{P}, \mathcal{V}$ know $h, g$, $\mathcal{P}$ hold $(h,w)$
    - Attempt (not, specially sound)
      - $\mathcal{P}$, chooses $a \in \mathbb{G}, a = g^r, r \in \{0, \cdots, n -1\}$, and $z = (w + r)$
      - $\mathcal{V}$ checks that $ha = g^z$
      - Complete
      - Zero-knowledge
        - Take $S(h)$, where $z$ is randomly chosen, and $a = g^zh^{-1}$, i.e $S$ does not have to know $w$, but can still output $(a, z)$ which are randomly distributed ($z$ has same dist. as $a$)
      - For above reason not sound, take $P^* = S(h)$
  - **protocol**
    - $\mathcal{P}$ sends $a = g^r, r \leftarrow^R \{0, \cdots, n - 1\}$ to $\mathcal{V}$
    - $\mathcal{V}$ sends $e \leftarrow^R \{0, \cdots, n - 1\}$ to $\mathcal{P}$
    - $\mathcal{P}$ sends $z =(ew + r)$ to $\mathcal{V}$ checks that $ah^e = g^{z}$
  - Completeness - triv.
  - Soundness
    - Let $(a, e, z), (a, e', z')$ be two accepting transcripts, then $w = \frac{z - z'}{e - e'}$
  - Zero-knowledge -
    - Have to fix poly. time simulator $S$, where $e, z \leftarrow \{0,\cdots, n - 1\}$, and $a = g^z(h^e)^{-1}$
- ## Fiat-Shamir in $\Sigma$-protocols
  - If $(a, e, z)$ is the transcript from a $\Sigma$-P $\mathcal{I}$, and $\mathcal{Q}$ be the NI argument obtained from applying FS, where $e = R(h, a)$
    - Notice, by **special-soundness**, a witness $w$ can be obtained from $\mathcal{Q}$ by executing twice, contradicting intractibility of $\mathcal{R}$
  - 
- ## Commitment Schemes
  - Two parties, $\mathcal{P}$ (comitter), $\mathcal{V}$ (verifier)
  - **binding** - Once $\mathcal{P}$ sends $\mathcal{C}(m)$, $\mathcal{P}$ cannot _open_ the commitment to anything else, i.e $\mathcal{C}(m_1) \not= \mathcal{C}(m_2)$
  - **hiding** - $\mathcal{C}(m)$ shld not reveal any information abt. $m$
  - Composed of algs. `KeyGen, Commit, Verify`
    - KeyGen -> $(ck, vk)$, where $vk$ is the public verification key
    - $c = Commit(m, ck)$
    - $Verify(vk, Commit(m, ck), m') = 1 \iff m = m'$ (can also come in statistical / computational flavors), i.e $Pr[A|m \not= m'] \leq negl$
  - ### Commitment Scheme From Sigma Protocol
    - **hard relation** - Let $\mathcal{R}$ be a relation, then it is **hard** if for $(h, w) \in \mathcal{R}$, is output by an efficient randomized algo., then no poly. algo. exists that when given $h$, can output $(h, w') \in \mathcal{R}$ (except w/ negl. prob.)
      - I.e no efficient algo. for identifying witness $w$ for instance $h$, wher $(h, w) \in \mathcal{R}$
      - Example, let $\mathbb{G}$ be a finitely generated group w/ order $p$ (prime), and $\mathcal{R}_g = \{(h, r): h = g^r\}, \langle g \rangle = \mathbb{G}$ (assume DLOG)
    - $\Sigma$-protocol for hard-relation can be used to obtain perfectly hiding, computationally binding commitment scheme
    - **Damgard**
      - Retrieve CS from schnorr $\Sigma$-protocol
      - $(h,w) \leftarrow Gen$, $ck = vk = h$, i,e $h = g^w$
        - $w$ is considered toxic-waste (i.e must be removed otherwise, binding is not satisfied)
      - To commit to $m$
        - Committer runs simulator to obtain $S(h) = (a, m, z)$, send $a$ as commitment
      - Verification
        - Send $m, z$, verifier runs $\Sigma$ on $(a, m, z)$
    - **Properties**
      - Perfectly hiding
        - Commitment $a$ is independent from $m$ (challenge)
      - Correctness
        - 
      - Computational Binding
        - Special soundness of $\Sigma$, implies that if $(a, m', z'), (a, m, z) \in \mathcal{R}$, then witness extraction is poly. time computable **hardness** of $\mathcal{R}$ is violated
- 
- # Cryptograhic Pairings
  - **DLP** - Suppose $G = \langle P \rangle$, then given $Q = aP$, it is intractable to determine $a$ from j $Q, P$
    - Multiplicative grp. of finite field
    - Grp. of points over elliptic curve
  - ![Alt text](Screen%20Shot%202023-05-26%20at%204.31.31%20PM.png)
  - **DHP** - Given $P, aP, bP$ it is intractable to determine $abP$
    - DHP key agreement - Alice generates $aP \in G$, Bob generates $bP \in G$, and each sends their grp. element, shared key is $abP$
      - I.e each is expected to know their own exponent
  - What abt for three parties?
    - I.e $K = abcP$?

      ![Alt text](Screen%20Shot%202023-05-26%20at%204.35.54%20PM.png)
    - I.e effectively repeating DHP twice
  - What about a 1 round protocol for DHP w/ > 2 ppl?
    - Bilinear pairings!!
  - **Bilinear Pairings**
    - let $(G_1, G_T)$ be grps, $G_1$ is a cyclic grp. of prime order (additive), and $G_T$ is a multip. grp. 
    - $e : G_1 \times G_1 \rightarrow G_T$ if
      - **bilinearity** - $r, s, t \in G_1, e(r + s, t) = e(r, t)e(s, t)$
      - **non-degeneracy** - $e(s, s) \not= 1_T$
    - DLP in $G_1$ -> DLP in $G_T$, fix $P, Q \in G_1, G_1 = \langle P \rangle, Q = aP$, then $e(P, Q) = e(P, xP) = e(P, P)^x$
  - **Bilinear DHP** 
    - Let $e : G_1 \times G_1 \rightarrow G_T$ be a bilinear pairing, then given $P, aP, bP, cP$ compute $e(P, P)^{abc}$
  - **Protocols**
    - **Three-Party one-round key agreement** (generalizable to n-party)
      ![Alt text](Screen%20Shot%202023-05-26%20at%205.28.56%20PM.png)
      - Shared secret-key is $K = e(P, P)^{abc}$, Alice $a \leftarrow o(G)$ computes $e(bP, cP)^a$
      -  Notice for $n-party$ there must exist pairing over $G_1^{n -1}$ (existence is open-question)
    - **Short Signatures** (BLS short-signatures)
      - Suppose the DLP is intractable over $G_1$, and $H : \{0,1\}^* \rightarrow G_1$ is hash fn.
      - Alice priv. key $a \leftarrow \{1, \cdots, n -1\}$, pubkey is $A = aP$, message $M = H(m)$, signature is $S = aM$, and $(P, A, M, S)$ is DDHP quad
        - i.e $e(P, S) = e(A, M)$
        - Pairings serve as check for DDHP
      - **signature aggregation**
        - Let $(m_i, s_i)$ signed messages generated by parties $(a_i, A_i)$, aggregate signature $S = \Sigma_i S_i$, $e(P, S) = e(P, \Sigma_i S_i) = \Pi_i e(A_i, H(m_i))$
    - ## Identity Based Encryption
      - Alice sends $ID_A$ and $TTP$ generates a pub-key for alice derived from $ID_A$
        - What are the criteria composing $ID_A$ that Bob uses to request the pK for Alice?
          - Can be arbitrary, credit-score, etc. policy is up to Bob and TTP for generating the pK
      - **Boneh / Franklin**
        - Let $e : G_1 \times G_1 \rightarrow G_T$ be BP, $H_1 : \{0,1\}^* \rightarrow G_1$, $H_T : G_t \rightarrow \{0,1\}^l$
        - TTP priv-key is $t \in \{1, \cdots, o(G_1)\}$, $T = tp$ is pub-key
        - Given $ID_A$ (Alices ID string), TTP sends a BLS signature $d_A = tH_1(ID_A)$ to Alice (over secure channel presumably)
        - Bob wishes to transmit $m$, to Alice, Bob fixes $r \leftarrow \{1, \cdots, o(G_1)\}$, $c = m \oplus H_T(e(H_1(ID_A), T)^r)$
          - Bob sends $(c, rP)$ to Alice
        - Alice verifies by $c \oplus H_T(e(d_A, R)) = c \oplus H_T(e(tH_1(ID_A), rP)) = c \oplus H_T(e(H_1(ID_A), tP)^r) = m$
- # Elliptic Curves
  - Defined over field $K$
    - **weierstrass** - $y^2 + a_1xy + a_3y = x^3 + a_2x^2 + a_4x + a_6$
  - **Hasse's** - If $K = \mathbb{F}_q$, then $(\sqrt{q} - 1)^2 \leq |E(K)| \leq (\sqrt{q} + 1)^2$
- ## KZG Commitments
  - Merkle proofs form of VC (Vector Commitment), i.e given ordered sequence $(a_1, \cdots, a_n)$, send $c \leftarrow \mathcal{C}$ which serves as commitment to all ordered values, and any value / position can be opened later
  - Polynomial Commitment - Prover commits to a poly. and at any point in the future, prover can _open_ commitment to evaluation of poly. at any point chosen by verifier
    - Hiding - Does not tell what the poly. is
    - Binding - Prover cannot trick verifier into accepting poly. commit for a different poly.
  - Commitment size is a grp. element
  - Proof size is one grp. element (~48 bytes)
  - Verification - 2 pairings + 2 grp. mult 
  - Computationally hiding
  - $\langle H \rangle = \mathbb{G}_1, \langle G \rangle = \mathbb{G}_2$, order of grps. is $p$, $e : \mathbb{G}_1 \times \mathbb{G}_2 \rightarrow \mathbb{G}_T$, $[x]_1 = xG, [x]_2 = xH$ 
    - Pairing serves for multiplication of commitments
  - **trusted setup**
    - Grps. generally group of points of EC
    - Choose random $s \in \mathbb{F}_q$, and make public $[s^i]_1, [s^i]_2$, $0 \leq i \leq deg(f)$
    - $[x]_i + [y]_i = [x + y]_i$ (additive), commitment also preserved across mult. by scalar (in $\mathbb{F}_q$)
  - i.e $[p(X)]_j = [\Sigma_i a_i X^i]_j = \Sigma_i a_i [X^i]_j$
  - **Commitment**
    - Commitment $C = [p(s)]_1$
    - Opening commitment?
      - Fix $z \in \mathbb{F}_q$, $p(z) = y$, $q(X)(X - z) = p(X) - p(z)$
      - Then $e([q(s)]_1, [(s - z)]_2) = e(C - [p(z)]_1, H)$
  - **Multi-proofs**
    - Proving evaluation of poly. at multiple points $(x_0, p(x_0)), \cdots, (x_n, p(x_n))$, create $I(X)$ (lagrange interpolation poly.) for the points mentioned, then $q(s) = \frac{p(s) - I(s)}{Z(s)}$, where $Z(X) = (X - x_0)\cdots (X - x_n)$, $[q(s)]_1$ is opening to commitment
- ## PCPs
  - IP - $\mathcal{P}$ asked questions by verifier, and $\mathcal{P}$ behaves adaptively
  - **PCP** - proof is $\pi$, i.e static object, that has well-defined responses to each query $q_i$ asked by $\mathcal{V}$, answers are not dependent upon $q_j, j < i$
    - A PCP for $\mathcal{L}$, is $(\mathcal{V}, \pi, x)$, $\pi \in \Sigma^l$
      - **completeness** - For every $x \in \mathbb{L}$, there exists a $\pi \in \Sigma^l$, where $Pr[\mathcal{V}^{\pi} = 1] \geq 1 - \delta_c$
      - **soundness** - For every $x \not\in \mathcal{L}$ and each proof string $\pi \in \Sigma^l$, $Pr[\mathcal{V}^{\pi}(x) = 1] \leq \delta_s$
  - 
- ## PLONK
  - General-purpose zkps
  - **trusted setup**
    - Multiple people can participate, once completed once, any kind of poly. can be proven
  - **arithmetization**
    - **Algebraic Intermediate Representation**
      - Execution Traces + Constraints
        - Evolution of some computation over time
        - Representation
          - $E \in Mat(T, W)$, i.e a $W$-column, $T$-row matrix, where $W$ is the number of registers, and $T$ is the number of time-steps
            - i.e each column $f_i : T \rightarrow \mathbb{F}$ (assignment of registers over time)
          - Must prove that execution trace adheres to certain constraints, i,e for fibonacci ($f_1(t + 2) = f_1(t) + f_1(t + 1)$)
            - **boundary contraints**
              - assertion, that register $i$ at time $t$ had value $\alpha$, i,e $(t, i, \alpha), f_i(t) = \alpha$
              - Can be used to verify input / output, etc.
            - **Transition constraints**
              - Poly, where $\forall j \in [T - 1], P(f_1(j), \cdots, f_w(j), f_1(j + 1), \cdots, f_w(j + 1))$
        - Recall that each column $i$, is a fn. $f_i : T \rightarrow \mathbb{F}$, this function has a specific structure
          - Let $H \subset \mathbb{F}^*, O(H) = T, H = \langle \omega \rangle$, then $f_i[t] = f_i(\omega^t)$ (i.e each column's value is evaluation of polynomial at specific point in multiplicative subgrp. of $\mathbb{F}$)
        - Expressing constraints via polynomials
          - Suppose that $f_i[t]^2 = f_i[t + 1]$, then $f(X)^2 = f(X * \omega)$, notice $X \in H, x = \omega^t$ (for some $t$)
          - Suppose that constraint is satisfied at $X_1, \cdots, X_n = (\omega^{t_1}, \cdots, \omega^{t_n})$, then $(X - \omega^{t_1}) \cdots (X - \omega^{t_n})|f(X)^2 - f(X * \omega)$
          - **boundary**
            - $(X - \omega^t)|f_i(X) - \alpha$
          - **transition**
            - notice, $H = \langle \omega \rangle, O(H) = T$, thus $X^T - 1 = (\omega - X) \cdots (\omega^T - X)$
            - $(X - \omega) \cdots (X - \omega) | P(f_1(X), \cdots, f_w(X), f_1(X * \omega), \cdots, f_w(X * \omega))$
- ## Statements
  - Let $\Sigma$ be alphabet, then $L \subset \Sigma^*$ is language, $R : \Sigma^* \rightarrow \{0,1\}$ (i.e $R$ determines what words are in language $L_R$)
  - Separate into two separate languages $\Sigma_I, \Sigma_W$ (one for instances, one for witnesses), where prover constructs instance, for a specific witness, i.e prover sends, $R_w : \Sigma_I \rightarrow \{0,1\}$, then the verifier evaluates $R_w(I)$
    - i.e in Schnorr, instance is $(a, e, z)$ witness is $w$
- ## Presentation
  - Intro to groups, rings, fields, pairings, poly., (elliptic curves?), sigma-protocols, FFT definitions of interactive, non-interactive, zk-proofs
  - Commitment Schemes
    - Pederson
    - KZG
  - Tying all together with PLONK
  - Looking forward to applications (zk-evms)
  - 
- ### Presentation 1
  - Intro
    - Introduce basic direction of presentation
      ![Alt text](Screen%20Shot%202023-05-29%20at%206.03.26%20PM.png)
      - I.e - Computation -> Witness Generation -> polynomials -> single polynomial commitment -> verifiers read commitment, and can request evaluation at random points
  - Introduce definitions of zk
    - Languages, relations,
    - Interactive Proofs
      - Definition
        - Introduce polynomials?
      - Graph Non-isomorphism
      - Sum-check
        - Example using poly.
        - MLEs
          - Schwartz-Zippel
      - Example?
    - Non-interactive proofs
      - Apply Fiat-shamir transform to sum-check using random-oracle
    - Brief Intro to GKR
      - Intro to Arithmetic Circuits
        - Matrix multiplication example
      - 
    - Circuit Construction
    - SNARKs
      - $\Sigma$-protocols?
      - Commitment Schemes
        - Polynomial v. vector commitments
    - Zero-knowledge
      - Definition
        - Simulator Paradigm
      - Quadratic Non-Residue zk-proof
      - Schnorr
        - Brief intro to grp. theory
