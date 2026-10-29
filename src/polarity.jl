# The polarities a link can carry, and how a conditional probability table is read as one.
#
# Baez labels the edges of a causal loop diagram by elements of a monoid [Baez2024](@cite):
# the basic case is the sign group {+, -}, and adding an element for "indeterminate" gives
# the three-element monoid {+, 0, -}. Composition along a path multiplies.
#
# This package uses four polarities rather than three, because a conditional probability
# table distinguishes two cases that monoid writes alike: a table that does not depend on a
# parent at all (`NO_EFFECT`) and one that depends on it in no consistent direction
# (`INDETERMINATE`). The four are the subsets {0}, {+}, {-} and {0, +, -} of the sign
# hyperfield, which are closed under its multiplication and its (multivalued) addition, so
# they form a commutative rig: a sub-rig of the power-set rig Baez constructs from the sign
# hyperfield. Multiplication composes links along a path; addition combines parallel links,
# which is what coarsening a diagram needs (`coarsen`, `collapse_lags`).

"""
    Polarity

The label on a link of a [`CausalLoopDiagram`](@ref): one of [`POSITIVE`](@ref),
[`NEGATIVE`](@ref), [`NO_EFFECT`](@ref) and [`INDETERMINATE`](@ref).

The four values are the subsets `{0}`, `{+}`, `{-}` and `{0, +, -}` of the sign
hyperfield, and they form a commutative rig under its operations
[Baez2024](@cite): `*` composes links along a path (so `one(Polarity) == POSITIVE`) and
`+` combines links in parallel (so `zero(Polarity) == NO_EFFECT`). Negation is
multiplication by `NEGATIVE`.

`show` prints the symbol ([`polarity_symbol`](@ref)), so a vector of polarities reads as
a row of signs.

```jldoctest
julia> POSITIVE * NEGATIVE
-

julia> NEGATIVE * NEGATIVE
+

julia> POSITIVE + NEGATIVE
?

julia> (one(Polarity), zero(Polarity))
(+, 0)
```
"""
struct Polarity
    code::UInt8
    function Polarity(code::Integer)
        0 <= code <= 3 ||
            throw(ArgumentError("a Polarity code is 0 to 3; got $(code). Use POSITIVE, " *
                                "NEGATIVE, NO_EFFECT or INDETERMINATE."))
        return new(UInt8(code))
    end
end

"""
    NO_EFFECT

The polarity of a link along which nothing moves: the table of the child does not depend
on this parent at all. It is the additive unit of [`Polarity`](@ref) (`zero(Polarity)`)
and absorbing for `*`, and prints as `0`.

Baez's three-element monoid `{+, 0, -}` writes `0` for an *indeterminate* sign and has no
element for this one; here the two are [`INDETERMINATE`](@ref) and `NO_EFFECT`
respectively, because a conditional probability table tells them apart.
"""
const NO_EFFECT = Polarity(0)

"""
    POSITIVE

The polarity of a link along which the child moves the same way as the parent: raising the
parent raises the child in the sense of stochastic dominance (see
[`polarity`](@ref polarity(::FiniteKernel, ::Integer))). It is the multiplicative unit of
[`Polarity`](@ref) (`one(Polarity)`) and prints as `+`.
"""
const POSITIVE = Polarity(1)

"""
    NEGATIVE

The polarity of a link along which the child moves the opposite way to the parent.
Prints as `-`.
"""
const NEGATIVE = Polarity(2)

"""
    INDETERMINATE

The polarity of a link with no consistent direction: the child depends on the parent, but
whether it rises or falls depends on the other parents, or on which pair of parent levels
is compared. Prints as `?`.

This is the value a genuine interaction takes, and it is the honest label for a link out of
a variable whose states carry no order at all (a treatment with several incomparable
options, say); [`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel)) takes an
`unordered` keyword that marks such variables.
"""
const INDETERMINATE = Polarity(3)

