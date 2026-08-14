import Testing
@testable import FastAbs

@Suite("Generated workout invariants")
struct WorkoutInvariantTests {
    @Test("Every step is valid and recoveries are explicit")
    func stepsAreStructurallyValid() {
        let engine = WorkoutEngine()
        let preferences: [WorkoutPreferences] = [
            TestSupport.preferences(difficulty: .beginner),
            TestSupport.preferences(difficulty: .balanced, extraRecovery: true),
            TestSupport.preferences(
                durationMinutes: 15,
                difficulty: .advanced,
                apartmentFriendly: false
            ),
            TestSupport.preferences(
                durationMinutes: 30,
                difficulty: .athlete,
                focusZones: [.lowerAbs, .obliques],
                apartmentFriendly: false
            )
        ]

        for preference in preferences {
            for seed in TestSupport.seeds {
                let plan = engine.makePlan(preferences: preference, seed: seed)

                #expect(plan.steps.first?.kind == .exercise)
                #expect(plan.steps.last?.kind == .exercise)
                #expect(plan.steps.allSatisfy { $0.duration > 0 })
                #expect(plan.steps.allSatisfy { step in
                    switch step.kind {
                    case .exercise: step.exercise != nil
                    case .recovery: step.exercise == nil
                    }
                })
                #expect(!zip(plan.steps, plan.steps.dropFirst()).contains { pair in
                    pair.0.kind == .recovery && pair.1.kind == .recovery
                })
                #expect(plan.exerciseCount > 0)
                #expect(plan.estimatedCalories >= 12)
            }
        }
    }

    @Test("A daily workout does not repeat an exercise")
    func dailyWorkoutHasNoDuplicateExercise() {
        let engine = WorkoutEngine()
        let preferences = [
            TestSupport.preferences(difficulty: .beginner),
            TestSupport.preferences(difficulty: .balanced),
            TestSupport.preferences(
                difficulty: .advanced,
                focusZones: [.obliques],
                apartmentFriendly: false
            ),
            TestSupport.preferences(
                difficulty: .athlete,
                focusZones: [.lowerAbs],
                apartmentFriendly: false
            )
        ]

        for preference in preferences {
            for seed in 0..<64 {
                let identifiers = engine.makePlan(preferences: preference, seed: UInt64(seed))
                    .steps.compactMap(\.exercise?.id)

                #expect(Set(identifiers).count == identifiers.count,
                        "Duplicate exercise for seed \(seed), difficulty \(preference.difficulty.title)")
            }
        }
    }

    @Test("Adjacent exercises use different movement families")
    func adjacentFamiliesDiffer() {
        let engine = WorkoutEngine()

        for difficulty in WorkoutDifficulty.allCases {
            let preference = TestSupport.preferences(
                durationMinutes: 12,
                difficulty: difficulty,
                apartmentFriendly: false
            )

            for seed in 0..<64 {
                let exercises = engine.makePlan(preferences: preference, seed: UInt64(seed))
                    .steps.compactMap(\.exercise)
                let repeatedFamily = zip(exercises, exercises.dropFirst()).first { pair in
                    pair.0.family == pair.1.family
                }

                #expect(repeatedFamily == nil,
                        "Consecutive \(repeatedFamily?.0.family.rawValue ?? "unknown") exercises for seed \(seed), difficulty \(difficulty.title)")
            }
        }
    }

    @Test("Every explicit focus is represented by multiple exercises")
    func explicitFocusIsRepresented() {
        let engine = WorkoutEngine()
        let zones: [MuscleZone] = [.upperAbs, .lowerAbs, .obliques, .deepCore, .lowerBack]

        for zone in zones {
            let preference = TestSupport.preferences(
                durationMinutes: 7,
                difficulty: .balanced,
                focusZones: [zone],
                apartmentFriendly: false
            )

            for seed in 0..<32 {
                let focusedExercises = engine.makePlan(preferences: preference, seed: UInt64(seed))
                    .steps.compactMap(\.exercise)
                    .count { $0.zones.contains(zone) }

                #expect(focusedExercises >= 2,
                        "Only \(focusedExercises) \(zone.rawValue) exercises for seed \(seed)")
            }
        }
    }

    @Test("The recommended workout covers the complete core")
    func recommendedWorkoutCoversCore() {
        let engine = WorkoutEngine()
        let requiredZones: Set<MuscleZone> = [.upperAbs, .lowerAbs, .obliques, .deepCore]

        for seed in 0..<64 {
            let coveredZones = engine.makePlan(preferences: .recommended, seed: UInt64(seed))
                .steps.compactMap(\.exercise)
                .reduce(into: Set<MuscleZone>()) { $0.formUnion($1.zones) }

            #expect(requiredZones.isSubset(of: coveredZones),
                    "Missing \(requiredZones.subtracting(coveredZones).map(\.rawValue).sorted()) for seed \(seed)")
        }
    }

    @Test("Every selected zone is represented when several focuses are combined")
    func combinedFocusesAreAllRepresented() {
        let engine = WorkoutEngine()
        let focusSets: [Set<MuscleZone>] = [
            [.upperAbs, .lowerAbs],
            [.obliques, .deepCore],
            [.lowerBack, .upperAbs]
        ]

        for focuses in focusSets {
            let preference = TestSupport.preferences(
                durationMinutes: 10,
                difficulty: .balanced,
                focusZones: focuses,
                apartmentFriendly: false
            )

            for seed in 0..<64 {
                let coveredZones = engine.makePlan(preferences: preference, seed: UInt64(seed))
                    .steps.compactMap(\.exercise)
                    .reduce(into: Set<MuscleZone>()) { $0.formUnion($1.zones) }

                #expect(focuses.isSubset(of: coveredZones),
                        "Missing \(focuses.subtracting(coveredZones).map(\.rawValue).sorted()) for seed \(seed)")
            }
        }
    }

    @Test("Exercise intervals stay inside their difficulty ceiling")
    func workIntervalsRespectDifficultyCeiling() {
        let engine = WorkoutEngine()

        for difficulty in WorkoutDifficulty.allCases {
            let preference = TestSupport.preferences(
                durationMinutes: 7,
                difficulty: difficulty,
                extraRecovery: true
            )

            for seed in 0..<64 {
                let intervals = engine.makePlan(preferences: preference, seed: UInt64(seed))
                    .steps.filter { $0.kind == .exercise }

                #expect(intervals.allSatisfy { $0.duration <= difficulty.interval.upperBound },
                        "An interval exceeds \(difficulty.interval.upperBound)s for seed \(seed)")
                #expect(intervals.allSatisfy { $0.duration >= 20 })
            }
        }
    }
}
