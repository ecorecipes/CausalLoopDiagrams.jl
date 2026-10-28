/-!
# Remaining work

This module contains no declarations. It records, in one place, what this project does
**not** prove, so that the claim made for it stays the claim it can support.

## The composition theorem

The reading of a polarity off a conditional probability table
(`polarity(kernel, parent)` in `src/polarity.jl`) is stochastic monotonicity in the declared
order of the states. What makes that reading a *labelling* in Baez's sense, rather than a
convention, is that monotone kernels compose: if the child's distribution rises with the
parent and a further kernel is monotone in the child, the composite rises with the parent,
so the polarity of a path is the product of the polarities of its links.

That theorem is checked numerically in `test/test_polarity.jl`, against
`compose_kernel` on all four sign combinations, and it is **not** proved here. The argument
needs real-valued kernels, finite sums and the equivalence between dominance of upper tails
and monotonicity of expectations of increasing functions, which is an Abel-summation
argument; none of that is available without Mathlib, and ADR 0026 chose a Mathlib-free
project for the sake of the four-element rig. Closing this gap means taking the Mathlib
dependency for one module, and it is the one gap worth closing.

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
