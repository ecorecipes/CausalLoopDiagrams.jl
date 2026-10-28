# The diagram itself: an ACSet schema for a labelled multigraph, its builders and its
# accessors.
#
# A causal loop diagram over a monoid M is, in Baez's formulation [Baez2024](@cite), a graph
# `G` -- a pair of functions source, target from edges to vertices -- together with a
# labelling of the edges by elements of M. That is exactly a two-table ACSet, so the schema
# below is the definition rather than an encoding of it. Parallel links are kept, not
# collapsed: two pathways from one factor to another are two links, and combining them is a
# deliberate operation (`coarsen`) rather than something the representation does silently.
#
# The schema is an ACSets.jl `BasicSchema` value rather than a Catlab `@present`
# presentation, so that this package needs no Catlab, following `SchBayesNet` and ADR 0009.

"""
    SchCausalLoop

Schema of a causal loop diagram: objects `Factor` and `Link`, homs
`link_source: Link -> Factor` and `link_target: Link -> Factor`, attribute types `Label`,
`Sign` and `Flag`, and attributes `factor_name` (on `Factor`), `link_polarity` and
`link_delay` (on `Link`). There are no path equations.

A self-link (`link_source == link_target`) is allowed and means what it says; so are
parallel links between the same pair of factors.
"""
const SchCausalLoop = BasicSchema([:Factor, :Link],
                                  [(:link_source, :Link, :Factor),
                                   (:link_target, :Link, :Factor)],
                                  [:Label, :Sign, :Flag],
                                  [(:factor_name, :Factor, :Label),
                                   (:link_polarity, :Link, :Sign),
                                   (:link_delay, :Link, :Flag)])

"""
    AbstractCausalLoopDiagram{S, Ts, P}

Abstract supertype of ACSets whose schema contains [`SchCausalLoop`](@ref). Every accessor
in this package accepts one.
"""
@abstract_acset_type AbstractCausalLoopDiagram

"""
    CausalLoopDiagramUntyped{Label, Sign, Flag}

ACSet type for [`SchCausalLoop`](@ref) with attribute types left open. Use
[`CausalLoopDiagram`](@ref) for the standard instantiation.
"""
@acset_type CausalLoopDiagramUntyped(SchCausalLoop;
                                     index=[:link_source, :link_target, :factor_name]) <:
            AbstractCausalLoopDiagram

"""
    CausalLoopDiagram

A causal loop diagram with `Symbol` factor names, [`Polarity`](@ref) link labels and
`Bool` delay flags: `CausalLoopDiagramUntyped{Symbol, Polarity, Bool}`.

Build one with [`causal_loop_diagram`](@ref causal_loop_diagram(::AbstractVector)) from a
list of links, or read one off a Bayesian network with
[`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel)).

# Example

```jldoctest
julia> cld = causal_loop_diagram([(:Infection, :Defoliation) => POSITIVE,
                                  (:Defoliation, :Vigour) => NEGATIVE,
                                  delayed((:Vigour, :Infection) => NEGATIVE)]);

julia> factor_names(cld)
3-element Vector{Symbol}:
 :Infection
 :Defoliation
 :Vigour
```
"""
const CausalLoopDiagram = CausalLoopDiagramUntyped{Symbol,Polarity,Bool}

# Link specifications
#####################

"""
    LinkSpec(source, target, polarity; delay = false)

One link of a diagram as a value, which is what
[`causal_loop_diagram`](@ref causal_loop_diagram(::AbstractVector)) takes a list of.
`(source, target) => polarity` is read as one of these, and [`delayed`](@ref) marks it as
crossing a delay.
"""
struct LinkSpec
    source::Symbol
    target::Symbol
    polarity::Polarity
    delay::Bool
end

function LinkSpec(source::Symbol, target::Symbol, polarity::Polarity; delay::Bool=false)
    return LinkSpec(source, target, polarity, delay)
end

LinkSpec(s::LinkSpec) = s
function LinkSpec(p::Pair{<:Tuple{Symbol,Symbol},Polarity})
    return LinkSpec(first(first(p)), last(first(p)), last(p), false)
end

"""
    link(source, target, polarity; delay = false) -> LinkSpec

A link specification, the same thing as `(source, target) => polarity` with a name.
"""
function link(source::Symbol, target::Symbol, polarity::Polarity; delay::Bool=false)
    return LinkSpec(source, target, polarity, delay)
end

