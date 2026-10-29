# Lean proofs for CausalLoopDiagrams.jl

A finite model of the polarity rig, of the polarity of a path and of a loop, and of the
composition theorem that makes the first two mean what they are read as meaning.

```sh
make build         # both libraries; each must be sorry-free and warning-free
make audit         # the axioms each headline theorem of the core uses
make audit-theory  # the same for the composition theorem
make mathlib-free  # check that the core still reaches no Mathlib
```

## Two libraries, and why

The project is in two parts, and the split is the subject of ADR 0028.

**The core** (`CausalLoopDiagramsProofs`, the default target) is **Mathlib-free**, as ADR
0026 decided: `Polarity` has four constructors, so every law it satisfies is a finite case
split closed by `rfl` or `decide`, and the distributive law is sixty-four such goals. A
clean build takes seconds. `make audit` expects no axioms at all for the ten rig laws and
the six order theorems, and `propext` alone for the three path and loop theorems, which
`simp` introduces in their list inductions.

**`Theory`** is the one library built against Mathlib, and it exists for one theorem. That
monotone kernels compose cannot be had on the core's terms: it quantifies over real-valued
conditional probability tables and its proof is summation by parts. ADR 0028 took the
dependency for this library alone. Nothing in the core imports it, which is what confines
the reversal -- `make mathlib-free` checks exactly that, and `make audit-theory` records
that these theorems inherit Mathlib's three standard axioms, which is the price of the real
numbers. The dependency checkout is the shared one (ADR 0005), so a cold first build spends
minutes reading ~5 GB of oleans; that is I/O, not elaboration.

## What is proved

- `Rig.lean`: `mul` and `add` are commutative and associative, `one = positive` and
  `zero = noEffect` are their units, `zero` is absorbing for `mul`, `mul` distributes over
  `add` on both sides, addition is idempotent, and `positive + negative = indeterminate`.
  So `Polarity` is a commutative rig, which is what `coarsen` needs: pushing edge labels
  forward along a map of graphs has to *add* the labels of links that become parallel.
- `Order.lean`: `subset` -- containment, reading the polarities as the subsets of the sign
  hyperfield they are -- is a partial order with `indeterminate` greatest, and both rig
  operations respect it. That order is what a motif matches along (ADR 0027), and the two
  monotonicity theorems are what make a motif of a path, and a motif that survives
  `coarsen`, mean what they appear to mean.
- `Loops.lean`: the polarity of a path is the product of its links' polarities;
  `pathPolarity_append` is the functoriality of the labelling; `pathPolarity_rotate` says a
  loop's polarity does not depend on where the loop is cut, which is what makes it a
  property of the loop rather than of the way it was written down. Also that a path through
  a link with no effect carries nothing.
- `Theory/Dominance.lean`: upper tails of a finite distribution, the usual stochastic order
  on them, and the analytic step -- a distribution higher in that order gives every
  increasing function a larger expectation, by Abel's transformation.
- `Theory/Composition.lean`: **monotone kernels compose.** `reads_comp` covers the four sign
  combinations, so a rising link followed by a falling one falls and two falling links rise;
  `polarity_comp` states the consequence in the rig, that the polarity of a path of two
  links is the product of the polarities of its links. `constant_comp_of_constant_left` and
  `..._right` are the `noEffect` case, which is `mul`'s absorbing element. `indeterminate`
  needs no theorem: it is the greatest element of the subset order, so it admits every
  behaviour and asserts none.

Together these say that `polarity(kernel, parent)` in `src/polarity.jl` *reads* a labelling
and does not merely assert one, which is the claim the package rests on and the one Julia
could check numerically but not state.

## What is not proved

`Roadmap.lean` has the list. The composition theorem is no longer on it, but two things
about it are: the Lean statement is for kernels with one parent, while the Julia function
quantifies over every configuration of the *other* parents; and the Lean statement is about
exact real arithmetic, while the Julia test allows `atol` slack in each comparison. Nor does
the project read the Julia source: `Basic.lean` holds a hand-written second copy of the two
tables in `src/polarity.jl`, and ADR 0026 requires the two to be changed together.
