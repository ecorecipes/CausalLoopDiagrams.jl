# Reading a causal loop diagram off a Bayesian network.
#
# This is the forgetful direction of the bridge: a model carries conditional probability
# tables, and the diagram keeps only the direction in which each table moves. Everything
# else -- how much, how certain, and whether two parents interact -- is discarded, which is
# why the diagram is a sketch and not a model.
#
# Two readings of the same network are available and they are not the same function.
# `:structural` reads each mechanism's own table, so it answers "what would intervening on
# this parent do", and `:observational` reads `conditional(m, child, parent)`, so it answers
# "which way do the two move together in this model". They differ exactly where the network
# is confounded, which is what `compare_diagrams` is for.

# Apply the caller's declarations about state order to a polarity read off a table.
function _declared(p::Polarity, source::Symbol, target::Symbol,
                   unordered::AbstractVector{Symbol}, reversed::AbstractVector{Symbol})
    (source in unordered || target in unordered) && return INDETERMINATE
    source in reversed && (p = -p)
    target in reversed && (p = -p)
    return p
end

"""
    causal_loop_diagram(m::BayesModel; mode = :structural, unordered = Symbol[],
                        reversed = Symbol[], atol = DEFAULT_ATOL, kwargs...)

The causal loop diagram of a model with its kernels bound: one factor per variable, in
variable-id order, and one link per arc, labelled with the direction in which the arc
moves (see [`polarity`](@ref polarity(::FiniteKernel, ::Integer))).

`mode` picks which question the labels answer.

  - `:structural` (the default) reads each mechanism's own table, one link per input, with
    the other parents held fixed. This is the interventional reading: the sign is what
    `do_intervention` on the parent would move. A variable wired to a mechanism twice gets
    two parallel links, which [`link_polarity`](@ref) then sums.
  - `:observational` reads `conditional(m, child, parent)` for each arc of the graph
    instead, so the sign is the direction in which the two move together, confounding and
    all. This enumerates the joint, so it is capped the way
    `BayesianNetworks.conditional` is capped; `kwargs` (for instance `max_states`,
    `evidence`) are forwarded to it and are otherwise unused.

The declared order of a variable's states is what "rises" means, so two keywords say where
that order is not the quantity the diagram is about.

  - `reversed` names the variables whose states run the other way -- declared best to worst
    when the diagram is about badness, say. Each reversed endpoint flips the sign of every
    link into and out of it.
  - `unordered` names the variables whose states carry no order at all: a platform choice,
    a delivery route, a species identity. Every link touching one is
    [`INDETERMINATE`](@ref), which is the truth. A diagram over a decision with
    incomparable options has little to say, and saying so is the point.

Unbound mechanisms raise `BayesianNetworks.MissingKernelError` from `kernel`, unchanged.
"""
function causal_loop_diagram(m::BayesModel; mode::Symbol=:structural,
                             unordered::AbstractVector{Symbol}=Symbol[],
                             reversed::AbstractVector{Symbol}=Symbol[],
                             atol::Real=DEFAULT_ATOL, kwargs...)
    mode in (:structural, :observational) ||
        throw(ArgumentError("mode is :structural or :observational; got $(repr(mode))."))
    bn = syntax(m)
    cld = CausalLoopDiagram()
    for v in variables(bn)
        add_factor!(cld, variable_name(bn, v))
    end
    if mode === :structural
        for mech in mechanisms(bn)
            child = variable_name(bn, target(bn, mech))
            k = kernel(m, child)
            for (position, p) in enumerate(inputs(bn, mech))
                parent = variable_name(bn, p)
                add_link!(cld, parent, child,
                          _declared(polarity(k, position; atol=atol), parent, child,
                                    unordered, reversed))
            end
        end
    else
        for mech in mechanisms(bn)
            child = variable_name(bn, target(bn, mech))
            for p in unique(inputs(bn, mech))
                parent = variable_name(bn, p)
                k = conditional(m, child, parent; kwargs...)
                add_link!(cld, parent, child,
                          _declared(polarity(k, 1; atol=atol), parent, child, unordered,
                                    reversed))
            end
        end
    end
    return cld
end

"""
    causal_loop_diagram(dm::DynamicBayesModel; kwargs...) -> CausalLoopDiagram

The causal loop diagram of a dynamic model's transition template, with the time index
quotiented away: one factor per template variable, a lagged input `X[t-k]` of `Y` becoming
a **delayed** link from `X` to `Y`, and a same-slice input an ordinary one.

This is the direction that recovers the loops. A dynamic Bayesian network is a Bayesian
network, so its transition template is acyclic and carries no loop; collapsing the slices
puts the loops back, and the ones that come back are exactly the delayed ones. Persistence
of a variable from one slice to the next becomes a self-link, which is the shortest
feedback loop there is.

Equivalent to `collapse_lags(causal_loop_diagram(transition_network(dm); kwargs...))`;
`kwargs` are those of [`causal_loop_diagram`](@ref causal_loop_diagram(::BayesModel)).
"""
function causal_loop_diagram(dm::DynamicBayesModel; kwargs...)
    return collapse_lags(causal_loop_diagram(transition_network(dm); kwargs...))
end
