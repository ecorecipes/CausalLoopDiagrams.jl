# Finding motifs: the embedding and what it counts, the subset order it matches along, the
# canonical form, and the census across a collection.

@testset "motifs" begin
    @testset "the subset order on polarities is a partial order with a top" begin
        for p in polarities()
            @test issubset(p, p)
            @test issubset(p, INDETERMINATE)
        end
        # Antisymmetry, and the three atoms being pairwise incomparable.
        for a in polarities(), b in polarities()
            issubset(a, b) && issubset(b, a) && @test a === b
        end
        @test !issubset(POSITIVE, NEGATIVE)
        @test !issubset(NEGATIVE, NO_EFFECT)
        @test !issubset(INDETERMINATE, POSITIVE)
        # Transitivity, on all 64 triples.
        for a in polarities(), b in polarities(), c in polarities()
            if issubset(a, b) && issubset(b, c)
                @test issubset(a, c)
            end
        end
    end

    @testset "an occurrence is an injective, label-respecting embedding" begin
        cld = causal_loop_diagram([(:Hare, :Lynx) => POSITIVE,
                                   (:Lynx, :Hare) => NEGATIVE])
        occ = only(occurrences(motif(:predator_prey), cld))
        @test host_factors(occ) == [:Hare, :Lynx]
        @test motif_factors(occ) == [:A, :B]
        @test occ[:A] === :Hare
        @test occ[:B] === :Lynx
        @test length(occ) == 2
        @test sprint(show, occ) == "A = Hare, B = Lynx"
        # The balancing pair is not a reinforcing one, whichever way round it is read.
        @test !has_motif(motif(:mutual_amplification), cld)
        @test !has_motif(motif(:mutual_suppression), cld)
        # Injectivity: a three-factor chain cannot be found in a two-factor loop by
        # visiting one factor twice.
        @test isempty(occurrences(motif(:chain), cld))
    end

    @testset "an INDETERMINATE motif link matches any sign, and not the reverse" begin
        cld = causal_loop_diagram([(:A1, :B1) => POSITIVE,
                                   (:B1, :C1) => NEGATIVE])
        @test count_occurrences(motif(:chain), cld) == 1
        # A wildcard matches a host link whose own sign is undetermined.
        murky = causal_loop_diagram([(:A1, :B1) => INDETERMINATE,
                                     (:B1, :C1) => INDETERMINATE])
        @test count_occurrences(motif(:chain), murky) == 1
        # But a motif asking for a sign is not satisfied by a link that has none: the
        # diagram does not claim it.
        positive_chain = causal_loop_diagram([(:A, :B) => POSITIVE, (:B, :C) => POSITIVE])
        @test isempty(occurrences(positive_chain, murky))
        @test count_occurrences(positive_chain,
                                causal_loop_diagram([(:X, :Y) => POSITIVE,
                                                     (:Y, :Z) => POSITIVE])) == 1
    end

    @testset "a symmetric motif occurs once per symmetry" begin
        pair = causal_loop_diagram([(:P, :Q) => POSITIVE, (:Q, :P) => POSITIVE])
        # Two maps, one for each way round, because occurrences counts maps.
        @test count_occurrences(motif(:mutual_amplification), pair) == 2
        @test count_occurrences(motif(:predator_prey), pair) == 0
    end

    @testset "induced matching refuses the extra links a plain match allows" begin
        # A chain with a shortcut: the chain is present, but the three factors do not
        # carry only the chain.
        cld = causal_loop_diagram([(:A1, :B1) => POSITIVE,
                                   (:B1, :C1) => POSITIVE,
                                   (:A1, :C1) => POSITIVE])
        @test count_occurrences(motif(:chain), cld) == 1
        @test isempty(occurrences(motif(:chain), cld; induced=true))
        # Twice, not once: the common-cause shape is symmetric in its two targets, so A1
        # driving both B1 and C1 is found once for each way of naming them.
        @test count_occurrences(motif(:common_cause), cld) == 2
        @test isempty(occurrences(motif(:common_cause), cld; induced=true))
    end

    @testset "delays are ignored unless asked for" begin
        cld = causal_loop_diagram([(:A1, :B1) => POSITIVE,
                                   delayed((:B1, :A1) => NEGATIVE)])
        @test count_occurrences(motif(:predator_prey), cld) == 1
        # The library's shapes carry no delay, so with match_delay the delayed link fails.
        @test isempty(occurrences(motif(:predator_prey), cld; match_delay=true))
        with_delay = causal_loop_diagram([(:A, :B) => POSITIVE,
                                          delayed((:B, :A) => NEGATIVE)])
        @test count_occurrences(with_delay, cld; match_delay=true) == 1
    end

    @testset "self-links are matched, and only by a self-link" begin
        cld = causal_loop_diagram([(:Stock, :Stock) => POSITIVE,
                                   (:Stock, :Other) => NEGATIVE])
        @test count_occurrences(motif(:self_reinforcing), cld) == 1
        @test isempty(occurrences(motif(:self_balancing), cld))
        @test only(host_factors(only(occurrences(motif(:self_reinforcing), cld)))) ===
              :Stock
    end

    @testset "the cap is a guard and says so" begin
        star = causal_loop_diagram([(:Hub, Symbol(:Leaf, i)) => POSITIVE for i in 1:6])
        @test count_occurrences(motif(:common_cause), star) == 30
        err = try
            occurrences(motif(:common_cause), star; max_occurrences=5)
            nothing
        catch e
            e
        end
        @test err isa TooManyOccurrencesError
        @test err isa CausalLoopDiagramsError
        @test occursin("occurs more than 5 times", sprint(showerror, err))
        @test_throws ArgumentError occurrences(motif(:chain), star; max_occurrences=-1)
    end

    @testset "the library" begin
        @test length(motif_names()) == 10
        @test :predator_prey in motif_names()
        @test_throws ArgumentError motif(:no_such_shape)
        # Every library shape occurs in itself.
        for name in motif_names()
            m = motif(name)
            @test has_motif(m, m)
        end
        # Mutual suppression is reinforcing, which is the point of carrying it.
        @test loop_polarity(motif(:mutual_suppression), [:A, :B]) === POSITIVE
        @test loop_polarity(motif(:mutual_amplification), [:A, :B]) === POSITIVE
        @test loop_polarity(motif(:predator_prey), [:A, :B]) === NEGATIVE
        # The copy is a copy: adding to it leaves the library alone.
        m = motif(:predator_prey)
        add_factor!(m, :Extra)
        @test nfactors(motif(:predator_prey)) == 2
        # The two four-factor shapes differ only in a sign, and coarsening tells them
        # apart exactly as the docstring claims.
        opposed = coarsen(motif(:opposed_pathways), Dict(:B => :Mid, :C => :Mid))
        agreeing = coarsen(motif(:agreeing_pathways), Dict(:B => :Mid, :C => :Mid))
        @test link_polarity(opposed, :Mid, :D) === INDETERMINATE
        @test link_polarity(agreeing, :Mid, :D) === POSITIVE
    end

    @testset "the canonical form is blind to names and sees shape" begin
        a = causal_loop_diagram([(:Rain, :Runoff) => POSITIVE])
        b = causal_loop_diagram([(:Spores, :Infection) => POSITIVE])
        @test motif_key(a) == motif_key(b) == "2: A+>B"
        # A sign is part of the shape; a name is not.
        @test motif_key(causal_loop_diagram([(:Rain, :Runoff) => NEGATIVE])) != motif_key(a)
        # Relabelling and reordering a diagram does not change its key.
        chain1 = causal_loop_diagram([(:X, :Y) => POSITIVE, (:Y, :Z) => NEGATIVE])
        chain2 = causal_loop_diagram([(:Q, :R) => NEGATIVE, (:P, :Q) => POSITIVE])
        @test motif_key(chain1) == motif_key(chain2)
        @test factor_names(canonical_motif(chain1)) == [:A, :B, :C]
        @test link_polarity(canonical_motif(chain1), :A, :B) === POSITIVE
        @test link_polarity(canonical_motif(chain1), :B, :C) === NEGATIVE
        # A loop of two and a single link are different shapes.
        @test motif_key(causal_loop_diagram([(:X, :Y) => POSITIVE,
                                             (:Y, :X) => POSITIVE])) != motif_key(a)
    end

    @testset "the canonical form can be told to see delays, or not" begin
        plain = causal_loop_diagram([(:X, :Y) => POSITIVE])
        lagged = causal_loop_diagram([delayed((:X, :Y) => POSITIVE)])
        @test motif_key(plain) == motif_key(lagged)
        @test motif_key(plain; match_delay=true) != motif_key(lagged; match_delay=true)
        @test occursin("~", motif_key(lagged; match_delay=true))
        @test !link_delay(canonical_motif(lagged), :A, :B)
        @test link_delay(canonical_motif(lagged; match_delay=true), :A, :B)
    end

    @testset "a canonical form is for motifs, not whole diagrams" begin
        big = causal_loop_diagram([(Symbol(:F, i), Symbol(:F, i + 1)) => POSITIVE
                                   for i in 1:7])
        @test nfactors(big) == 8
        @test_throws ArgumentError motif_key(big)
    end

    @testset "the census counts shapes across a collection" begin
        a = causal_loop_diagram([(:X, :Y) => POSITIVE, (:Y, :X) => NEGATIVE])
        b = causal_loop_diagram([(:P, :Q) => POSITIVE, (:Q, :P) => NEGATIVE])
        census = motif_census([:a => a, :b => b]; size=2)
        row = only(census)
        @test row.key == "2: A+>B B->A"
        @test row.support == 2
        @test row.occurrences == 2
        @test row.diagrams == [:a, :b]
        @test occursin("in 2 diagrams, 2 times", sprint(show, row))
        @test motif_key(row.motif) == row.key
    end

    @testset "the census is induced, so its rows partition the factor sets" begin
        # Three factors, a chain with a shortcut: the one connected triple carries the
        # shortcut too, so it is counted once, as the shape it actually has.
        cld = causal_loop_diagram([(:A1, :B1) => POSITIVE,
                                   (:B1, :C1) => POSITIVE,
                                   (:A1, :C1) => POSITIVE])
        census = motif_census([:only => cld]; size=3)
        @test length(census) == 1
        @test only(census).occurrences == 1
        @test nlinks(only(census).motif) == 3
        # Every connected pair, and nothing else: three pairs, each a bare positive link.
        pairs = motif_census([:only => cld]; size=2)
        @test only(pairs).key == "2: A+>B"
        @test only(pairs).occurrences == 3
        # The counts add up to the connected sets of that size, which is what induced buys.
        @test sum(c -> c.occurrences, pairs) == 3
    end

    @testset "the census takes its collection three ways, and orders by support" begin
        loop = causal_loop_diagram([(:X, :Y) => POSITIVE, (:Y, :X) => NEGATIVE])
        chain = causal_loop_diagram([(:P, :Q) => POSITIVE, (:Q, :R) => POSITIVE])
        chain2 = causal_loop_diagram([(:S, :T) => POSITIVE, (:T, :U) => POSITIVE])
        byvec = motif_census([loop, chain]; size=2)
        @test Set(vcat([c.diagrams for c in byvec]...)) == Set([:d1, :d2])
        bypair = motif_census([:loop => loop, :chain => chain, :chain2 => chain2]; size=2)
        bydict = motif_census(Dict(:loop => loop, :chain => chain, :chain2 => chain2);
                              size=2)
        @test sort([c.key for c in bypair]) == sort([c.key for c in bydict])
        # Two shapes only, and the bare positive link is *not* one of the loop's: the pair
        # of factors in the loop carries both of its links, so the shape that pair
        # contributes is the loop. That is the induced reading doing its work.
        @test length(bypair) == 2
        @test first(bypair).key == "2: A+>B"
        @test first(bypair).support == 2
        @test first(bypair).diagrams == [:chain, :chain2]
        @test first(bypair).occurrences == 4
        @test last(bypair).key == "2: A+>B B->A"
        @test last(bypair).support == 1
        @test last(bypair).diagrams == [:loop]
        @test issorted([-c.support for c in bypair])
    end

    @testset "the census at size one finds the self-links and nothing else" begin
        cld = causal_loop_diagram([(:Stock, :Stock) => POSITIVE,
                                   (:Stock, :Sink) => NEGATIVE])
        census = motif_census([:one => cld]; size=1)
        @test only(census).key == "1: A+>A"
        # With connected = false the factor carrying no self-link is counted as well.
        loose = motif_census([:one => cld]; size=1, connected=false)
        @test length(loose) == 2
        @test any(c -> c.key == "1: ", loose)
    end

    @testset "the census separates delayed from instantaneous when asked" begin
        instant = causal_loop_diagram([(:X, :Y) => POSITIVE, (:Y, :X) => NEGATIVE])
        lagged = causal_loop_diagram([(:P, :Q) => POSITIVE,
                                      delayed((:Q, :P) => NEGATIVE)])
        @test length(motif_census([instant, lagged]; size=2)) == 1
        split = motif_census([instant, lagged]; size=2, match_delay=true)
        @test length(split) == 2
        @test all(c -> c.support == 1, split)
    end

    @testset "the census rejects a size below one" begin
        cld = causal_loop_diagram([(:X, :Y) => POSITIVE])
        @test_throws ArgumentError motif_census([cld]; size=0)
    end

    @testset "a motif of a network read off its tables" begin
        m = reference_habitat_model()
        cld = causal_loop_diagram(m)
        # This network is a tree narrowing to a chain: every factor has at most one child,
        # so it holds no confounder at all. What it holds is two colliders -- SoilMoisture
        # under Climate and Irrigation, Vegetation under SoilMoisture and GrazingPressure
        # -- each found once per ordering of its two parents.
        @test !has_motif(motif(:common_cause), cld)
        @test count_occurrences(motif(:common_effect), cld) == 4
        @test Set(occ[:C] for occ in occurrences(motif(:common_effect), cld)) ==
              Set([:SoilMoisture, :Vegetation])
        # Nothing read off an acyclic network can contain a loop of any size.
        @test isempty(occurrences(motif(:predator_prey), cld))
        @test isempty(occurrences(motif(:self_reinforcing), cld))
        @test isempty(motif_census([cld]; size=1))
    end
end
