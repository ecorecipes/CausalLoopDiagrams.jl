# Motifs: the shapes that recur inside a diagram, and the census of them across a
# collection of diagrams.
#
# Baez and Chaudhuri list three kinds of morphism between labelled graphs -- refining,
# simplifying and finding motifs [BaezChaudhuri2025](@cite). `coarsen` in morphisms.jl is
# the simplifying one. This file is the third: a motif is itself a small labelled graph, and
# an occurrence of it in a diagram is a label-respecting embedding of the motif into the
# diagram.
#
# Three decisions give the search its meaning; ADR 0027 records them.
#
# The embedding is *injective on factors*, so a three-factor chain does not occur in a
# two-cycle by visiting one factor twice. Without that, every long motif occurs in every
# short loop and the census is noise.
#
# Matching a label is *containment in the subset order* on `Polarity` (`issubset`), not
# equality. The four polarities are subsets of the sign hyperfield, so a motif link labelled
# `INDETERMINATE` = {0, +, -} matches a host link of any sign, and one labelled `POSITIVE`
# = {+} matches only a positive link. The wildcard is therefore not an extra value added for
# the matcher; it is the top of the rig that was already there.
#
# An occurrence is *not induced* by default: the host may carry further links among the
# matched factors. A motif is a shape that is present, not a complete description of a
# neighbourhood. `motif_census` is the other way round, because a census must partition --
# see its docstring.

# Existence, polarity and delay as three square matrices over the factor order of
# `factor_names`. Existence cannot be read off the polarity matrix: an absent link and a
# `NO_EFFECT` link both read as `NO_EFFECT` there (see `link_polarity`).
function _adjacency(cld::AbstractCausalLoopDiagram)
    n = nfactors(cld)
    present = falses(n, n)
    for l in parts(cld, :Link)
        present[subpart(cld, l, :link_source), subpart(cld, l, :link_target)] = true
    end
    return present, polarity_matrix(cld), delay_matrix(cld)
end

"""
    MotifOccurrence

One occurrence of a motif in a diagram: the injective map from the motif's factors to the
host's, as a list of `(; motif, host)` pairs in the motif's factor order.

Index it with a motif factor name to get the host factor it matched (`occ[:A]`), or take
them all with [`host_factors`](@ref).
"""
struct MotifOccurrence
    pairs::Vector{@NamedTuple{motif::Symbol,host::Symbol}}
end

"""
    host_factors(occ::MotifOccurrence) -> Vector{Symbol}

The host factors the occurrence matched, in the motif's factor order.
"""
host_factors(occ::MotifOccurrence) = [p.host for p in occ.pairs]

"""
    motif_factors(occ::MotifOccurrence) -> Vector{Symbol}

The motif's own factor names, in its factor order.
"""
motif_factors(occ::MotifOccurrence) = [p.motif for p in occ.pairs]

function Base.getindex(occ::MotifOccurrence, name::Symbol)
    for p in occ.pairs
        p.motif === name && return p.host
    end
    throw(UnknownFactorError(name, motif_factors(occ)))
end

Base.length(occ::MotifOccurrence) = length(occ.pairs)

function Base.show(io::IO, occ::MotifOccurrence)
    print(io, join(("$(p.motif) = $(p.host)" for p in occ.pairs), ", "))
    return nothing
end

