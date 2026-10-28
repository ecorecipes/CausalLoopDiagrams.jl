# CausalLoopDiagrams.jl

Causal loop diagrams as labelled graphs, and the bridge between them and the Bayesian networks of the
ecorecipes compositional Bayesian-network ecosystem.

## Place in the ecosystem

Dependency order (arrows = depends on):
EcologicalBayesianNetworks → InfluenceDiagrams → BayesianNetworkInference → BayesianNetworks →
FiniteKernels, and BayesianNetworks → BayesianNetworkFormats (a leaf).
This package sits **off** that chain, beside MarkovCategories:
CausalLoopDiagrams → BayesianNetworks → FiniteKernels. Nothing in the ecosystem depends on it.
It depends on ACSets, OrderedCollections, FiniteKernels and BayesianNetworks, and **must not depend
on Catlab or MarkovCategories** (ADR 0009). Sibling packages are expected at `../<Name>.jl`, declared
via `[sources]` in `Project.toml`.

## Invariants that must not be broken

- **Four polarities, not three.** `POSITIVE`, `NEGATIVE`, `NO_EFFECT`, `INDETERMINATE`. Baez's
  three-element monoid `{+, 0, -}` writes `0` for an *indeterminate* sign; here that is
  `INDETERMINATE` and `NO_EFFECT` is the additive unit, the link along which nothing moves. The two
  are distinct because a conditional probability table tells them apart. Never collapse them, and
  never add a fifth: the four are the subsets `{0}`, `{+}`, `{-}` and `{0, +, -}` of the sign
  hyperfield, which is why they are closed under both operations.
- **The rig laws.** `*` composes along a path and `+` combines in parallel; `one(Polarity) ==
  POSITIVE`, `zero(Polarity) == NO_EFFECT`, `NO_EFFECT` is absorbing for `*`, and the whole thing is
  a commutative rig. `test/test_polarity.jl` checks associativity, commutativity, both identities and
  distributivity on all 4^3 triples; `proofs/` proves the same of the same tables. The two
  multiplication / addition tables in `src/polarity.jl` and in `proofs/` are written out rather than
  derived, so that they can be compared line by line. Change one and change the other.
- **A polarity is read, not asserted.** `polarity(kernel, parent)` is stochastic monotonicity in the
  *declared* order of the states, holding the other parents fixed, with `atol` slack per comparison.
  It must stay a test on the table. The direction depends on the declared order, which is what
  `reversed` is for; a variable with no order at all is what `unordered` is for, and every link
  touching one is `INDETERMINATE`.
- **Monotone kernels compose**, which is what makes the reading a labelling in Baez's sense rather
  than a convention: `polarity(compose_kernel(f, g), x) == polarity(f, x) * polarity(g, y)`.
  `test_polarity.jl` checks it against `compose_kernel` directly on all four sign combinations. Any
  change to the monotonicity test must keep that test passing, or the package is no longer computing
  a functor.
- **Observation and intervention stay apart**, as in BayesianNetworks. `mode = :structural` reads each
  mechanism's own table and `mode = :observational` reads `conditional(m, child, parent)`. They are
  different functions and must not be merged or defaulted into each other; the disagreement between
  them is the package's most useful output.
- **Parallel links and self-links are kept.** The diagram is a multigraph, which is Baez's definition
  (a pair of functions source, target from edges to vertices). Combining parallel links is
  `coarsen`'s job, or `link_polarity`'s on reading; it never happens silently in `add_link!`.
- **A diagram may be cyclic.** That is the whole point, and it is why this is not a `BayesNet`.
  `instantaneous_loops` names the loops that no Bayesian network can hold, and the docstring must keep
  saying that unrolling does not help them.

## Layout

- `src/polarity.jl`: the `Polarity` rig (the two 4x4 tables, `*`, `+`, unary `-`, `one`, `zero`,
  `show`, `polarity_symbol`, `polarity_name`) and `polarity(::FiniteKernel, position_or_name)`, the
  stochastic-monotonicity test. Included first; `errors.jl` follows it.
