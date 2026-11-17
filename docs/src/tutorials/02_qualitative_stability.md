# Qualitative stability: what the signs of a diagram say about a system
Simon Frost

- [Overview](#overview)
- [The snowshoe hare models](#the-snowshoe-hare-models)
- [The sign pattern](#the-sign-pattern)
- [How often is each model stable?](#how-often-is-each-model-stable)
- [A press on the vegetation](#a-press-on-the-vegetation)
- [Why: a positive feedback loop](#why-a-positive-feedback-loop)
- [Links of unknown sign](#links-of-unknown-sign)
- [What the signs do not say](#what-the-signs-do-not-say)

## Overview

A causal loop diagram drawn for a dynamical system says which way each
variable pushes each other one. Read near an equilibrium, that is the
sign pattern of the system’s Jacobian: the link from `A` to `B` is the
sign of the entry in row `B`, column `A`. The signs alone do not fix the
dynamics, but they constrain it, and two questions can be asked of every
system consistent with them:

- **Is it stable?** The fraction of matrices with the diagram’s signs
  and random magnitudes whose eigenvalues all have negative real part
  (quasi-sign-stability, Allesina and Pascual 2008).
- **What does a press do?** A sustained increase in one variable shifts
  the equilibrium of every other by the corresponding column of `-J⁻¹`.
  Among the stable matrices, how often does each response have the same
  sign? This is the simulation approach of QPress (Melbourne-Thomas et
  al. 2012, *Ecological Monographs* 82:505–519), building on Dambacher
  et al.’s qualitative analysis.

The metrics live in ResilienceCore.jl, which this package re-exports for
diagrams: `SignPattern(cld)`, `quasi_sign_stability(cld)` and
`press_sign_determinacy(cld)`.

``` julia
using CausalLoopDiagrams
using Random: Xoshiro
```

## The snowshoe hare models

Dambacher and Ramos-Jiliberto (2007, *The Quarterly Review of Biology*
82:227–250) compare five models of snowshoe hares *H*, the vegetation
*V* they eat and their predator *P*. The QPress package uses them as its
worked example; the definitions below follow its vignette (“Snowshoe
hare example analyses”, Melbourne-Thomas, Raymond, Constable and
Wotherspoon). Each consumer link is a pair: the resource benefits the
consumer, the consumer harms the resource.

``` julia
consume(resource, consumer) = [(resource, consumer) => POSITIVE, (consumer, resource) => NEGATIVE]
limited(x) = (x, x) => NEGATIVE

base = [limited(:V); limited(:P); consume(:V, :H); consume(:H, :P)]
models = (A = causal_loop_diagram(base),
          B = causal_loop_diagram([base; (:V, :P) => POSITIVE]),
          C = causal_loop_diagram([base; (:V, :P) => POSITIVE; limited(:H)]),
          D = causal_loop_diagram([base; consume(:V, :P)]),
          E = causal_loop_diagram([base; consume(:V, :P); limited(:H)]))
nothing
```

In model B the vegetation also benefits the predator directly (cover,
say); in model D the predator also eats the vegetation; C and E add
self-limitation of the hares to B and D.

## The sign pattern

`SignPattern` turns a diagram into the sign pattern of a Jacobian, with
rows for the affected factor and columns for the acting one. A causal
loop diagram rarely draws self-limitation, and by default every factor
without a drawn self-link is given one (QPress’s `enforce.limitation`).
To keep the models exactly as drawn, pass `self_regulation = :as_drawn`.

``` julia
s = SignPattern(models.A; self_regulation = :as_drawn)
s.labels, s.S
```

    (["V", "P", "H"], Int8[-1 0 -1; 0 -1 1; 1 -1 0])

With the default, the hare gains a negative diagonal entry, which is
model A’s counterpart of model C:

``` julia
SignPattern(models.A).S
```

    3×3 Matrix{Int8}:
     -1   0  -1
      0  -1   1
      1  -1  -1

## How often is each model stable?

``` julia
for (name, m) in pairs(models)
    drawn = quasi_sign_stability(Xoshiro(1), m; self_regulation = :as_drawn).fraction
    limited_all = quasi_sign_stability(Xoshiro(1), m).fraction
    println(rpad(name, 3), "as drawn ", rpad(round(drawn; digits = 3), 7),
            "  all self-limited ", round(limited_all; digits = 3))
end
```

    A  as drawn 1.0      all self-limited 1.0
    B  as drawn 0.783    all self-limited 0.856
    C  as drawn 0.856    all self-limited 0.856
    D  as drawn 0.822    all self-limited 0.946
    E  as drawn 0.946    all self-limited 0.946

Model A is stable for every choice of magnitudes: a chain of
predator-prey pairs with self-limitation at both ends. Adding the direct
benefit of vegetation to the predator (model B) makes stability depend
on the magnitudes.

## A press on the vegetation

The question in Dambacher and Ramos-Jiliberto (2007) is how hares
respond to more vegetation. `press_sign_determinacy` returns, for every
pair, the most common sign of the response (row: responding factor,
column: pressed factor) and the fraction of stable systems with that
sign.

``` julia
function hare_response(m)
    p = press_sign_determinacy(Xoshiro(1), m; self_regulation = :as_drawn)
    h, v = findfirst(==("H"), p.labels), findfirst(==("V"), p.labels)
    sgn, det = p.sign[h, v], p.determinacy[h, v]
    # the share of stable systems in which hares fall (the response is never exactly zero here)
    down = sgn < 0 ? det : sgn > 0 ? 1 - det : missing
    return (sign = sgn, determinacy = round(det; digits = 3), hares_fall = round(down; digits = 3),
            stable = round(p.stable; digits = 3))
end
[name => hare_response(m) for (name, m) in pairs(models)]
```

    5-element Vector{Pair{Symbol, @NamedTuple{sign::Int8, determinacy::Float64, hares_fall::Float64, stable::Float64}}}:
     :A => (sign = 1, determinacy = 1.0, hares_fall = 0.0, stable = 1.0)
     :B => (sign = 1, determinacy = 0.641, hares_fall = 0.359, stable = 0.783)
     :C => (sign = 1, determinacy = 0.587, hares_fall = 0.413, stable = 0.856)
     :D => (sign = 1, determinacy = 0.585, hares_fall = 0.415, stable = 0.822)
     :E => (sign = 1, determinacy = 0.528, hares_fall = 0.472, stable = 0.946)

This reproduces QPress’s reading of the two models: in model A a press
on the vegetation always increases the hares, and in model B hares fall
in close to 40% of the stable systems (the QPress vignette’s figure:
“almost 40%”). Manipulation experiments in which hares did not always
increase with food are what led Dambacher and Ramos-Jiliberto to reject
model A.

## Why: a positive feedback loop

The difference between A and B is one link, and what it adds is a
feedback loop. Loops are read off the diagram itself:

``` julia
for l in loops(models.B)
    println(l)
end
```

    P -> P (-, balancing, instantaneous)
    V -> V (-, balancing, instantaneous)
    P -> H -> P (-, balancing, instantaneous)
    V -> H -> V (-, balancing, instantaneous)
    V -> P -> H -> V (+, reinforcing, instantaneous)

The new loop runs from vegetation to predator to hare and back, and its
polarity is the product of its links’ polarities:

``` julia
loop_polarity(models.B, [:V, :P, :H])
```

    +

A positive (reinforcing) loop of length three. In model A every loop
longer than a self-link is a negative predator-prey pair, which is why
its press responses are all determined; the positive loop of model B is
what can turn the response of hares to more vegetation around. Loop
analysis predicts the sign ambiguity, and the sampling measures it.

## Links of unknown sign

`INDETERMINATE` is the polarity of a link that exists but whose
direction of effect is not known. A sign pattern keeps such links as
*unknown*, and each sample draws them with either sign. If the
predator’s link to the vegetation in model D were known to exist but not
which way it pushes:

``` julia
uncertain = causal_loop_diagram([base; (:V, :P) => POSITIVE; (:P, :V) => INDETERMINATE])
u = SignPattern(uncertain; self_regulation = :as_drawn)
u.unknown
```

    3×3 BitMatrix:
     0  1  0
     0  0  0
     0  0  0

``` julia
quasi_sign_stability(Xoshiro(1), uncertain; self_regulation = :as_drawn)
```

    (fraction = 0.6501, se = 0.004769381406429979)

This is a different kind of uncertainty from QPress’s *uncertain edges*,
which are links of known sign that may or may not be present. A link of
unknown sign is always present.

## What the signs do not say

- **Magnitudes.** The fractions here are for magnitudes drawn uniformly
  on (0, 1). Other distributions give other fractions; only fractions of
  exactly 0 or 1 are properties of the signs alone.
- **Delays.** A delayed link enters the pattern with the sign of its
  effect when it arrives. Stability of a system with delays depends on
  their length, which the pattern cannot see.
- **Self-limitation.** Whether a factor regulates itself is often the
  least certain part of a diagram and the one that matters most for
  stability. Compare `:as_drawn` with the default before trusting
  either.
