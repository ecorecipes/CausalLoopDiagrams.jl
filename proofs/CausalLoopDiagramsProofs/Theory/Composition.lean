import CausalLoopDiagramsProofs.Basic
import CausalLoopDiagramsProofs.Theory.Dominance

/-!
# CausalLoopDiagramsProofs.Theory.Composition

**Monotone kernels compose, so the polarity of a path is the product of the polarities of
its links.**

This is the theorem `Roadmap.lean` named as the one gap worth closing, and ADR 0028 is the
amendment that let it be proved: it needs real-valued kernels and summation by parts, so
this library is built against Mathlib while the polarity rig in `Basic`, `Rig`, `Order` and
`Loops` stays Mathlib-free.

What it is for. `polarity(kernel, parent)` in `src/polarity.jl` *reads* a polarity off a
conditional probability table rather than asserting one, by testing stochastic monotonicity
in the declared order of the states. That reading is only a labelling in Baez's sense if the
label of a path is determined by the labels of its links, and `reads_comp` is that fact:
composing a kernel that reads `d` with one that reads `e` gives a kernel that reads
`d.mul e`, and `Direction.polarity_mul` says `mul` on directions agrees with `Polarity.mul`
on the nose. Julia checks the same statement numerically against `compose_kernel` on all
four sign combinations in `test/test_polarity.jl`; here it is proved for every kernel.

The two remaining polarities need no theorem of their own:

- `noEffect` is covered by `constant_comp_of_constant_left` and
  `constant_comp_of_constant_right`, which together say that a constant link on either side
  makes the composite constant -- which is exactly `noEffect` being absorbing for `mul`.
- `indeterminate` is the greatest element of the subset order, so it admits every behaviour
  and asserts none. `Order.lean`'s `mul_subset_mul` is what makes that coarsening sound, and
  it is proved there without Mathlib.
-/

set_option autoImplicit false

namespace CausalLoopDiagrams.Theory

open Finset

variable {n : ℕ} {K L : ℕ → ℕ → ℝ}

/-- A kernel on `n` states: `K a i` is the probability of child state `i` at parent level
`a`, so every level carries a distribution. -/
structure IsKernel (n : ℕ) (K : ℕ → ℕ → ℝ) : Prop where
  /-- Each level of the parent gives a distribution over the `n` child states. -/
  dist : ∀ a, IsDist n (K a)

/-- The kernel rises with its parent: the child's distribution moves up in the stochastic
order as the level rises. This is `POSITIVE` in `src/polarity.jl`, apart from the separate
requirement there that the kernel not be constant. -/
def Increasing (n : ℕ) (K : ℕ → ℕ → ℝ) : Prop := ∀ a b, a ≤ b → Dominates n (K a) (K b)

/-- The kernel falls with its parent. `NEGATIVE`, with the same caveat. -/
def Decreasing (n : ℕ) (K : ℕ → ℕ → ℝ) : Prop := ∀ a b, a ≤ b → Dominates n (K b) (K a)

/-- The child's distribution does not depend on the parent at all: `NO_EFFECT`. Stated on
tails, because that is what the Julia test compares. -/
def Constant (n : ℕ) (K : ℕ → ℕ → ℝ) : Prop := ∀ a b k, tail n (K a) k = tail n (K b) k

/-- Composition of two links of a path: `K` carries the level to the middle factor, `L`
carries the middle factor to the child. This is `compose_kernel` for one-parent kernels. -/
def comp (n : ℕ) (K L : ℕ → ℕ → ℝ) : ℕ → ℕ → ℝ := fun a j => ∑ i ∈ range n, K a i * L i j

/-- A tail splits off its lowest state. -/
theorem tail_succ (p : ℕ → ℝ) {n k : ℕ} (h : k < n) :
    tail n p k = p k + tail n p (k + 1) := sum_eq_sum_Ico_succ_bot h p

/-- Equal tails everywhere means equal probabilities on the states, so `Constant` really is
"the table does not depend on this parent" and not merely something weaker about tails. -/
theorem eq_of_tail_eq {p q : ℕ → ℝ} (h : ∀ k, tail n p k = tail n q k) {i : ℕ} (hi : i < n) :
    p i = q i := by
  have h₁ := tail_succ p hi
  have h₂ := tail_succ q hi
  have := h i
  have := h (i + 1)
  linarith