# The backtracking search. `stop_after` bounds the number of occurrences collected, so that
# `has_motif` can stop at the first and `occurrences` can detect having hit its cap.
function _occurrences(motif::AbstractCausalLoopDiagram, cld::AbstractCausalLoopDiagram,
                      stop_after::Int; induced::Bool, match_delay::Bool)
    mnames = factor_names(motif)
    hnames = factor_names(cld)
    nm = length(mnames)
    nh = length(hnames)
    out = MotifOccurrence[]
    (nm == 0 || nm > nh || stop_after <= 0) && return out
    mpresent, mpol, mdelay = _adjacency(motif)
    hpresent, hpol, hdelay = _adjacency(cld)
    assign = zeros(Int, nm)
    used = falses(nh)
    # Would sending motif factor `i` to host factor `h` keep every constraint among the
    # factors placed so far? Checks both directions of every pair, and `i` against itself,
    # which is what carries self-links.
    function consistent(i::Int, h::Int)
        for j in 1:i
            hj = j == i ? h : assign[j]
            for (a, b, ha, hb) in ((i, j, h, hj), (j, i, hj, h))
                if mpresent[a, b]
                    hpresent[ha, hb] || return false
                    # The host's label must be among the signs the motif admits, so the
                    # containment runs host into motif and not the other way about.
                    issubset(hpol[ha, hb], mpol[a, b]) || return false
                    match_delay && mdelay[a, b] != hdelay[ha, hb] && return false
                elseif induced && hpresent[ha, hb]
                    return false
                end
            end
        end
        return true
    end
    function walk(i::Int)
        length(out) >= stop_after && return nothing
        if i > nm
            push!(out,
                  MotifOccurrence([(motif=mnames[k], host=hnames[assign[k]])
                                   for k in 1:nm]))
            return nothing
        end
        for h in 1:nh
            used[h] && continue
            consistent(i, h) || continue
            assign[i] = h
            used[h] = true
            walk(i + 1)
            used[h] = false
            assign[i] = 0
            length(out) >= stop_after && return nothing
        end
        return nothing
    end
    walk(1)
    return out
end

"""
    occurrences(motif, cld; induced = false, match_delay = false,
                max_occurrences = 10_000) -> Vector{MotifOccurrence}

Every occurrence of `motif` in the diagram `cld`: every injective map from the motif's
factors to the diagram's under which each link of the motif becomes a link of the diagram
whose polarity the motif's label allows.

Both arguments are ordinary diagrams; a motif is a small labelled graph and nothing more, so
[`causal_loop_diagram`](@ref causal_loop_diagram(::AbstractVector)) builds one, and
[`motif`](@ref) names the standard shapes.

A label matches by containment rather than equality (`issubset` on [`Polarity`](@ref)): a
motif link labelled [`INDETERMINATE`](@ref) asks only that some link be there, whatever its
sign, while one labelled [`POSITIVE`](@ref) matches a positive link alone. A host link that
is itself `INDETERMINATE` matches only a motif link that is, because the diagram does not
claim a sign for it.

`induced = false` (the default) lets the diagram carry further links among the matched
factors: the question is whether the shape is present. With `induced = true` the matched
factors must carry *exactly* the motif's links and no others.

`match_delay = false` (the default) ignores [`delayed`](@ref) flags, because a motif is a
question about shape; with `match_delay = true` each link must agree about its delay as
well.

The map is injective, so distinct motif factors match distinct diagram factors: a chain of
three does not occur in a loop of two. A motif with a symmetry occurs once per symmetry --
`:mutual_amplification` has two occurrences in a single reinforcing pair, one for each way
round -- which is a property of counting maps, not a defect.

Throws [`TooManyOccurrencesError`](@ref) past `max_occurrences`.

```jldoctest
julia> cld = causal_loop_diagram([(:Hare, :Lynx) => POSITIVE,
                                  (:Lynx, :Hare) => NEGATIVE]);

julia> only(occurrences(motif(:predator_prey), cld))
A = Hare, B = Lynx
```
"""
function occurrences(motif::AbstractCausalLoopDiagram, cld::AbstractCausalLoopDiagram;
                     induced::Bool=false, match_delay::Bool=false,
                     max_occurrences::Integer=10_000)
    cap = Int(max_occurrences)
    cap >= 0 ||
        throw(ArgumentError("max_occurrences must be non-negative; got $(max_occurrences)"))
    out = _occurrences(motif, cld, cap + 1; induced=induced, match_delay=match_delay)
    length(out) > cap && throw(TooManyOccurrencesError(length(out), cap))
    return out
end

"""
    count_occurrences(motif, cld; kwargs...) -> Int

How many times `motif` occurs in `cld`. Keywords are [`occurrences`](@ref)'s.
"""
function count_occurrences(motif::AbstractCausalLoopDiagram,
                           cld::AbstractCausalLoopDiagram; kwargs...)
    return length(occurrences(motif, cld; kwargs...))
