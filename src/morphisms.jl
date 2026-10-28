# Maps between diagrams: coarsening (the push-forward of labels along a map of graphs),
# the special case that collapses a time index, and the comparison of two labellings of the
# same graph.
#
# Baez treats pulling back and pushing forward edge labels along a map of graphs as the two
# functorial operations on labelled graphs, and notes that pushing forward is the one that
# needs the labels to be addable: when two edges are identified, their labels must combine.
# That is why `Polarity` is a rig and not just a monoid, and `coarsen` is where the addition
# earns its keep.

# Merge parallel links into one, summing polarities and taking the delay of any of them.
function _combine(cld::AbstractCausalLoopDiagram)
    out = CausalLoopDiagram()
    for f in factor_names(cld)
        add_factor!(out, f)
    end
    seen = Set{Tuple{Symbol,Symbol}}()
    for row in link_table(cld)
        key = (row.source, row.target)
        key in seen && continue
        push!(seen, key)
        add_link!(out, row.source, row.target, link_polarity(cld, row.source, row.target);
                  delay=link_delay(cld, row.source, row.target))
    end
    return out
end

"""
    coarsen(cld, f; combine = true) -> CausalLoopDiagram

The diagram pushed forward along a map of factors: `f` sends each factor name to the name
it becomes, as a `Dict` (names it does not mention are kept) or as a function. Links follow
their endpoints, keeping their polarity and their delay.

With `combine = true` (the default) links that become parallel are merged into one, their
polarities added in the rig of [`Polarity`](@ref) -- so two pathways that disagree become
one [`INDETERMINATE`](@ref) link -- and the merged link is delayed if any of them was. With
`combine = false` they are left side by side, which keeps every pathway visible;
[`link_polarity`](@ref) adds them on reading either way.

Merging two factors that were linked to each other turns that link into a self-link, which
is a feedback loop of length one. That is not a defect of the operation: it is what
coarsening a diagram does to the detail inside a factor.

```jldoctest
julia> cld = causal_loop_diagram([(:Spores, :Infection) => POSITIVE,
                                  (:Conidia, :Infection) => POSITIVE]);

julia> lumped = coarsen(cld, Dict(:Spores => :Inoculum, :Conidia => :Inoculum));

julia> nfactors(lumped), nlinks(lumped)
(2, 1)
```
"""
function coarsen(cld::AbstractCausalLoopDiagram, f; combine::Bool=true)
    rename = f isa AbstractDict ? (name -> get(f, name, name)) : f
    out = CausalLoopDiagram()
    for name in factor_names(cld)
        add_factor!(out, rename(name))
    end
    for row in link_table(cld)
        add_link!(out, rename(row.source), rename(row.target), row.polarity;
                  delay=row.delay)
    end
    return combine ? _combine(out) : out
end

"""
    collapse_lags(cld) -> CausalLoopDiagram

The diagram with its time index quotiented away: a factor named `X[t-k]` becomes `X`, and a
link that crosses a slice boundary becomes a [`delayed`](@ref) link. Names follow
BayesianNetworks' lag convention, which `lag_of` parses.

This is the operation that turns a transition template back into a diagram with loops in
it. The template is acyclic, as every Bayesian network must be; the loops are carried by
the lags, and collapsing the index is what makes them visible again. A variable that
persists from one slice to the next becomes a self-link.

Parallel links produced by the collapse are merged as in [`coarsen`](@ref), so a variable
that enters a mechanism both at the current slice and at a lag yields one link, delayed,
whose polarity is the sum of the two.
"""
function collapse_lags(cld::AbstractCausalLoopDiagram)
    out = CausalLoopDiagram()
    for name in factor_names(cld)
        add_factor!(out, first(lag_of(name)))
    end
    for row in link_table(cld)
        source, source_lag = lag_of(row.source)
        target, target_lag = lag_of(row.target)
        add_link!(out, source, target, row.polarity;
                  delay=row.delay || source_lag > target_lag)
    end
    return _combine(out)
end

# Comparing two labellings
##########################

