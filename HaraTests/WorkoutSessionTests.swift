import Foundation
import Testing
@testable import Hara

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

    /// Starts a session and waits out its lead-in. Every control is gated on
    /// the session having actually begun, which is correct — and which means a
    /// test that skips the lead-in is testing nothing. The length is cut down
    /// because ten seconds of preview per test is ten seconds of nothing under
    /// test; the lead-in itself has its own case below.
    private func running(_ plan: WorkoutPlan, leadIn: Double = 0.3) async -> WorkoutSession? {
        let session = WorkoutSession(plan: plan, leadIn: leadIn)
        session.start()
        for _ in 0..<60 {
            if session.phase == .running { return session }
            try? await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("the session never started running")
        return nil
    }

    @Test("Pause answers during the lead-in too")
    func pauseWorksWhileCountingDown() async {
        let session = WorkoutSession(plan: plan())
        session.start()
        // The lead-in is a phase of its own; the toggle used to fall through
        // to resume, whose guard rejected it, so the button did nothing.
        try? await Task.sleep(for: .milliseconds(60))
        guard case .preparing = session.phase else {
            Issue.record("the session did not enter its lead-in")
            return
        }

        session.togglePause()
        #expect(session.phase == .paused)
        // The preview stays on screen through the pause rather than blinking
        // away to a session that has not started.
        #expect(session.isPreparing)

        // And it stays paused: a cancelled lead-in must not fire later.
        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(session.phase == .paused)

        // Resuming picks the lead-in back up rather than dropping the athlete
        // straight into the first movement.
        session.resume()
        if case .preparing = session.phase {} else {
            Issue.record("resuming skipped the rest of the lead-in: \(session.phase)")
        }
    }

    @Test("The lead-in previews the session and counts its last seconds out loud")
    func leadInAnnouncesItself() async {
        let recorder = CueRecorder()
        let session = WorkoutSession(plan: plan(), leadIn: 3.4, feedback: recorder)
        #expect(!session.isPreparing)

        session.start()
        #expect(recorder.didPrepare, "the hardware was not warmed up before the first cue")
        #expect(session.isPreparing)
        #expect(session.leadInProgress < 0.2)

        for _ in 0..<60 {
            if session.phase == .running { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(session.phase == .running)
        #expect(!session.isPreparing)
        #expect(
            recorder.moments == [
                .sessionOpening, .countdown(3), .countdown(2), .countdown(1), .movementStarting
            ],
            "\(recorder.moments)"
        )
        // Ten seconds of preview are not ten seconds of training.
        #expect(session.activeSeconds < 0.5, "the lead-in was credited as work")
    }

    @Test("The lead-in can be cut short")
    func leadInCanBeEndedEarly() async {
        let recorder = CueRecorder()
        let session = WorkoutSession(plan: plan(), leadIn: 10, feedback: recorder)
        session.start()
        try? await Task.sleep(for: .milliseconds(120))

        session.beginNow()
        #expect(session.phase == .running)
        #expect(recorder.moments.last == .movementStarting)
        // A preview you cannot leave is a preview you learn to resent, so the
        // skip button answers during it too.
        #expect(session.stepIndex == 0)
    }

    @Test("Every kind of step counts its last three seconds out loud")
    func everyStepKindCountsDown() async {
        // The count-out used to be gated on `.exercise`, so a recovery and the
        // five seconds set aside to change position both ended without warning
        // — and the change of position is the one where being caught out costs
        // the start of the next movement.
        //
        // Built by hand at four seconds a step: the shortest length that still
        // owes a full three-two-one, and the last one is a transition only so
        // the case stays short enough to keep in a suite.
        let steps = [
            WorkoutStep(kind: .exercise, exercise: ExerciseCatalog.byID["forearm-plank"], duration: 4),
            WorkoutStep(kind: .recovery, exercise: nil, duration: 4),
            WorkoutStep(kind: .transition, exercise: nil, duration: 4)
        ]
        let recorder = CueRecorder()
        let session = WorkoutSession(
            plan: WorkoutPlan(preferences: .recommended, steps: steps, estimatedCalories: 20),
            leadIn: 0.2,
            feedback: recorder
        )
        session.start()

        for _ in 0..<180 {
            if session.phase == .completed { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        #expect(session.phase == .completed)

        for second in 1...3 {
            #expect(
                recorder.count(of: .countdown(second)) == 3,
                "\(second) was announced \(recorder.count(of: .countdown(second))) times"
            )
        }
        #expect(recorder.moments.contains(.recoveryStarting))
        #expect(recorder.moments.contains(.positionChange))
        #expect(recorder.moments.last == .sessionComplete)
        // And a lead-in shorter than the count itself does not answer its own
        // opening cue with a count-out on top of it.
        #expect(
            Array(recorder.moments.prefix(2)) == [.sessionOpening, .movementStarting],
            "\(Array(recorder.moments.prefix(4)))"
        )
    }

    @Test("The count-out speaks each second once and never over a step's own cue")
    func countOutRuleHoldsAtEveryLength() {
        // Twelve ticks a second, which is what the clock actually delivers.
        func spoken(over duration: Int) -> [Int] {
            var announcer = WorkoutSession.CountdownAnnouncer()
            var seconds: [Int] = []
            for tick in stride(from: Double(duration), through: 0, by: -1.0 / 12) {
                if let second = announcer.secondToAnnounce(remaining: tick, of: duration) {
                    seconds.append(second)
                }
            }
            return seconds
        }

        #expect(spoken(over: 45) == [3, 2, 1], "a movement")
        #expect(spoken(over: 15) == [3, 2, 1], "a recovery")
        #expect(spoken(over: 5) == [3, 2, 1], "five seconds to change position")
        // Three seconds or fewer and the first count would land on top of the
        // cue that opened the step, so it is dropped rather than doubled.
        #expect(spoken(over: 3) == [2, 1])
        #expect(spoken(over: 2) == [1])
        #expect(spoken(over: 1) == [])
    }

    @Test("A pause before a change of side is announced as one")
    func transitionKnowsItPrecedesASideChange() async {
        let sidePlank = ExerciseCatalog.byID["side-plank"]
        guard let sidePlank else {
            Issue.record("side-plank is missing from the catalog")
            return
        }
        let steps = [
            WorkoutStep(kind: .exercise, exercise: sidePlank, side: .left, duration: 30),
            WorkoutStep(kind: .transition, exercise: nil, duration: 5),
            WorkoutStep(kind: .exercise, exercise: sidePlank, side: .right, duration: 30),
            WorkoutStep(kind: .transition, exercise: nil, duration: 5),
            WorkoutStep(kind: .exercise, exercise: ExerciseCatalog.byID["dead-bug"], duration: 30)
        ]
        guard let session = await running(
            WorkoutPlan(preferences: .recommended, steps: steps, estimatedCalories: 20)
        ) else { return }

        // Standing on the first half, the change is still one step away.
        #expect(session.nextIsSideSwitch)
        session.skip()
        #expect(session.currentStep.kind == .transition)
        #expect(session.nextIsSideSwitch, "the transition did not know what it was for")
        session.skip()
        #expect(session.isSideSwitch)
        #expect(!session.nextIsSideSwitch)
        session.skip()
        #expect(!session.nextIsSideSwitch, "an ordinary transition claimed a change of side")
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
            plan: WorkoutPlan(preferences: .recommended, steps: steps, estimatedCalories: 20),
            leadIn: 0.3
        )
        session.start()
        // Lead-in plus every step, with room to spare.
        try? await Task.sleep(for: .milliseconds(6_000))

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
