import Foundation
import Observation

@MainActor
@Observable
final class WorkoutSession {
    enum Phase: Equatable {
        case ready
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
            case .running, .paused: true
            case .preparing: true
            case .ready, .completed, .abandoned: false
            }
        }
    }

    let plan: WorkoutPlan
    private(set) var phase: Phase = .ready
    private(set) var stepIndex = 0
    private(set) var secondsRemaining: Double = 0
    /// Time actually spent working, which is what gets recorded. Reading the
    /// plan's own duration instead meant every session was filed at its
    /// planned length, rests included, whatever the athlete really did.
    private(set) var activeSeconds: Double = 0

    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var countdown: Task<Void, Never>?
    /// Set when the app itself paused the session, so resuming can tell the
    /// difference between "the athlete pressed pause" and "a sheet appeared".
    @ObservationIgnored private var pausedBySystem = false
    /// The last whole second announced, so the count-out fires once per second
    /// rather than on every one of the twelve ticks it spans.
    @ObservationIgnored private var lastCountdownSecond: Int?

    init(plan: WorkoutPlan) {
        self.plan = plan
        secondsRemaining = Double(plan.steps.first?.duration ?? 0)
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
        countdown?.cancel()
        countdown = Task { [weak self] in
            for count in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                phase = .preparing(count)
                try? await Task.sleep(for: .seconds(1))
            }
            guard let self, !Task.isCancelled else { return }
            WorkoutFeedback.start()
            beginCurrentStep()
        }
    }

    func pause(bySystem: Bool = false) {
        // Also admits the countdown: pressing pause during 3-2-1 used to do
        // nothing at all, because the toggle fell through to resume and its
        // guard rejected the preparing phase.
        switch phase {
        case .running:
            if let deadline {
                secondsRemaining = max(0, deadline.timeIntervalSinceNow)
            }
        case .preparing:
            countdown?.cancel()
            countdown = nil
        default:
            return
        }

        // Cancelled before the phase changes: the loop watches both, and
        // flipping the phase first left one tick able to fire after the pause.
        ticker?.cancel()
        ticker = nil
        pausedBySystem = bySystem
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        pausedBySystem = false
        beginCurrentStep(duration: secondsRemaining)
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
        guard phase == .running || phase == .paused else { return }
        // Keeps the phase it had. Skipping while paused used to restart the
        // session, because advancing always ended in `beginCurrentStep`.
        let wasPaused = phase.isPaused
        advance(resumePaused: wasPaused)
    }

    func abandon() {
        ticker?.cancel()
        ticker = nil
        countdown?.cancel()
        countdown = nil
        phase = .abandoned
    }

    /// Only a genuine trip to the background stops the session. It used to fire
    /// on any inactive phase, so a notification banner or a swipe at Control
    /// Centre silently paused a workout mid-plank.
    func handleAppEnteredBackground() {
        guard phase == .running else { return }
        pause(bySystem: true)
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        countdown?.cancel()
        countdown = nil
    }

    private func beginCurrentStep(duration: Double? = nil, staysPaused: Bool = false) {
        secondsRemaining = duration ?? Double(currentStep.duration)
        guard !staysPaused else {
            deadline = nil
            return
        }
        deadline = Date.now.addingTimeInterval(secondsRemaining)
        phase = .running
        ticker?.cancel()
        ticker = Task { [weak self] in
            var last = Date.now
            while let self, !Task.isCancelled, phase == .running {
                tick(since: &last)
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func tick(since last: inout Date) {
        guard let deadline else { return }
        let now = Date.now
        if currentStep.kind == .exercise {
            activeSeconds += now.timeIntervalSince(last)
        }
        last = now
        secondsRemaining = max(0, deadline.timeIntervalSince(now))
        countOutFinalSeconds()
        if secondsRemaining <= 0.02 { advance() }
    }

    /// Three, two, one. Knowing the movement is about to end is the difference
    /// between finishing it and being cut off mid-repetition, and it has to
    /// arrive without looking at the screen.
    private func countOutFinalSeconds() {
        guard currentStep.kind == .exercise else {
            lastCountdownSecond = nil
            return
        }
        let second = Int(ceil(secondsRemaining))
        guard (1...3).contains(second), second != lastCountdownSecond else {
            if second > 3 { lastCountdownSecond = nil }
            return
        }
        lastCountdownSecond = second
        WorkoutFeedback.countdownTick()
    }

    private func advance(resumePaused: Bool = false) {
        ticker?.cancel()
        ticker = nil
        guard stepIndex < plan.steps.count - 1 else {
            secondsRemaining = 0
            phase = .completed
            WorkoutFeedback.success()
            return
        }

        stepIndex += 1
        lastCountdownSecond = nil
        if isSideSwitch {
            WorkoutFeedback.switchSides()
        } else {
            WorkoutFeedback.transition()
        }
        beginCurrentStep(staysPaused: resumePaused)
        if resumePaused { phase = .paused }
    }
}
