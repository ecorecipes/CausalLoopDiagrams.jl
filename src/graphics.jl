# Graphviz drawings of a causal loop diagram, as a method on BayesianNetworks'
# `to_graphviz`, so that a vignette draws a diagram and a network the same way.
#
# The notation: colour carries the polarity and dashing carries the delay. Those are
# separate channels on purpose, because the two things a reader needs from a causal loop
# diagram are which way each link pushes and which links cross a period boundary, and a
# single channel cannot hold both.

const _GV_FONT = "Helvetica"

const _POLARITY_COLOUR = Dict(POSITIVE => "darkgreen", NEGATIVE => "firebrick",
                              NO_EFFECT => "grey70", INDETERMINATE => "grey40")

_gv_string(x) = x isa AbstractString ? String(x) : string(x)
_gv_attrs(d::AbstractDict) = Dict{Symbol,String}(Symbol(k) => _gv_string(v) for (k, v) in d)

# The consecutive pairs of a loop, closing link included.
function _loop_pairs(loop::Loop)
    n = length(loop.factors)
    return Set((loop.factors[i], loop.factors[mod1(i + 1, n)]) for i in 1:n)
end

function _factor_node(cld, f)
    return Graphviz.Node("f$f",
                         Dict{Symbol,String}(:label => string(factor_name(cld,
                                                                          f))))
end

# A themed box. The name must begin with `cluster` for dot to draw the border at all.
function _cluster(index::Integer, label, members::Vector{Graphviz.Statement})
    attrs = Dict{Symbol,String}(:label => _gv_string(label), :style => "rounded",
                                :color => "grey60", :fontcolor => "grey25",
                                :fontsize => "11", :labeljust => "l", :margin => "10")
    return Graphviz.Subgraph("cluster_$(index)", members; graph_attrs=attrs)
end

"""
    to_graphviz(cld::AbstractCausalLoopDiagram; kwargs...) -> Graphviz.Graph

Draw a causal loop diagram: one node per factor and one edge per link, the edge labelled
with the polarity's symbol (`+`, `-`, `0` or `?`), coloured green for
[`POSITIVE`](@ref), red for [`NEGATIVE`](@ref) and grey for the other two, and dashed when
the link crosses a delay.

Keyword arguments:

  - `highlight`: a [`Loop`](@ref), or a vector of factor names read as one, whose links are
    drawn heavier. This is how a figure points at the loop the text is about.
  - `groups`: an iterable of `label => factor names` pairs, each drawn as a labelled box
    (a Graphviz cluster) around those factors. This is what keeps a diagram of thirty or
    more factors legible: the boxes carry the themes -- the abiotic drivers, the biotic
    interactions, the management levers -- while the links stay where the diagram puts
    them. A factor named in no group is drawn outside the boxes, so a partial grouping is
    allowed; naming a factor the diagram does not have raises
    [`UnknownFactorError`](@ref), and naming one in two groups an `ArgumentError`.
  - `rankdir = "LR"`, `name = "G"`, and `graph_attrs`, `node_attrs`, `edge_attrs`
    (dictionaries merged over the defaults), as in BayesianNetworks' own `to_graphviz`.

Render with `show(io, MIME"image/svg+xml"(), g)` or
`BayesianNetworks.Graphviz.run_graphviz`, which is how the vignettes write their PNGs.
"""
function to_graphviz(cld::AbstractCausalLoopDiagram; highlight=nothing, groups=nothing,
                     rankdir::AbstractString="LR", name::AbstractString="G",
                     graph_attrs::AbstractDict=Dict{Symbol,String}(),
                     node_attrs::AbstractDict=Dict{Symbol,String}(),
                     edge_attrs::AbstractDict=Dict{Symbol,String}())
    marked = if highlight === nothing
        Set{Tuple{Symbol,Symbol}}()
    elseif highlight isa Loop
        _loop_pairs(highlight)
    else
        names = collect(Symbol, highlight)
        Set((names[i], names[mod1(i + 1, length(names))]) for i in 1:length(names))
    end
    stmts = Graphviz.Statement[]
    boxed = Set{Symbol}()
    if groups !== nothing
        for (i, group) in enumerate(groups)
            label, members = first(group), last(group)
            inside = Graphviz.Statement[]
            for nm in members
                f = Symbol(nm)
                has_factor(cld, f) ||
                    throw(UnknownFactorError(f, collect(factor_names(cld))))
                f in boxed &&
                    throw(ArgumentError("factor $(repr(f)) is in two groups; each factor " *
                                        "belongs to at most one box."))
                push!(boxed, f)
                push!(inside, _factor_node(cld, factor_id(cld, f)))
            end
            push!(stmts, _cluster(i, label, inside))
        end
    end
    for f in parts(cld, :Factor)
        factor_name(cld, f) in boxed || push!(stmts, _factor_node(cld, f))
    end
    for l in parts(cld, :Link)
        s = subpart(cld, l, :link_source)
        t = subpart(cld, l, :link_target)
        p = subpart(cld, l, :link_polarity)
        colour = _POLARITY_COLOUR[p]
        attrs = Dict{Symbol,String}(:label => " " * polarity_symbol(p),
                                    :color => colour, :fontcolor => colour)
        subpart(cld, l, :link_delay) && (attrs[:style] = "dashed")
        (factor_name(cld, s), factor_name(cld, t)) in marked && (attrs[:penwidth] = "2.2")
        push!(stmts, Graphviz.Edge(["f$s", "f$t"], attrs))
    end
    return Graphviz.Digraph(String(name), stmts; prog="dot",
                            graph_attrs=merge(Dict{Symbol,String}(:rankdir => String(rankdir),
                                                                  :fontname => _GV_FONT),
                                              _gv_attrs(graph_attrs)),
                            node_attrs=merge(Dict{Symbol,String}(:shape => "ellipse",
                                                                 :fontname => _GV_FONT,
                                                                 :style => "filled",
                                                                 :fillcolor => "white",
                                                                 :margin => "0.1,0.05"),
                                             _gv_attrs(node_attrs)),
                            edge_attrs=merge(Dict{Symbol,String}(:arrowsize => "0.7",
                                                                 :fontsize => "11",
                                                                 :fontname => _GV_FONT),
                                             _gv_attrs(edge_attrs)))
end
