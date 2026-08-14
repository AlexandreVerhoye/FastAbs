import AudioToolbox
import UIKit

@MainActor
enum WorkoutFeedback {
    static func start() {
        guard UserDefaults.standard.object(forKey: "sound-enabled") as? Bool ?? true else {
            haptic(.medium)
            return
        }
        AudioServicesPlaySystemSound(1113)
        haptic(.medium)
    }

    static func transition() {
        if UserDefaults.standard.object(forKey: "sound-enabled") as? Bool ?? true {
            AudioServicesPlaySystemSound(1104)
        }
        haptic(.light)
    }

    static func success() {
        if UserDefaults.standard.object(forKey: "sound-enabled") as? Bool ?? true {
            AudioServicesPlaySystemSound(1025)
        }
        guard UserDefaults.standard.object(forKey: "haptics-enabled") as? Bool ?? true else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard UserDefaults.standard.object(forKey: "haptics-enabled") as? Bool ?? true else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
