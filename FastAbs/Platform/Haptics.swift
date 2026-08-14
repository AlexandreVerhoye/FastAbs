import UIKit

/// Every vibration the app produces.
///
/// The generators are created once and kept. `prepare()` needs lead time to
/// spin the Taptic Engine up, so building a generator and firing it in the same
/// turn — which is what the app did before — makes the first tap after a quiet
/// moment land weak or not at all. Keeping them also means a rapid sequence
/// (pause, skip, pause) feels like one instrument rather than three.
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
    }

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
    static func begin() {
        guard isEnabled else { return }
        medium.impactOccurred()
        medium.prepare()
    }

    /// Something stopped. Softer than starting, so the pair is legible without
    /// looking at the screen.
    static func halt() {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.85)
        soft.prepare()
    }

    /// A step boundary inside a session.
    static func step() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.9)
        rigid.prepare()
    }

    /// One second closer to the end. Light on purpose — it lands three times
    /// in a row, and at full strength that reads as an alarm.
    static func tick() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.55)
        light.prepare()
    }

    /// Change sides. Two knocks, because it asks the athlete to do something
    /// rather than just marking that time passed.
    static func switchSides() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 1)
        rigid.prepare()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            guard isEnabled else { return }
            rigid.impactOccurred(intensity: 0.8)
            rigid.prepare()
        }
    }

    static func success() {
        guard isEnabled else { return }
        notifier.notificationOccurred(.success)
        notifier.prepare()
    }

    static func warning() {
        guard isEnabled else { return }
        notifier.notificationOccurred(.warning)
        notifier.prepare()
    }
}
