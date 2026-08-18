import UIKit

/// Every vibration the app produces.
///
/// Two layers sit behind this. Anything with a shape worth feeling — the
/// session vocabulary — is a `HapticPattern` played on the Taptic Engine
/// through `HapticEngine`, because transients and shaped continuous events are
/// the only way to make "go" and "rest" feel like different instructions. The
/// plain taps of ordinary UI stay on `UIFeedbackGenerator`, which is what it is
/// good at, and which is also what every pattern falls back to on hardware
/// without CoreHaptics.
///
/// The generators are created once and kept. `prepare()` needs lead time to
/// spin the Taptic Engine up, so building a generator and firing it in the same
/// turn — which is what the app did before — makes the first tap after a quiet
/// moment land weak or not at all.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let selector = UISelectionFeedbackGenerator()
    private static let notifier = UINotificationFeedbackGenerator()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics-enabled") as? Bool ?? true
    }

    /// Called when a screen that will produce haptics appears, so the engine is
    /// already awake by the time the first tap lands.
    static func warmUp() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        rigid.prepare()
        soft.prepare()
        selector.prepare()
        notifier.prepare()
        HapticEngine.shared.warmUp()
    }

    /// Releases the Taptic Engine once nothing is going to ask for it.
    static func relax() {
        HapticEngine.shared.relax()
    }

    /// Plays a shaped pattern, or the closest plain knock the device can manage.
    static func play(_ pattern: HapticPattern) {
        guard isEnabled else { return }
        guard !HapticEngine.shared.play(pattern) else { return }
        perform(pattern.fallback)
    }

    // MARK: - Vocabulary

    /// A choice among several — a chip, a difficulty, a day on a chart.
    static func selection() {
        guard isEnabled else { return }
        selector.selectionChanged()
        selector.prepare()
    }

    /// An ordinary button.
    static func tap() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.75)
        light.prepare()
    }

    /// Something started.
    static func begin() { play(HapticVocabulary.begin) }

    /// Something stopped. Softer than starting, so the pair is legible without
    /// looking at the screen.
    static func halt() { play(HapticVocabulary.halt) }

    /// A step boundary inside a session.
    static func step() { play(HapticVocabulary.step) }

    /// One second closer to the end.
    static func tick() { tick(secondsLeft: 2) }

    /// One second closer, told apart from its neighbours. Three, two and one
    /// firm up in turn, so the count can be followed with the eyes shut.
    static func tick(secondsLeft: Int) {
        play(HapticVocabulary.countdown(secondsLeft: secondsLeft))
    }

    /// Change sides. It asks the athlete to do something rather than just
    /// marking that time passed, so it travels before it lands.
    static func switchSides() { play(HapticVocabulary.sideChange) }

    static func success() { play(HapticVocabulary.sessionComplete) }

    static func warning() {
        guard isEnabled else { return }
        notifier.notificationOccurred(.warning)
        notifier.prepare()
    }

    // MARK: - Fallbacks

    private static func perform(_ fallback: HapticPattern.Fallback) {
        switch fallback {
        case let .light(intensity):
            light.impactOccurred(intensity: intensity)
            light.prepare()
        case let .medium(intensity):
            medium.impactOccurred(intensity: intensity)
            medium.prepare()
        case let .rigid(intensity):
            rigid.impactOccurred(intensity: intensity)
            rigid.prepare()
        case let .soft(intensity):
            soft.impactOccurred(intensity: intensity)
            soft.prepare()
        case .selection:
            selector.selectionChanged()
            selector.prepare()
        case .success:
            notifier.notificationOccurred(.success)
            notifier.prepare()
        case .warning:
            notifier.notificationOccurred(.warning)
            notifier.prepare()
        case .doubleRigid:
            rigid.impactOccurred(intensity: 1)
            rigid.prepare()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                guard isEnabled else { return }
                rigid.impactOccurred(intensity: 0.8)
                rigid.prepare()
            }
        }
    }
}
