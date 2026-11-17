using Random: Xoshiro
using ResilienceCore: ResilienceCore

@testset "qualitative stability through ResilienceCore" begin
    # Snowshoe hare model A of Dambacher & Ramos-Jiliberto (2007), as in QPress:
    # vegetation and predator self-limited, hare eats vegetation, predator eats hare.
    modelA = causal_loop_diagram([(:V, :V) => NEGATIVE, (:P, :P) => NEGATIVE,
                                  (:V, :H) => POSITIVE, (:H, :V) => NEGATIVE,
                                  (:H, :P) => POSITIVE, (:P, :H) => NEGATIVE])
    fnames = factor_names(modelA)
    idx = Dict(n => i for (i, n) in enumerate(fnames))

    @testset "orientation" begin
        s = SignPattern(modelA; self_regulation=:as_drawn)
        @test s isa ResilienceCore.SignPattern
        @test s.labels == string.(fnames)
        # a link A -> B is the effect of A on B, entry [B, A]
        @test s.S[idx[:H], idx[:V]] == 1
        @test s.S[idx[:V], idx[:H]] == -1
        @test s.S[idx[:P], idx[:H]] == 1
        @test s.S[idx[:H], idx[:P]] == -1
        @test s.S[idx[:V], idx[:P]] == 0
        @test s.S == permutedims(Int8[p == POSITIVE ? 1 : p == NEGATIVE ? -1 : 0
                                      for p in polarity_matrix(modelA)])
        @test s.S[idx[:H], idx[:H]] == 0
    end

    @testset "self-regulation" begin
        @test SignPattern(modelA).S[idx[:H], idx[:H]] == -1               # added
        @test SignPattern(modelA; self_regulation=:as_drawn).S[idx[:H], idx[:H]] == 0
        grow = causal_loop_diagram([(:X, :X) => POSITIVE, (:X, :Y) => POSITIVE])
        @test SignPattern(grow).S[1, 1] == 1                                # a drawn self-link is kept
        @test SignPattern(grow).S[2, 2] == -1
        @test_throws ArgumentError SignPattern(modelA; self_regulation=:none)
    end

    @testset "indeterminate links have unknown sign" begin
        d = causal_loop_diagram([(:A, :B) => INDETERMINATE, (:B, :A) => NEGATIVE])
        s = SignPattern(d)
        i, j = factor_id(d, :B), factor_id(d, :A)
        @test s.unknown[i, j] && s.S[i, j] == 0
        @test count(s.unknown) == 1
        # parallel links of opposite sign sum to INDETERMINATE in the rig
        both = causal_loop_diagram([(:A, :B) => POSITIVE, (:A, :B) => NEGATIVE])
        @test SignPattern(both).unknown[factor_id(both, :B), factor_id(both, :A)]
        # a negative draw of the unknown link makes the 2-loop positive, which can destabilise
        q = quasi_sign_stability(Xoshiro(2), d; samples=4000, self_regulation=:all_negative)
        @test 0.6 < q.fraction < 0.9
    end

    @testset "press analysis reproduces QPress on the snowshoe hare models" begin
        # model A: a press on the vegetation always increases the hare
        pA = press_sign_determinacy(Xoshiro(1), modelA; samples=2000,
                                    self_regulation=:as_drawn)
        @test pA.labels == string.(fnames)
        @test pA.stable == 1
        @test pA.sign[idx[:H], idx[:V]] == 1 && pA.determinacy[idx[:H], idx[:V]] == 1
        @test quasi_sign_stability(Xoshiro(1), modelA; samples=2000,
                                   self_regulation=:as_drawn).fraction == 1
        # model B adds V -> P (+): about 40% of stable systems lose hares (QPress vignette)
        modelB = causal_loop_diagram([(:V, :V) => NEGATIVE, (:P, :P) => NEGATIVE,
                                      (:V, :H) => POSITIVE, (:H, :V) => NEGATIVE,
                                      (:H, :P) => POSITIVE, (:P, :H) => NEGATIVE,
                                      (:V, :P) => POSITIVE])
        pB = press_sign_determinacy(Xoshiro(1), modelB; samples=4000,
                                    self_regulation=:as_drawn)
        jdx = Dict(n => i for (i, n) in enumerate(factor_names(modelB)))
        down = 1 - pB.determinacy[jdx[:H], jdx[:V]]
        @test pB.sign[jdx[:H], jdx[:V]] == 1
        @test 0.3 < down < 0.5
    end

    @testset "defaults and the no-rng methods" begin
        @test quasi_sign_stability(modelA; samples=200) isa NamedTuple
        @test press_sign_determinacy(modelA; samples=200).sign isa Matrix{Int8}
    end

    @testset "no name clashes with ResilienceCore" begin
        shared = intersect(names(CausalLoopDiagrams), names(ResilienceCore))
        @test all(n -> getfield(CausalLoopDiagrams, n) === getfield(ResilienceCore, n),
                  shared)
        @test Set(shared) ⊇
              Set([:SignPattern, :quasi_sign_stability, :press_sign_determinacy])
    end
end
