import Foundation
import Testing
@testable import Hara

/// What happens when the athlete decides they train more — or less — than their
/// abdomen.
///
/// The promise being defended throughout is narrow and easy to break: switching
/// a part of the body off is a *small* instruction. It must remove exactly what
/// has become unreachable and touch nothing else. The tempting implementation —
/// rebuild the preferences from the defaults — passes a "the session is legal"
/// test and quietly throws away a dozen decisions the athlete made.
@Suite("Body areas")
struct BodyAreaTests {
    // MARK: - The model

    @Test("Every muscle group belongs to exactly one area")
    func zonesPartitionCleanly() {
        for zone in MuscleZone.allCases {
            let owners = BodyArea.allCases.filter { $0.zones.contains(zone) }
            #expect(owners.count == 1, "\(zone.rawValue) belongs to \(owners.count) areas")
            #expect(owners.first == zone.area)
        }
        // And the areas between them account for the whole list, so no group can
        // be trained by a movement the athlete has no switch for.
        let covered = BodyArea.allCases.reduce(into: Set<MuscleZone>()) { $0.formUnion($1.zones) }
        #expect(covered == Set(MuscleZone.allCases))
    }

    @Test("Every exercise trains at least one area, and knows which")
    func exercisesCarryTheirAreas() {
        for exercise in ExerciseCatalog.all {
            #expect(!exercise.areas.isEmpty, "\(exercise.id) trains no area")
            #expect(
                exercise.areas == Set(exercise.zones.map(\.area)),
                "\(exercise.id) disagrees with its own zones"
            )
        }
    }

    @Test("Trunk patterns are claimed only by movements that train the trunk")
    func patternsStayHonest() {
        for exercise in ExerciseCatalog.all where exercise.pattern != nil {
            #expect(
                exercise.areas.contains(.core),
                "\(exercise.id) claims a trunk job without training the trunk"
            )
        }
        // And a movement with no trunk job contributes nothing to core coverage
        // rather than contributing noise to it.
        let legDay = TestSupport.record(exercises: ["squat", "calf-raise"])
        #expect(legDay.trainedPatterns.isEmpty)
        #expect(legDay.trainedAreas == [.lowerBody])
    }

    // MARK: - Turning an area off

    @Test("Switching an area off keeps every other setting")
    func disablingAnAreaIsNotAReset() {
        var preferences = TestSupport.preferences(
            durationMinutes: 14,
            difficulty: .advanced,
            focusZones: [.obliques, .glutes],
            apartmentFriendly: false,
            neckFriendly: true,
            extraRecovery: true,
            trainedAreas: [.core, .lowerBody]
        )
        preferences.excludedExerciseIDs = ["classic-crunch", "russian-twist"]

        var narrowed = preferences
        narrowed.trainedAreas = [.core]
        narrowed.reconcile()

        // Gone: the priority that can no longer be programmed.
        #expect(narrowed.focusZones == [.obliques])
        // Kept: everything else, to the letter.
        #expect(narrowed.durationMinutes == 14)
        #expect(narrowed.difficulty == .advanced)
        #expect(narrowed.apartmentFriendly == false)
        #expect(narrowed.neckFriendly == true)
        #expect(narrowed.extraRecovery == true)
        #expect(narrowed.excludedExerciseIDs == ["classic-crunch", "russian-twist"])
    }

    @Test("A focus that empties out falls back to no priority, not to nothing")
    func focusFallsBackWhenItEmpties() {
        var preferences = TestSupport.preferences(
            focusZones: [.glutes, .hamstrings],
            trainedAreas: [.core, .lowerBody]
        )
        preferences.trainedAreas = [.core]
        preferences.reconcile()

        #expect(preferences.focusZones == [.fullCore])
        #expect(preferences.explicitFocus.isEmpty)
    }

    @Test("Something is always trained")
    func areasAreNeverEmpty() {
        var preferences = TestSupport.preferences(trainedAreas: [])
        #expect(preferences.trainedAreas == BodyArea.fallback)

        preferences.trainedAreas = []
        preferences.reconcile()
        #expect(preferences.trainedAreas == BodyArea.fallback)
    }

    /// A store of its own per test, cleaned before use.
    ///
    /// These tests run inside the app's own process, so anything they write to
    /// the shared defaults is the athlete's settings — and before `AppModel`
    /// wrote back to the store it was given, that is exactly what happened: the
    /// simulator booted the app with three body areas switched on because a test
    /// had asked for them.
    @MainActor
    private static func isolatedModel(_ name: String) -> AppModel {
        let defaults = UserDefaults(suiteName: "hara-tests-\(name)") ?? .standard
        defaults.removePersistentDomain(forName: "hara-tests-\(name)")
        return AppModel(defaults: defaults)
    }

    @MainActor
    @Test("The last area standing cannot be switched off")
    func theLastAreaIsRefused() {
        let model = Self.isolatedModel("last-area")
        model.preferences = TestSupport.preferences(trainedAreas: [.core])

        #expect(model.setArea(.core, enabled: false) == false)
        #expect(model.preferences.trainedAreas == [.core])

        #expect(model.setArea(.lowerBody, enabled: true))
        #expect(model.preferences.trainedAreas == [.core, .lowerBody])
        #expect(model.setArea(.core, enabled: false))
        #expect(model.preferences.trainedAreas == [.lowerBody])
    }

    @MainActor
    @Test("Restoring the recommended programme leaves the athlete's body alone")
    func restoringKeepsTheAreas() {
        let model = Self.isolatedModel("restore")
        model.preferences = TestSupport.preferences(
            durationMinutes: 20,
            trainedAreas: [.core, .upperBody, .lowerBody]
        )

        model.restoreRecommendedPlan()

        #expect(model.preferences.durationMinutes == WorkoutPreferences.recommended.durationMinutes)
        #expect(model.preferences.trainedAreas == [.core, .upperBody, .lowerBody])
    }

    // MARK: - Migration

    @Test("Preferences saved before areas existed come back as core training")
    func oldPreferencesDecodeToTheCore() throws {
        let json = """
        {
            "durationMinutes": 12,
            "difficulty": 3,
            "focusZones": ["obliques"],
            "apartmentFriendly": false,
            "neckFriendly": true,
            "extraRecovery": true,
            "positionTransitions": false,
            "adaptiveCoaching": false,
            "excludedExerciseIDs": ["classic-crunch"]
        }
        """
        let decoded = try JSONDecoder().decode(WorkoutPreferences.self, from: Data(json.utf8))

        #expect(decoded.trainedAreas == BodyArea.fallback)
        // Everything the athlete had chosen is still there: a new key must never
        // cost someone their settings.
        #expect(decoded.durationMinutes == 12)
        #expect(decoded.difficulty == .advanced)
        #expect(decoded.focusZones == [.obliques])
        #expect(decoded.apartmentFriendly == false)
        #expect(decoded.neckFriendly == true)
        #expect(decoded.extraRecovery == true)
        #expect(decoded.positionTransitions == false)
        #expect(decoded.adaptiveCoaching == false)
        #expect(decoded.excludedExerciseIDs == ["classic-crunch"])
    }

    @Test("A stored focus outside the stored areas is dropped on the way in")
    func decodingReconciles() throws {
        let json = """
        {
            "durationMinutes": 10,
            "difficulty": 2,
            "trainedAreas": ["core"],
            "focusZones": ["glutes", "obliques"],
            "apartmentFriendly": true,
            "neckFriendly": false,
            "extraRecovery": false
        }
        """
        let decoded = try JSONDecoder().decode(WorkoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.focusZones == [.obliques])
    }

    @Test("Areas survive a round trip")
    func areasRoundTrip() throws {
        let original = TestSupport.preferences(trainedAreas: [.core, .upperBody])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutPreferences.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - What the engine does with them

    /// Every combination someone can actually arrive at.
    static let combinations: [Set<BodyArea>] = [
        [.core], [.upperBody], [.lowerBody],
        [.core, .upperBody], [.core, .lowerBody], [.upperBody, .lowerBody],
        [.core, .upperBody, .lowerBody]
    ]

    @Test("A session never contains work the athlete switched off")
    func sessionsRespectTheAreas() {
        for areas in Self.combinations {
            for difficulty in WorkoutDifficulty.allCases {
                for seed in TestSupport.seeds.prefix(4) {
                    let plan = WorkoutEngine().makePlan(
                        preferences: TestSupport.preferences(
                            durationMinutes: 12,
                            difficulty: difficulty,
                            trainedAreas: areas
                        ),
                        seed: seed
                    )
                    for movement in plan.movements {
                        #expect(
                            movement.areas.isSubset(of: areas),
                            "\(movement.id) trains \(movement.areas) with only \(areas) switched on"
                        )
                    }
                }
            }
        }
    }

    @Test("A session reaches every area the athlete switched on")
    func sessionsCoverTheAreas() {
        // Measured on a session long enough to hold them: a five-minute session
        // is four movements, and promising three areas inside it would be a
        // promise about arithmetic rather than about training.
        for areas in Self.combinations {
            for seed in TestSupport.seeds.prefix(5) {
                let plan = WorkoutEngine().makePlan(
                    preferences: TestSupport.preferences(durationMinutes: 14, trainedAreas: areas),
                    seed: seed
                )
                #expect(
                    plan.areas == areas,
                    "with \(areas) switched on, seed \(seed) trained \(plan.areas)"
                )
            }
        }
    }

    @Test("A whole-body session still trains the trunk properly")
    func wholeBodyKeepsTheCore() {
        for seed in TestSupport.seeds.prefix(5) {
            let plan = WorkoutEngine().makePlan(
                preferences: TestSupport.preferences(
                    durationMinutes: 16,
                    trainedAreas: [.core, .upperBody, .lowerBody]
                ),
                seed: seed
            )
            let patterns = Set(plan.movements.compactMap(\.pattern))
            #expect(patterns.count >= 2, "seed \(seed) covered only \(patterns.count) trunk jobs")
            let core = plan.movements.filter { $0.areas.contains(.core) }
            #expect(core.count >= 2, "seed \(seed) had \(core.count) core movements")
        }
    }

    @Test("A named priority is still followed inside the chosen areas")
    func focusSurvivesTheAreas() {
        for seed in TestSupport.seeds.prefix(5) {
            let plan = WorkoutEngine().makePlan(
                preferences: TestSupport.preferences(
                    durationMinutes: 12,
                    focusZones: [.glutes],
                    trainedAreas: [.core, .lowerBody]
                ),
                seed: seed
            )
            let onFocus = plan.movements.count { $0.zones.contains(.glutes) }
            #expect(onFocus >= 2, "seed \(seed) served the chosen priority \(onFocus) times")
        }
    }

    @Test("The duration promise holds whatever is switched on")
    func durationStillLandsExactly() {
        for areas in Self.combinations {
            for minutes in [5, 7, 12, 20] {
                for seed in TestSupport.seeds.prefix(3) {
                    let plan = WorkoutEngine().makePlan(
                        preferences: TestSupport.preferences(
                            durationMinutes: minutes,
                            trainedAreas: areas
                        ),
                        seed: seed
                    )
                    #expect(
                        plan.duration == minutes * 60,
                        "\(areas) at \(minutes) min produced \(plan.duration)s"
                    )
                }
            }
        }
    }

    @Test("Nothing needs equipment")
    func everythingIsBodyweight() {
        // The whole catalog is meant to be done with a mat and nothing else, so
        // no name may advertise a tool.
        // Not "poids": in French that is the body's own weight as often as it is
        // a dumbbell, and "poids du corps" is exactly what this app is about.
        let equipment = ["haltère", "élastique", "kettlebell", "machine", "step ", "swiss ball"]
        for exercise in ExerciseCatalog.all {
            let text = ([exercise.name, exercise.setup, exercise.instruction] + exercise.tips)
                .joined(separator: " ")
                .lowercased()
            for tool in equipment {
                #expect(!text.contains(tool), "\(exercise.id) mentions \(tool)")
            }
        }
    }

    // MARK: - The rest of the app

    @Test("Playlists appear only when their work is switched on")
    func playlistsFollowTheAreas() {
        let core = WorkoutPlaylist.available(for: [.core])
        #expect(!core.isEmpty)
        #expect(core.allSatisfy { $0.preferences.trainedAreas == [.core] })
        #expect(!core.contains { $0.id == "lower-body" })

        let everything = WorkoutPlaylist.available(for: [.core, .upperBody, .lowerBody])
        #expect(everything.count == WorkoutPlaylist.all.count)
        #expect(everything.contains { $0.id == "full-body" })

        // And every playlist has to build the session it advertises.
        for playlist in WorkoutPlaylist.all {
            let plan = WorkoutEngine().makePlan(preferences: playlist.preferences, seed: 7)
            #expect(
                plan.areas == playlist.preferences.trainedAreas,
                "\(playlist.id) advertises \(playlist.preferences.trainedAreas) and trains \(plan.areas)"
            )
        }
    }

    @Test("The history reports the body, not just the trunk")
    func analyticsSplitByArea() {
        let analytics = WorkoutHistoryAnalytics(calendar: .current)
        let load = analytics.areaLoad(records: [
            TestSupport.record(exercises: ["squat", "reverse-lunge"], activeSeconds: 600),
            TestSupport.record(exercises: ["forearm-plank", "classic-crunch"], activeSeconds: 300)
        ])

        #expect(load.count == 2)
        #expect(load.first?.area == .lowerBody)
        #expect(load.first?.activeMinutes == 10)
        #expect(analytics.areaLoad(records: []).isEmpty)
    }

    @Test("A balanced week means the whole body once there is more than one area")
    func weeklyBalanceFollowsTheAreas() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        let engine = RewardsEngine(calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)) ?? .now
        let records = [
            TestSupport.record(
                exercises: ["forearm-plank", "classic-crunch"],
                at: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                activeSeconds: 400
            )
        ]

        let core = engine.weeklyBalance(records: records, areas: [.core], now: now)
        #expect(core.unit == .corePatterns)
        #expect(core.targetValue == CorePattern.allCases.count)

        let whole = engine.weeklyBalance(
            records: records, areas: [.core, .upperBody, .lowerBody], now: now
        )
        #expect(whole.unit == .bodyAreas)
        #expect(whole.targetValue == 3)
        #expect(whole.currentValue == 1)
    }

    @Test("The coach only names groups the athlete actually trains")
    func coachStaysInsideTheAreas() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        let advisor = CoachAdvisor(calendar: calendar)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)) ?? .now
        let records = (1...4).map { offset in
            TestSupport.record(
                exercises: ["squat", "reverse-lunge", "calf-raise"],
                at: calendar.date(byAdding: .day, value: -offset, to: now) ?? now,
                activeSeconds: 400
            )
        }

        let debt = advisor.neglectedZone(in: records, areas: [.lowerBody], now: now)
        #expect(debt == nil || debt?.zone.area == .lowerBody)

        // With the core switched off, trunk jobs are not something to be behind
        // on: every one of them would be permanently missing.
        let guidance = advisor.guidance(
            records: records,
            preferences: TestSupport.preferences(trainedAreas: [.lowerBody]),
            now: now
        )
        #expect(guidance.underworkedPatterns.isEmpty)

        // With two areas on and only one trained, the other is named.
        let mixed = advisor.guidance(
            records: records,
            preferences: TestSupport.preferences(trainedAreas: [.core, .lowerBody]),
            now: now
        )
        #expect(mixed.underworkedAreas == [.core])
    }

    @Test("The essential groups follow the areas")
    func essentialZonesFollowTheAreas() {
        #expect(WorkoutEngine.essentialZones(for: [.core]) == BodyArea.core.essentialZones)
        #expect(
            WorkoutEngine.essentialZones(for: [.core, .lowerBody])
                == BodyArea.core.essentialZones.union(BodyArea.lowerBody.essentialZones)
        )
        for area in BodyArea.allCases {
            #expect(area.essentialZones.allSatisfy { $0.area == area })
            #expect(!area.essentialZones.isEmpty)
        }
    }

    @Test("Every section of the catalog holds something, and nothing twice")
    func catalogSectionsPartition() {
        for exercise in ExerciseCatalog.all {
            let owners = CatalogSection.all.filter { $0.contains(exercise) }
            #expect(owners.count == 1, "\(exercise.id) lands in \(owners.count) sections")
        }
        let grouped = CatalogSection.grouping(ExerciseCatalog.all)
        #expect(grouped.reduce(0) { $0 + $1.exercises.count } == ExerciseCatalog.all.count)
        #expect(grouped.count == CatalogSection.all.count, "a section of the catalog is empty")
    }
}
