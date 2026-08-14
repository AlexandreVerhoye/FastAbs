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
    }

    let plan: WorkoutPlan
    private(set) var phase: Phase = .ready
    private(set) var stepIndex = 0
    private(set) var secondsRemaining: Double = 0

    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(plan: WorkoutPlan) {
        self.plan = plan
        secondsRemaining = Double(plan.steps.first?.duration ?? 0)
    }

    var currentStep: WorkoutStep { plan.steps[stepIndex] }
    var nextStep: WorkoutStep? {
        let index = stepIndex + 1
        return plan.steps.indices.contains(index) ? plan.steps[index] : nil
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
        ticker?.cancel()
        ticker = Task { [weak self] in
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

    func pause() {
        guard phase == .running else { return }
        if let deadline {
            secondsRemaining = max(0, deadline.timeIntervalSinceNow)
        }
        phase = .paused
        ticker?.cancel()
        ticker = nil
    }

    func resume() {
        guard phase == .paused else { return }
        beginCurrentStep(duration: secondsRemaining)
    }

    func togglePause() {
        phase == .running ? pause() : resume()
    }

    func skip() {
        guard phase == .running || phase == .paused else { return }
        advance()
    }

    func abandon() {
        ticker?.cancel()
        ticker = nil
        phase = .abandoned
    }

    func handleAppBecameInactive() {
        if phase == .running { pause() }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    private func beginCurrentStep(duration: Double? = nil) {
        secondsRemaining = duration ?? Double(currentStep.duration)
        deadline = Date.now.addingTimeInterval(secondsRemaining)
        phase = .running
        ticker?.cancel()
        ticker = Task { [weak self] in
            while let self, !Task.isCancelled, phase == .running {
                tick()
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func tick() {
        guard let deadline else { return }
        secondsRemaining = max(0, deadline.timeIntervalSinceNow)
        if secondsRemaining <= 0.02 { advance() }
    }

    private func advance() {
        ticker?.cancel()
        ticker = nil
        if stepIndex == plan.steps.count - 1 {
            secondsRemaining = 0
            phase = .completed
            WorkoutFeedback.success()
        } else {
            stepIndex += 1
            WorkoutFeedback.transition()
            beginCurrentStep()
        }
    }
}

