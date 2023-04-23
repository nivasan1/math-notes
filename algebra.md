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
