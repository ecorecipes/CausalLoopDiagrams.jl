import CausalLoopDiagramsProofs

/-!
The axioms every headline theorem of this project depends on. Run with `make audit`
(`lake env lean Audit.lean`).

Expected output: the ten rig laws depend on **no axioms at all**, because each is a finite
case split closed by `rfl`. The three path and loop theorems depend on `propext` alone,
which `simp` introduces in the list inductions. Nothing here uses `Classical.choice` or
`Quot.sound`.
-/

open CausalLoopDiagrams.Polarity

#print axioms mul_comm
#print axioms mul_assoc
#print axioms one_mul
#print axioms zero_mul
#print axioms add_comm
#print axioms add_assoc
#print axioms zero_add
#print axioms left_distrib
#print axioms right_distrib
#print axioms neg_neg
#print axioms pathPolarity_append
#print axioms pathPolarity_rotate
#print axioms pathPolarity_eq_zero_of_mem_zero
