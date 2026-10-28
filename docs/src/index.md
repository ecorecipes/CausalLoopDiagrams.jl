# CausalLoopDiagrams.jl

Causal loop diagrams as labelled graphs, and the bridge between them and the
Bayesian networks of the ecorecipes ecosystem
(`CausalLoopDiagrams` → `BayesianNetworks` → `FiniteKernels`).

A causal loop diagram is the first thing a group of people draw when they describe
a system: factors joined by arrows, each arrow marked with the direction in which
it pushes, and loops closing back on themselves. Baez formalises one as a graph
whose edges are labelled by elements of a monoid of polarities, which makes a
labelling the same thing as a functor from the free category on the graph into the
delooping of the monoid [Baez2024](@cite); Baez and Chaudhuri extend this to three
kinds of morphism between labelled graphs -- refining, simplifying, finding motifs --
and to a homology that counts the feedback a composite acquires that neither part
had [BaezChaudhuri2025](@cite).

A Bayesian network carries much more than a sign per arrow, and one thing less: it
must be acyclic, so it cannot hold a loop at all. This package is the translation
in both directions.

## The polarities

[`Polarity`](@ref) has four values, not the three of Baez's `{+, 0, -}`:

| value | prints | meaning |
|---|---|---|
| [`POSITIVE`](@ref) | `+` | the child moves the same way as the parent |
| [`NEGATIVE`](@ref) | `-` | the child moves the opposite way |
| [`NO_EFFECT`](@ref) | `0` | the child does not depend on the parent |
| [`INDETERMINATE`](@ref) | `?` | it depends which way, so the diagram does not say |

The fourth and the third are distinct here because a conditional probability table
tells them apart, where a whiteboard sketch cannot. The four are the subsets `{0}`,
`{+}`, `{-}` and `{0, +, -}` of the sign hyperfield, closed under its multiplication
and its multivalued addition, so they form a commutative rig: `*` composes links
along a path and `+` combines links in parallel. The rig, rather than just a monoid,
is what [`coarsen`](@ref) needs, because merging two factors must combine the labels
of the links that become parallel.

## Reading a sign off a table

[`polarity`](@ref polarity(::FiniteKernel, ::Integer)) tests **stochastic
monotonicity** in the declared order of the states: the child's distribution rises
with the parent if its upper tail never shrinks, for every configuration of the
other parents. Monotone kernels compose, which is what makes this a labelling in
Baez's sense rather than a convention -- the polarity of a path really is the product
of the polarities of its links, and `test/test_polarity.jl` checks that against
`compose_kernel` directly.

Two keywords say where the declared order is not the quantity the diagram is about:
`reversed` for a variable whose states run best to worst, and `unordered` for one
whose states carry no order at all, every link touching which comes out
`INDETERMINATE`.

## The two kinds of loop

```julia
using CausalLoopDiagrams

sketch = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                              (:Infection, :Defoliation) => POSITIVE,
                              (:Defoliation, :Vigour) => NEGATIVE,
                              delayed((:Vigour, :Infection) => NEGATIVE),
                              delayed((:Infection, :Inoculum) => POSITIVE)])
loops(sketch)
```

[`delayed`](@ref) is the mark that matters for modelling, and it splits the feedback
in two.

  - A loop with a delay in it ([`delayed_loops`](@ref)) is one a **dynamic** Bayesian
    network holds as it stands: the delayed link becomes a lagged input, and
    [`causal_loop_diagram`](@ref causal_loop_diagram(::DynamicBayesModel)) recovers
    the loop from a transition template by collapsing the time index
    ([`collapse_lags`](@ref)). Persistence of a variable from one slice to the next
    comes back as a self-link, the shortest feedback loop there is.
  - A loop with no delay anywhere ([`instantaneous_loops`](@ref)) asserts that
    everything in it happens at once. No Bayesian network holds one, and unrolling
    does not help, because there is no slice boundary to put the closing link across.
    Representing one means changing the model.

## What the translation discards

Worth stating plainly, because it is why a diagram is a sketch and a network a model.
A polarity carries no magnitude, so it cannot say which of two loops through one
factor wins -- which is why Baez's series moves on to rings, hyperfields and rigs with
more in them than signs. It carries no interaction: a link whose sign depends on
another parent comes out `INDETERMINATE`, and a lever worth more alongside an
intervention than alone has no expression in a diagram at all. And it carries no
unordered variable, which is what most choices between incomparable options are.

## Two readings of one network

[`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel)) reads a model either
way, and [`compare_diagrams`](@ref) says where they differ:

  - `:structural` reads each mechanism's own table, so the sign is what intervening
    on the parent would move;
  - `:observational` reads `conditional(m, child, parent)`, so the sign is the
    direction in which the two move together in this model.

They part company exactly where the network is confounded. A causal loop diagram
drawn from observed co-movement carries the second while claiming the first, so the
disagreement list is a soundness check on a diagram someone else drew.

## Contents

```@contents
Pages = ["api.md", "references.md"]
Depth = 2
```
