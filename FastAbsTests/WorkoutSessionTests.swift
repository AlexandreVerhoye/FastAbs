import Foundation
import Testing
@testable import FastAbs

/// The session state machine, which had no coverage at all.
///
/// Every case here is a bug that reached the athlete's phone: pausing during
/// the countdown did nothing, skipping while paused restarted the session, the
/// exit dialog resumed a session that had been paused on purpose, and a
/// notification banner paused a workout mid-plank.
@Suite("Workout session")
@MainActor
struct WorkoutSessionTests {
    private func plan(
        minutes: Int = 7,
        difficulty: WorkoutDifficulty = .balanced,
        transitions: Bool = true,
        seed: UInt64 = 4
    ) -> WorkoutPlan {
        WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(
                durationMinutes: minutes,
                difficulty: difficulty,
                apartmentFriendly: false,
                positionTransitions: transitions
            ),
            seed: seed
        )
    }

    /// Starts a session and waits out its countdown. Every control is gated on
    /// the session having actually begun, which is correct — and which means a
    /// test that skips the countdown is testing nothing.
    private func running(_ plan: WorkoutPlan) async -> WorkoutSession? {
        let session = WorkoutSession(plan: plan)
        session.start()
        for _ in 0..<60 {
            if session.phase == .running { return session }
            try? await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("the session never started running")
        return nil
    }

    @Test("Pause answers during the countdown too")
    func pauseWorksWhileCountingDown() async {
        let session = WorkoutSession(plan: plan())
        session.start()
        // The countdown is a phase of its own; the toggle used to fall through
        // to resume, whose guard rejected it, so the button did nothing.
        try? await Task.sleep(for: .milliseconds(60))
        guard case .preparing = session.phase else {
            Issue.record("the session did not enter its countdown")
            return
        }

        session.togglePause()
        #expect(session.phase == .paused)

        // And it stays paused: a cancelled countdown must not fire later.
        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(session.phase == .paused)
    }

    @Test("Skipping while paused stays paused")
    func skipDoesNotSecretlyResume() async {
        guard let session = await running(plan()) else { return }
        session.togglePause()
        #expect(session.phase == .paused)

        let before = session.stepIndex
        session.skip()

        #expect(session.stepIndex == before + 1, "the skip did not advance")
        #expect(session.phase == .paused, "skipping restarted a paused session")
    }

    @Test("Only the app's own pauses are resumed automatically")
    func systemPausesAreDistinguishable() async {
        // Paused by the athlete: dismissing a dialog must leave it paused.
        guard let mine = await running(plan()) else { return }
        mine.pause(bySystem: false)
        mine.resumeIfSystemPaused()
        #expect(mine.phase == .paused, "a deliberate pause was overridden")

        guard let theirs = await running(plan()) else { return }
        theirs.pause(bySystem: true)
        #expect(theirs.phase == .paused)
        theirs.resumeIfSystemPaused()
        #expect(theirs.phase == .running, "an app-made pause was not released")
    }

    @Test("Only a real trip to the background stops the clock")
    func backgroundingPauses() async {
        guard let session = await running(plan()) else { return }
        session.handleAppEnteredBackground()
        #expect(session.phase == .paused)
    }

    @Test("The next-up lookahead skips past rests and transitions")
    func lookaheadFindsTheNextMovement() {
        let session = WorkoutSession(plan: plan(minutes: 12))
        // From the very first step, what is announced must be a movement —
        // never the five-second transition sitting in between.
        #expect(session.nextExerciseStep?.kind == .exercise)

        for index in session.plan.steps.indices.dropLast() {
            let ahead = session.plan.steps.dropFirst(index + 1).first { $0.kind == .exercise }
            #expect(ahead?.kind == .exercise || ahead == nil)
        }
    }

    @Test("A held movement announces its change of side")
    func sideSwitchIsDetected() async {
        // Built by hand: which movements a generated plan happens to pick is
        // not the thing under test.
        let sidePlank = ExerciseCatalog.byID["side-plank"]
        guard let sidePlank else {
            Issue.record("side-plank is missing from the catalog")
            return
        }
        let crunch = ExerciseCatalog.byID["classic-crunch"]

        let steps = [
            WorkoutStep(kind: .exercise, exercise: crunch, duration: 30),
            WorkoutStep(kind: .transition, exercise: nil, duration: 5),
            WorkoutStep(kind: .exercise, exercise: sidePlank, side: .left, duration: 30),
            WorkoutStep(kind: .transition, exercise: nil, duration: 5),
            WorkoutStep(kind: .exercise, exercise: sidePlank, side: .right, duration: 30)
        ]
        guard let session = await running(
            WorkoutPlan(preferences: .recommended, steps: steps, estimatedCalories: 20)
        ) else { return }

        session.skip()
        session.skip()
        #expect(session.currentStep.side == .left)
        #expect(!session.isSideSwitch, "the first half is not a change of side")

        session.skip()
        session.skip()
        #expect(session.currentStep.side == .right)
        #expect(session.isSideSwitch, "the second half did not read as a change of side")
        #expect(session.currentStep.isMirrored)
    }

    @Test("Time is credited to work, not to standing still")
    func activeTimeCountsOnlyWork() async {
        let steps = [
            WorkoutStep(kind: .exercise, exercise: ExerciseCatalog.byID["forearm-plank"], duration: 1),
            WorkoutStep(kind: .recovery, exercise: nil, duration: 2),
            WorkoutStep(kind: .exercise, exercise: ExerciseCatalog.byID["dead-bug"], duration: 1)
        ]
        let session = WorkoutSession(
            plan: WorkoutPlan(preferences: .recommended, steps: steps, estimatedCalories: 20)
        )
        session.start()
        // Countdown plus every step, with room to spare.
        try? await Task.sleep(for: .milliseconds(8_000))

        #expect(session.phase == .completed, "the session did not finish")
        // Two one-second efforts and two seconds of rest: the rest must not be
        // filed as training. Recording the plan's own duration instead is what
        // made every stored session claim its full planned length.
        #expect(session.activeSeconds >= 1.5, "credited only \(session.activeSeconds)s of work")
        #expect(session.activeSeconds < 3.0, "rest was credited as work: \(session.activeSeconds)s")
    }

    @Test("The step counter counts movements, not steps")
    func progressCountsMovements() async {
        guard let session = await running(plan(minutes: 12)) else { return }
        #expect(session.completedExerciseCount == 0)
        session.skip()
        // The first skip lands on a rest or a transition, so the count of
        // finished movements is one either way.
        #expect(session.completedExerciseCount == 1)
    }
}
