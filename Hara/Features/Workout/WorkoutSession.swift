import Foundation
import Observation

@MainActor
@Observable
final class WorkoutSession {
    enum Phase: Equatable {
        case ready
        /// The lead-in, carrying the whole second on show.
        case preparing(Int)
        case running
        case paused
        case completed
        case abandoned

        var isPaused: Bool { self == .paused }
        /// Counting down or working — anything that is spending the athlete's
        /// time and can therefore be interrupted.
        var isLive: Bool {
            switch self {
            case .running, .paused, .preparing: true
            case .ready, .completed, .abandoned: false
            }
        }

        /// Whether the deadline clock should be turning. The lead-in runs on
        /// the same clock as the session so it cannot drift either.
        var isTicking: Bool {
            switch self {
            case .running, .preparing: true
            default: false
            }
        }
    }

    /// Decides when the last three seconds are announced.
    ///
    /// Lifted out of the ticker because the rule is the part that was wrong.
    /// It only ever ran on movements, so a recovery and a change of position
    /// each ended without warning — and the change of position is the one step
    /// where being caught out costs the athlete the start of the next
    /// movement. It also has to survive steps shorter than the count itself,
    /// where the third second would otherwise land on top of the cue that
    /// opened the step.
    struct CountdownAnnouncer {
        private var lastAnnounced: Int?

        mutating func reset() { lastAnnounced = nil }

        mutating func secondToAnnounce(remaining: Double, of duration: Int) -> Int? {
            let second = Int(ceil(remaining))
            guard (1...3).contains(second) else {
                if second > 3 { lastAnnounced = nil }
                return nil
            }
            guard second < duration, second != lastAnnounced else { return nil }
            lastAnnounced = second
            return second
        }
    }

    /// How long the preview runs before the first movement.
    ///
    /// Three seconds was only ever enough to be caught standing up. Ten is what
    /// it takes to put the phone down, find the mat and get into position — and
    /// it is long enough to be worth spending on what is actually coming.
    static let defaultLeadIn: Double = 10

    let plan: WorkoutPlan
    let leadInDuration: Double
    private(set) var phase: Phase = .ready
    private(set) var stepIndex = 0
    private(set) var secondsRemaining: Double = 0
    private(set) var leadInRemaining: Double = 0
    /// Time actually spent working, which is what gets recorded. Reading the
    /// plan's own duration instead meant every session was filed at its
    /// planned length, rests included, whatever the athlete really did.
    private(set) var activeSeconds: Double = 0

    @ObservationIgnored private let feedback: any WorkoutMomentReceiver
    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Set when the app itself paused the session, so resuming can tell the
    /// difference between "the athlete pressed pause" and "a sheet appeared".
    @ObservationIgnored private var pausedBySystem = false
    /// Which clock was stopped, so resuming picks the same one back up rather
    /// than dropping the athlete straight into the first movement.
    @ObservationIgnored private var pausedInLeadIn = false
    @ObservationIgnored private var announcer = CountdownAnnouncer()

    init(
        plan: WorkoutPlan,
        leadIn: Double = WorkoutSession.defaultLeadIn,
        feedback: any WorkoutMomentReceiver = WorkoutFeedback.shared
    ) {
        self.plan = plan
        self.leadInDuration = max(0, leadIn)
        self.feedback = feedback
        secondsRemaining = Double(plan.steps.first?.duration ?? 0)
        leadInRemaining = self.leadInDuration
    }

    var currentStep: WorkoutStep { plan.steps[stepIndex] }

    var nextStep: WorkoutStep? {
        let index = stepIndex + 1
        return plan.steps.indices.contains(index) ? plan.steps[index] : nil
    }

    /// The next actual movement, skipping past rests and transitions.
    ///
    /// The recovery screen announces what is coming; without this it would
    /// announce the five-second transition sitting between them.
    var nextExerciseStep: WorkoutStep? {
        plan.steps.dropFirst(stepIndex + 1).first { $0.kind == .exercise }
    }

