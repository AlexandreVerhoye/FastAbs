import Foundation
import Testing
@testable import FastAbs

/// What the app notices between sessions.
///
/// The engine builds one excellent session and has no idea one happened
/// yesterday. Everything here is about the gap between a generator and a coach:
/// remembering, noticing a pattern in the answers, and knowing when to say
/// nothing.
@Suite("Coach")
struct CoachAdvisorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    private func record(
        day: Int,
        difficulty: WorkoutDifficulty = .balanced,
        effort: PerceivedEffort = .unrated,
        exercises: [String] = ["forearm-plank"]
    ) -> WorkoutRecord {
        let plan = WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(difficulty: difficulty),
            seed: 5
        )
        let stored = WorkoutRecord(plan: plan, completedAt: date(day), activeDuration: 420)
        stored.plannedDuration = 420
        stored.difficultyRaw = difficulty.rawValue
        stored.perceivedEffortRaw = effort.rawValue
        stored.exerciseIDs = exercises
        return stored
    }

    @Test("Three easy sessions earn an invitation to step up")
    func repeatedEaseSuggestsHarder() {
        let records = (10...12).map { record(day: $0, effort: .easy) }
        let note = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: TestSupport.preferences(), now: date(13))
            .note

        #expect(note?.kind == .stepUp)
        #expect(note?.suggestedDifficulty == .advanced)
    }

    @Test("Two hard sessions earn permission to ease off")
    func repeatedStruggleSuggestsEasier() {
        let records = [record(day: 11, effort: .hard), record(day: 12, effort: .hard)]
        let note = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: TestSupport.preferences(), now: date(13))
            .note

        #expect(note?.kind == .easeOff)
        #expect(note?.suggestedDifficulty == .beginner)
    }

    @Test("A mixed answer proposes nothing")
    func mixedFeedbackDoesNotMoveTheLevel() {
        // Suggesting a change off one easy session is how an app becomes noise.
        let records = [
            record(day: 10, effort: .easy),
            record(day: 11, effort: .hard),
            record(day: 12, effort: .easy)
        ]
        let note = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: TestSupport.preferences(), now: date(13))
            .note

        #expect(note?.suggestedDifficulty == nil)
    }

    @Test("Rest comes before progress")
    func longStreakAsksForRest() {
        // Six days running outranks every other note, including a step up the
        // athlete has otherwise earned.
        let records = (7...12).map { record(day: $0, effort: .easy) }
        let note = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: TestSupport.preferences(), now: date(12, hour: 20))
            .note

        #expect(note?.kind == .rest)
        #expect(note?.suggestedDifficulty == nil)
    }

    @Test("A week away is met with a smaller ask, not a scolding")
    func timeAwayIsWelcomed() {
        let note = CoachAdvisor(calendar: calendar)
            .guidance(records: [record(day: 1)], preferences: TestSupport.preferences(), now: date(12))
            .note

        #expect(note?.kind == .comeback)
    }

    @Test("An empty history has nothing to say")
    func silenceOnDayOne() {
        let guidance = CoachAdvisor(calendar: calendar)
            .guidance(records: [], preferences: TestSupport.preferences(), now: date(12))

        #expect(guidance.note == nil)
        #expect(guidance.recentMovementIDs.isEmpty)
    }

    @Test("The week's untouched jobs are reported")
    func weeklyGapsAreFound() {
        // Monday 10 August 2026 starts the week; a session of nothing but
        // planks leaves four of the five jobs untouched.
        let records = [record(day: 11, exercises: ["forearm-plank"])]
        let guidance = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: TestSupport.preferences(), now: date(12))

        #expect(!guidance.underworkedPatterns.contains(.antiExtension))
        #expect(guidance.underworkedPatterns.contains(.antiLateralFlexion))
        #expect(guidance.underworkedPatterns.count == 4)
    }

    @Test("Yesterday's movements come back less often")
    func freshnessSteersSelection() {
        // Not banned — repeating a movement is fine. But across many seeds a
        // session that knows what you did yesterday must reach for it less.
        let yesterday = ["forearm-plank", "classic-crunch", "side-plank", "bird-dog", "glute-bridge"]
        let guidance = CoachGuidance(recentMovementIDs: Set(yesterday))
        let engine = WorkoutEngine()

        func repeats(_ guidance: CoachGuidance) -> Int {
            (0..<40).reduce(0) { total, seed in
                let plan = engine.makePlan(
                    preferences: TestSupport.preferences(durationMinutes: 12),
                    seed: UInt64(seed),
                    guidance: guidance
                )
                return total + plan.movements.filter { yesterday.contains($0.id) }.count
            }
        }

        let blind = repeats(.none)
        let aware = repeats(guidance)
        #expect(aware < blind, "guidance changed nothing: \(aware) against \(blind)")
    }

    @Test("A job the week has skipped is reached for")
    func weeklyGapSteersSelection() {
        let engine = WorkoutEngine()

        func lateralCount(_ guidance: CoachGuidance) -> Int {
            (0..<40).reduce(0) { total, seed in
                let plan = engine.makePlan(
                    preferences: TestSupport.preferences(durationMinutes: 12),
                    seed: UInt64(seed),
                    guidance: guidance
                )
                return total + plan.movements.filter { $0.pattern == .antiLateralFlexion }.count
            }
        }

        let blind = lateralCount(.none)
        let aware = lateralCount(CoachGuidance(underworkedPatterns: [.antiLateralFlexion]))
        #expect(aware > blind, "the neglected job was not favoured: \(aware) against \(blind)")
    }

    // MARK: - The prescription

    @Test("Sessions that land easy raise the level on their own")
    func easySessionsRaiseTheLevel() {
        let records = (10...12).map { record(day: $0, effort: .easy) }
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: TestSupport.preferences(), now: date(13))

        #expect(recipe.preferences.difficulty == .advanced)
        #expect(recipe.isAdapted)
        #expect(recipe.rationale.contains { $0.contains("faciles") })
    }

    @Test("Sessions that land hard lower it")
    func hardSessionsLowerTheLevel() {
        let records = [record(day: 11, effort: .hard), record(day: 12, effort: .hard)]
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: TestSupport.preferences(), now: date(13))

        #expect(recipe.preferences.difficulty == .beginner)
    }

    @Test("The adaptation never runs away from what was chosen")
    func adaptationStaysWithinOneStep() {
        // Ten easy sessions must not walk the athlete from beginner to athlete.
        let records = (3...12).map { record(day: $0, difficulty: .beginner, effort: .easy) }
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(
                records: records,
                base: TestSupport.preferences(difficulty: .beginner),
                now: date(13)
            )

        #expect(recipe.preferences.difficulty == .balanced)
    }

    @Test("A session abandoned twice buys a shorter one")
    func abandonedSessionsShortenTheDay() {
        let records = (11...12).map { day -> WorkoutRecord in
            let stored = record(day: day)
            stored.wasCompleted = false
            return stored
        }
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(
                records: records,
                base: TestSupport.preferences(durationMinutes: 12),
                now: date(13)
            )

        #expect(recipe.preferences.durationMinutes == 9)
        #expect(recipe.rationale.contains { $0.contains("abandonnée") })
    }

    @Test("The group that has waited longest is put first")
    func theNeglectedZoneIsPrioritised() {
        // Nothing but planks for a week leaves the upper abs untouched.
        let records = (6...12).map { record(day: $0, exercises: ["forearm-plank"]) }
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: TestSupport.preferences(), now: date(13))

        #expect(recipe.preferences.focusZones != [.fullCore])
        #expect(recipe.rationale.contains { $0.contains("priorité") })
    }

    @Test("A zone the athlete chose themselves is left alone")
    func explicitFocusIsAnInstruction() {
        // An explicit choice is an instruction, not a hint the coach may
        // improve on.
        let records = (6...12).map { record(day: $0, exercises: ["forearm-plank"]) }
        let base = TestSupport.preferences(focusZones: [.lowerAbs])
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: base, now: date(13))

        #expect(recipe.preferences.focusZones == [.lowerAbs])
    }

    @Test("Switching the coach off follows the settings to the letter")
    func adaptationCanBeRefused() {
        let records = (10...12).map { record(day: $0, effort: .easy) }
        let base = TestSupport.preferences(adaptiveCoaching: false)
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: base, now: date(13))

        #expect(recipe.preferences == base)
        #expect(!recipe.isAdapted)
    }

    @Test("Nothing to go on means nothing is changed")
    func aFreshStartIsNotAdapted() {
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: [], base: TestSupport.preferences(), now: date(13))

        #expect(recipe.preferences == TestSupport.preferences())
        #expect(!recipe.isAdapted)
    }

    @Test("Every adaptation says why")
    func adaptationsAreAlwaysExplained() {
        // An adaptation the athlete cannot see is indistinguishable from a bug.
        for records in [
            (10...12).map { record(day: $0, effort: .easy) },
            [record(day: 11, effort: .hard), record(day: 12, effort: .hard)],
            (6...12).map { record(day: $0, exercises: ["forearm-plank"]) }
        ] {
            let base = TestSupport.preferences()
            let recipe = CoachAdvisor(calendar: calendar)
                .recipe(records: records, base: base, now: date(13))
            let changed = recipe.preferences != base
            #expect(changed == recipe.isAdapted, "an adjustment went unexplained")
        }
    }

    @Test("Guidance never breaks the session's own promises")
    func guidedSessionsStayValid() {
        let guidance = CoachGuidance(
            recentMovementIDs: Set(ExerciseCatalog.all.prefix(20).map(\.id)),
            underworkedPatterns: [.antiLateralFlexion, .hipExtension]
        )
        for seed in TestSupport.seeds {
            let plan = WorkoutEngine().makePlan(
                preferences: TestSupport.preferences(durationMinutes: 12),
                seed: seed,
                guidance: guidance
            )
            #expect(plan.duration == 720)
            #expect(plan.steps.first?.kind == .exercise)
            #expect(plan.steps.last?.kind == .exercise)
            let ids = plan.movements.map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }
}
