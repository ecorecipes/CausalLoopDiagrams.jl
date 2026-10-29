import Mathlib.Algebra.BigOperators.Module
import Mathlib.Algebra.Order.BigOperators.Ring.Finset
import Mathlib.Data.Real.Basic
import Mathlib.Tactic.Linarith

/-!
# CausalLoopDiagramsProofs.Theory.Dominance

**The stochastic order on finite distributions, and what a monotone function does to it.**

`polarity(kernel, parent)` in `src/polarity.jl` reads a polarity off a conditional
probability table by comparing *upper tails*: writing `F(j | x)` for the probability that
the child is in state `j` or later given parent level `x`, the kernel is increasing in that
parent when `F(j | x)` never decreases as `x` rises, for every `j`. `tail` below is that
`F`, and `Dominates` is that comparison.

The one theorem this file exists for is `sum_mul_le_of_dominates`: a distribution higher in
the stochastic order gives a larger expectation to every increasing function. It is the
step the composition theorem in `Theory.Composition` turns on, and it is why that theorem
needs Mathlib at all -- the proof is summation by parts (`Finset.sum_range_by_parts`), which
needs real-valued sums and is not reachable from Lean core. ADR 0028.

States are the naturals, and a distribution on `n` states is a function `ℕ → ℝ` whose mass
on `Finset.range n` is one. A level of a parent is likewise any natural: a kernel given as
a matrix with finitely many rows extends to all levels by repeating its last row, which
preserves everything proved here.
-/

set_option autoImplicit false

namespace CausalLoopDiagrams.Theory

open Finset

variable {n : ℕ} {p q f : ℕ → ℝ}

/-- The upper tail of `p` at `k`: the probability of state `k` or later, among `n` states.
This is `F(k | x)` of the `polarity` docstring, and the quantity the Julia loop accumulates
as it scans the states from the top down. -/
def tail (n : ℕ) (p : ℕ → ℝ) (k : ℕ) : ℝ := ∑ i ∈ Ico k n, p i

/-- A distribution on `n` states: nonnegative, with total mass one. -/
structure IsDist (n : ℕ) (p : ℕ → ℝ) : Prop where
  /-- No state has negative probability. -/
  nonneg : ∀ i, 0 ≤ p i
  /-- The mass on the `n` states is one. -/
  total : ∑ i ∈ range n, p i = 1

/-- `q` is at least `p` in the usual stochastic order: every upper tail of `q` is at least
the corresponding upper tail of `p`. This is the comparison `polarity` makes between two
adjacent levels of a parent. -/
def Dominates (n : ℕ) (p q : ℕ → ℝ) : Prop := ∀ k, tail n p k ≤ tail n q k

theorem dominates_refl (n : ℕ) (p : ℕ → ℝ) : Dominates n p p := fun _ => le_refl _

theorem dominates_trans {r : ℕ → ℝ} (h₁ : Dominates n p q) (h₂ : Dominates n q r) :
    Dominates n p r := fun k => (h₁ k).trans (h₂ k)

/-- The mass of `p` splits at any state within range into what lies below and the tail. -/
theorem sum_range_add_tail (p : ℕ → ℝ) {n k : ℕ} (h : k ≤ n) :
    (∑ i ∈ range k, p i) + tail n p k = ∑ i ∈ range n, p i := by
  rw [tail, range_eq_Ico, range_eq_Ico]
  exact sum_Ico_consecutive p (Nat.zero_le k) h

/-- Tails subtract, which is what lets a difference of distributions be handled at once. -/
theorem tail_sub (p q : ℕ → ℝ) (n k : ℕ) :
    tail n (fun i => q i - p i) k = tail n q k - tail n p k := by
  simp [tail, sum_sub_distrib]

/-- **A higher distribution gives every increasing function a larger expectation.**

The proof is summation by parts. Writing `d = q - p`, the partial sums of `d` vanish at `n`
(the two distributions carry the same mass) and are nonpositive everywhere below it (`q`
dominates `p`), so Abel's transformation turns the difference of expectations into a sum of
products of a nonnegative increment of `f` with a nonpositive partial sum.

