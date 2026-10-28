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
end
