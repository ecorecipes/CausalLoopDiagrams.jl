# Feedback loops: enumeration, polarity and the two kinds.
#
# The elementary loops are enumerated on the diagram with parallel links summed, so the
# polarity of a loop is a product of sums, each sum over the pathways between one pair of
# adjacent factors. Each loop is found once, rooted at its smallest factor id.
#
# The polarity of a loop is the product of the polarities around it, and because
# multiplication is commutative the answer does not depend on where the loop is cut, which
# is what makes it a property of the loop rather than of the way it was written down.
# Baez and Chaudhuri account for this in general with a homology of labelled graphs with
# coefficients in a commutative monoid [BaezChaudhuri2025](@cite).

"""
    Loop(factors, polarity, delay)

An elementary feedback loop: the factors in the order the loop visits them, starting from
the one with the smallest part id, its [`polarity`](@ref polarity(::Loop)) and whether it
crosses a delay. The closing link runs from the last factor back to the first.

A loop whose polarity is [`POSITIVE`](@ref) is *reinforcing*: a push on any factor in it
comes back as a push the same way. A [`NEGATIVE`](@ref) loop is *balancing*: the push comes
back the other way. A loop whose polarity is [`INDETERMINATE`](@ref) is a loop whose
direction the diagram does not determine, and one whose polarity is [`NO_EFFECT`](@ref)
runs through a link along which nothing moves, so it is not live.
"""
struct Loop
    factors::Vector{Symbol}
    polarity::Polarity
    delay::Bool
end

"""
    polarity(loop::Loop) -> Polarity

The polarity of a loop: the product of the polarities of its links.
"""
polarity(loop::Loop) = loop.polarity

"""
    is_delayed(loop::Loop) -> Bool

Whether any link of the loop crosses a delay (see [`delayed`](@ref)).
"""
is_delayed(loop::Loop) = loop.delay

"""
    reinforcing(loop::Loop) -> Bool

Whether the loop is reinforcing, that is whether its polarity is [`POSITIVE`](@ref).
"""
reinforcing(loop::Loop) = loop.polarity == POSITIVE

"""
    balancing(loop::Loop) -> Bool

Whether the loop is balancing, that is whether its polarity is [`NEGATIVE`](@ref).
"""
balancing(loop::Loop) = loop.polarity == NEGATIVE

"""
    loop_length(loop::Loop) -> Int

The number of links in the loop, which is also the number of factors it visits. A self-link
is a loop of length one.
"""
loop_length(loop::Loop) = length(loop.factors)

function _loop_kind(loop::Loop)
    loop.polarity == POSITIVE && return "reinforcing"
    loop.polarity == NEGATIVE && return "balancing"
    loop.polarity == NO_EFFECT && return "not live"
    return "undetermined"
end

function Base.show(io::IO, loop::Loop)
    for f in loop.factors
        print(io, f, " -> ")
    end
    print(io, first(loop.factors), " (", polarity_symbol(loop.polarity), ", ",
          _loop_kind(loop), ", ", loop.delay ? "delayed" : "instantaneous", ")")
    return nothing
end

# Elementary circuits of the collapsed digraph. Each is reported once, rooted at its
# smallest vertex: the search from `s` visits only vertices greater than `s` and closes only
# back to `s`.
function _elementary_cycles(succ::Vector{Vector{Int}}, n::Int, max_loops::Int)
    found = Vector{Vector{Int}}()
    path = Int[]
    on_path = falses(n)
    function walk(s::Int, v::Int)
        push!(path, v)
        on_path[v] = true
        for w in succ[v]
            if w == s
                push!(found, copy(path))
                length(found) > max_loops &&
                    throw(TooManyLoopsError(length(found), max_loops))
            elseif w > s && !on_path[w]
                walk(s, w)
            end
        end
        pop!(path)
        on_path[v] = false
        return nothing
    end
    for s in 1:n
        walk(s, s)
    end
    return found
end

