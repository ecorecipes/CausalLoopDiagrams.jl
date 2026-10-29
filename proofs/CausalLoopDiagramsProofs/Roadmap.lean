/-!
# Remaining work

This module contains no declarations. It records, in one place, what this project does
**not** prove, so that the claim made for it stays the claim it can support.

## The composition theorem, which is now proved

This file used to say that the one gap worth closing was the composition theorem: that
monotone kernels compose, which is what makes reading a polarity off a conditional
probability table a *labelling* in Baez's sense rather than a convention. It is closed.
`Theory.Composition` proves it -- `reads_comp` for the four sign combinations, with
`polarity_comp` stating the consequence in the rig of `Basic.lean` -- and the proof needed
exactly what this file predicted it would: real-valued kernels and summation by parts, so
Mathlib. ADR 0028 took that dependency for the `Theory` library alone, and the core remains
Mathlib-free and axiom-free.

Two things that proof does **not** cover, which are the honest residue of closing the gap:

- **The other parents.** The theorem is stated for kernels with one parent, which is what a
  link of a causal loop diagram is. `polarity(kernel, parent)` in `src/polarity.jl` holds
  the other parents fixed and demands monotonicity for *every* configuration of them,
  failing to `INDETERMINATE` otherwise. That quantifier over configurations is not modelled
  here, so the Lean theorem is about each slice and the Julia function is about all of them
  at once.
- **The tolerance.** The theorem is about exact real arithmetic. The Julia test allows
  `atol` slack in each comparison, so a table within tolerance of monotone reads as
  monotone, and nothing proved here says that composing two such tables stays within any
  particular tolerance. The numerical test in `test/test_polarity.jl` is what stands behind
  the floating-point case.

## What else is outside the project

- The Julia implementation. `pathPolarity` is a product over a list; `loops` in Julia
  enumerates elementary circuits of an ACSet and multiplies entries of a matrix. The two
  agree by inspection, not by proof, and no part of this project reads the Julia source.
- The two tables. `Basic.lean` holds a hand-written copy of the matrices in
  `src/polarity.jl`. Neither is generated from the other, and nothing checks that they
  agree; ADR 0026 requires them to be changed together, and the numerical rig-law tests on
  the Julia side are what would catch a divergence in the laws (though not one that
  preserved them).
- The sign hyperfield itself. That the four values are a sub-rig of the power-set rig of the
  hyperfield of signs is the reason the tables are what they are; here they are given, and
  the rig laws are proved of them directly.
-/
