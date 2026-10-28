import CausalLoopDiagramsProofs.Basic
import CausalLoopDiagramsProofs.Rig
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
- `Loops`: the polarity of a path as a product over a list, its functoriality
  (`pathPolarity_append`), and the theorem that a loop's polarity does not depend on where
  the loop is cut (`pathPolarity_rotate`).
- `Roadmap`: what is not proved, chiefly that monotone kernels compose.

Mathlib-free by decision (ADR 0026).
-/