end

"""
    has_motif(motif, cld; induced = false, match_delay = false) -> Bool

Whether `motif` occurs in `cld` at all. Stops at the first occurrence, so it is cheap and
needs no cap.

```jldoctest
julia> cld = causal_loop_diagram([(:Load, :Defence) => POSITIVE,
                                  (:Defence, :Load) => NEGATIVE]);

julia> has_motif(motif(:predator_prey), cld), has_motif(motif(:self_balancing), cld)
(true, false)
```
"""
function has_motif(motif::AbstractCausalLoopDiagram, cld::AbstractCausalLoopDiagram;
                   induced::Bool=false, match_delay::Bool=false)
    return !isempty(_occurrences(motif, cld, 1; induced=induced, match_delay=match_delay))
end

# Canonical form
################

# Brute force over all relabellings, which is what a motif's size makes affordable: these
# are graphs of a handful of factors, and a canonical labelling algorithm would be a
# dependency and a correctness risk for no gain.
const _MAX_CANONICAL = 7

const _CANONICAL_NAMES = (:A, :B, :C, :D, :E, :F, :G)

function _permutations(n::Int)
    out = Vector{Vector{Int}}()
    p = collect(1:n)
    function rec(k::Int)
        if k > n
            push!(out, copy(p))
            return nothing
        end
        for i in k:n
            p[k], p[i] = p[i], p[k]
            rec(k + 1)
            p[k], p[i] = p[i], p[k]
        end
        return nothing
    end
    rec(1)
    return out
end

# The sorted link list under the relabelling `sigma`, which sends factor `v` to position
# `sigma[v]`. Comparing these lexicographically is what picks the canonical labelling.
function _signature(cld::AbstractCausalLoopDiagram, sigma::Vector{Int}, with_delay::Bool)
    rows = Tuple{Int,Int,UInt8,Bool}[]
    for l in parts(cld, :Link)
        push!(rows,
              (sigma[subpart(cld, l, :link_source)],
               sigma[subpart(cld, l, :link_target)],
               subpart(cld, l, :link_polarity).code,
               with_delay && subpart(cld, l, :link_delay)))
    end
    sort!(rows)
    return rows
end

function _canonical(cld::AbstractCausalLoopDiagram, with_delay::Bool)
    n = nfactors(cld)
    n <= _MAX_CANONICAL ||
        throw(ArgumentError("a canonical form is for motifs, not whole diagrams: this " *
                            "one has $(n) factors and the limit is $(_MAX_CANONICAL)."))
    best_sigma = Int[]
    best = Tuple{Int,Int,UInt8,Bool}[]
    for sigma in _permutations(n)
        sig = _signature(cld, sigma, with_delay)
        if isempty(best_sigma) || sig < best
            best_sigma = sigma
            best = sig
        end
    end
    return best_sigma, best
end

"""
    motif_key(cld; match_delay = false) -> String

A string that is the same for two diagrams exactly when they are isomorphic as labelled
graphs: the canonical form, found by minimising over every relabelling of the factors. The
factor names themselves are discarded, which is the point -- a motif is a shape.

The key reads as the links of the canonical labelling, whose factors are `A`, `B`, `C`, ...
in canonical order, so `"3: A+>B B->C"` is a three-factor chain, positive then negative.

With `match_delay = true` delays are part of the shape, so the same signed shape with and
without a delay gets different keys; a delayed link is marked `~`.

Brute force over all relabellings, so it is for motifs: it throws an `ArgumentError` past
seven factors.

```jldoctest
julia> a = causal_loop_diagram([(:Rain, :Runoff) => POSITIVE]);

julia> b = causal_loop_diagram([(:Spores, :Infection) => POSITIVE]);

julia> motif_key(a) == motif_key(b)
true

julia> motif_key(a)
"2: A+>B"
```
"""
function motif_key(cld::AbstractCausalLoopDiagram; match_delay::Bool=false)
    _, best = _canonical(cld, match_delay)
    pieces = String[]
    for (s, t, code, delay) in best
        push!(pieces,
              string(_CANONICAL_NAMES[s], polarity_symbol(Polarity(code)), ">",
                     _CANONICAL_NAMES[t], delay ? "~" : ""))
    end
    return string(nfactors(cld), ": ", join(pieces, " "))
