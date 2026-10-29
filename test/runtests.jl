using Test
using CausalLoopDiagrams
using BayesianNetworks
using FiniteKernels

@testset "CausalLoopDiagrams" begin
    include("test_polarity.jl")
    include("test_diagram.jl")
    include("test_loops.jl")
    include("test_extraction.jl")
    include("test_morphisms.jl")
    include("test_motifs.jl")
    include("test_graphics.jl")
    include("test_errors.jl")
    include("test_docstrings.jl")
end
