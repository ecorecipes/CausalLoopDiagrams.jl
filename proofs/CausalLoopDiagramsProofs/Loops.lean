import CausalLoopDiagramsProofs.Rig

/-!
# Paths and loops

The polarity of a path is the product of the polarities of its links, which is Baez's
labelling read as a functor out of the free category on the graph: `pathPolarity_append`
is its functoriality.

The theorem worth having is `pathPolarity_rotate`. A loop has no distinguished starting
point, so its polarity had better not depend on where it is cut, and that is exactly what
commutativity of `mul` gives: cutting a loop at a different link rotates its list of
labels, and a rotation leaves the product alone. `loops` in Julia reports every loop rooted
at its smallest factor id, which is one of those cuts; this says that the choice does not
matter.

`pathPolarity_eq_zero_of_mem_zero` is the other one: a loop through a link along which
nothing moves is not a live loop, which is `zero` being absorbing, propagated along a list.
-/

namespace CausalLoopDiagrams.Polarity

/-- The polarity of a path, as the product of its links' polarities in order. The empty
path is the identity, `one`. -/
def pathPolarity : List Polarity → Polarity
  | [] => one
  | p :: ps => mul p (pathPolarity ps)

@[simp] theorem pathPolarity_nil : pathPolarity [] = one := rfl

@[simp] theorem pathPolarity_cons (p : Polarity) (ps : List Polarity) :
    pathPolarity (p :: ps) = mul p (pathPolarity ps) := rfl

/-- Composing two paths multiplies their polarities: the labelling is functorial. -/
theorem pathPolarity_append (xs ys : List Polarity) :
    pathPolarity (xs ++ ys) = mul (pathPolarity xs) (pathPolarity ys) := by
  induction xs with
  | nil => simp [one_mul]
  | cons p ps ih => simp [ih, mul_assoc]

/-- A loop's polarity does not depend on where the loop is cut. -/
theorem pathPolarity_rotate (xs ys : List Polarity) :
    pathPolarity (xs ++ ys) = pathPolarity (ys ++ xs) := by
  rw [pathPolarity_append, pathPolarity_append, mul_comm]

/-- A path through a link along which nothing moves carries nothing. -/
theorem pathPolarity_eq_zero_of_mem_zero :
    ∀ (xs : List Polarity), zero ∈ xs → pathPolarity xs = zero
  | [], h => absurd h (by simp)
  | p :: ps, h => by
      rcases List.mem_cons.mp h with hp | hps
      · simp [← hp, zero_mul]
      · simp [pathPolarity_eq_zero_of_mem_zero ps hps, mul_zero]

/-- A path all of whose links are positive is positive; the reinforcing case. -/
theorem pathPolarity_eq_one_of_all_one :
    ∀ (xs : List Polarity), (∀ p ∈ xs, p = one) → pathPolarity xs = one
  | [], _ => rfl
  | p :: ps, h => by
      have hp : p = one := h p (List.mem_cons_self ..)
      have hps : pathPolarity ps = one :=
        pathPolarity_eq_one_of_all_one ps fun q hq => h q (List.mem_cons_of_mem _ hq)
      simp [hp, hps, one_mul]

end CausalLoopDiagrams.Polarity