"""
    DiagramComparison

The result of [`compare_diagrams`](@ref): four lists of links, each entry naming its
endpoints.

  - `agree`: links both diagrams have, with the same polarity. Entries are
    `(; source, target, polarity)`.
  - `disagree`: links both diagrams have with different polarities. Entries are
    `(; source, target, first, second)`, the two polarities in the order the diagrams were
    given.
  - `only_first`, `only_second`: links only one diagram has, as
    `(; source, target, polarity)`.

`only_first` is the interesting list when the first diagram is a sketch and the second was
read off a network: it is what the network leaves out.
"""
struct DiagramComparison
    agree::Vector{@NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}}
    disagree::Vector{@NamedTuple{source::Symbol,target::Symbol,first::Polarity,
                                 second::Polarity}}
    only_first::Vector{@NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}}
    only_second::Vector{@NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}}
end

"""
    compare_diagrams(a, b) -> DiagramComparison

Compare two diagrams link by link: which links both have and agree on, which both have and
disagree on, and which only one has. Parallel links are summed first, so the comparison is
between the polarities [`link_polarity`](@ref) reports.

Three uses, all of them checks that something has not been assumed.

  - A hand-drawn sketch against the diagram read off the finished network says which links
    the modelling kept, which it silently re-signed, and which feedback it had to cut.
  - The `:structural` against the `:observational` reading of one network (see
    [`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel))) says where the
    direction two variables move together is not the direction intervening on one moves the
    other. Those links are the confounded ones, and a diagram drawn from observed
    co-movement has them wrong while claiming to be causal.
  - A diagram against the collapse of a dynamic model's template ([`collapse_lags`](@ref))
    says whether the loops the sketch drew are the loops the dynamic model closed.
"""
function compare_diagrams(a::AbstractCausalLoopDiagram, b::AbstractCausalLoopDiagram)
    agree = @NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}[]
    disagree = @NamedTuple{source::Symbol,target::Symbol,first::Polarity,
                           second::Polarity}[]
    only_a = @NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}[]
    only_b = @NamedTuple{source::Symbol,target::Symbol,polarity::Polarity}[]
    pairs = Tuple{Symbol,Symbol}[]
    for row in link_table(a)
        (row.source, row.target) in pairs || push!(pairs, (row.source, row.target))
    end
    for row in link_table(b)
        (row.source, row.target) in pairs || push!(pairs, (row.source, row.target))
    end
    for (source, target) in pairs
        in_a = has_factor(a, source) && has_factor(a, target) && has_link(a, source, target)
        in_b = has_factor(b, source) && has_factor(b, target) && has_link(b, source, target)
        if in_a && in_b
            pa = link_polarity(a, source, target)
            pb = link_polarity(b, source, target)
            if pa == pb
                push!(agree, (source=source, target=target, polarity=pa))
            else
                push!(disagree, (source=source, target=target, first=pa, second=pb))
            end
        elseif in_a
            push!(only_a,
                  (source=source, target=target,
                   polarity=link_polarity(a, source, target)))
        else
            push!(only_b,
                  (source=source, target=target,
                   polarity=link_polarity(b, source, target)))
        end
    end
    return DiagramComparison(agree, disagree, only_a, only_b)
end

function Base.show(io::IO, ::MIME"text/plain", c::DiagramComparison)
    println(io, "DiagramComparison: ", length(c.agree), " agree, ", length(c.disagree),
            " disagree, ", length(c.only_first), " only in the first, ",
            length(c.only_second), " only in the second")
    for row in c.disagree
        println(io, "  ", row.source, " -> ", row.target, ": ",
                polarity_symbol(row.first), " against ", polarity_symbol(row.second))
    end
    for row in c.only_first
        println(io, "  ", row.source, " -(", polarity_symbol(row.polarity), ")-> ",
                row.target, ": only in the first")
    end
    for row in c.only_second
        println(io, "  ", row.source, " -(", polarity_symbol(row.polarity), ")-> ",
                row.target, ": only in the second")
    end
    return nothing
end
