# Lean proofs for CausalLoopDiagrams.jl

A finite model of the polarity rig, and of the polarity of a path and of a loop.

```sh
lake build --wfail   # the proofs; must be sorry-free and warning-free
make audit           # the axioms each headline theorem uses
```

The audit expects no axioms at all for the ten rig laws, each being a case split closed
by `rfl`, and `propext` alone for the three path and loop theorems, which `simp`
introduces in their list inductions. Nothing uses `Classical.choice` or `Quot.sound`.

**No Mathlib.** This is the only `proofs/` project in the ecosystem without it, and the
reason is in ADR 0026: `Polarity` has four constructors, so every law it satisfies is a
finite case split closed by `rfl`, and the distributive law is sixty-four such goals. There
is no shared dependency checkout to fetch and no `lake exe cache get` step; a clean build
takes seconds.

## What is proved

- `Rig.lean`: `mul` and `add` are commutative and associative, `one = positive` and
  `zero = noEffect` are their units, `zero` is absorbing for `mul`, `mul` distributes over
  `add` on both sides, addition is idempotent, and `positive + negative = indeterminate`.
  So `Polarity` is a commutative rig, which is what `coarsen` needs: pushing edge labels
  forward along a map of graphs has to *add* the labels of links that become parallel.
- `Loops.lean`: the polarity of a path is the product of its links' polarities;
  `pathPolarity_append` is the functoriality of the labelling; `pathPolarity_rotate` says a
  loop's polarity does not depend on where the loop is cut, which is what makes it a
  property of the loop rather than of the way it was written down. Also that a path through
  a link with no effect carries nothing.

## What is not proved

`Roadmap.lean` has the list. The short version: that **monotone kernels compose**, which is
what makes reading a sign off a conditional probability table a labelling rather than a
convention, is checked numerically in `test/test_polarity.jl` and is not a theorem here. It
needs real-valued kernels and an Abel-summation argument, so it needs Mathlib. Nor does the
project read the Julia source: `Basic.lean` holds a hand-written second copy of the two
tables in `src/polarity.jl`, and ADR 0026 requires the two to be changed together.
