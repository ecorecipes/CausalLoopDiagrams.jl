import CausalLoopDiagramsProofs.Basic

/-!
# The polarity rig

`Polarity` with `mul` and `add` is a commutative rig: both operations are commutative and
associative, `one` and `zero` are their units, `zero` is absorbing for `mul`, and `mul`
distributes over `add` on both sides.

Every proof here is a finite case split closed by `rfl`, which is the whole argument for
not depending on Mathlib: there are four constructors, so the distributive law is sixty-four
goals and each is a table lookup. `test/test_polarity.jl` checks the same identities
numerically on the same tables, so a change to one copy that is not mirrored in the other
shows up as a failure on the side that was not changed.

That `Polarity` is a rig and not merely a monoid is what makes `coarsen` well defined: the
push-forward of edge labels along a map of graphs has to combine the labels of links that
become parallel, and combining them is `add`.
-/

namespace CausalLoopDiagrams.Polarity

theorem mul_comm (a b : Polarity) : mul a b = mul b a := by
  cases a <;> cases b <;> rfl

theorem mul_assoc (a b c : Polarity) : mul (mul a b) c = mul a (mul b c) := by
  cases a <;> cases b <;> cases c <;> rfl

theorem one_mul (a : Polarity) : mul one a = a := by cases a <;> rfl

theorem mul_one (a : Polarity) : mul a one = a := by cases a <;> rfl

theorem zero_mul (a : Polarity) : mul zero a = zero := by cases a <;> rfl

theorem mul_zero (a : Polarity) : mul a zero = zero := by cases a <;> rfl

theorem add_comm (a b : Polarity) : add a b = add b a := by
  cases a <;> cases b <;> rfl

theorem add_assoc (a b c : Polarity) : add (add a b) c = add a (add b c) := by
  cases a <;> cases b <;> cases c <;> rfl

theorem zero_add (a : Polarity) : add zero a = a := by cases a <;> rfl

theorem add_zero (a : Polarity) : add a zero = a := by cases a <;> rfl

theorem left_distrib (a b c : Polarity) :
    mul a (add b c) = add (mul a b) (mul a c) := by
  cases a <;> cases b <;> cases c <;> rfl

theorem right_distrib (a b c : Polarity) :
    mul (add a b) c = add (mul a c) (mul b c) := by
  cases a <;> cases b <;> cases c <;> rfl

/-- Addition is idempotent: two pathways that agree say no more than one of them does. -/
theorem add_idem (a : Polarity) : add a a = a := by cases a <;> rfl

/-- A positive pathway beside a negative one determines nothing. This is the entry in the
table that a diagram of signs cannot improve on: it has no magnitudes to compare. -/
theorem positive_add_negative : add positive negative = indeterminate := rfl

theorem neg_neg (a : Polarity) : neg (neg a) = a := by cases a <;> rfl

theorem neg_mul (a b : Polarity) : neg (mul a b) = mul (neg a) b := by
  cases a <;> cases b <;> rfl

end CausalLoopDiagrams.Polarity