    /// True at the moment a held movement changes side, so the screen and the
    /// Taptic Engine can say so.
    var isSideSwitch: Bool {
        guard currentStep.side == .right, stepIndex > 0 else { return false }
        return plan.steps[..<stepIndex].last { $0.kind == .exercise }?.exercise?.id
            == currentStep.exercise?.id
    }

    /// True while standing on the step *before* a change of side, so the
    /// transition screen can ask for the change rather than only count it down.
    var nextIsSideSwitch: Bool {
        guard let next = nextExerciseStep, next.side == .right else { return false }
        return plan.steps.prefix(stepIndex + 1).last { $0.kind == .exercise }?.exercise?.id
            == next.exercise?.id
    }

    /// True while the preview is on screen, including when it is paused, so it
    /// does not blink away and back for a dialog.
    var isPreparing: Bool {
        if case .preparing = phase { return true }
        return phase.isPaused && pausedInLeadIn
    }

    /// How far through the lead-in, nought to one. The preview walks the
    /// session's movements across this rather than running a timer of its own.
    var leadInProgress: Double {
        guard leadInDuration > 0 else { return 1 }
        return min(1, max(0, 1 - leadInRemaining / leadInDuration))
    }

    var stepProgress: Double {
        guard currentStep.duration > 0 else { return 0 }
        return 1 - (secondsRemaining / Double(currentStep.duration))
    }

    var totalProgress: Double {
        let completed = plan.steps.prefix(stepIndex).reduce(0) { $0 + $1.duration }
        let elapsed = max(0, Double(currentStep.duration) - secondsRemaining)
        return min(1, (Double(completed) + elapsed) / Double(plan.duration))
    }

    var completedExerciseCount: Int {
        plan.steps.prefix(stepIndex).filter { $0.kind == .exercise }.count
    }

    func start() {
        guard phase == .ready else { return }
        feedback.prepare()
        guard leadInDuration > 0 else {
            beginFirstStep()
            return
        }
        feedback.receive(.sessionOpening)
        beginLeadIn(duration: leadInDuration)
    }

    /// Ends the lead-in early. Ten seconds is right for someone who has just
    /// chosen the session and is still holding the phone; it is ten seconds too
    /// many for someone already on the mat, and a preview you cannot leave is a
    /// preview you learn to resent.
    func beginNow() {
        guard case .preparing = phase else { return }
        ticker?.cancel()
        ticker = nil
        leadInRemaining = 0
        beginFirstStep()
    }

    func pause(bySystem: Bool = false) {
        // Also admits the countdown: pressing pause during the lead-in used to
        // do nothing at all, because the toggle fell through to resume and its
        // guard rejected the preparing phase.
        switch phase {
        case .running:
            if let deadline {
                secondsRemaining = max(0, deadline.timeIntervalSinceNow)
            }
            pausedInLeadIn = false
        case .preparing:
            if let deadline {
                leadInRemaining = max(0, deadline.timeIntervalSinceNow)
            }
            pausedInLeadIn = true
        default:
            return
        }

        // Cancelled before the phase changes: the loop watches both, and
        // flipping the phase first left one tick able to fire after the pause.
        ticker?.cancel()
        ticker = nil
        deadline = nil
        pausedBySystem = bySystem
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        pausedBySystem = false
        if pausedInLeadIn {
            pausedInLeadIn = false
            beginLeadIn(duration: leadInRemaining)
        } else {
            beginCurrentStep(duration: secondsRemaining)
        }
    }

    func togglePause() {
        if phase.isPaused {
            resume()
            Haptics.begin()
        } else {
            pause()
            Haptics.halt()
        }
    }

    /// Resumes only if the app was the one that paused. The exit dialog used to
    /// call `resume()` unconditionally, so dismissing it started the clock on a
    /// session the athlete had deliberately paused.
    func resumeIfSystemPaused() {
        guard pausedBySystem else { return }
        resume()
    }