end

"""
    canonical_motif(cld; match_delay = false) -> CausalLoopDiagram

The diagram relabelled into its canonical form: the same shape with its factors renamed
`A`, `B`, `C`, ... so that two isomorphic diagrams come out identical. This is the
representative [`motif_census`](@ref) reports, and [`motif_key`](@ref) is its string form.

With `match_delay = false` (the default) the delays are dropped, since they are not then
part of the shape being counted.
"""
function canonical_motif(cld::AbstractCausalLoopDiagram; match_delay::Bool=false)
    sigma, _ = _canonical(cld, match_delay)
    out = CausalLoopDiagram()
    for c in 1:nfactors(cld)
        add_factor!(out, _CANONICAL_NAMES[c])
    end
    for l in parts(cld, :Link)
        add_link!(out, _CANONICAL_NAMES[sigma[subpart(cld, l, :link_source)]],
                  _CANONICAL_NAMES[sigma[subpart(cld, l, :link_target)]],
                  subpart(cld, l, :link_polarity);
                  delay=match_delay && subpart(cld, l, :link_delay))
    end
    return out
end

# The library of named shapes
#############################

function _library()
    lib = OrderedDict{Symbol,CausalLoopDiagram}()
    lib[:self_reinforcing] = causal_loop_diagram([(:A, :A) => POSITIVE])
    lib[:self_balancing] = causal_loop_diagram([(:A, :A) => NEGATIVE])
    lib[:mutual_amplification] = causal_loop_diagram([(:A, :B) => POSITIVE,
                                                      (:B, :A) => POSITIVE])
    lib[:mutual_suppression] = causal_loop_diagram([(:A, :B) => NEGATIVE,
                                                    (:B, :A) => NEGATIVE])
    lib[:predator_prey] = causal_loop_diagram([(:A, :B) => POSITIVE,
                                               (:B, :A) => NEGATIVE])
    lib[:chain] = causal_loop_diagram([(:A, :B) => INDETERMINATE,
                                       (:B, :C) => INDETERMINATE])
    lib[:common_cause] = causal_loop_diagram([(:A, :B) => INDETERMINATE,
                                              (:A, :C) => INDETERMINATE])
    lib[:common_effect] = causal_loop_diagram([(:A, :C) => INDETERMINATE,
                                               (:B, :C) => INDETERMINATE])
    lib[:opposed_pathways] = causal_loop_diagram([(:A, :B) => POSITIVE,
                                                  (:B, :D) => POSITIVE,
                                                  (:A, :C) => POSITIVE,
                                                  (:C, :D) => NEGATIVE])
    lib[:agreeing_pathways] = causal_loop_diagram([(:A, :B) => POSITIVE,
                                                   (:B, :D) => POSITIVE,
                                                   (:A, :C) => POSITIVE,
                                                   (:C, :D) => POSITIVE])
    return lib
end

