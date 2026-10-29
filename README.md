# CausalLoopDiagrams.jl

Causal loop diagrams as labelled graphs, and the bridge between them and the Bayesian
networks of the [ecorecipes](https://github.com/ecorecipes) ecosystem.

A causal loop diagram is the first thing a group of people draw when they describe a
system: factors joined by arrows, each arrow marked with the direction in which it pushes,
and loops closing back on themselves. John Baez formalises one as a graph whose edges are
labelled by elements of a monoid of *polarities*, so that a labelling is the same thing as
a functor from the free category on the graph into the delooping of the monoid; with
Adittya Chaudhuri he extends this to three kinds of morphism between labelled graphs --
refining, simplifying and finding motifs -- and to a homology that counts the feedback a
composite acquires that neither part had ([arXiv:2506.23375](https://arxiv.org/abs/2506.23375),
*Graphs With Polarities*).

A Bayesian network carries far more than a sign per arrow, and one thing less: it must be
acyclic, so it cannot hold a loop at all. This package is the translation in both
directions, and it is as interested in what the translation loses as in what it keeps.

## Features

- **Four polarities, a commutative rig.** `POSITIVE`, `NEGATIVE`, `NO_EFFECT` and
  `INDETERMINATE` -- the subsets `{0}`, `{+}`, `{-}` and `{0, +, -}` of the sign
  hyperfield, closed under its operations. `*` composes links along a path and `+`
  combines links in parallel. The fourth and the third are distinct here, where Baez's
  three-element monoid writes both as `0`, because a conditional probability table tells
  "does not depend on it" from "depends on it in no consistent direction".
- **A sign read off a table, not asserted.** `polarity(kernel, parent)` tests stochastic
  monotonicity in the declared order of the states. Monotone kernels compose, so the
  polarity of a path really is the product of its links' polarities; the test suite checks
  that against `compose_kernel` rather than taking it on faith.
- **Diagrams as ACSets.** A diagram is a two-table attributed C-set -- factors and links,
  with a source and a target function -- which is Baez's definition rather than an encoding
  of it. Parallel links and self-links are kept.
- **Loops, and the distinction that matters.** `loops` enumerates the elementary feedback
  loops with their polarities; `delayed_loops` are the ones a *dynamic* Bayesian network
  holds as they stand, and `instantaneous_loops` are the ones no Bayesian network holds at
  all.
- **Both directions.** `causal_loop_diagram(model)` reads a diagram off a bound
  `BayesModel`, structurally or observationally; `causal_loop_diagram(dynamic_model)`
  collapses a transition template's time index and the loops come back.
- **Maps between diagrams.** `coarsen` is the push-forward of labels along a map of
  factors, `collapse_lags` its time-index special case, and `compare_diagrams` a
  link-by-link comparison -- which is how a sketch is held against the network that was
  built from it.
- **Motifs.** `occurrences` finds every label-respecting embedding of a small diagram in a
  larger one, matching along the subset order on polarities, so a motif link labelled `?`
  matches any sign. `MOTIF_LIBRARY` names ten standard shapes and `motif_census` counts
  them across a *collection* of diagrams, ranked by how many contain each -- which asks a
  question of a body of models that no single model can answer.

## Installation

The ecosystem packages are not registered. This package depends on two of them, so install
all three by URL:

```julia
using Pkg
Pkg.add(url="https://github.com/ecorecipes/FiniteKernels.jl")
Pkg.add(url="https://github.com/ecorecipes/BayesianNetworks.jl")
Pkg.add(url="https://github.com/ecorecipes/CausalLoopDiagrams.jl")
```

## Quick Start

A sketch of a seasonal tree disease, with its two feedback loops:

```julia
using CausalLoopDiagrams

sketch = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                              (:Infection, :Defoliation) => POSITIVE,
                              (:Defoliation, :Vigour) => NEGATIVE,
                              delayed((:Vigour, :Infection) => NEGATIVE),
                              delayed((:Infection, :Inoculum) => POSITIVE)])

loops(sketch)
# Inoculum -> Infection -> Inoculum (+, reinforcing, delayed)
# Infection -> Defoliation -> Vigour -> Infection (+, reinforcing, delayed)
```

Both loops are delayed, so a dynamic Bayesian network can carry them. Going the other way,
a transition template's time index collapses and the loops reappear:

```julia
using BayesianNetworks

collapsed = causal_loop_diagram(vegetation_herbivore_model())
loops(collapsed)
# Vegetation -> Vegetation (+, reinforcing, delayed)
# Vegetation -> Herbivores -> Vegetation (-, balancing, delayed)
```

Grazing is a balancing loop, and the sign was computed from the conditional probability
tables rather than asserted.

## What it will not do

A polarity carries no magnitude, so a diagram cannot say which of two loops through one
factor wins; that is why Baez's series moves on from monoids to rings, hyperfields and
rigs. It carries no interaction: a link whose sign depends on another parent comes out
`INDETERMINATE`, and a lever worth more alongside an intervention than alone has no
expression in a diagram at all. And it carries no unordered variable, which is what most
choices between incomparable options are. Those limits are the reason a sketch is a sketch;
the package reports them rather than papering over them.

## Place in the ecosystem

`CausalLoopDiagrams` → `BayesianNetworks` → `FiniteKernels`. It sits off the main chain,
beside `MarkovCategories`, and needs no Catlab.

## References

John C. Baez and Adittya Chaudhuri, *Graphs With Polarities*,
[arXiv:2506.23375](https://arxiv.org/abs/2506.23375) (2025), and Baez's
[Polarities](https://johncarlosbaez.wordpress.com/2024/11/02/polarities/) series on the
Azimuth blog, parts 1 to 6.

## Licence

MIT. Copyright (c) 2026 Simon Frost.
