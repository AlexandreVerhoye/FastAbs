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

    /// Switches a part of the body on or off, keeping every other setting.
    ///
    /// Returns false when the change was refused, which happens for exactly one
    /// reason: something has to be trained. Everything else — the duration, the
    /// level, the rhythm, the exclusions, and any priority that is still
    /// reachable — survives untouched; only a focus that has become unreachable
    /// is dropped. Rebuilding from the defaults would be the easy answer and
    /// the wrong one: it would undo a dozen decisions to carry out one.
    @discardableResult
    func setArea(_ area: BodyArea, enabled: Bool) -> Bool {
        var updated = preferences
        if enabled {
            updated.trainedAreas.insert(area)
        } else {
            guard updated.trainedAreas.count > 1 else { return false }
            updated.trainedAreas.remove(area)
        }
        updated.reconcile()
        guard updated != preferences else { return false }
        preferences = updated
        return true
    }

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: Keys.hasSeenWelcome) }
    }

    var activePlan: WorkoutPlan?

    /// Where the settings are read from *and* written to.
    ///
    /// Held rather than only read at launch: it was read from the injected store
    /// and written straight back to `.standard`, so a test that set a preference
    /// on its own throwaway store still overwrote the athlete's — and did, which
    /// is how a simulator ended up booting the app with three body areas
    /// switched on that nobody had asked for.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        makeCustomWorkout(preferences: preferences, seed: seed)
    }

    /// The session the athlete asked for, exactly.
    ///
    /// Deliberately not routed through the coach, and the counterpart to
    /// `makeTodayWorkout`: the home hero is the adapted session, and
    /// "Personnaliser" is the way out of it. If this adapted too there would be
    /// nowhere left in the app to get what the settings actually say, and the
    /// settings screen would become a suggestion box.
    func makeCustomWorkout(
        preferences: WorkoutPreferences,
        seed: UInt64 = UInt64(Date().timeIntervalSince1970)
    ) -> WorkoutPlan {
        let plan = WorkoutEngine().makePlan(preferences: preferences, seed: seed, guidance: .none)
        activePlan = plan
        return plan
    }

    func makeTodayWorkout(
        records: [WorkoutRecord] = [],
        calendar: Calendar = .current,
        date: Date = .now
    ) -> WorkoutPlan {
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: preferences, now: date)
        todayRecipe = recipe
        let plan = WorkoutEngine().makePlan(
            preferences: recipe.preferences,
            seed: dailySeed(for: preferences, calendar: calendar, date: date),
            guidance: recipe.guidance
        )
        activePlan = plan
        return plan
    }

    /// The session a set of preferences would produce today, without adopting
    /// them or touching anything.
    ///
    /// The last screen of the setup flow promises "your first session", and a
    /// promise like that has to be the session that then starts — not a second
    /// draw from a different seed that happens to land on a different movement
    /// count. Same seed, same coach, same engine.
    func previewTodayWorkout(
        for preferences: WorkoutPreferences,
        records: [WorkoutRecord] = [],
        calendar: Calendar = .current,
        date: Date = .now
    ) -> WorkoutPlan {
        let recipe = CoachAdvisor(calendar: calendar)
            .recipe(records: records, base: preferences, now: date)
        return WorkoutEngine().makePlan(
            preferences: recipe.preferences,
            seed: dailySeed(for: preferences, calendar: calendar, date: date),
            guidance: recipe.guidance
        )
    }

    /// Stable for a day and for a set of settings, so the day's session does not
    /// change on a redraw and does change when a setting does.
    private func dailySeed(
        for preferences: WorkoutPreferences,
        calendar: Calendar,
        date: Date
    ) -> UInt64 {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = calendar.timeZone
        return [
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0),
            String(preferences.durationMinutes),
            String(preferences.difficulty.rawValue),
            // Switching a part of the body on has to redraw the day, for the
            // same reason banishing a movement does.
            preferences.trainedAreas.map(\.rawValue).sorted().joined(separator: ","),
            preferences.focusZones.map(\.rawValue).sorted().joined(separator: ","),
            String(preferences.apartmentFriendly),
            String(preferences.neckFriendly),
            String(preferences.extraRecovery),
            String(preferences.positionTransitions),
            String(preferences.adaptiveCoaching),
            // Banishing a movement has to redraw the day. Without this the seed
            // stays put and the session only changes where the exclusion
            // happened to bite, which reads as the setting being ignored.
            preferences.excludedExerciseIDs.sorted().joined(separator: ",")
        ].joined(separator: "|").fnv1a64
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

    /// Puts the programme back to the recommended one — the duration, the
    /// level, the rhythm, the constraints.
    ///
    /// Not the areas. What parts of the body someone trains is not part of "the
    /// recommended programme"; taking the legs away because the athlete asked
    /// for the default duration back would be a different, much larger answer
    /// than the one the button offers.
    func restoreRecommendedPlan() {
        var restored = WorkoutPreferences.recommended
        restored.trainedAreas = preferences.trainedAreas
        restored.reconcile()
        preferences = restored
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
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