"""
    MOTIF_LIBRARY

The standard shapes, as an `OrderedDict` from name to diagram. [`motif`](@ref) takes a copy
of one by name and [`motif_names`](@ref) lists them.

| name | shape | what it says |
|:--|:--|:--|
| `:self_reinforcing` | `A -(+)-> A` | a factor that feeds itself: growth, or decline |
| `:self_balancing` | `A -(-)-> A` | a factor that damps itself |
| `:mutual_amplification` | `A -(+)-> B -(+)-> A` | each raises the other; reinforcing |
| `:mutual_suppression` | `A -(-)-> B -(-)-> A` | each suppresses the other; reinforcing too |
| `:predator_prey` | `A -(+)-> B -(-)-> A` | the balancing pair |
| `:chain` | `A -(?)-> B -(?)-> C` | any two links in series |
| `:common_cause` | `A -(?)-> B`, `A -(?)-> C` | one factor driving two: the confounding shape |
| `:common_effect` | `A -(?)-> C`, `B -(?)-> C` | two factors meeting at one |
| `:opposed_pathways` | two routes `A` to `D`, signs `+ +` and `+ -` | the shape whose coarsening is `INDETERMINATE` |
| `:agreeing_pathways` | two routes `A` to `D`, both `+ +` | the same shape that coarsens to a sign |

The three with `?` labels are shape-only and match any sign (see [`occurrences`](@ref));
they are the ones to count rather than to read a direction off.

`:mutual_suppression` is in the library because it is the one practitioners misread: two
negative links in series multiply to a positive loop, so mutual suppression is reinforcing,
not balancing. `:opposed_pathways` and `:agreeing_pathways` are the same unlabelled shape
with different signs, and they are worth telling apart because [`coarsen`](@ref) merges the
first into an `INDETERMINATE` link and the second into a signed one: a sketch that lumps
them loses a trade-off it cannot then state.
"""
const MOTIF_LIBRARY = _library()

"""
    motif_names() -> Vector{Symbol}

The names in [`MOTIF_LIBRARY`](@ref), in its order.
"""
motif_names() = collect(keys(MOTIF_LIBRARY))

"""
    motif(name::Symbol) -> CausalLoopDiagram

A copy of the named shape from [`MOTIF_LIBRARY`](@ref). A copy, so that adding to what
comes back cannot change the library.

Throws an `ArgumentError` for a name the library does not hold.

```jldoctest
julia> nfactors(motif(:predator_prey)), nlinks(motif(:predator_prey))
(2, 2)
```
"""
function motif(name::Symbol)
    haskey(MOTIF_LIBRARY, name) ||
        throw(ArgumentError("no motif named $(repr(name)); the library has " *
                            "$(motif_names())."))
    return coarsen(MOTIF_LIBRARY[name], identity)
end

# The census across a collection
################################

"""
    MotifCount

One row of a [`motif_census`](@ref): a shape, and where it was found.

  - `key`: the canonical form as a string ([`motif_key`](@ref)).
  - `motif`: the shape itself, canonically labelled ([`canonical_motif`](@ref)).
  - `support`: how many diagrams of the collection contain it. This is the column to read:
    a shape in one diagram is that diagram's business, and a shape in most of them is a
    property of the subject rather than of any one model.
  - `occurrences`: how many times in total, summed over the collection.
  - `diagrams`: the names of the diagrams that contain it, in the order given.
"""
struct MotifCount
    key::String
    motif::CausalLoopDiagram
    support::Int
    occurrences::Int
    diagrams::Vector{Symbol}
end

function Base.show(io::IO, c::MotifCount)
    print(io, c.key, "  in ", c.support, " diagram", c.support == 1 ? "" : "s", ", ",
          c.occurrences, " time", c.occurrences == 1 ? "" : "s")
    return nothing
end

function _combinations(n::Int, k::Int)
    out = Vector{Vector{Int}}()
    (k < 0 || k > n) && return out
    k == 0 && return push!(out, Int[])
    idx = collect(1:k)
    while true
        push!(out, copy(idx))
        i = k
        while i >= 1 && idx[i] == n - k + i
            i -= 1
        end
        i == 0 && break
        idx[i] += 1
        for j in (i + 1):k
            idx[j] = idx[j - 1] + 1
        end
    end
    return out
end

# The sub-diagram on a set of factors, carrying every link of the host between them.
function _induced_subdiagram(cld::AbstractCausalLoopDiagram, idx::Vector{Int})
    names = factor_names(cld)
    out = CausalLoopDiagram()
    for i in idx
        add_factor!(out, names[i])
    end
    keep = Set(idx)
    for l in parts(cld, :Link)
        s = subpart(cld, l, :link_source)
        t = subpart(cld, l, :link_target)
        if s in keep && t in keep
            add_link!(out, names[s], names[t], subpart(cld, l, :link_polarity);
                      delay=subpart(cld, l, :link_delay))
        end
    end
    return out
end

