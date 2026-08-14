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

/// A programme has to be more than a filter on the same session. These are the
/// promises it makes.
@Suite("Training programmes")
struct TrainingProgrammeTests {
    private func plan(_ programme: TrainingProgramme, minutes: Int = 12, seed: UInt64 = 7) -> WorkoutPlan {
        WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(durationMinutes: minutes, programme: programme),
            seed: seed
        )
    }

    @Test("A programme only draws from the body it is about")
    func programmesStayInTheirRegion() {
        for programme in TrainingProgramme.allCases {
            for seed in TestSupport.seeds {
                for exercise in plan(programme, seed: seed).steps.compactMap(\.exercise) {
                    #expect(
                        exercise.zones.contains { programme.regions.contains($0.region) },
                        "\(programme.rawValue) picked \(exercise.id), which trains nothing it covers"
                    )
                }
            }
        }
    }

    @Test("A full session covers everything its programme promises")
    func programmesCoverTheirEssentials() {
        // The point of a programme: you are owed every group it names, not a
        // random draw that happens to skip your hamstrings.
        for programme in TrainingProgramme.allCases {
            for seed in TestSupport.seeds.prefix(5) {
                let covered = plan(programme, minutes: 15, seed: seed)
                    .steps
                    .compactMap(\.exercise)
                    .reduce(into: Set<MuscleZone>()) { $0.formUnion($1.zones) }

                let missing = Set(programme.essentialZones).subtracting(covered)
                #expect(
                    missing.isEmpty,
                    "\(programme.rawValue) at seed \(seed) never trains \(missing.map(\.rawValue).sorted())"
                )
            }
        }
    }

    @Test("Whole-body work alternates areas instead of stacking them")
    func fullBodyAlternatesAreas() {
        func area(_ exercise: Exercise) -> BodyRegion {
            exercise.zones.map(\.region).first { $0 != .core } ?? .core
        }

        for seed in TestSupport.seeds.prefix(6) {
            let exercises = plan(.fullBody, minutes: 15, seed: seed).steps.compactMap(\.exercise)
            guard exercises.count > 3 else { continue }

            var runs = 0
            for index in exercises.indices.dropFirst() where area(exercises[index]) == area(exercises[index - 1]) {
                runs += 1
            }
            #expect(
                Double(runs) / Double(exercises.count - 1) < 0.5,
                "seed \(seed): \(runs) of \(exercises.count - 1) transitions stay in the same area"
            )
        }
    }

    @Test("Recovery follows effort rather than being handed out evenly")
    func recoveryFollowsEffort() {
        // A set of squats and a dead bug do not leave you in the same state.
        for seed in TestSupport.seeds.prefix(6) {
            let steps = plan(.fullBody, minutes: 16, seed: seed).steps
            var pairs: [(intensity: Double, rest: Int)] = []
            for (index, step) in steps.enumerated() where step.kind == .recovery {
                guard let previous = steps[..<index].last(where: { $0.kind == .exercise })?.exercise else { continue }
                pairs.append((previous.intensity, step.duration))
            }
            guard pairs.count > 2, Set(pairs.map(\.intensity)).count > 1 else { continue }

            let hardest = pairs.max { $0.intensity < $1.intensity }
            let easiest = pairs.min { $0.intensity < $1.intensity }
            #expect(
                (hardest?.rest ?? 0) >= (easiest?.rest ?? 0),
                "seed \(seed): the hardest exercise earns no more rest than the easiest"
            )
        }
    }

    @Test("Adapting is not just making the session longer")
    func shortSessionsFavourCompoundWork() {
        // With few slots, movements that pay several muscles at once have to win.
        var shortBreadth = 0.0
        var longBreadth = 0.0

        for seed in TestSupport.seeds.prefix(6) {
            let short = plan(.fullBody, minutes: 6, seed: seed).steps.compactMap(\.exercise)
            let long = plan(.fullBody, minutes: 18, seed: seed).steps.compactMap(\.exercise)
            shortBreadth += short.map { Double($0.zones.count) }.reduce(0, +) / Double(max(short.count, 1))
            longBreadth += long.map { Double($0.zones.count) }.reduce(0, +) / Double(max(long.count, 1))
        }

        #expect(
            shortBreadth > longBreadth,
            "short sessions (\(shortBreadth)) are no more compound than long ones (\(longBreadth))"
        )
    }

    @Test("Duration and difficulty still hold whatever the programme")
    func settingsSurviveTheProgramme() {
        for programme in TrainingProgramme.allCases {
            for minutes in [5, 9, 14, 20] {
                for difficulty in WorkoutDifficulty.allCases {
                    let preferences = TestSupport.preferences(
                        durationMinutes: minutes,
                        difficulty: difficulty,
                        programme: programme
                    )
                    let plan = WorkoutEngine().makePlan(preferences: preferences, seed: 11)

                    #expect(
                        abs(plan.duration - minutes * 60) <= 1,
                        "\(programme.rawValue) at \(minutes) min lands on \(plan.duration)s"
                    )
                    for step in plan.steps where step.kind == .exercise {
                        #expect(
                            step.duration <= difficulty.interval.upperBound,
                            "\(programme.rawValue) exceeds the \(difficulty.title) interval"
                        )
                    }
                }
            }
        }
    }
}