Only equality of total mass is used, not that the mass is one, so this applies to any two
distributions with the same total. -/
theorem sum_mul_le_of_dominates (hf : Monotone f)
    (htotal : ∑ i ∈ range n, p i = ∑ i ∈ range n, q i) (hpq : Dominates n p q) :
    ∑ i ∈ range n, p i * f i ≤ ∑ i ∈ range n, q i * f i := by
  set d : ℕ → ℝ := fun i => q i - p i with hd
  -- The total of the difference is zero, so each partial sum is minus the tail there.
  have hdn : ∑ i ∈ range n, d i = 0 := by
    simp only [hd, sum_sub_distrib, htotal, sub_self]
  have hD : ∀ k, k ≤ n → ∑ i ∈ range k, d i ≤ 0 := by
    intro k hk
    have hsplit := sum_range_add_tail d hk
    have hnn : 0 ≤ tail n d k := by
      rw [hd, tail_sub]
      linarith [hpq k]
    rw [hdn] at hsplit
    linarith
  -- Abel's transformation, with the boundary term killed by `hdn`.
  have habel : ∑ i ∈ range n, d i * f i
      = -∑ i ∈ range (n - 1), (f (i + 1) - f i) * ∑ j ∈ range (i + 1), d j := by
    have h := Finset.sum_range_by_parts f d n
    simp only [smul_eq_mul] at h
    rw [hdn, mul_zero, zero_sub] at h
    calc ∑ i ∈ range n, d i * f i
        = ∑ i ∈ range n, f i * d i := sum_congr rfl fun i _ => mul_comm _ _
      _ = _ := h
  -- Every term of that sum is nonpositive: a rising increment times a nonpositive partial sum.
  have hterms : ∑ i ∈ range (n - 1), (f (i + 1) - f i) * ∑ j ∈ range (i + 1), d j ≤ 0 := by
    refine sum_nonpos fun i hi => ?_
    have hi' : i + 1 ≤ n := by have := mem_range.mp hi; omega
    have h1 : 0 ≤ f (i + 1) - f i := by linarith [hf (Nat.le_succ i)]
    have h2 : ∑ j ∈ range (i + 1), d j ≤ 0 := hD (i + 1) hi'
    exact mul_nonpos_iff.mpr (Or.inl ⟨h1, h2⟩)
  -- Unwind: the difference of the two expectations is that nonnegative quantity.
  have hdiff : ∑ i ∈ range n, d i * f i
      = (∑ i ∈ range n, q i * f i) - ∑ i ∈ range n, p i * f i := by
    simp only [hd, ← sum_sub_distrib]
    exact sum_congr rfl fun i _ => by ring
  rw [hdiff] at habel
  linarith

/-- The mirror of `sum_mul_le_of_dominates` for a decreasing function: a higher distribution
gives every *decreasing* function a smaller expectation. Proved by applying the increasing
case to `-f`. -/
theorem sum_mul_le_of_dominates_antitone (hf : Antitone f)
    (htotal : ∑ i ∈ range n, p i = ∑ i ∈ range n, q i) (hpq : Dominates n p q) :
    ∑ i ∈ range n, q i * f i ≤ ∑ i ∈ range n, p i * f i := by
  have hmono : Monotone fun i => -f i := fun a b hab => neg_le_neg (hf hab)
  have h := sum_mul_le_of_dominates (f := fun i => -f i) hmono htotal hpq
  have hp : ∑ i ∈ range n, p i * -f i = -∑ i ∈ range n, p i * f i := by
    simp [mul_neg, sum_neg_distrib]
  have hq : ∑ i ∈ range n, q i * -f i = -∑ i ∈ range n, q i * f i := by
    simp [mul_neg, sum_neg_distrib]
  rw [hp, hq] at h
  linarith

end CausalLoopDiagrams.Theory
