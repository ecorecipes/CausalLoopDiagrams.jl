# The Graphviz drawing: the DOT that comes out carries the polarity in the colour and the
# label, and the delay in the dashing. The PNG itself is not checked here; the vignettes
# render it.

@testset "graphics" begin
    cld = causal_loop_diagram([(:Inoculum, :Infection) => POSITIVE,
                               (:Infection, :Defoliation) => POSITIVE,
                               (:Defoliation, :Vigour) => NEGATIVE,
                               delayed((:Vigour, :Infection) => NEGATIVE)])
    dot = sprint(show, MIME"text/plain"(), to_graphviz(cld))

    @testset "a node per factor and an edge per link" begin
        @test occursin("digraph", dot)
        for name in factor_names(cld)
            @test occursin(string(name), dot)
        end
        @test count("->", dot) == nlinks(cld)
    end

    @testset "colour carries the sign and dashing carries the delay" begin
        @test occursin("darkgreen", dot)
        @test occursin("firebrick", dot)
        # One dashed edge, for the one delayed link.
        @test count("dashed", dot) == 1
    end

    @testset "the other two polarities are grey" begin
        grey = sprint(show, MIME"text/plain"(),
                      to_graphviz(causal_loop_diagram([(:A, :B) => NO_EFFECT,
                                                       (:B, :C) => INDETERMINATE])))
        @test occursin("grey70", grey)
        @test occursin("grey40", grey)
        @test !occursin("darkgreen", grey)
    end

    @testset "highlighting a loop thickens its links" begin
        loop = only(loops(cld))
        marked = sprint(show, MIME"text/plain"(), to_graphviz(cld; highlight=loop))
        @test count("penwidth", marked) == loop_length(loop)
        by_name = sprint(show, MIME"text/plain"(),
                         to_graphviz(cld; highlight=loop.factors))
        @test count("penwidth", by_name) == loop_length(loop)
        @test !occursin("penwidth", dot)
    end

    @testset "the usual drawing keywords are forwarded" begin
        named = sprint(show, MIME"text/plain"(),
                       to_graphviz(cld; name="loops", rankdir="TB",
                                   node_attrs=Dict(:shape => "box")))
        @test occursin("loops", named)
        @test occursin("TB", named)
        @test occursin("box", named)
    end

    @testset "groups draw themed boxes" begin
        # What a comprehensive diagram needs: the themes as boxes, so that thirty factors
        # stay readable. Every factor still appears exactly once.
        boxed = sprint(show, MIME"text/plain"(),
                       to_graphviz(cld;
                                   groups=["Pathogen" => [:Inoculum, :Infection],
                                           "Host" => [:Defoliation, :Vigour]]))
        @test count("cluster_", boxed) == 2
        @test occursin("Pathogen", boxed)
        @test occursin("Host", boxed)
        for name in factor_names(cld)
            @test count("label=\"$(name)\"", boxed) == 1
        end
        @test count("->", boxed) == nlinks(cld)
        # Ungrouped by default, so every existing drawing is unchanged.
        @test !occursin("cluster_", dot)
    end

    @testset "a partial grouping leaves the rest outside the boxes" begin
        partial = sprint(show, MIME"text/plain"(),
                         to_graphviz(cld; groups=["Pathogen" => [:Inoculum]]))
        @test count("cluster_", partial) == 1
        for name in factor_names(cld)
            @test count("label=\"$(name)\"", partial) == 1
        end
    end

    @testset "a group naming an unknown or repeated factor is an error" begin
        @test_throws UnknownFactorError to_graphviz(cld; groups=["x" => [:Nonesuch]])
        @test_throws ArgumentError to_graphviz(cld;
                                               groups=["a" => [:Inoculum],
                                                       "b" => [:Inoculum]])
    end
end
