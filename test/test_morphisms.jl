# Coarsening (the push-forward of labels), the lag collapse as its special case, and the
# link-by-link comparison of two diagrams.

@testset "morphisms" begin
    @testset "coarsening merges factors and adds their labels" begin
        cld = causal_loop_diagram([(:Spores, :Infection) => POSITIVE,
                                   (:Conidia, :Infection) => POSITIVE])
        lumped = coarsen(cld, Dict(:Spores => :Inoculum, :Conidia => :Inoculum))
        @test factor_names(lumped) == [:Inoculum, :Infection]
        @test nlinks(lumped) == 1
        @test link_polarity(lumped, :Inoculum, :Infection) === POSITIVE
        # Two pathways that disagree come out indeterminate, which is where the rig's
        # addition is doing the work.
        mixed = causal_loop_diagram([(:Shade, :Growth) => NEGATIVE,
                                     (:Shelter, :Growth) => POSITIVE])
        one_factor = coarsen(mixed, Dict(:Shade => :Canopy, :Shelter => :Canopy))
        @test nlinks(one_factor) == 1
        @test link_polarity(one_factor, :Canopy, :Growth) === INDETERMINATE
        # With combine = false both pathways stay visible and reading them still adds.
        kept = coarsen(mixed, Dict(:Shade => :Canopy, :Shelter => :Canopy);
                       combine=false)
        @test nlinks(kept) == 2
        @test link_polarity(kept, :Canopy, :Growth) === INDETERMINATE
    end

    @testset "coarsening takes a function, and merging linked factors makes a loop" begin
        chain = causal_loop_diagram([(:Larvae, :Adults) => POSITIVE,
                                     (:Adults, :Forage) => NEGATIVE])
        merged = coarsen(chain, name -> name in (:Larvae, :Adults) ? :Bees : name)
        @test factor_names(merged) == [:Bees, :Forage]
        @test has_link(merged, :Bees, :Bees)
        @test loop_length(only(loops(merged))) == 1
    end

    @testset "a merged link is delayed if any of its parts was" begin
        cld = causal_loop_diagram([(:A, :Z) => POSITIVE,
                                   delayed((:B, :Z) => POSITIVE)])
        merged = coarsen(cld, Dict(:A => :AB, :B => :AB))
        @test nlinks(merged) == 1
        @test link_delay(merged, :AB, :Z)
    end

    @testset "collapse_lags is coarsening by the time index, and marks the crossings" begin
        template = causal_loop_diagram([(Symbol("Vegetation[t-1]"),
                                        :Vegetation) => POSITIVE,
                                        (Symbol("Herbivores[t-1]"),
                                        :Vegetation) => NEGATIVE,
                                        (:Vegetation, :Herbivores) => POSITIVE])
        @test isempty(loops(template))
        collapsed = collapse_lags(template)
        @test factor_names(collapsed) == [:Vegetation, :Herbivores]
        @test link_delay(collapsed, :Vegetation, :Vegetation)
        @test link_delay(collapsed, :Herbivores, :Vegetation)
        @test !link_delay(collapsed, :Vegetation, :Herbivores)
        @test length(loops(collapsed)) == 2
        @test isempty(instantaneous_loops(collapsed))
    end

    @testset "a variable entering at the slice and at a lag gives one delayed link" begin
        template = causal_loop_diagram([(:Rain, :Runoff) => POSITIVE,
                                        (Symbol("Rain[t-1]"), :Runoff) => POSITIVE])
        collapsed = collapse_lags(template)
        @test nlinks(collapsed) == 1
        @test link_polarity(collapsed, :Rain, :Runoff) === POSITIVE
        @test link_delay(collapsed, :Rain, :Runoff)
    end

    @testset "comparison: a sketch against what the network kept" begin
        sketch = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                                      (:Infection, :Defoliation) => POSITIVE,
                                      (:Defoliation, :Vigour) => NEGATIVE,
                                      delayed((:Vigour, :Infection) => NEGATIVE)])
        # What a one-season belief network of the same system can hold: the loop is cut and
        # one link is signed the other way round.
        network = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                                       (:Infection, :Defoliation) => POSITIVE,
                                       (:Defoliation, :Vigour) => POSITIVE,
                                       (:Weather, :Infection) => POSITIVE])
        c = compare_diagrams(sketch, network)
        @test length(c.agree) == 2
        @test only(c.disagree) == (source=:Defoliation, target=:Vigour, first=NEGATIVE,
                                   second=POSITIVE)
        @test only(c.only_first) == (source=:Vigour, target=:Infection, polarity=NEGATIVE)
        @test only(c.only_second) == (source=:Weather, target=:Infection,
                                      polarity=POSITIVE)
        text = sprint(show, MIME"text/plain"(), c)
        @test occursin("2 agree, 1 disagree", text)
        @test occursin("Defoliation -> Vigour: - against +", text)
        @test occursin("only in the first", text)
    end

    @testset "comparing a diagram with itself finds nothing" begin
        cld = causal_loop_diagram([(:A, :B) => POSITIVE, delayed((:B, :A) => NEGATIVE)])
        c = compare_diagrams(cld, cld)
        @test length(c.agree) == 2
        @test isempty(c.disagree)
        @test isempty(c.only_first)
        @test isempty(c.only_second)
    end
end
