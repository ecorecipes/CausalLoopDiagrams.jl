"""
    CausalLoopDiagrams

Causal loop diagrams as labelled graphs, and the bridge between them and the Bayesian
networks of the ecorecipes ecosystem.

A **causal loop diagram** is what a group of people draw on a whiteboard when they first
describe a system: factors joined by arrows, each arrow marked with the direction in which
it pushes, and loops closing back on themselves. Baez formalises one as a graph whose edges
are labelled by elements of a monoid of *polarities*, which makes a labelling the same
thing as a functor from the free category on the graph into the delooping of the monoid
[Baez2024](@cite); Baez and Chaudhuri take it further, to three kinds of morphism between
labelled graphs -- refining, simplifying and finding motifs -- and to a homology that counts
the feedback loops a composite acquires that neither part had [BaezChaudhuri2025](@cite).

A **Bayesian network** carries much more: a conditional probability table for every
mechanism rather than a sign. It also carries less, in one specific way: it must be
acyclic, so it cannot hold a loop at all.

This package is the two-way translation.

  - [`Polarity`](@ref) is the label: [`POSITIVE`](@ref), [`NEGATIVE`](@ref),
    [`NO_EFFECT`](@ref) and [`INDETERMINATE`](@ref), a commutative rig under composition
    along a path (`*`) and combination in parallel (`+`).
  - [`polarity`](@ref polarity(::FiniteKernel, ::Integer)) reads a polarity off a
    conditional probability table, by stochastic monotonicity in the declared order of the
    states. Monotone kernels compose, which is what makes the reading a labelling in Baez's
    sense rather than a convention: the polarity of a path really is the product of the
    polarities of its links.
  - [`causal_loop_diagram`](@ref causal_loop_diagram(::AbstractVector)) builds a diagram
    from a list of links -- the sketch, drawn by hand, loops intact -- or reads one off a
    `BayesianNetworks.BayesModel`, in either an interventional (`:structural`) or an
    observational reading.
  - [`loops`](@ref), [`delayed_loops`](@ref) and [`instantaneous_loops`](@ref) enumerate
    the feedback and classify it. The distinction the last two draw is the one that matters
    for modelling: a loop with a delay in it is a loop a dynamic Bayesian network holds as
    it stands, the delayed link becoming a lagged input, and
    [`causal_loop_diagram`](@ref causal_loop_diagram(::DynamicBayesModel)) recovers it by
    collapsing the time index of a transition template. A loop with no delay asserts
    simultaneity and no Bayesian network holds it.
  - [`coarsen`](@ref), [`collapse_lags`](@ref) and [`compare_diagrams`](@ref) are the maps
    between diagrams: the push-forward of labels along a map of factors, its time-index
    special case, and a link-by-link comparison of two labellings of one graph.

What the translation discards is worth stating plainly, because it is the reason a diagram
is a sketch and a network is a model. A polarity cannot hold a magnitude, so it cannot say
which of two loops through the same factor wins. It cannot hold an interaction: a link
whose sign depends on another parent comes out [`INDETERMINATE`](@ref), and a quantity that
is worth more alongside an intervention than alone has no expression in the diagram at all.
And it cannot hold a variable whose states have no order, which is what most decisions
between incomparable options are.

Part of the ecorecipes compositional Bayesian-network ecosystem.
"""
module CausalLoopDiagrams

using ACSets: BasicSchema, @abstract_acset_type, @acset_type, nparts, parts, subpart,
              incident, add_part!

using FiniteKernels: FiniteKernel, FiniteAxis, FiniteSpace, cpt, axis_names, DEFAULT_ATOL

using BayesianNetworks: BayesModel, DynamicBayesModel, Graphviz, syntax, variables,
                        variable_name, mechanisms, target, inputs, kernel, conditional,
                        lag_of, transition_network

import BayesianNetworks: to_graphviz

# Polarities: the labels and how a conditional probability table is read as one
export Polarity, POSITIVE, NEGATIVE, NO_EFFECT, INDETERMINATE, polarities, polarity,
       polarity_symbol, polarity_name
# The diagram
export SchCausalLoop, AbstractCausalLoopDiagram, CausalLoopDiagramUntyped,
       CausalLoopDiagram, LinkSpec, link, delayed, causal_loop_diagram, add_factor!,
       add_link!
export nfactors, nlinks, factor_names, factor_name, has_factor, factor_id, link_table,
       has_link, link_polarity, link_delay, polarity_matrix, delay_matrix
# Loops
export Loop, loops, loop_polarity, loop_length, loop_summary, delayed_loops,
       instantaneous_loops, reinforcing, balancing, is_delayed
# Maps between diagrams
export coarsen, collapse_lags, compare_diagrams, DiagramComparison
# Drawing
export to_graphviz
# Exceptions (ADR 0013): the root and the three concrete types under it
export CausalLoopDiagramsError, UnknownFactorError, NotALoopError, TooManyLoopsError

include("polarity.jl")
include("errors.jl")
include("diagram.jl")
include("loops.jl")
include("extraction.jl")
include("morphisms.jl")
include("graphics.jl")

end # module
