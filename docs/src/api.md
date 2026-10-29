# API Reference

```@docs
CausalLoopDiagrams
```

## Polarities

```@docs
Polarity
POSITIVE
NEGATIVE
NO_EFFECT
INDETERMINATE
polarities
polarity_symbol
polarity_name
polarity(::FiniteKernel, ::Integer)
```

## Diagrams

```@docs
SchCausalLoop
AbstractCausalLoopDiagram
CausalLoopDiagramUntyped
CausalLoopDiagram
LinkSpec
link
delayed
causal_loop_diagram(::AbstractVector)
add_factor!
add_link!
```

## Reading a diagram

```@docs
nfactors
nlinks
factor_names
factor_name
has_factor
factor_id
link_table
has_link
link_polarity
link_delay
polarity_matrix
delay_matrix
```

## Loops

```@docs
Loop
loops
loop_polarity
loop_length
loop_summary
polarity(::Loop)
is_delayed
reinforcing
balancing
delayed_loops
instantaneous_loops
```

## From a Bayesian network

```@docs
causal_loop_diagram(::BayesModel)
causal_loop_diagram(::DynamicBayesModel)
```

## Maps between diagrams

```@docs
coarsen
collapse_lags
compare_diagrams
DiagramComparison
```

## Motifs

Finding motifs is the third of Baez and Chaudhuri's morphisms between labelled graphs. A
motif is itself a small labelled graph, and an occurrence of it is an embedding that
respects the labels: the matching runs along the subset order on [`Polarity`](@ref)
(`issubset`), so a motif link labelled [`INDETERMINATE`](@ref) matches a link of any sign.

```@docs
occurrences
count_occurrences
has_motif
MotifOccurrence
host_factors
motif_factors
issubset(::Polarity, ::Polarity)
```

### The standard shapes

```@docs
MOTIF_LIBRARY
motif
motif_names
```

### Canonical form and the census

```@docs
motif_key
canonical_motif
motif_census
MotifCount
```

## Drawing

```@docs
to_graphviz(::AbstractCausalLoopDiagram)
```

## Exceptions

```@docs
CausalLoopDiagramsError
UnknownFactorError
NotALoopError
TooManyLoopsError
TooManyOccurrencesError
```
