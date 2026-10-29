# Exceptions of CausalLoopDiagrams (ADR 0013). Every exception the package defines lives in
# this file with its `showerror` method and subtypes the root `CausalLoopDiagramsError`.
#
# - Carry the offending factor names in the fields and the message.
# - Invalid arguments and keywords raise `ArgumentError`, not a type from this file (for
#   example an unknown `mode`, or a `polarity` position outside the parents of a kernel).
# - Typed errors from BayesianNetworks and FiniteKernels pass through unchanged: a model
#   with an unbound mechanism raises that package's `MissingKernelError` from `kernel`, and
#   a query too large for the brute-force evaluator raises its `ModelTooLargeError`.
# - A docstring names another package's type as a code span, never with `@ref`.

"""
    CausalLoopDiagramsError

Abstract supertype of every exception that CausalLoopDiagrams defines:
[`UnknownFactorError`](@ref), [`NotALoopError`](@ref), [`TooManyLoopsError`](@ref) and
[`TooManyOccurrencesError`](@ref). It
marks the package that introduced an error, not a kind of failure. Invalid arguments and
keywords raise Base's `ArgumentError` instead, which is outside this root, and the typed
errors of `BayesianNetworks` and `FiniteKernels` pass through unchanged.
"""
abstract type CausalLoopDiagramsError <: Exception end

"""
    UnknownFactorError(name, known)

Thrown when a factor name is looked up that the diagram does not carry. `known` is the
diagram's factor names, so the message can show what was available.
"""
struct UnknownFactorError <: CausalLoopDiagramsError
    name::Symbol
    known::Vector{Symbol}
end

function Base.showerror(io::IO, e::UnknownFactorError)
    return print(io, "UnknownFactorError: no factor ", repr(e.name),
                 " in the diagram; its factors are ", e.known, ".")
end

"""
    NotALoopError(factors, msg)

Thrown when a sequence of factor names is read as a loop but is not one: a repeated factor,
or a consecutive pair with no link between them. `factors` is the sequence as given.
"""
struct NotALoopError <: CausalLoopDiagramsError
    factors::Vector{Symbol}
    msg::String
end

function Base.showerror(io::IO, e::NotALoopError)
    return print(io, "NotALoopError: ", e.factors, " is not a loop of the diagram: ",
                 e.msg)
end

"""
    TooManyLoopsError(found, max_loops)

Thrown by [`loops`](@ref) when a diagram has more elementary loops than `max_loops`.
Enumerating loops is exponential in the worst case, so the cap is a guard rather than a
limit of the algorithm; raise it deliberately.
"""
struct TooManyLoopsError <: CausalLoopDiagramsError
    found::Int
    max_loops::Int
end

function Base.showerror(io::IO, e::TooManyLoopsError)
    return print(io, "TooManyLoopsError: the diagram has more than ", e.max_loops,
                 " elementary loops (", e.found, " found before stopping). Pass a larger ",
                 "max_loops if that is what you want.")
end

"""
    TooManyOccurrencesError(found, max_occurrences)

Thrown by [`occurrences`](@ref) when a motif occurs in a diagram more often than
`max_occurrences`. Subgraph matching is exponential in the size of the motif, so the cap is
a guard rather than a limit of the algorithm; raise it deliberately.

A motif that occurs this often is usually a motif that says nothing -- a bare link, or a
chain of [`INDETERMINATE`](@ref) links, which matches everywhere.
"""
struct TooManyOccurrencesError <: CausalLoopDiagramsError
    found::Int
    max_occurrences::Int
end

function Base.showerror(io::IO, e::TooManyOccurrencesError)
    return print(io, "TooManyOccurrencesError: the motif occurs more than ",
                 e.max_occurrences, " times (", e.found, " found before stopping). Pass a ",
                 "larger max_occurrences if that is what you want, but a motif this common ",
                 "is usually one that says nothing.")
end
