# The diagram as a labelled multigraph: construction, the accessors, and the two places the
# representation deliberately keeps something a simple graph would throw away (parallel
# links and self-links).

@testset "diagram" begin
    sketch = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                                  (:Infection, :Defoliation) => POSITIVE,
                                  (:Defoliation, :Vigour) => NEGATIVE,
                                  delayed((:Vigour, :Infection) => NEGATIVE),
                                  delayed((:Infection, :Inoculum) => POSITIVE)])

    @testset "factors come in the order they are first mentioned" begin
        @test nfactors(sketch) == 4
        @test nlinks(sketch) == 5
        @test factor_names(sketch) == [:Inoculum, :Infection, :Defoliation, :Vigour]
        @test factor_name(sketch, 1) === :Inoculum
        @test factor_id(sketch, :Vigour) == 4
        @test has_factor(sketch, :Vigour)
        @test !has_factor(sketch, :Rainfall)
    end

    @testset "a leading factors list fixes the order and admits isolated factors" begin
        with_order = causal_loop_diagram([(:B, :A) => POSITIVE];
                                         factors=[:A, :B, :Spectator])
        @test factor_names(with_order) == [:A, :B, :Spectator]
        @test nlinks(with_order) == 1
    end

    @testset "links, their polarities and their delays" begin
        @test link_polarity(sketch, :Inoculum, :Infection) === POSITIVE
        @test link_polarity(sketch, :Defoliation, :Vigour) === NEGATIVE
        @test link_delay(sketch, :Vigour, :Infection)
        @test !link_delay(sketch, :Inoculum, :Infection)
        @test has_link(sketch, :Vigour, :Infection)
        @test !has_link(sketch, :Infection, :Vigour)
        # A missing link reads as the additive unit, which is not the same question as
        # whether the link is there.
        @test link_polarity(sketch, :Infection, :Vigour) === NO_EFFECT
        rows = link_table(sketch)
        @test length(rows) == 5
        @test first(rows) == (source=:Inoculum, target=:Infection, polarity=POSITIVE,
                              delay=false)
        @test count(r -> r.delay, rows) == 2
    end

    @testset "parallel links are kept and summed on reading" begin
        two_ways = causal_loop_diagram([(:Nitrogen, :Growth) => POSITIVE,
                                        (:Nitrogen, :Growth) => NEGATIVE])
        @test nlinks(two_ways) == 2
        @test nfactors(two_ways) == 2
        # Two pathways that disagree: the diagram says so and says no more.
        @test link_polarity(two_ways, :Nitrogen, :Growth) === INDETERMINATE
        agreeing = causal_loop_diagram([(:Nitrogen, :Growth) => POSITIVE,
                                        (:Nitrogen, :Growth) => POSITIVE])
        @test link_polarity(agreeing, :Nitrogen, :Growth) === POSITIVE
    end

    @testset "a self-link is a link" begin
        persistent = causal_loop_diagram([delayed((:Reservoir, :Reservoir) => POSITIVE)])
        @test nfactors(persistent) == 1
        @test has_link(persistent, :Reservoir, :Reservoir)
        @test link_polarity(persistent, :Reservoir, :Reservoir) === POSITIVE
    end

    @testset "building by hand matches the list constructor" begin
        built = CausalLoopDiagram()
        add_factor!(built, :Inoculum)
        add_factor!(built, :Inoculum)                 # idempotent
        @test nfactors(built) == 1
        add_link!(built, :Inoculum, :Infection, POSITIVE)
        add_link!(built, link(:Infection, :Inoculum, POSITIVE; delay=true))
        @test factor_names(built) == [:Inoculum, :Infection]
        @test link_delay(built, :Infection, :Inoculum)
    end

    @testset "LinkSpec and delayed" begin
        spec = LinkSpec(:A, :B, POSITIVE)
        @test !spec.delay
        @test delayed(spec).delay
        @test delayed((:A, :B) => NEGATIVE) == LinkSpec(:A, :B, NEGATIVE, true)
        @test link(:A, :B, POSITIVE) == LinkSpec((:A, :B) => POSITIVE)
    end

    @testset "the matrices are the diagram over the rig" begin
        m = polarity_matrix(sketch)
        names = factor_names(sketch)
        @test size(m) == (4, 4)
        for (i, source) in enumerate(names), (j, t) in enumerate(names)
            @test m[i, j] === link_polarity(sketch, source, t)
        end
        d = delay_matrix(sketch)
        @test count(d) == 2
        @test d[factor_id(sketch, :Vigour), factor_id(sketch, :Infection)]
    end

    @testset "printing names the polarity and the delay" begin
        text = sprint(show, MIME"text/plain"(), sketch)
        @test occursin("4 factors and 5 links", text)
        @test occursin("Inoculum -(+)-> Infection", text)
        @test occursin("Defoliation -(-)-> Vigour", text)
        @test occursin("(delayed)", text)
    end
end