/-- A kernel both increasing and decreasing is constant -- the step by which the Julia test
returns `NO_EFFECT` when its `up` and `down` flags both survive the scan. -/
theorem constant_of_increasing_of_decreasing (hi : Increasing n K) (hd : Decreasing n K) :
    Constant n K := by
  intro a b k
  rcases le_total a b with hab | hab
  · exact le_antisymm (hi a b hab k) (hd a b hab k)
  · exact le_antisymm (hd b a hab k) (hi b a hab k)

/-- **The tail of a composite is an expectation of tails.** The probability that the child
of the composite lands at `k` or later is the mean, under the first kernel, of the same
probability for the second. Everything below is this identity plus `Dominance`. -/
theorem tail_comp (n : ℕ) (K L : ℕ → ℕ → ℝ) (a k : ℕ) :
    tail n (comp n K L a) k = ∑ i ∈ range n, K a i * tail n (L i) k := by
  simp only [tail, comp]
  rw [Finset.sum_comm]
  exact sum_congr rfl fun i _ => (mul_sum _ _ _).symm

/-- A composite of kernels is a kernel. -/
theorem isKernel_comp (hK : IsKernel n K) (hL : IsKernel n L) : IsKernel n (comp n K L) :=
  ⟨fun a =>
    ⟨fun j => sum_nonneg fun i _ => mul_nonneg ((hK.dist a).nonneg i) ((hL.dist i).nonneg j), by
      simp only [comp]
      rw [Finset.sum_comm]
      calc ∑ i ∈ range n, ∑ j ∈ range n, K a i * L i j
          = ∑ i ∈ range n, K a i * ∑ j ∈ range n, L i j :=
            sum_congr rfl fun i _ => (mul_sum _ _ _).symm
        _ = ∑ i ∈ range n, K a i :=
            sum_congr rfl fun i _ => by rw [(hL.dist i).total, mul_one]
        _ = 1 := (hK.dist a).total⟩⟩

/-- Two rising links make a rising path: `positive * positive = positive`. -/
theorem increasing_comp (hK : IsKernel n K) (hKi : Increasing n K) (hLi : Increasing n L) :
    Increasing n (comp n K L) := by
  intro a b hab k
  rw [tail_comp, tail_comp]
  exact sum_mul_le_of_dominates (f := fun i => tail n (L i) k) (fun i j hij => hLi i j hij k)
    (by rw [(hK.dist a).total, (hK.dist b).total]) (hKi a b hab)

/-- A rising link then a falling one makes a falling path:
`positive * negative = negative`. -/
theorem decreasing_comp_of_increasing_of_decreasing (hK : IsKernel n K) (hKi : Increasing n K)
    (hLd : Decreasing n L) : Decreasing n (comp n K L) := by
  intro a b hab k
  rw [tail_comp, tail_comp]
  exact sum_mul_le_of_dominates_antitone (f := fun i => tail n (L i) k)
    (fun i j hij => hLd i j hij k) (by rw [(hK.dist a).total, (hK.dist b).total]) (hKi a b hab)

/-- A falling link then a rising one makes a falling path:
`negative * positive = negative`. -/
theorem decreasing_comp_of_decreasing_of_increasing (hK : IsKernel n K) (hKd : Decreasing n K)
    (hLi : Increasing n L) : Decreasing n (comp n K L) := by
  intro a b hab k
  rw [tail_comp, tail_comp]
  exact sum_mul_le_of_dominates (f := fun i => tail n (L i) k) (fun i j hij => hLi i j hij k)
    (by rw [(hK.dist b).total, (hK.dist a).total]) (hKd a b hab)

/-- Two falling links make a rising path: `negative * negative = positive`. This is the one
of the four that readers of causal loop diagrams most often get the wrong way round, and the
reason a pair of factors that each suppress the other is a reinforcing loop. -/
theorem increasing_comp_of_decreasing_of_decreasing (hK : IsKernel n K) (hKd : Decreasing n K)
    (hLd : Decreasing n L) : Increasing n (comp n K L) := by
  intro a b hab k
  rw [tail_comp, tail_comp]
  exact sum_mul_le_of_dominates_antitone (f := fun i => tail n (L i) k)
    (fun i j hij => hLd i j hij k) (by rw [(hK.dist b).total, (hK.dist a).total]) (hKd a b hab)

