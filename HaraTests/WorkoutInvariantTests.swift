import Testing
@testable import Hara

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
                    case .transition: step.exercise == nil && step.duration == 5
                    }
                })
                #expect(!zip(plan.steps, plan.steps.dropFirst()).contains { pair in
                    pair.0.kind == .recovery && pair.1.kind == .recovery
                })
                // Grammar: E ( [R] [X] E )*. A transition is a doorway, so it
                // always has a movement on the far side of it.
                for (step, next) in zip(plan.steps, plan.steps.dropFirst())
                where step.kind == .transition {
                    #expect(next.kind == .exercise, "a transition led to \(next.kind)")
                }
                #expect(!plan.steps.contains { $0.kind == .transition } || preference.positionTransitions)
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
                let plan = engine.makePlan(preferences: preference, seed: UInt64(seed))
                let identifiers = plan.movements.map(\.id)

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
                // Evaluated over movements, not steps: the two halves of a
                // side plank are the same movement and cannot clash with
                // themselves.
                let exercises = engine.makePlan(preferences: preference, seed: UInt64(seed)).movements
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

                #expect(intervals.allSatisfy { $0.duration <= difficulty.work.upperBound },
                        "An interval exceeds \(difficulty.work.upperBound)s for seed \(seed)")
                #expect(intervals.allSatisfy { $0.duration >= 20 })
            }
        }
    }
}