"""
    polarities() -> NTuple{4, Polarity}

The four polarities in the order [`NO_EFFECT`](@ref), [`POSITIVE`](@ref),
[`NEGATIVE`](@ref), [`INDETERMINATE`](@ref).
"""
polarities() = (NO_EFFECT, POSITIVE, NEGATIVE, INDETERMINATE)

# Multiplication (composition along a path) and addition (parallel links), as 4x4 tables
# indexed by `code + 1`. Written out rather than derived so that the Lean project's tables
# can be compared with these line by line.
const _TIMES = Polarity[NO_EFFECT NO_EFFECT NO_EFFECT NO_EFFECT
                        NO_EFFECT POSITIVE NEGATIVE INDETERMINATE
                        NO_EFFECT NEGATIVE POSITIVE INDETERMINATE
                        NO_EFFECT INDETERMINATE INDETERMINATE INDETERMINATE]

const _PLUS = Polarity[NO_EFFECT POSITIVE NEGATIVE INDETERMINATE
                       POSITIVE POSITIVE INDETERMINATE INDETERMINATE
                       NEGATIVE INDETERMINATE NEGATIVE INDETERMINATE
                       INDETERMINATE INDETERMINATE INDETERMINATE INDETERMINATE]

Base.:*(a::Polarity, b::Polarity) = _TIMES[Int(a.code) + 1, Int(b.code) + 1]
Base.:+(a::Polarity, b::Polarity) = _PLUS[Int(a.code) + 1, Int(b.code) + 1]
Base.:-(a::Polarity) = a * NEGATIVE
Base.one(::Type{Polarity}) = POSITIVE
Base.one(::Polarity) = POSITIVE
Base.zero(::Type{Polarity}) = NO_EFFECT
Base.zero(::Polarity) = NO_EFFECT

"""
    issubset(a::Polarity, b::Polarity) -> Bool

Whether every sign `a` admits is a sign `b` admits, in the subset order the four
polarities carry by construction: `{0}`, `{+}` and `{-}` are the three atoms, each
contained in itself and in `{0, +, -}` ([`INDETERMINATE`](@ref)) and in nothing else.

It is a partial order, not a total one -- [`POSITIVE`](@ref) and [`NEGATIVE`](@ref) are
incomparable -- with `INDETERMINATE` as its greatest element. There is no least element,
because the empty set is not one of the four.

This is the order a motif matches along (see [`occurrences`](@ref)), and the direction
matters: a motif link matches a diagram's link when `issubset(diagram_label,
motif_label)`, the label found being one of the signs the motif will admit. So a motif link
labelled `INDETERMINATE` asks only that *some* link be there and matches whatever sign it
carries, while one labelled `POSITIVE` matches a positive link alone. The wildcard of the
motif search is therefore not an extra value added for it, but the top of the rig that was
already there.

Read the other way the containment says something different and also true: a link which is
genuinely `INDETERMINATE` does **not** match a motif asking for `POSITIVE`, because the
diagram does not claim that sign.

```jldoctest
julia> issubset(POSITIVE, INDETERMINATE)
true

julia> issubset(INDETERMINATE, POSITIVE)
false

julia> issubset(POSITIVE, NEGATIVE)
false
```
"""
Base.issubset(a::Polarity, b::Polarity) = a == b || b == INDETERMINATE

const _SYMBOLS = ("0", "+", "-", "?")
const _NAMES = (:no_effect, :positive, :negative, :indeterminate)

"""
    polarity_symbol(p::Polarity) -> String

The one-character form of a polarity, as the figures and tables print it: `"0"`, `"+"`,
`"-"` or `"?"`.
"""
polarity_symbol(p::Polarity) = _SYMBOLS[Int(p.code) + 1]

"""
    polarity_name(p::Polarity) -> Symbol

The polarity as a word: `:no_effect`, `:positive`, `:negative` or `:indeterminate`.
"""
polarity_name(p::Polarity) = _NAMES[Int(p.code) + 1]

