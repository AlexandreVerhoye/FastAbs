import Testing
@testable import FastAbs

@Suite("Workout engine")
struct WorkoutEngineTests {
    @Test("A seed reproduces the same workout")
    func seedIsDeterministic() {
        let engine = WorkoutEngine()
        let preferences = TestSupport.preferences(
            durationMinutes: 12,
            difficulty: .advanced,
            focusZones: [.lowerAbs, .obliques],
            apartmentFriendly: false,
            neckFriendly: true,
            extraRecovery: true
        )

        for seed in TestSupport.seeds {
            let first = engine.makePlan(preferences: preferences, seed: seed)
            let second = engine.makePlan(preferences: preferences, seed: seed)

            #expect(TestSupport.signature(of: first) == TestSupport.signature(of: second),
                    "Plan changed for seed \(seed)")
            #expect(first.estimatedCalories == second.estimatedCalories)
        }
    }

    @Test("Different seeds create meaningful daily variation")
    func seedsCreateVariation() {
        let engine = WorkoutEngine()
        let preferences = TestSupport.preferences(durationMinutes: 10)
        let signatures = Set((0..<20).map { seed in
            TestSupport.signature(
                of: engine.makePlan(preferences: preferences, seed: UInt64(seed))
            ).joined(separator: "|")
        })

        #expect(signatures.count >= 10)
    }

    @Test("The requested duration is exact and clamped to supported limits")
    func durationIsExactAndClamped() {
        let engine = WorkoutEngine()
        let durations = [1: 300, 5: 300, 7: 420, 12: 720, 30: 1_800, 45: 1_800]

        for (minutes, expectedSeconds) in durations {
            for seed in TestSupport.seeds {
                let plan = engine.makePlan(
                    preferences: TestSupport.preferences(durationMinutes: minutes),
                    seed: seed
                )
                #expect(plan.duration == expectedSeconds,
                        "Unexpected duration for \(minutes) min and seed \(seed)")
            }
        }
    }

    @Test("The generated plan preserves its preferences")
    func planPreservesPreferences() {
        let preferences = TestSupport.preferences(
            durationMinutes: 15,
            difficulty: .athlete,
            focusZones: [.upperAbs, .obliques],
            apartmentFriendly: false,
            neckFriendly: true,
            extraRecovery: true
        )

        let plan = WorkoutEngine().makePlan(preferences: preferences, seed: 42)

        #expect(plan.preferences == preferences)
    }

    @Test("Difficulty, apartment and neck constraints are respected")
    func builtInCatalogConstraintsAreRespected() {
        let engine = WorkoutEngine()

        for difficulty in WorkoutDifficulty.allCases {
            let preferences = TestSupport.preferences(
                durationMinutes: 12,
                difficulty: difficulty,
                apartmentFriendly: true,
                neckFriendly: true
            )

            for seed in TestSupport.seeds {
                let exercises = engine.makePlan(preferences: preferences, seed: seed)
                    .steps.compactMap(\.exercise)

                #expect(exercises.allSatisfy { $0.minimumDifficulty <= difficulty },
                        "Difficulty violated for seed \(seed)")
                #expect(exercises.allSatisfy { $0.impact == .quiet },
                        "Apartment mode violated for seed \(seed)")
                #expect(exercises.allSatisfy { $0.neckFriendly },
                        "Neck-friendly mode violated for seed \(seed)")
            }
        }
    }

    @Test("Safety filters remain hard constraints with a small catalog")
    func smallCatalogDoesNotDisableSafetyFilters() {
        let catalog = [
            TestSupport.exercise(id: "safe"),
            TestSupport.exercise(id: "jump-1", impact: .dynamic),
            TestSupport.exercise(id: "jump-2", impact: .dynamic),
            TestSupport.exercise(id: "jump-3", impact: .dynamic),
            TestSupport.exercise(id: "neck-1", neckFriendly: false),
            TestSupport.exercise(id: "neck-2", neckFriendly: false)
        ]
        let preferences = TestSupport.preferences(
            durationMinutes: 5,
            apartmentFriendly: true,
            neckFriendly: true
        )

        for seed in TestSupport.seeds {
            let exercises = WorkoutEngine(catalog: catalog)
                .makePlan(preferences: preferences, seed: seed)
                .steps.compactMap(\.exercise)

            #expect(exercises.allSatisfy { $0.impact == .quiet && $0.neckFriendly },
                    "A safety constraint was relaxed for seed \(seed)")
        }
    }

    @Test("An incompatible catalog never produces an unsafe fallback")
    func incompatibleCatalogUsesSafeFallback() {
        let incompatible = TestSupport.exercise(
            id: "unsafe-only",
            impact: .dynamic,
            neckFriendly: false
        )
        let preferences = TestSupport.preferences(
            durationMinutes: 5,
            apartmentFriendly: true,
            neckFriendly: true
        )

        let exercises = WorkoutEngine(catalog: [incompatible])
            .makePlan(preferences: preferences, seed: 42)
            .steps.compactMap(\.exercise)

        #expect(!exercises.isEmpty)
        #expect(exercises.allSatisfy { $0.impact == .quiet && $0.neckFriendly })
    }

    @Test("Recovery spends exactly the budget the settings ask for")
    func recoveryDurationMatchesPreferences() {
        // Individual rests now follow the effort that earned them, so the
        // promise is about the total rather than every rest being identical.
        for difficulty in WorkoutDifficulty.allCases {
            for extraRecovery in [false, true] {
                let preferences = TestSupport.preferences(
                    durationMinutes: 14,
                    difficulty: difficulty,
                    extraRecovery: extraRecovery
                )
                let plan = WorkoutEngine().makePlan(preferences: preferences, seed: 3)
                let recoveries = plan.steps.filter { $0.kind == .recovery }
                guard !recoveries.isEmpty else { continue }

                let expected = (difficulty.rest + (extraRecovery ? 5 : 0)) * recoveries.count
                let total = recoveries.reduce(0) { $0 + $1.duration }
                #expect(total == expected, "budgeted \(expected)s of rest but spent \(total)s")
                #expect(recoveries.allSatisfy { $0.duration >= 6 }, "a rest was cut to nothing")
            }
        }
    }

    @Test("Higher difficulties select harder movements, not only longer intervals")
    func difficultyChangesExerciseSelection() {
        let engine = WorkoutEngine()
        var harderSelections = 0

        for seed in TestSupport.seeds {
            let beginner = engine.makePlan(
                preferences: TestSupport.preferences(
                    durationMinutes: 10,
                    difficulty: .beginner,
                    apartmentFriendly: false
                ),
                seed: seed
            )
            let athlete = engine.makePlan(
                preferences: TestSupport.preferences(
                    durationMinutes: 10,
                    difficulty: .athlete,
                    apartmentFriendly: false
                ),
                seed: seed
            )

            #expect(beginner.steps.compactMap(\.exercise).allSatisfy {
                $0.minimumDifficulty == .beginner
            })
            if athlete.steps.compactMap(\.exercise).contains(where: {
                $0.minimumDifficulty >= .advanced
            }) {
                harderSelections += 1
            }
        }

        #expect(harderSelections == TestSupport.seeds.count)
    }
}
