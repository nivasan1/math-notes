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
        - Suppose $|\mathcal{K}| < |\mathcal{M}|$
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
- ## Computational Complexity
  - 
