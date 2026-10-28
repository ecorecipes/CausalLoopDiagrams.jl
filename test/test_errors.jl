# The exception hierarchy of ADR 0013: every exception type this package defines, exported
# or not, subtypes the root `CausalLoopDiagramsError`, and the types keep their module and
# their unqualified names.
function owned_exception_types(M)
    types = Type[]
    for n in names(M; all=true)
        isdefined(M, n) || continue
        T = getglobal(M, n)
        T isa Type && T <: Exception && parentmodule(T) === M && push!(types, T)
    end
    return types
end

@testset "errors" begin
    owned = owned_exception_types(CausalLoopDiagrams)

    @testset "hierarchy" begin
        @test isabstracttype(CausalLoopDiagramsError)
        @test CausalLoopDiagramsError <: Exception
        # The search is not vacuous: it finds the root and the three concrete types.
        @test issubset([CausalLoopDiagramsError, UnknownFactorError, NotALoopError,
                        TooManyLoopsError], owned)
        for T in owned
            @test T <: CausalLoopDiagramsError
            @test string(T) == string(nameof(T))
        end
    end

    @testset "an unknown factor names itself and what was there" begin
        cld = causal_loop_diagram([(:A, :B) => POSITIVE])
        @test_throws UnknownFactorError factor_id(cld, :C)
        @test_throws CausalLoopDiagramsError has_link(cld, :A, :C)
        e = try
            factor_id(cld, :C)
        catch err
            err
        end
        msg = sprint(showerror, e)
        @test occursin(":C", msg)
        @test occursin(":A", msg)
    end

    @testset "a sequence that is not a loop" begin
        cld = causal_loop_diagram([(:A, :B) => POSITIVE, (:B, :A) => POSITIVE,
                                   (:B, :C) => POSITIVE])
        @test_throws NotALoopError loop_polarity(cld, Symbol[])
        @test_throws NotALoopError loop_polarity(cld, [:A, :B, :A])
        @test_throws NotALoopError loop_polarity(cld, [:A, :B, :C])
        e = try
            loop_polarity(cld, [:A, :B, :C])
        catch err
            err
        end
        @test occursin("no link from C to A", sprint(showerror, e))
    end

    @testset "too many loops says so and says the cap" begin
        complete = causal_loop_diagram([(a, b) => POSITIVE
                                        for a in (:A, :B, :C, :D)
                                        for b in (:A, :B, :C, :D)])
        e = try
            loops(complete; max_loops=2)
        catch err
            err
        end
        @test e isa TooManyLoopsError
        @test occursin("more than 2", sprint(showerror, e))
    end

    @testset "invalid arguments and keywords stay outside the root" begin
        @test_throws ArgumentError Polarity(7)
        @test_throws ArgumentError causal_loop_diagram(reference_habitat_model();
                                                       mode=:sideways)
    end

    @testset "another package's errors pass through unchanged" begin
        # An unbound mechanism is BayesianNetworks' business, not this package's.
        bn = bayesnet(:A => [:low, :high], :B => [:low, :high]; mechanisms=[:B => :A])
        @test_throws BayesianNetworks.BayesNetError causal_loop_diagram(BayesModel(bn))
    end
end
