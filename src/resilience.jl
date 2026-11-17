# Qualitative stability and press analysis of a diagram, through ResilienceCore's sign
# patterns. A causal loop diagram read as the signed digraph of a dynamical system says
# which way each variable pushes each other one near an equilibrium; sampling magnitudes
# consistent with those signs (Dambacher et al. 2003; Melbourne-Thomas et al. 2012) asks
# how often such a system is stable, and how determined its responses to a press are.

"""
    SignPattern(cld; self_regulation = :all_negative, collapse = true)

The diagram as the sign pattern of a Jacobian, a `ResilienceCore.SignPattern` labelled by
[`factor_names`](@ref). A link from `A` to `B` is the effect of `A` on `B`, so it is entry
`[B, A]` (row: affected factor, column: acting factor), which is the transpose of
[`polarity_matrix`](@ref). Parallel links are summed in the rig first, as
[`link_polarity`](@ref) does. [`POSITIVE`](@ref) and [`NEGATIVE`](@ref) give `+1` and `-1`,
[`NO_EFFECT`](@ref) gives no link, and [`INDETERMINATE`](@ref) gives a link of unknown
sign, which the sampling metrics draw with either sign.

With `collapse = true` the time index of a diagram read from a dynamic Bayesian network is
quotiented away first ([`collapse_lags`](@ref)). Delays are otherwise ignored: the pattern
describes the Jacobian at an equilibrium, where a delayed effect has the sign it has when
it arrives.

`self_regulation` sets the diagonal. A causal loop diagram rarely draws self-limitation,
and a variable with none makes stability impossible or fragile, so the default
`:all_negative` gives every factor without a drawn self-link a negative one (QPress's
`enforce.limitation`). A drawn self-link is kept. `:as_drawn` uses the diagram's own
self-links only.
"""
function ResilienceCore.SignPattern(cld::AbstractCausalLoopDiagram;
                                    self_regulation::Symbol=:all_negative,
                                    collapse::Bool=true)
    self_regulation in (:all_negative, :as_drawn) ||
        throw(ArgumentError("self_regulation must be :all_negative or :as_drawn, got :$self_regulation"))
    d = collapse ? collapse_lags(cld) : cld
    P = polarity_matrix(d)
    n = size(P, 1)
    S = zeros(Int8, n, n)
    unknown = falses(n, n)
    for source in 1:n, target in 1:n
        p = P[source, target]
        if p == POSITIVE
            S[target, source] = 1
        elseif p == NEGATIVE
            S[target, source] = -1
        elseif p == INDETERMINATE
            unknown[target, source] = true
        end
    end
    if self_regulation === :all_negative
        for i in 1:n
            P[i, i] == NO_EFFECT && (S[i, i] = -1)
        end
    end
    return ResilienceCore.SignPattern(S; labels=string.(factor_names(d)), unknown=unknown)
end

function ResilienceCore.quasi_sign_stability(rng::AbstractRNG,
                                             cld::AbstractCausalLoopDiagram;
                                             samples::Integer=10_000,
                                             self_regulation::Symbol=:all_negative,
                                             collapse::Bool=true)
    s = ResilienceCore.SignPattern(cld; self_regulation, collapse)
    return ResilienceCore.quasi_sign_stability(rng, s; samples)
end
"""
    quasi_sign_stability([rng], cld; samples = 10_000, self_regulation = :all_negative,
                         collapse = true)

The fraction of systems consistent with the diagram that are stable: matrices with the sign
pattern of [`SignPattern`](@ref)`(cld; self_regulation, collapse)` and magnitudes uniform on
(0, 1), counted stable when every eigenvalue has negative real part. Returns
`(fraction, se)`.
"""
function ResilienceCore.quasi_sign_stability(cld::AbstractCausalLoopDiagram; kwargs...)
    return ResilienceCore.quasi_sign_stability(Random.default_rng(), cld; kwargs...)
end

function ResilienceCore.press_sign_determinacy(rng::AbstractRNG,
                                               cld::AbstractCausalLoopDiagram;
                                               samples::Integer=10_000,
                                               self_regulation::Symbol=:all_negative,
                                               collapse::Bool=true)
    s = ResilienceCore.SignPattern(cld; self_regulation, collapse)
    return ResilienceCore.press_sign_determinacy(rng, s; samples)
end
"""
    press_sign_determinacy([rng], cld; samples = 10_000, self_regulation = :all_negative,
                           collapse = true)

Qualitative press analysis of the diagram, in the manner of QPress: among stable systems
consistent with [`SignPattern`](@ref)`(cld; self_regulation, collapse)`, the most common
sign of each factor's equilibrium response to a sustained increase in each factor, and the
fraction of stable draws with that sign. Returns `(sign, determinacy, stable, labels)`;
in `sign` and `determinacy` the row is the responding factor and the column the pressed
one, both in the order of `labels`, the factor names.
"""
function ResilienceCore.press_sign_determinacy(cld::AbstractCausalLoopDiagram; kwargs...)
    return ResilienceCore.press_sign_determinacy(Random.default_rng(), cld; kwargs...)
end
