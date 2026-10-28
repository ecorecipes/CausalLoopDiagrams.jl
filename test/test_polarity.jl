# The rig laws, exhaustively over the four polarities, and the reading of a polarity off a
# conditional probability table. The laws are checked here on all 4^3 triples and proved in
# `proofs/` for the same four-element rig; the two must agree.

@testset "polarity" begin
    P = collect(polarities())

    @testset "the four are distinct and complete" begin
        @test length(P) == 4
        @test allunique(P)
        @test Set(P) == Set([NO_EFFECT, POSITIVE, NEGATIVE, INDETERMINATE])
        @test polarity_symbol.(P) == ["0", "+", "-", "?"]
        @test polarity_name.(P) == [:no_effect, :positive, :negative, :indeterminate]
        @test string.(P) == ["0", "+", "-", "?"]
    end

    @testset "commutative rig laws" begin
        @test one(Polarity) === POSITIVE
        @test zero(Polarity) === NO_EFFECT
        for a in P
            @test a * one(Polarity) === a
            @test a + zero(Polarity) === a
            @test a * zero(Polarity) === NO_EFFECT    # the zero is absorbing
            @test -(-a) === a
            for b in P
                @test a * b === b * a
                @test a + b === b + a
                for c in P
                    @test (a * b) * c === a * (b * c)
                    @test (a + b) + c === a + (b + c)
                    @test a * (b + c) === a * b + a * c
                end
            end
        end
    end

    @testset "the signs multiply and the disagreements add" begin
        @test POSITIVE * POSITIVE === POSITIVE
        @test POSITIVE * NEGATIVE === NEGATIVE
        @test NEGATIVE * NEGATIVE === POSITIVE
        @test POSITIVE + POSITIVE === POSITIVE
        @test NEGATIVE + NEGATIVE === NEGATIVE
        @test POSITIVE + NEGATIVE === INDETERMINATE
        @test -POSITIVE === NEGATIVE
        # Indeterminate is absorbing for both operations except against the zero.
        @test INDETERMINATE * NO_EFFECT === NO_EFFECT
        for a in P
            a === NO_EFFECT && continue
            @test INDETERMINATE * a === INDETERMINATE
            @test INDETERMINATE + a === INDETERMINATE
        end
        @test_throws ArgumentError Polarity(4)
    end

    @testset "reading a two-state table" begin
        rain = FiniteAxis(:Rain, [:dry, :wet])
        grass = FiniteAxis(:Grass, [:brown, :green])
        @test polarity(cpt(rain, grass, [0.9 0.1; 0.2 0.8]), :Rain) === POSITIVE
        @test polarity(cpt(rain, grass, [0.1 0.9; 0.8 0.2]), :Rain) === NEGATIVE
        @test polarity(cpt(rain, grass, [0.5 0.5; 0.5 0.5]), :Rain) === NO_EFFECT
        @test polarity(cpt(rain, grass, [0.9 0.1; 0.2 0.8]), 1) === POSITIVE
        @test_throws ArgumentError polarity(cpt(rain, grass, [0.9 0.1; 0.2 0.8]), :Sun)
        @test_throws ArgumentError polarity(cpt(rain, grass, [0.9 0.1; 0.2 0.8]), 2)
    end

    @testset "three states: dominance, not the mean" begin
        load = FiniteAxis(:Load, [:low, :medium, :high])
        damage = FiniteAxis(:Damage, [:none, :some, :severe])
        # Each row dominates the one above it, so the table is increasing.
        rising = cpt(load, damage, [0.7 0.2 0.1; 0.3 0.4 0.3; 0.1 0.2 0.7])
        @test polarity(rising, :Load) === POSITIVE
        # The mean damage rises with the load, but the middle row does not dominate the
        # first (less chance of "none" and less chance of "severe"), so the direction is
        # not determined. This is the case a signed arrow cannot carry.
        spread = cpt(load, damage, [0.6 0.1 0.3; 0.2 0.7 0.1; 0.1 0.2 0.7])
        @test polarity(spread, :Load) === INDETERMINATE
    end

    @testset "an interaction between two parents is indeterminate" begin
        allele = FiniteAxis(:Allele, [:absent, :present])
        exposure = FiniteAxis(:Exposure, [:low, :high])
        harm = FiniteAxis(:Harm, [:no, :yes])
        table = Array{Float64}(undef, 2, 2, 2)
        table[1, 1, :] = [0.8, 0.2]          # no allele, low exposure
        table[1, 2, :] = [0.4, 0.6]          # no allele, high exposure: worse
        table[2, 1, :] = [0.9, 0.1]          # allele, low exposure
        table[2, 2, :] = [0.95, 0.05]        # allele, high exposure: better
        k = cpt([allele, exposure], harm, table)
        @test polarity(k, :Exposure) === INDETERMINATE
        @test polarity(k, :Allele) === NEGATIVE
    end

    @testset "monotone kernels compose, so polarities multiply along a path" begin
        rain = FiniteAxis(:Rain, [:dry, :wet])
        grass = FiniteAxis(:Grass, [:brown, :green])
        sheep = FiniteAxis(:Sheep, [:few, :many])
        up = cpt(rain, grass, [0.9 0.1; 0.2 0.8])
        down = cpt(rain, grass, [0.1 0.9; 0.8 0.2])
        grass_up = cpt(grass, sheep, [0.7 0.3; 0.25 0.75])
        grass_down = cpt(grass, sheep, [0.3 0.7; 0.75 0.25])
        for (first_link, second_link) in Iterators.product((up, down),
                                                           (grass_up, grass_down))
            composite = compose_kernel(first_link, second_link)
            @test polarity(composite, :Rain) ===
                  polarity(first_link, :Rain) * polarity(second_link, :Grass)
        end
        # A link along which nothing moves kills the path, as the absorbing zero says.
        flat = cpt(grass, sheep, [0.5 0.5; 0.5 0.5])
        @test polarity(compose_kernel(up, flat), :Rain) === NO_EFFECT
    end

    @testset "atol is the slack in each comparison" begin
        rain = FiniteAxis(:Rain, [:dry, :wet])
        grass = FiniteAxis(:Grass, [:brown, :green])
        barely = cpt(rain, grass, [0.5 0.5; 0.5-1e-6 0.5+1e-6])
        @test polarity(barely, :Rain) === POSITIVE
        @test polarity(barely, :Rain; atol=1e-3) === NO_EFFECT
    end
end