Base.show(io::IO, p::Polarity) = print(io, polarity_symbol(p))

# Reading a polarity off a conditional probability table
########################################################

"""
    polarity(k::FiniteKernel, position::Integer; atol = DEFAULT_ATOL) -> Polarity
    polarity(k::FiniteKernel, parent::Symbol; atol = DEFAULT_ATOL) -> Polarity

The polarity of the dependence of a kernel's child on one of its parents, named or given
by its position in the domain: the direction in which the child's distribution moves as
that parent rises through its states, with the other parents held fixed.

The test is **stochastic monotonicity** in the declared order of the states. Writing
`F(j | x)` for the probability that the child is in state `j` or later given parent level
`x`, the kernel is increasing in that parent when `F(j | x)` never decreases as `x` rises,
for every `j` and every configuration of the other parents, and decreasing when it never
increases. So

  - [`POSITIVE`](@ref) -- increasing and not constant,
  - [`NEGATIVE`](@ref) -- decreasing and not constant,
  - [`NO_EFFECT`](@ref) -- the child's distribution does not depend on this parent,
  - [`INDETERMINATE`](@ref) -- neither, which is what an interaction with another parent
    looks like.

`atol` is the slack allowed in each comparison; it defaults to FiniteKernels'
`DEFAULT_ATOL`.

Monotone kernels compose, which is what makes this reading a labelling in the sense of
[Baez2024](@cite): if the child's distribution rises with the parent and a further kernel
is monotone in the child, the composite rises with the parent, so the polarity of a path is
the product of the polarities of its links. The direction depends on the order the states
were *declared* in; a variable whose states run from best to worst reads backwards, which
is what the `reversed` keyword of
[`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel)) is for.

Both state orders matter, so a kernel over unordered states has no meaningful polarity;
nothing here can detect that, and it is the caller's business to say so.

```jldoctest
julia> X = FiniteAxis(:Rain, [:dry, :wet]);

julia> Y = FiniteAxis(:Grass, [:brown, :green]);

julia> polarity(cpt(X, Y, [0.9 0.1; 0.2 0.8]), :Rain)
+

julia> polarity(cpt(X, Y, [0.5 0.5; 0.5 0.5]), :Rain)
0
```
"""
function polarity(k::FiniteKernel, position::Integer; atol::Real=DEFAULT_ATOL)
    ndims(k.codom) == 1 ||
        throw(ArgumentError("polarity needs a kernel with one child axis; this one has " *
                            "$(ndims(k.codom))."))
    table = cpt(k)
    nparents = ndims(table) - 1
    1 <= position <= nparents ||
        throw(ArgumentError("position $(position) is outside the $(nparents) parents of " *
                            "the kernel."))
    # Bring the parent of interest to the front and flatten the others, so that the scan
    # below is over (level, other configuration, child state) whatever the rank.
    rest = filter(!=(Int(position)), 1:nparents)
    block = reshape(permutedims(table, (Int(position), rest..., nparents + 1)),
                    size(table, position), :, size(table, nparents + 1))
    up = true
    down = true
    for other in axes(block, 2), level in 1:(size(block, 1) - 1)
        lower = zero(float(eltype(block)))
        upper = zero(float(eltype(block)))
        for j in reverse(axes(block, 3))     # tail probabilities, from the top state down
            lower += block[level, other, j]
            upper += block[level + 1, other, j]
            upper < lower - atol && (up = false)
            upper > lower + atol && (down = false)
            up || down || return INDETERMINATE
        end
    end
    up && down && return NO_EFFECT           # every level gives the same distribution
    return up ? POSITIVE : NEGATIVE
end

function polarity(k::FiniteKernel, parent::Symbol; atol::Real=DEFAULT_ATOL)
    names = axis_names(k.dom)
    position = findfirst(==(parent), names)
    position === nothing &&
        throw(ArgumentError("the kernel has no parent $(repr(parent)); its parents are " *
                            "$(names)."))
    return polarity(k, position; atol=atol)
end
