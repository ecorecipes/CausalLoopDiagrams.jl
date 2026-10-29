import CausalLoopDiagramsProofs.Theory

/-!
The axioms the composition theorem and its supporting lemmas depend on. Run with
`make audit-theory` (`lake env lean AuditTheory.lean`).

This is a **separate** audit from `Audit.lean`, and the separation is the point. The rig,
order and loop theorems are Mathlib-free and audit as depending on no axioms at all, or on
`propext` alone; that claim is checked by `Audit.lean` and ADR 0028 does not weaken it.

The theorems below are about real-valued conditional probability tables, so they inherit
Mathlib's three standard axioms -- `propext`, `Classical.choice` and `Quot.sound`. That is
the price of the real numbers, it is the same price every other proofs/ project in the
ecosystem pays, and it is recorded here rather than left to be discovered.
-/

open CausalLoopDiagrams.Theory

-- The stochastic order, and the analytic step: summation by parts.
#print axioms sum_mul_le_of_dominates
#print axioms sum_mul_le_of_dominates_antitone
#print axioms sum_range_add_tail
#print axioms tail_sub
#print axioms dominates_trans

-- Kernels and their composition.
#print axioms tail_comp
#print axioms isKernel_comp
#print axioms tail_succ
#print axioms eq_of_tail_eq
#print axioms constant_of_increasing_of_decreasing

-- The four sign combinations.
#print axioms increasing_comp
#print axioms decreasing_comp_of_increasing_of_decreasing
#print axioms decreasing_comp_of_decreasing_of_increasing
#print axioms increasing_comp_of_decreasing_of_decreasing

-- The absorbing case, `noEffect`.
#print axioms constant_comp_of_constant_left
#print axioms constant_comp_of_constant_right

-- The headline theorems: monotone kernels compose, and the polarity of a path is the
-- product of the polarities of its links.
#print axioms Direction.polarity_mul
#print axioms reads_comp
#print axioms polarity_comp