# Connected with no isolated factor: every factor touches a link inside the sub-diagram and
# the undirected graph on them hangs together. For a single factor this forces a self-link,
# which is what makes a one-factor census report feedback rather than mere existence.
function _is_connected(cld::AbstractCausalLoopDiagram)
    n = nfactors(cld)
    n == 0 && return false
    present, _, _ = _adjacency(cld)
    for v in 1:n
        (any(@view present[v, :]) || any(@view present[:, v])) || return false
    end
    seen = falses(n)
    seen[1] = true
    stack = [1]
    while !isempty(stack)
        v = pop!(stack)
        for w in 1:n
            if !seen[w] && (present[v, w] || present[w, v])
                seen[w] = true
                push!(stack, w)
            end
        end
    end
    return all(seen)
end

_named_diagrams(diagrams::AbstractDict) = [(Symbol(k), v) for (k, v) in diagrams]

function _named_diagrams(diagrams::AbstractVector{<:Pair})
    return [(Symbol(first(p)), last(p)) for p in diagrams]
end

function _named_diagrams(diagrams::AbstractVector)
    return [(Symbol("d", i), d)
            for (i, d) in enumerate(diagrams)]
end

"""
    motif_census(diagrams; size, match_delay = false, connected = true)
        -> Vector{MotifCount}

The shapes of `size` factors that occur across a collection of diagrams, counted by how
many diagrams contain each: [`MotifCount`](@ref) rows, the widest support first.

`diagrams` is a `Dict` of name to diagram, a vector of `name => diagram` pairs, or a plain
vector (named `d1`, `d2`, ... in order).

The census is **induced**, which is the opposite of [`occurrences`](@ref)'s default and is
deliberate: each set of `size` factors contributes exactly one shape, the one it actually
carries, so the rows partition the sets counted and the `occurrences` column adds up. Were
it not induced, a set carrying a loop would also be counted as each chain inside it, and a
shape's count would say more about the vocabulary of shapes than about the diagrams.

`connected = true` (the default) keeps only those sets whose factors all touch a link
inside the set and which hang together as an undirected graph. For `size = 1` that leaves
exactly the self-links, which is the useful one-factor question.

With `match_delay = true` a delay is part of the shape, so the same signed shape counts
separately according to whether it crosses one.

What the result is for, and what it is not. `support` is the interesting column, and a
shape supported by every diagram is usually telling you about the vocabulary rather than
the subject -- a bare link occurs everywhere. The counts are of *factor sets*, not of
causal claims, and a polarity carries no magnitude, so a recurring shape is a question
worth asking of each diagram rather than a finding on its own.

```jldoctest
julia> a = causal_loop_diagram([(:X, :Y) => POSITIVE, (:Y, :X) => NEGATIVE]);

julia> b = causal_loop_diagram([(:P, :Q) => POSITIVE, (:Q, :P) => NEGATIVE]);

julia> only(motif_census([:a => a, :b => b]; size=2))
2: A+>B B->A  in 2 diagrams, 2 times
```
"""
function motif_census(diagrams; size::Integer, match_delay::Bool=false,
                      connected::Bool=true)
    k = Int(size)
    k >= 1 || throw(ArgumentError("a motif has at least one factor; got size = $(size)"))
    named = _named_diagrams(diagrams)
    order = String[]
    shapes = Dict{String,CausalLoopDiagram}()
    counts = Dict{String,Int}()
    support = Dict{String,Vector{Symbol}}()
    for (name, cld) in named
        for idx in _combinations(nfactors(cld), k)
            sub = _induced_subdiagram(cld, idx)
            connected && !_is_connected(sub) && continue
            key = motif_key(sub; match_delay=match_delay)
            if !haskey(counts, key)
                push!(order, key)
                shapes[key] = canonical_motif(sub; match_delay=match_delay)
                counts[key] = 0
                support[key] = Symbol[]
            end
            counts[key] += 1
            name in support[key] || push!(support[key], name)
        end
    end
    out = [MotifCount(key, shapes[key], length(support[key]), counts[key], support[key])
           for key in order]
    sort!(out; by=c -> (-c.support, -c.occurrences, c.key))
    return out
end
