import CausalLoopDiagramsProofs.Basic

/-!
# The subset order on polarities

`subset` is a partial order with `indeterminate` as its greatest element, and it is
compatible with both rig operations.

The order is what a motif matches along: a motif link matches a diagram's link when the
diagram's label is a subset of the motif's label, so a motif link labelled `indeterminate`
matches a link of any sign and one labelled `positive` matches only a positive link
(ADR 0027). The matching is therefore not an extra notion bolted onto the rig; it is the
containment the four polarities already carry by being subsets of the sign hyperfield.

Two of these theorems say something the Julia code relies on but could not state.
`mul_subset_mul` says that composing matched links gives matched composites, so if a path's
links are each admitted by a motif's links then the path's polarity is admitted by the
motif's path polarity -- which is what makes a motif of a path mean what it appears to mean.
`add_subset_add` says the same of parallel links, which is what lets a motif survive the
push-forward of labels that `coarsen` performs.

Every proof is a finite case split: reflexivity and the top are four goals each,
transitivity sixty-four and the two monotonicity laws two hundred and fifty-six, and each
goal is a table lookup, so `decide` closes it. Mathlib-free, as the rest of this project is
(ADR 0026).
-/

namespace CausalLoopDiagrams.Polarity

/-- Reflexivity: every polarity admits the signs it admits. -/
theorem subset_refl (a : Polarity) : subset a a = true := by
  cases a <;> rfl

/-- `indeterminate` is the greatest element: it admits every sign. -/
theorem subset_top (a : Polarity) : subset a indeterminate = true := by
  cases a <;> rfl

/-- Transitivity. -/
theorem subset_trans (a b c : Polarity) (hab : subset a b = true)
    (hbc : subset b c = true) : subset a c = true := by
  revert hab hbc
  cases a <;> cases b <;> cases c <;> decide

/-- Antisymmetry: two polarities that admit each other's signs are the same polarity. This
is what makes the order a partial order rather than a preorder, and it is why the three
atoms stay distinct. -/
theorem subset_antisymm (a b : Polarity) (hab : subset a b = true)
    (hba : subset b a = true) : a = b := by
  revert hab hba
  cases a <;> cases b <;> decide

/-- The order is not total: `positive` and `negative` are incomparable, which is the whole
reason a diagram can be undetermined about a sign without being wrong about it. -/
theorem positive_negative_incomparable :
    subset positive negative = false ∧ subset negative positive = false := by
  constructor <;> rfl

/-- Composition respects the order: matched links compose to matched composites. -/
theorem mul_subset_mul (a a' b b' : Polarity) (ha : subset a a' = true)
    (hb : subset b b' = true) : subset (mul a b) (mul a' b') = true := by
  revert ha hb
  cases a <;> cases a' <;> cases b <;> cases b' <;> decide

/-- Parallel combination respects the order, which is what lets a motif survive the
push-forward of labels that `coarsen` performs. -/
theorem add_subset_add (a a' b b' : Polarity) (ha : subset a a' = true)
    (hb : subset b b' = true) : subset (add a b) (add a' b') = true := by
  revert ha hb
  cases a <;> cases a' <;> cases b <;> cases b' <;> decide

end CausalLoopDiagrams.Polarity
