# Reading a diagram off a network: the two modes, the state-order keywords, and the
# collapse of a dynamic template that puts the loops back.

# A confounded model. Fertiliser goes on poor soil, soil drives yield harder than
# fertiliser does, so observing fertiliser is bad news about yield while applying it is
# good. Both mechanisms are monotone, so neither sign is indeterminate: the disagreement
# between the two modes is confounding, not interaction.
function confounded_model()
    bn = bayesnet(:Soil => [:poor, :rich], :Fertiliser => [:none, :some],
                  :Yield => [:low, :high];
                  mechanisms=[:Fertiliser => :Soil, :Yield => (:Soil, :Fertiliser)])
    yield = Array{Float64}(undef, 2, 2, 2)
    yield[1, 1, :] = [0.9, 0.1]        # poor soil, no fertiliser
    yield[1, 2, :] = [0.7, 0.3]        # poor soil, fertiliser
    yield[2, 1, :] = [0.3, 0.7]        # rich soil, no fertiliser
    yield[2, 2, :] = [0.1, 0.9]        # rich soil, fertiliser
    return bind_cpt(BayesModel(bn),
                    [:Soil => [0.5, 0.5], :Fertiliser => [0.1 0.9; 0.9 0.1],
                     :Yield => yield])
end

@testset "extraction" begin
    @testset "the structural reading of the reference habitat network" begin
        m = reference_habitat_model()
        cld = causal_loop_diagram(m)
        @test nfactors(cld) == 7
        @test nlinks(cld) == 6
        @test link_polarity(cld, :SoilMoisture, :Vegetation) === POSITIVE
        @test link_polarity(cld, :GrazingPressure, :Vegetation) === NEGATIVE
        @test link_polarity(cld, :Vegetation, :HabitatQuality) === POSITIVE
        # A belief network is acyclic, so its diagram has no feedback in it at all.
        @test isempty(loops(cld))
        @test !any(r -> r.delay, link_table(cld))
    end

    @testset "observational and structural agree where nothing is confounded" begin
        m = reference_habitat_model()
        c = compare_diagrams(causal_loop_diagram(m),
                             causal_loop_diagram(m; mode=:observational))
        @test length(c.agree) == 6
        @test isempty(c.disagree)
        @test isempty(c.only_first)
        @test isempty(c.only_second)
    end

    @testset "and disagree exactly where it is" begin
        m = confounded_model()
        structural = causal_loop_diagram(m)
        observational = causal_loop_diagram(m; mode=:observational)
        @test link_polarity(structural, :Fertiliser, :Yield) === POSITIVE
        @test link_polarity(structural, :Soil, :Fertiliser) === NEGATIVE
        @test link_polarity(structural, :Soil, :Yield) === POSITIVE
        # Fertiliser and yield move together the other way, because fertiliser marks poor
        # soil. A diagram drawn from co-movement would sign this link backwards.
        @test link_polarity(observational, :Fertiliser, :Yield) === NEGATIVE
        c = compare_diagrams(structural, observational)
        @test length(c.disagree) == 1
        @test only(c.disagree) == (source=:Fertiliser, target=:Yield, first=POSITIVE,
                                   second=NEGATIVE)
        @test length(c.agree) == 2
    end

    @testset "reversed flips every link at a factor, unordered kills it" begin
        m = reference_habitat_model()
        plain = causal_loop_diagram(m)
        flipped = causal_loop_diagram(m; reversed=[:Vegetation])
        @test link_polarity(flipped, :SoilMoisture, :Vegetation) ===
              -link_polarity(plain, :SoilMoisture, :Vegetation)
        @test link_polarity(flipped, :Vegetation, :HabitatQuality) ===
              -link_polarity(plain, :Vegetation, :HabitatQuality)
        @test link_polarity(flipped, :Climate, :SoilMoisture) ===
              link_polarity(plain, :Climate, :SoilMoisture)
        # Reversing both ends of a link leaves it alone, which is the sign rule.
        both = causal_loop_diagram(m; reversed=[:SoilMoisture, :Vegetation])
        @test link_polarity(both, :SoilMoisture, :Vegetation) ===
              link_polarity(plain, :SoilMoisture, :Vegetation)
        unordered = causal_loop_diagram(m; unordered=[:Vegetation])
        @test link_polarity(unordered, :SoilMoisture, :Vegetation) === INDETERMINATE
        @test link_polarity(unordered, :Vegetation, :HabitatQuality) === INDETERMINATE
        @test link_polarity(unordered, :Climate, :SoilMoisture) === POSITIVE
    end

    @testset "an unknown mode is an ArgumentError" begin
        @test_throws ArgumentError causal_loop_diagram(reference_habitat_model();
                                                       mode=:guess)
    end

    @testset "collapsing a dynamic template puts the loops back" begin
        dm = vegetation_herbivore_model()
        template = causal_loop_diagram(transition_network(dm))
        # The template itself is acyclic and its lagged parents are separate factors.
        @test isempty(loops(template))
        @test has_factor(template, Symbol("Vegetation[t-1]"))
        collapsed = causal_loop_diagram(dm)
        @test factor_names(collapsed) == [:Vegetation, :Herbivores]
        @test link_polarity(collapsed, :Vegetation, :Herbivores) === POSITIVE
        @test link_polarity(collapsed, :Herbivores, :Vegetation) === NEGATIVE
        @test link_polarity(collapsed, :Vegetation, :Vegetation) === POSITIVE
        @test link_delay(collapsed, :Herbivores, :Vegetation)
        @test !link_delay(collapsed, :Vegetation, :Herbivores)
        ls = loops(collapsed)
        @test length(ls) == 2
        @test [l.factors for l in ls] == [[:Vegetation], [:Vegetation, :Herbivores]]
        # Grazing: more vegetation, more herbivores, less vegetation next season.
        grazing = last(ls)
        @test balancing(grazing)
        @test is_delayed(grazing)
        @test isempty(instantaneous_loops(collapsed))
    end
end