    func skip() {
        if case .preparing = phase {
            beginNow()
            return
        }
        guard phase == .running || phase == .paused else { return }
        // Keeps the phase it had. Skipping while paused used to restart the
        // session, because advancing always ended in `beginCurrentStep`.
        let wasPaused = phase.isPaused
        advance(resumePaused: wasPaused)
    }

    func abandon() {
        ticker?.cancel()
        ticker = nil
        phase = .abandoned
        feedback.release()
    }

    /// Only a genuine trip to the background stops the session. It used to fire
    /// on any inactive phase, so a notification banner or a swipe at Control
    /// Centre silently paused a workout mid-plank.
    func handleAppEnteredBackground() {
        guard phase.isTicking else { return }
        pause(bySystem: true)
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        feedback.release()
    }

    // MARK: - The clock

    private func beginLeadIn(duration: Double) {
        leadInRemaining = max(0, duration)
        announcer.reset()
        deadline = Date.now.addingTimeInterval(leadInRemaining)
        phase = .preparing(max(1, Int(ceil(leadInRemaining))))
        runClock()
    }

    private func beginFirstStep() {
        announcer.reset()
        feedback.receive(.movementStarting)
        beginCurrentStep()
    }

    private func beginCurrentStep(duration: Double? = nil, staysPaused: Bool = false) {
        secondsRemaining = duration ?? Double(currentStep.duration)
        guard !staysPaused else {
            deadline = nil
            return
        }
        deadline = Date.now.addingTimeInterval(secondsRemaining)
        phase = .running
        runClock()
    }

    private func runClock() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            var last = Date.now
            while let self, !Task.isCancelled, phase.isTicking {
                tick(since: &last)
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func tick(since last: inout Date) {
        guard let deadline else { return }
        let now = Date.now
        let elapsed = now.timeIntervalSince(last)
        last = now

        if case .preparing = phase {
            leadInRemaining = max(0, deadline.timeIntervalSince(now))
            show(leadInSecond: max(1, Int(ceil(leadInRemaining))))
            // Measured against the whole lead-in, so a lead-in of three seconds
            // or fewer does not answer its own opening cue with a count-out.
            announceCountdown(remaining: leadInRemaining, of: Int(ceil(leadInDuration)))
            if leadInRemaining <= 0.02 { beginFirstStep() }
            return
        }

        if currentStep.kind == .exercise {
            activeSeconds += elapsed
        }
        secondsRemaining = max(0, deadline.timeIntervalSince(now))
        announceCountdown(remaining: secondsRemaining, of: currentStep.duration)
        if secondsRemaining <= 0.02 { advance() }
    }

    /// The phase carries the whole second, so it is only written when that
    /// second actually changes — a phase rewritten twelve times a second
    /// restarts every animation keyed on it.
    private func show(leadInSecond second: Int) {
        guard case let .preparing(shown) = phase, shown != second else { return }
        phase = .preparing(second)
    }

    /// Three, two, one. Knowing something is about to end is the difference
    /// between finishing it and being cut off, and it has to arrive without
    /// looking at the screen — on every kind of step, not only on movements.
    private func announceCountdown(remaining: Double, of duration: Int) {
        guard let second = announcer.secondToAnnounce(remaining: remaining, of: duration) else {
            return
        }
        feedback.receive(.countdown(second))
    }

    private func advance(resumePaused: Bool = false) {
        ticker?.cancel()
        ticker = nil
        guard stepIndex < plan.steps.count - 1 else {
            secondsRemaining = 0
            phase = .completed
            feedback.receive(.sessionComplete)
            return
        }

        stepIndex += 1
        announcer.reset()
        feedback.receive(momentEnteringCurrentStep())
        beginCurrentStep(staysPaused: resumePaused)
        if resumePaused { phase = .paused }
    }

    private func momentEnteringCurrentStep() -> WorkoutMoment {
        switch currentStep.kind {
        case .recovery: .recoveryStarting
        case .transition: .positionChange
        case .exercise: isSideSwitch ? .sideChange : .movementStarting
        }
    }
}
