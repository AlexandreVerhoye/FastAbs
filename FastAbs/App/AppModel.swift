import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    private enum Keys {
        static let preferences = "workout-preferences-v1"
        static let appearance = "appearance-v1"
        static let hasSeenWelcome = "has-seen-welcome"
    }

    var preferences: WorkoutPreferences {
        didSet { save(preferences, key: Keys.preferences) }
    }

    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var hasSeenWelcome: Bool {
        didSet { UserDefaults.standard.set(hasSeenWelcome, forKey: Keys.hasSeenWelcome) }
    }

    var activePlan: WorkoutPlan?

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Keys.preferences),
           let saved = try? JSONDecoder().decode(WorkoutPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = .recommended
        }
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        hasSeenWelcome = defaults.bool(forKey: Keys.hasSeenWelcome)
    }

    func makeWorkout(seed: UInt64 = UInt64(Date().timeIntervalSince1970)) -> WorkoutPlan {
        let plan = WorkoutEngine().makePlan(preferences: preferences, seed: seed)
        activePlan = plan
        return plan
    }

    func makeTodayWorkout(
        records: [WorkoutRecord] = [],
        calendar: Calendar = .current,
        date: Date = .now
    ) -> WorkoutPlan {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = calendar.timeZone
        let signature = [
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0),
            String(preferences.durationMinutes),
            String(preferences.difficulty.rawValue),
            preferences.focusZones.map(\.rawValue).sorted().joined(separator: ","),
            String(preferences.apartmentFriendly),
            String(preferences.neckFriendly),
            String(preferences.extraRecovery),
            String(preferences.positionTransitions)
        ].joined(separator: "|")
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: preferences, now: date)
        todayRecipe = recipe
        let plan = WorkoutEngine().makePlan(
            preferences: recipe.preferences,
            seed: signature.fnv1a64,
            guidance: recipe.guidance
        )
        activePlan = plan
        return plan
    }

    /// Stable per playlist per day, so tapping the same card twice in a row
    /// gives the same session and tomorrow gives a different one.
    func seed(for playlist: WorkoutPlaylist, calendar: Calendar = .current, date: Date = .now) -> UInt64 {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = calendar.timeZone
        return [
            playlist.id,
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0)
        ].joined(separator: "|").fnv1a64
    }

    /// What the coach settled on for today, so the home screen can show the
    /// reasoning rather than quietly handing over a different session.
    private(set) var todayRecipe: SessionRecipe?

    func restoreRecommendedPlan() {
        preferences = .recommended
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private extension String {
    var fnv1a64: UInt64 {
        utf8.reduce(0xcbf29ce484222325) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automatique"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