"""
    delayed(spec) -> LinkSpec

Mark a link as crossing a delay: the effect of the source on the target is not felt in the
same period. `spec` is a [`LinkSpec`](@ref) or a `(source, target) => polarity` pair.

The mark is what separates the two kinds of feedback loop. A loop with a delay in it is a
loop a dynamic Bayesian network represents directly, the delayed link becoming a lagged
input. A loop with no delay anywhere asserts that everything in it happens at once, and no
Bayesian network, static or dynamic, can hold it without an extra assumption; see
[`delayed_loops`](@ref) and [`instantaneous_loops`](@ref).

```jldoctest
julia> delayed((:Vigour, :Infection) => NEGATIVE)
LinkSpec(:Vigour, :Infection, -, true)
```
"""
delayed(spec) = (s = LinkSpec(spec); LinkSpec(s.source, s.target, s.polarity, true))

# Builders
##########

"""
    add_factor!(cld, name::Symbol) -> Int

The part id of the factor called `name`, adding it if the diagram does not have it yet.
Idempotent, so a diagram never acquires two factors with the same name.
"""
function add_factor!(cld::AbstractCausalLoopDiagram, name::Symbol)
    existing = incident(cld, name, :factor_name)
    isempty(existing) || return first(existing)
    return add_part!(cld, :Factor; factor_name=name)
end

"""
    add_link!(cld, source::Symbol, target::Symbol, polarity::Polarity; delay = false) -> Int
    add_link!(cld, spec::LinkSpec) -> Int

Add a link and return its part id, adding either endpoint if the diagram does not carry it
yet. A link parallel to an existing one is added as a second link rather than merged; use
[`coarsen`](@ref) to combine them.
"""
function add_link!(cld::AbstractCausalLoopDiagram, source::Symbol, target::Symbol,
                   polarity::Polarity; delay::Bool=false)
    s = add_factor!(cld, source)
    t = add_factor!(cld, target)
    return add_part!(cld, :Link; link_source=s, link_target=t, link_polarity=polarity,
                     link_delay=delay)
end

function add_link!(cld::AbstractCausalLoopDiagram, spec::LinkSpec)
    return add_link!(cld, spec.source, spec.target, spec.polarity; delay=spec.delay)
end

"""
    causal_loop_diagram(links; factors = Symbol[]) -> CausalLoopDiagram

The diagram with these links, each a [`LinkSpec`](@ref) or a
`(source, target) => polarity` pair. Factors appear in the order they are first mentioned,
after any named in `factors`, which is how an isolated factor is included and how the order
of the rows of [`polarity_matrix`](@ref) is fixed.

```jldoctest
julia> cld = causal_loop_diagram([(:Rain, :Grass) => POSITIVE,
                                  (:Grass, :Sheep) => POSITIVE,
                                  delayed((:Sheep, :Grass) => NEGATIVE)]);

julia> nfactors(cld), nlinks(cld)
(3, 3)
```
"""
function causal_loop_diagram(links::AbstractVector;
                             factors::AbstractVector{Symbol}=Symbol[])
    cld = CausalLoopDiagram()
    for f in factors
        add_factor!(cld, f)
    end
    for spec in links
        add_link!(cld, LinkSpec(spec))
    end
    return cld
end

# Accessors
###########

"""
    nfactors(cld) -> Int

The number of factors.
"""
nfactors(cld::AbstractCausalLoopDiagram) = nparts(cld, :Factor)

"""
    nlinks(cld) -> Int

The number of links, counting parallel links separately.
"""
nlinks(cld::AbstractCausalLoopDiagram) = nparts(cld, :Link)

"""
    factor_names(cld) -> Vector{Symbol}

The names of the factors in part-id order, which is the order they were added in.
"""
factor_names(cld::AbstractCausalLoopDiagram) = collect(subpart(cld, :factor_name))

"""
    factor_name(cld, f::Integer) -> Symbol

The name of factor `f`.
"""
function factor_name(cld::AbstractCausalLoopDiagram, f::Integer)
    return subpart(cld, Int(f), :factor_name)
end

"""
    has_factor(cld, name::Symbol) -> Bool

Whether the diagram carries a factor of this name.
"""
function has_factor(cld::AbstractCausalLoopDiagram, name::Symbol)
    return !isempty(incident(cld, name, :factor_name))
end

"""
    factor_id(cld, name::Symbol) -> Int

The part id of the factor called `name`. Throws [`UnknownFactorError`](@ref) if there is
none.
"""
function factor_id(cld::AbstractCausalLoopDiagram, name::Symbol)
    existing = incident(cld, name, :factor_name)
    isempty(existing) && throw(UnknownFactorError(name, factor_names(cld)))
    return first(existing)
end

