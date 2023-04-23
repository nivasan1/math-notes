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
 - `cases` 
   - breaks inductive definition into constructors
     - How is this diff from induction?
       - Induction introduces motive given goal, for recursive types assumes motive for arbitrary type
   - Given $n : nat$
   - injection tactic?
  ## Inductive Families
  - Defines an inductive type of $\alpha$ that is indexed by another type $\beta$
    - This is represented as $\alpha \rightarrow \beta$
  - Consider `vector`
    ```
    inductive vector (α : Type u) : nat → Type u
    | nil {}                              : vector zero
    | cons {n : ℕ} (a : α) (v : vector n) : vector (succ n)
    ```
  - In the above definition, each instance of  `vector` in the definition is an instance of `vector \a`
    - `motive`s in recursors are going to be dependent function types (they parametrize the index of the inductive family)
## Axiomatic Details

## Structures
- Let $G$ be a group $\leftrightarrow$ `variable (G : Type) [group G]`
- Group homo-morphism defn. 
    ```
    @[ext] structure my_group_hom (G H : Type) [group G] [group H] :=
    (to_fun : G → H)
    (map_mul' (a b : G) : to_fun (a * b) = to_fun a * to_fun b)
    ```
    - Structure is an inductive type w/ single constructor, defined below are the arguments to the constructor (`mk`)
- For each argument to constructor, a function is given `my_group_hom.to_fun : \Pi {G H : Type} [group G] [group H](a : my_group_hom G H), G -> H` (similarly for map_mul')
  - Can apply above function to instance of structure, using dot notation on instance of structure
## Classes
- Structure tagged w/ class keyword
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
## Lean Tips
- ## Useful tactics
  - **simpa**
    - Similar to use of `simp`
      - Uses all thms / lemmas tagged with `@[simp]`, to rewrite goal (must be equality / logical equality), and ideally solves
    - Use: `simpa [//additional lemmas] using h`, rewrites goal / h so that they are equivalent and applies `exact`
  - **obtain**
    - Instead of doing `have` / cases, obtain does the work for you, deconstructing statement, after applying to specific instance
## Working with sets
 - Set is defined as `let a := set : X`,  can be thought of as the following
   1. A set of elements, each of which `: X`
   2. A function from `X -> Prop`, mapping $x \in A$, to true, nad false otherwise
   3. An element of the power-set of `X`
   4. A subset of $X$
- Are types / sets interchangeable? Can't be, a `set : Type`? Let $A : set X$, `set X` is a type (dependent type), and $A$ is a term, then $\in$ is a relation over $(X, set X)$, where $x : X$, and $x \in A$
  - `set X`, is the type of all sets containing elements $x : X$, thus $x \in A : \space Prop$
## Order Relations in Lean