/// A programme has to be more than a filter on the same session. These are the
/// promises it makes.
@Suite("Session shape")
struct SessionShapeTests {
    private func plan(
        minutes: Int = 12,
        difficulty: WorkoutDifficulty = .balanced,
        seed: UInt64 = 5,
        transitions: Bool = true,
        extraRecovery: Bool = false
    ) -> WorkoutPlan {
        WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(
                durationMinutes: minutes,
                difficulty: difficulty,
                apartmentFriendly: false,
                extraRecovery: extraRecovery,
                positionTransitions: transitions
            ),
            seed: seed
        )
    }

    @Test("The hardest movements are spread through the session, not stacked")
    func hardWorkIsSpreadOut() {
        // Under the old design this was the rests' job: a gap between two
        // demanding movements scored highly and bought itself a recovery. A
        // session that only rests every third or fourth movement cannot pay for
        // that and should not have to — ordering is the cheaper instrument, so
        // this is now a claim about the running order rather than about rest.
        for difficulty in WorkoutDifficulty.allCases {
            for seed in TestSupport.seeds {
                let plan = plan(minutes: 16, difficulty: difficulty, seed: seed)
                let exercises = plan.steps.filter { $0.kind == .exercise }
                let demands = exercises.map { $0.exercise?.intensity ?? 1 }
                guard demands.count > 2 else { continue }
                let mean = demands.reduce(0, +) / Double(demands.count)
                let heavy = demands.map { $0 > mean * 1.12 }

                // Never three demanding movements in a row.
                for index in heavy.indices.dropFirst(2) {
                    #expect(
                        !(heavy[index] && heavy[index - 1] && heavy[index - 2]),
                        "three demanding movements in a row at \(index) for seed \(seed)"
                    )
                }

                // And a demanding pair is the exception, not the shape of the
                // session: the two halves of a held movement are one effort.
                var stacked = 0
                for index in heavy.indices.dropFirst() where heavy[index] && heavy[index - 1] {
                    let sameMovement = exercises[index].exercise?.id == exercises[index - 1].exercise?.id
                        && exercises[index].side != nil
                    if !sameMovement { stacked += 1 }
                }
                #expect(stacked <= 1, "\(stacked) demanding pairs for \(difficulty) seed \(seed)")
            }
        }
    }

    @Test("A recovery is never followed by a placement")
    func recoveryReplacesThePlacement() {
        // An interval carries one thing. A recovery already gives you the time
        // to move, so five more seconds on top only makes the session feel like
        // it is waiting for you.
        for difficulty in WorkoutDifficulty.allCases {
            for seed in TestSupport.seeds {
                let plan = plan(minutes: 14, difficulty: difficulty, seed: seed)
                for (step, next) in zip(plan.steps, plan.steps.dropFirst()) {
                    #expect(
                        !(step.kind == .recovery && next.kind == .transition),
                        "a placement followed a recovery at \(difficulty.title)"
                    )
                }
                // And every interval between two movements carries exactly one.
                var carried = 0
                for step in plan.steps {
                    switch step.kind {
                    case .exercise:
                        #expect(carried <= 1, "an interval carried \(carried) steps")
                        carried = 0
                    case .recovery, .transition:
                        carried += 1
                    }
                }
            }
        }
    }

    @Test("A block runs for as long as the level said it would, and no longer")
    func blocksMatchTheLevelsCadence() {
        // What separates the levels is how many movements run back to back
        // before a break is earned. One over is the most a session may drift,
        // and only because the gap inside a movement held per side cannot take
        // a rest, so the break either side of it shifts by one.
        for difficulty in WorkoutDifficulty.allCases {
            for minutes in [5, 7, 12, 16, 20] {
                for seed in TestSupport.seeds {
                    let plan = plan(minutes: minutes, difficulty: difficulty, seed: seed)
                    let ceiling = difficulty.movementsPerRecovery + 1
                    var run = 0
                    for step in plan.steps {
                        switch step.kind {
                        case .exercise: run += 1
                        case .recovery: run = 0
                        case .transition: break
                        }
                        #expect(
                            run <= ceiling,
                            "\(run) movements in a row at \(difficulty.title), cadence allows \(ceiling)"
                        )
                    }
                }
            }
        }
    }

    @Test("A recovery never runs longer than the level promises")
    func recoveriesHonourTheLevelsCeiling() {
        // The complaint this whole model was rebuilt around: seven minutes at
        // Intense handing out five recoveries of up to thirty-one seconds.
        for difficulty in WorkoutDifficulty.allCases {
            for minutes in [5, 7, 12, 16, 20] {
                for extra in [false, true] {
                    for seed in TestSupport.seeds {
                        let plan = plan(
                            minutes: minutes, difficulty: difficulty, seed: seed, extraRecovery: extra
                        )
                        for rest in plan.steps where rest.kind == .recovery {
                            #expect(
                                difficulty.recovery.contains(rest.duration),
                                "\(rest.duration)s recovery at \(difficulty.title), promised \(difficulty.recovery)"
                            )
                        }
                    }
                }
            }
        }
    }

    @Test("A movement held on one side is performed on both")
    func heldMovementsTrainBothSides() {
        for difficulty in WorkoutDifficulty.allCases {
            for seed in TestSupport.seeds {
                let plan = plan(minutes: 16, difficulty: difficulty, seed: seed)
                let steps = plan.steps.filter { $0.kind == .exercise }

                for (index, step) in steps.enumerated() {
                    guard step.exercise?.sideMode == .heldPerSide else {
                        #expect(step.side == nil, "\(step.title) carries a side it cannot use")
                        continue
                    }
                    #expect(step.side != nil, "\(step.title) was programmed without a side")
                    if step.side == .left {
                        let next = index + 1 < steps.count ? steps[index + 1] : nil
                        #expect(next?.side == .right, "the left half of \(step.title) had no right half")
                        #expect(next?.exercise?.id == step.exercise?.id)
                        #expect(next?.duration == step.duration, "the two sides ran for different times")
                    }
                }
            }
        }
    }

    @Test("A session covers several of the jobs the trunk does")
    func sessionsCoverSeveralPatterns() {
        for difficulty in WorkoutDifficulty.allCases {
            for seed in TestSupport.seeds {
                let patterns = Set(plan(minutes: 14, difficulty: difficulty, seed: seed).movements.map(\.pattern))
                #expect(patterns.count >= 3, "only \(patterns.count) job(s) at \(difficulty.title)")
            }
        }
    }

    @Test("No single job takes over the session")
    func noPatternDominates() {
        for seed in TestSupport.seeds {
            let movements = plan(minutes: 16, seed: seed).movements
            let counts = Dictionary(grouping: movements, by: \.pattern).mapValues(\.count)
            for (pattern, count) in counts {
                let share = Double(count) / Double(movements.count)
                #expect(share <= 0.55, "\(pattern.rawValue) took \(Int(share * 100))% of the session")
            }
        }
    }

    @Test("A repeated movement is spaced, never adjacent")
    func repeatsAreSpaced() {
        // The beginner catalog cannot fill a long session without repeating.
        // Repeating is allowed; repeating back to back is not.
        for minutes in [16, 20] {
            for seed in TestSupport.seeds {
                let movements = plan(minutes: minutes, difficulty: .beginner, seed: seed).movements
                for (index, movement) in movements.enumerated() {
                    let earlier = movements[..<index].lastIndex { $0.id == movement.id }
                    guard let earlier else { continue }
                    #expect(index - earlier >= 3, "\(movement.name) came back after \(index - earlier) slots")
                }
            }
        }
    }

    @Test("Every setting still lands on the requested duration")
    func settingsSurviveEverySetting() {
        for minutes in [5, 8, 12, 16, 20] {
            for difficulty in WorkoutDifficulty.allCases {
                for transitions in [false, true] {
                    let plan = plan(
                        minutes: minutes, difficulty: difficulty, seed: 21, transitions: transitions
                    )
                    #expect(plan.duration == minutes * 60, "\(minutes) min came out at \(plan.duration)s")
                    #expect(plan.steps.allSatisfy { step in
                        step.kind != .exercise || step.duration <= difficulty.work.upperBound
                    })
                    #expect(plan.steps.allSatisfy { step in
                        step.kind != .exercise || step.duration >= 20
                    })
                }
            }
        }
    }

    @Test("A short session prefers movements that pay several groups at once")
    func shortSessionsFavourCompoundWork() {
        func breadth(_ minutes: Int) -> Double {
            let movements = plan(minutes: minutes, seed: 8).movements
            return movements.reduce(0.0) { $0 + Double($1.zones.count) } / Double(movements.count)
        }
        #expect(breadth(6) > breadth(18))
    }
}
