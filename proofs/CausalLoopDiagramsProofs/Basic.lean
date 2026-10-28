/-!
# Polarities

The four polarities a link of a causal loop diagram can carry, and the two operations on
them. This file is a second, hand-written copy of the two tables in
`src/polarity.jl`: neither is generated from the other, so neither is the source of truth
for the other, and ADR 0026 requires them to be changed together.

The four values are the subsets `{0}`, `{+}`, `{-}` and `{0, +, -}` of the sign hyperfield.
`mul` composes links along a path and `add` combines links in parallel. Both tables are
written out in full, sixteen cases each, in the same order as the Julia matrices, so that
the two can be compared line by line.
-/

namespace CausalLoopDiagrams

/-- A polarity: the label on a link of a causal loop diagram. -/
inductive Polarity where
  /-- The link along which nothing moves: the additive unit, absorbing for composition. -/
  | noEffect : Polarity
  /-- The target moves the same way as the source. The multiplicative unit. -/
  | positive : Polarity
  /-- The target moves the opposite way to the source. -/
  | negative : Polarity
  /-- The direction is not determined: `{0, +, -}`. -/
  | indeterminate : Polarity
  deriving DecidableEq, Repr, Inhabited

namespace Polarity

/-- Composition of two links along a path. -/
def mul : Polarity → Polarity → Polarity
  | noEffect, noEffect => noEffect
  | noEffect, positive => noEffect
  | noEffect, negative => noEffect
  | noEffect, indeterminate => noEffect
  | positive, noEffect => noEffect
  | positive, positive => positive
  | positive, negative => negative
  | positive, indeterminate => indeterminate
  | negative, noEffect => noEffect
  | negative, positive => negative
  | negative, negative => positive
  | negative, indeterminate => indeterminate
  | indeterminate, noEffect => noEffect
  | indeterminate, positive => indeterminate
  | indeterminate, negative => indeterminate
  | indeterminate, indeterminate => indeterminate

/-- Combination of two links in parallel. -/
def add : Polarity → Polarity → Polarity
  | noEffect, noEffect => noEffect
  | noEffect, positive => positive
  | noEffect, negative => negative
  | noEffect, indeterminate => indeterminate
  | positive, noEffect => positive
  | positive, positive => positive
  | positive, negative => indeterminate
  | positive, indeterminate => indeterminate
  | negative, noEffect => negative
  | negative, positive => indeterminate
  | negative, negative => negative
  | negative, indeterminate => indeterminate
  | indeterminate, noEffect => indeterminate
  | indeterminate, positive => indeterminate
  | indeterminate, negative => indeterminate
  | indeterminate, indeterminate => indeterminate

/-- The multiplicative unit: a link that passes its source through unchanged. -/
def one : Polarity := positive

/-- The additive unit: no link at all, which reads the same as a link with no effect. -/
def zero : Polarity := noEffect

/-- Negation: multiplication by `negative`, which is what reversing a factor's state order
does to every link at it. -/
def neg (p : Polarity) : Polarity := mul p negative

instance : Mul Polarity := ⟨mul⟩
instance : Add Polarity := ⟨add⟩
instance : Neg Polarity := ⟨neg⟩

/-- The four polarities, for an exhaustive check. -/
def all : List Polarity := [noEffect, positive, negative, indeterminate]

theorem mem_all (p : Polarity) : p ∈ all := by cases p <;> simp [all]

end Polarity

end CausalLoopDiagrams
