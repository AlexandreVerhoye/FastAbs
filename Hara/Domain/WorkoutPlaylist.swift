import SwiftUI

/// A session someone else already decided on.
///
/// The customisation screen is six cards deep, which is the right amount of
/// control and the wrong amount of friction when you have eight minutes and no
/// opinion. Each playlist is a set of preferences with a name and a reason,
/// hand-written rather than generated so what you tap is what you get.
struct WorkoutPlaylist: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// One line on why you would pick this one today.
    let detail: String
    let symbol: String
    let tint: Color
    let preferences: WorkoutPreferences

    var durationText: String { "\(preferences.durationMinutes) min" }

    static let all: [WorkoutPlaylist] = [
        WorkoutPlaylist(
            id: "wake-up",
            title: "Réveil",
            detail: "Cinq minutes pour se mettre en route, sans se faire mal.",
            symbol: "sunrise.fill",
            tint: .haraOrange,
            preferences: WorkoutPreferences(
                durationMinutes: 5,
                difficulty: .beginner,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: true,
                extraRecovery: false
            )
        ),
        WorkoutPlaylist(
            id: "lower-abs",
            title: "Bas des abdos",
            detail: "La zone que tout le monde néglige, travaillée franchement.",
            symbol: "arrow.down.to.line.compact",
            tint: .haraBlue,
            preferences: WorkoutPreferences(
                durationMinutes: 8,
                difficulty: .balanced,
                focusZones: [.lowerAbs],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false
            )
        ),
        WorkoutPlaylist(
            id: "obliques",
            title: "Obliques",
            detail: "Rotation et gainage latéral, les deux côtés.",
            symbol: "arrow.left.and.right",
            tint: .purple,
            preferences: WorkoutPreferences(
                durationMinutes: 10,
                difficulty: .balanced,
                focusZones: [.obliques],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false
            )
        ),
        WorkoutPlaylist(
            id: "deep-core",
            title: "Gainage profond",
            detail: "Des tenues longues et lentes, rien de spectaculaire.",
            symbol: "circle.hexagongrid.fill",
            tint: .haraMint,
            preferences: WorkoutPreferences(
                durationMinutes: 10,
                difficulty: .balanced,
                focusZones: [.deepCore],
                apartmentFriendly: true,
                neckFriendly: true,
                extraRecovery: true
            )
        ),
        WorkoutPlaylist(
            id: "cardio",
            title: "Abdos cardio",
            detail: "Ça bouge et ça saute : le souffle travaille aussi.",
            symbol: "bolt.heart.fill",
            tint: .haraCoral,
            preferences: WorkoutPreferences(
                durationMinutes: 12,
                difficulty: .advanced,
                focusZones: [.fullCore],
                apartmentFriendly: false,
                neckFriendly: false,
                extraRecovery: false
            )
        ),
        WorkoutPlaylist(
            id: "burn",
            title: "Brûlure",
            detail: "Douze minutes serrées, peu de repos.",
            symbol: "flame.fill",
            tint: .haraOrange,
            preferences: WorkoutPreferences(
                durationMinutes: 12,
                difficulty: .advanced,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false
            )
        ),
        WorkoutPlaylist(
            id: "back-care",
            title: "Dos fragile",
            detail: "Lombaires et transverse, sans rien demander à la nuque.",
            symbol: "figure.strengthtraining.traditional",
            tint: .cyan,
            preferences: WorkoutPreferences(
                durationMinutes: 9,
                difficulty: .beginner,
                focusZones: [.lowerBack, .deepCore],
                apartmentFriendly: true,
                neckFriendly: true,
                extraRecovery: true
            )
        ),
        WorkoutPlaylist(
            id: "long-haul",
            title: "Séance longue",
            detail: "Vingt minutes, tous les angles, une seule fois par semaine.",
            symbol: "infinity",
            tint: .haraIndigo,
            preferences: WorkoutPreferences(
                durationMinutes: 20,
                difficulty: .balanced,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false
            )
        )
    ]
}