- `src/errors.jl`: the root `CausalLoopDiagramsError` and the three concrete types under it
  (`UnknownFactorError`, `NotALoopError`, `TooManyLoopsError`) with their `showerror` methods
  (ADR 0013). Invalid arguments and keywords raise `ArgumentError`; BayesianNetworks' and
  FiniteKernels' typed errors pass through unchanged and documented.
- `src/diagram.jl`: `SchCausalLoop` (an ACSets.jl `BasicSchema`, not a Catlab `@present`, following
  `SchBayesNet` and ADR 0009), the abstract and concrete ACSet types, `LinkSpec` / `link` / `delayed`,
  `causal_loop_diagram(links)`, `add_factor!` (idempotent) / `add_link!`, the accessors, and
  `polarity_matrix` / `delay_matrix`.
- `src/loops.jl`: `Loop`, elementary-circuit enumeration (each cycle rooted at its smallest factor
  id, capped by `max_loops`), `loop_polarity`, the classifiers and `loop_summary`. Loops are
  enumerated on the diagram with parallel links summed, so each cycle of factors appears once.
- `src/extraction.jl`: `causal_loop_diagram(::BayesModel; mode, unordered, reversed, atol)` and
  `causal_loop_diagram(::DynamicBayesModel)`, which is `collapse_lags` of the transition template.
- `src/morphisms.jl`: `coarsen` (the push-forward of labels along a map of factors -- the operation
  the rig's addition exists for), `collapse_lags`, `compare_diagrams` and `DiagramComparison`.
- `src/graphics.jl`: `to_graphviz` as a method on BayesianNetworks' generic. Colour carries the
  polarity and dashing carries the delay, on separate channels deliberately; `highlight` thickens one
  loop.
- `test/test_*.jl`: one file per source file, plus `test_errors.jl` (the ADR 0013 hierarchy) and
  `test_docstrings.jl` (every owned export documented). The suite uses `reference_habitat_model` and
  `vegetation_herbivore_model` from BayesianNetworks for the extraction tests, and builds a small
  confounded model of its own for the two reading modes.
- `proofs/`: the Lean 4 library `CausalLoopDiagramsProofs`. Mathlib-free: the polarity rig is a
  four-element type, so its laws and the rotation-invariance of a loop's polarity are decidable, and
  a 7 GB dependency for `decide` would be absurd. It proves the rig laws of the same two tables and
  that a loop's polarity does not depend on where the loop is cut. It does **not** model Julia arrays,
  stochastic monotonicity, or the composition theorem; that last is the gap worth closing and it is
  the one thing in `Roadmap.lean`.

## Commands

```sh
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'   # the test suite
julia --project=docs docs/make.jl                                 # build docs locally
cd vignettes && quarto render                                     # render vignettes to html/gfm/pdf
julia scripts/sync_vignettes.jl [--check]                         # copy vignettes into docs/src/tutorials
cd proofs && lake build --wfail                                   # the Lean proofs
```

## Files not to edit by hand

- `docs/src/tutorials/` is generated by `scripts/sync_vignettes.jl`.
- `vignettes/*/*.md`, `*.html`, `*.pdf` and `*_files/` are quarto output; edit the `.qmd`.
- `docs/adr/` is copied from the workspace `docs/adr/` by `scripts/sync_adrs.jl`; edit the workspace copy.
- `docs/src/references.bib` and `vignettes/references.bib` are copied from the workspace
  `docs/references.bib` by `scripts/sync_references.jl`; edit the workspace copy.

## Style

JuliaFormatter `yas`; docstrings on every exported name, which `test/test_docstrings.jl` enforces; the
docs build is strict (no `warnonly`), so a docstring left out of the manual or a broken `@ref` fails
it; typed exceptions with the offending factor names in the message, following ADR 0013: they live in
`src/errors.jl` and subtype `CausalLoopDiagramsError`, invalid arguments and keywords raise
`ArgumentError`, typed errors from a lower package pass through unchanged and documented, and another
package's type is named as a code span, never with `@ref`; no emojis in code or docs.
