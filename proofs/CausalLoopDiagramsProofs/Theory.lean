import CausalLoopDiagramsProofs.Theory.Dominance
import CausalLoopDiagramsProofs.Theory.Composition

/-!
# CausalLoopDiagramsProofs.Theory

**The composition theorem: that monotone kernels compose, so the polarity of a path is the
product of the polarities of its links.**

This is the one library in the project built against Mathlib, and the only reason it exists
separately. ADR 0026 chose a Mathlib-free project because the polarity rig is a four-element
inductive type whose every law is a case split; that is still true of `Basic`, `Rig`, `Order`
and `Loops`, and `lake build` still builds only those. ADR 0028 amends the decision for the
one theorem that cannot be had on those terms: it quantifies over real-valued conditional
probability tables and its proof is summation by parts.

Modules, in import order:

- `Theory.Dominance`: upper tails of a finite distribution, the usual stochastic order on
  them, and the theorem that a higher distribution gives every increasing function a larger
  expectation. That last is the analytic content, and it is Abel's transformation.
- `Theory.Composition`: kernels, their composition, and the four theorems that say a
  monotone kernel composed with a monotone kernel is monotone with the product direction --
  together with `polarity_comp`, which states the conclusion in the rig of `Basic.lean`.

Nothing in `CausalLoopDiagramsProofs` imports this library, which is what keeps the
amendment confined to it: the rig proofs remain Mathlib-free and their axiom audit remains
the stricter one. `make mathlib-free` checks the separation, and `make audit-theory` prints
the axioms these theorems use -- which, unlike the rig's, are the three Mathlib standard
axioms.
-/