"""
    loops(cld; max_loops = 1_000) -> Vector{Loop}

Every elementary feedback loop of the diagram: every directed cycle that visits no factor
twice, shortest first. Parallel links are summed first (see [`link_polarity`](@ref)), so
each cycle of factors appears once, and a self-link is a loop of length one.

Enumerating elementary cycles is exponential in the worst case; `max_loops` caps it and
[`TooManyLoopsError`](@ref) says so.

```jldoctest
julia> cld = causal_loop_diagram([(:Hare, :Lynx) => POSITIVE,
                                  delayed((:Lynx, :Hare) => NEGATIVE)]);

julia> only(loops(cld))
Hare -> Lynx -> Hare (-, balancing, delayed)
```
"""
function loops(cld::AbstractCausalLoopDiagram; max_loops::Integer=1_000)
    n = nfactors(cld)
    names = factor_names(cld)
    signs = polarity_matrix(cld)
    delays = delay_matrix(cld)
    succ = [sort!([w for w in 1:n if !isempty(_links_between(cld, v, w))]) for v in 1:n]
    out = Loop[]
    for cycle in _elementary_cycles(succ, n, Int(max_loops))
        p = one(Polarity)
        d = false
        for (i, v) in enumerate(cycle)
            w = cycle[mod1(i + 1, length(cycle))]
            p *= signs[v, w]
            d |= delays[v, w]
        end
        push!(out, Loop(names[cycle], p, d))
    end
    sort!(out; by=loop -> (length(loop.factors), loop.factors))
    return out
end

"""
    loop_polarity(cld, factors::AbstractVector{Symbol}) -> Polarity

The polarity of the loop that visits these factors in this order and closes from the last
back to the first: the product of the polarities of its links. Throws
[`NotALoopError`](@ref) if a factor repeats or a consecutive pair has no link, and
[`UnknownFactorError`](@ref) if a name is not a factor of the diagram.

Because the rig is commutative the answer does not depend on which factor the sequence
starts from.
"""
function loop_polarity(cld::AbstractCausalLoopDiagram, factors::AbstractVector{Symbol})
    isempty(factors) && throw(NotALoopError(collect(factors), "it is empty"))
    allunique(factors) ||
        throw(NotALoopError(collect(factors), "it visits a factor more than once"))
    p = one(Polarity)
    for (i, v) in enumerate(factors)
        w = factors[mod1(i + 1, length(factors))]
        has_link(cld, v, w) ||
            throw(NotALoopError(collect(factors), "there is no link from $(v) to $(w)"))
        p *= link_polarity(cld, v, w)
    end
    return p
end

"""
    delayed_loops(cld; max_loops = 1_000) -> Vector{Loop}

The loops with a delay somewhere in them: the loops a dynamic Bayesian network can hold as
they stand, the delayed link becoming a lagged input.
"""
function delayed_loops(cld::AbstractCausalLoopDiagram; max_loops::Integer=1_000)
    return filter(is_delayed, loops(cld; max_loops=max_loops))
end

"""
    instantaneous_loops(cld; max_loops = 1_000) -> Vector{Loop}

The loops with no delay anywhere in them. These are the loops that assert simultaneous
mutual dependence, and no Bayesian network holds one: a directed cycle in a belief network
is rejected (`BayesianNetworks.CyclicBayesNetError`), and unrolling does not help, because
there is no slice boundary to put the closing link across. Representing one means changing
the model: separating the factor into stages, pushing it to equilibrium, or admitting a
delay that the sketch left out.
"""
function instantaneous_loops(cld::AbstractCausalLoopDiagram; max_loops::Integer=1_000)
    return filter(!is_delayed, loops(cld; max_loops=max_loops))
end

"""
    loop_summary(cld; max_loops = 1_000) -> NamedTuple

Counts of the loops of a diagram: `(; loops, reinforcing, balancing, undetermined,
inactive, delayed, instantaneous)`. `undetermined` counts the loops whose polarity is
[`INDETERMINATE`](@ref) and `inactive` those whose polarity is [`NO_EFFECT`](@ref), so
`loops == reinforcing + balancing + undetermined + inactive` and
`loops == delayed + instantaneous`.
"""
function loop_summary(cld::AbstractCausalLoopDiagram; max_loops::Integer=1_000)
    ls = loops(cld; max_loops=max_loops)
    return (loops=length(ls),
            reinforcing=count(reinforcing, ls),
            balancing=count(balancing, ls),
            undetermined=count(l -> polarity(l) == INDETERMINATE, ls),
            inactive=count(l -> polarity(l) == NO_EFFECT, ls),
            delayed=count(is_delayed, ls),
            instantaneous=count(!is_delayed, ls))
end