/-- A constant first link makes the composite constant: `noEffect * p = noEffect`. -/
theorem constant_comp_of_constant_left (hc : Constant n K) : Constant n (comp n K L) := by
  intro a b k
  rw [tail_comp, tail_comp]
  exact sum_congr rfl fun i hi => by
    rw [eq_of_tail_eq (fun j => hc a b j) (mem_range.mp hi)]

/-- A constant second link makes the composite constant: `p * noEffect = noEffect`. -/
theorem constant_comp_of_constant_right (hK : IsKernel n K) (hc : Constant n L) :
    Constant n (comp n K L) := by
  intro a b k
  have key : ∀ c, ∑ i ∈ range n, K c i * tail n (L i) k = tail n (L 0) k := by
    intro c
    calc ∑ i ∈ range n, K c i * tail n (L i) k
        = ∑ i ∈ range n, K c i * tail n (L 0) k := sum_congr rfl fun i _ => by rw [hc i 0 k]
      _ = (∑ i ∈ range n, K c i) * tail n (L 0) k := by rw [← sum_mul]
      _ = tail n (L 0) k := by rw [(hK.dist c).total, one_mul]
  rw [tail_comp, tail_comp, key a, key b]

/-- The two determinate directions a link can read as. `indeterminate` and `noEffect` are
not here: the first asserts nothing and the second is handled by `Constant`. -/
inductive Direction where
  /-- The child rises with the parent. -/
  | up : Direction
  /-- The child falls as the parent rises. -/
  | down : Direction
  deriving DecidableEq, Repr

namespace Direction

/-- The polarity a direction is written as. -/
def polarity : Direction → Polarity
  | up => Polarity.positive
  | down => Polarity.negative

/-- Composition of directions: signs multiply. -/
def mul : Direction → Direction → Direction
  | up, up => up
  | up, down => down
  | down, up => down
  | down, down => up

/-- Composing directions agrees with multiplying polarities, on all four combinations. This
is what ties the analytic theorem below to the rig of `Basic.lean`. -/
theorem polarity_mul (d e : Direction) :
    (d.mul e).polarity = Polarity.mul d.polarity e.polarity := by
  cases d <;> cases e <;> rfl

end Direction

/-- `Reads n K d`: the kernel `K`, read by the test of `src/polarity.jl`, has direction
`d`. -/
def Reads (n : ℕ) (K : ℕ → ℕ → ℝ) : Direction → Prop
  | Direction.up => Increasing n K
  | Direction.down => Decreasing n K

/-- **Monotone kernels compose.** If the first link reads as `d` and the second as `e`, the
composite reads as `d.mul e`. The four cases are the four theorems above. -/
theorem reads_comp (hK : IsKernel n K) {d e : Direction} (hd : Reads n K d)
    (he : Reads n L e) : Reads n (comp n K L) (d.mul e) := by
  cases d <;> cases e
  · exact increasing_comp hK hd he
  · exact decreasing_comp_of_increasing_of_decreasing hK hd he
  · exact decreasing_comp_of_decreasing_of_increasing hK hd he
  · exact increasing_comp_of_decreasing_of_decreasing hK hd he

/-- **The composition theorem, as the polarity statement it exists to support:** the
polarity of a path of two links is the product, in the rig of `Basic.lean`, of the
polarities of its links.

This is what makes `polarity(kernel, parent)` a labelling of a causal loop diagram rather
than a convention, and so what makes `pathPolarity` and `loop_polarity` -- products over
lists in `Loops.lean` -- mean what they are read as meaning. -/
theorem polarity_comp (hK : IsKernel n K) {d e : Direction} (hd : Reads n K d)
    (he : Reads n L e) :
    ∃ g : Direction, Reads n (comp n K L) g ∧
      g.polarity = Polarity.mul d.polarity e.polarity :=
  ⟨d.mul e, reads_comp hK hd he, Direction.polarity_mul d e⟩

end CausalLoopDiagrams.Theory
