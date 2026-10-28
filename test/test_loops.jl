# Loop enumeration, loop polarity and the delayed / instantaneous split.

@testset "loops" begin
    @testset "a two-link loop, and its polarity is where you cut it" begin
        predation = causal_loop_diagram([(:Hare, :Lynx) => POSITIVE,
                                         delayed((:Lynx, :Hare) => NEGATIVE)])
        loop = only(loops(predation))
        @test loop.factors == [:Hare, :Lynx]
        @test polarity(loop) === NEGATIVE
        @test balancing(loop)
        @test !reinforcing(loop)
        @test is_delayed(loop)
        @test loop_length(loop) == 2
        @test loop_polarity(predation, [:Hare, :Lynx]) === NEGATIVE
        @test loop_polarity(predation, [:Lynx, :Hare]) === NEGATIVE
        @test sprint(show, loop) == "Hare -> Lynx -> Hare (-, balancing, delayed)"
    end

    @testset "two loops through one factor" begin
        disease = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                                       delayed((:Infection, :Inoculum) => POSITIVE),
                                       (:Infection, :Defoliation) => POSITIVE,
                                       (:Defoliation, :Vigour) => NEGATIVE,
                                       delayed((:Vigour, :Infection) => NEGATIVE)])
        ls = loops(disease)
        @test length(ls) == 2
        @test [l.factors for l in ls] == [[:Inoculum, :Infection],
                                          [:Infection, :Defoliation, :Vigour]]
        @test all(reinforcing, ls)           # two negatives in the second loop
        @test all(is_delayed, ls)
        s = loop_summary(disease)
        @test s.loops == 2
        @test s.reinforcing == 2
        @test s.balancing == 0
        @test s.undetermined == 0
        @test s.inactive == 0
        @test s.delayed == 2
        @test s.instantaneous == 0
        @test s.loops == s.reinforcing + s.balancing + s.undetermined + s.inactive
        @test s.loops == s.delayed + s.instantaneous
    end

    @testset "a self-link is a loop of length one" begin
        persistence = causal_loop_diagram([delayed((:Reservoir, :Reservoir) => POSITIVE)])
        loop = only(loops(persistence))
        @test loop.factors == [:Reservoir]
        @test loop_length(loop) == 1
        @test reinforcing(loop)
        @test is_delayed(loop)
    end

    @testset "the two kinds of loop" begin
        both = causal_loop_diagram([(:Price, :Supply) => POSITIVE,
                                    (:Supply, :Price) => NEGATIVE,
                                    (:Stock, :Harvest) => POSITIVE,
                                    delayed((:Harvest, :Stock) => NEGATIVE)])
        @test length(loops(both)) == 2
        @test length(delayed_loops(both)) == 1
        @test length(instantaneous_loops(both)) == 1
        @test only(instantaneous_loops(both)).factors == [:Price, :Supply]
        @test only(delayed_loops(both)).factors == [:Stock, :Harvest]
    end

    @testset "a loop through a link that carries no effect is not live" begin
        dead = causal_loop_diagram([(:A, :B) => POSITIVE,
                                    delayed((:B, :A) => NO_EFFECT)])
        loop = only(loops(dead))
        @test polarity(loop) === NO_EFFECT
        @test !reinforcing(loop)
        @test !balancing(loop)
        @test loop_summary(dead).inactive == 1
        @test occursin("not live", sprint(show, loop))
    end

    @testset "a loop whose sign the diagram does not determine" begin
        unsure = causal_loop_diagram([(:A, :B) => INDETERMINATE,
                                      delayed((:B, :A) => POSITIVE)])
        @test polarity(only(loops(unsure))) === INDETERMINATE
        @test loop_summary(unsure).undetermined == 1
        @test occursin("undetermined", sprint(show, only(loops(unsure))))
    end

    @testset "parallel links are summed before the loop is read" begin
        both_ways = causal_loop_diagram([(:A, :B) => POSITIVE,
                                         (:A, :B) => NEGATIVE,
                                         delayed((:B, :A) => POSITIVE)])
        @test length(loops(both_ways)) == 1      # one cycle of factors, not two
        @test polarity(only(loops(both_ways))) === INDETERMINATE
    end

    @testset "an acyclic diagram has no loops" begin
        chain = causal_loop_diagram([(:A, :B) => POSITIVE, (:B, :C) => POSITIVE])
        @test isempty(loops(chain))
        @test loop_summary(chain).loops == 0
    end

    @testset "shortest first, then by name" begin
        many = causal_loop_diagram([(:A, :B) => POSITIVE, (:B, :A) => POSITIVE,
                                    (:B, :C) => POSITIVE, (:C, :A) => POSITIVE])
        @test [l.factors for l in loops(many)] == [[:A, :B], [:A, :B, :C]]
    end

    @testset "the loop cap" begin
        complete = causal_loop_diagram([(a, b) => POSITIVE
                                        for a in (:A, :B, :C, :D, :E)
                                        for b in (:A, :B, :C, :D, :E)])
        @test length(loops(complete)) > 5
        @test_throws TooManyLoopsError loops(complete; max_loops=3)
    end
end