"""
    link_table(cld) -> Vector{<:NamedTuple}

Every link in part-id order as a named tuple `(; source, target, polarity, delay)`, with
its endpoints named. This is the form the figures and the vignette tables read.
"""
function link_table(cld::AbstractCausalLoopDiagram)
    return [(source=factor_name(cld, subpart(cld, l, :link_source)),
             target=factor_name(cld, subpart(cld, l, :link_target)),
             polarity=subpart(cld, l, :link_polarity),
             delay=subpart(cld, l, :link_delay)) for l in parts(cld, :Link)]
end

# The ids of the links from `s` to `t` (part ids of factors).
function _links_between(cld::AbstractCausalLoopDiagram, s::Integer, t::Integer)
    return [l
            for l in incident(cld, Int(s), :link_source)
            if subpart(cld, l, :link_target) == Int(t)]
end

"""
    has_link(cld, source::Symbol, target::Symbol) -> Bool

Whether the diagram has at least one link from `source` to `target`. Throws
[`UnknownFactorError`](@ref) if either name is not a factor.

This is not the same question as whether [`link_polarity`](@ref) is
[`NO_EFFECT`](@ref): a link can be present and carry no effect.
"""
function has_link(cld::AbstractCausalLoopDiagram, source::Symbol, target::Symbol)
    return !isempty(_links_between(cld, factor_id(cld, source), factor_id(cld, target)))
end

"""
    link_polarity(cld, source::Symbol, target::Symbol) -> Polarity

The polarity of the dependence of `target` on `source`: the sum, in the rig of
[`Polarity`](@ref), of the polarities of the parallel links between them. With no link at
all the sum is empty and the answer is [`NO_EFFECT`](@ref), the additive unit; use
[`has_link`](@ref) to tell that case from a link that carries no effect.

Two parallel links of opposite sign give [`INDETERMINATE`](@ref), which is the honest
answer: the diagram says the two pathways disagree and says nothing about which wins.
"""
function link_polarity(cld::AbstractCausalLoopDiagram, source::Symbol, target::Symbol)
    ls = _links_between(cld, factor_id(cld, source), factor_id(cld, target))
    return isempty(ls) ? NO_EFFECT :
           reduce(+, (subpart(cld, l, :link_polarity) for l in ls))
end

"""
    link_delay(cld, source::Symbol, target::Symbol) -> Bool

Whether any link from `source` to `target` crosses a delay (see [`delayed`](@ref)).
"""
function link_delay(cld::AbstractCausalLoopDiagram, source::Symbol, target::Symbol)
    ls = _links_between(cld, factor_id(cld, source), factor_id(cld, target))
    return any(l -> subpart(cld, l, :link_delay), ls)
end

"""
    polarity_matrix(cld) -> Matrix{Polarity}

The diagram as a square matrix over the rig of [`Polarity`](@ref): entry `(i, j)` is the
polarity of the link from factor `i` to factor `j`, in the order of
[`factor_names`](@ref), and [`NO_EFFECT`](@ref) where there is no link.

Matrix multiplication over this rig then does what it does for an ordinary adjacency
matrix: the `(i, j)` entry of the `n`-th power is the sum of the polarities of the paths of
length `n` from `i` to `j`, so a diagonal entry of a power is a loop polarity, summed over
the loops of that length.
"""
function polarity_matrix(cld::AbstractCausalLoopDiagram)
    n = nfactors(cld)
    m = fill(NO_EFFECT, n, n)
    for l in parts(cld, :Link)
        s = subpart(cld, l, :link_source)
        t = subpart(cld, l, :link_target)
        m[s, t] += subpart(cld, l, :link_polarity)
    end
    return m
end

"""
    delay_matrix(cld) -> Matrix{Bool}

Entry `(i, j)` is whether any link from factor `i` to factor `j` crosses a delay, in the
order of [`factor_names`](@ref).
"""
function delay_matrix(cld::AbstractCausalLoopDiagram)
    n = nfactors(cld)
    m = falses(n, n)
    for l in parts(cld, :Link)
        if subpart(cld, l, :link_delay)
            m[subpart(cld, l, :link_source), subpart(cld, l, :link_target)] = true
        end
    end
    return m
end

function Base.show(io::IO, ::MIME"text/plain", cld::AbstractCausalLoopDiagram)
    println(io, "CausalLoopDiagram with ", nfactors(cld), " factors and ", nlinks(cld),
            " links")
    for row in link_table(cld)
        println(io, "  ", row.source, " -(", polarity_symbol(row.polarity), ")-> ",
                row.target, row.delay ? "  (delayed)" : "")
    end
    return nothing
end
