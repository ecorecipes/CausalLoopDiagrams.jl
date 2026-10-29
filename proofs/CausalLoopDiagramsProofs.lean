import CausalLoopDiagramsProofs.Basic
import CausalLoopDiagramsProofs.Rig
import CausalLoopDiagramsProofs.Order
import CausalLoopDiagramsProofs.Loops

/-!
# CausalLoopDiagramsProofs

A finite model of the polarity rig of `CausalLoopDiagrams.jl`, and of the polarity of a
path and of a loop.

Modules, in import order:

- `Basic`: the four-element `Polarity` type and the two sixteen-case tables, `mul` and
  `add`, a hand-written copy of the matrices in `src/polarity.jl`.
- `Rig`: that the two make a commutative rig, with `one = positive` and `zero = noEffect`,
  `zero` absorbing for `mul`, and distributivity both ways. Every proof is a case split
  closed by `rfl`.
- `Order`: that `subset` -- containment, reading the polarities as the subsets of the sign
  hyperfield they are -- is a partial order with `indeterminate` greatest, and that both rig
  operations respect it. That order is what a motif matches along (ADR 0027), and the two
  monotonicity theorems are what make a motif of a path, and a motif that survives
  `coarsen`, mean what they appear to mean.
- `Loops`: the polarity of a path as a product over a list, its functoriality
  (`pathPolarity_append`), and the theorem that a loop's polarity does not depend on where
  the loop is cut (`pathPolarity_rotate`).
- `Roadmap`: what is not proved, and the two things the composition theorem does not cover.

Mathlib-free by decision (ADR 0026), and this library still is: `lake build` builds exactly
the four modules above. The composition theorem -- that monotone kernels compose, so the
polarity of a path is the product of the polarities of its links -- is proved in the
separate `Theory` library, which is built against Mathlib because it quantifies over
real-valued conditional probability tables and its proof is summation by parts (ADR 0028).
Nothing here imports it, which is what keeps that dependency confined; `make mathlib-free`
checks the separation and `make audit` still reports these proofs as axiom-free.
-/
