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

    /// The playlists worth offering to someone who trains these areas.
    ///
    /// A playlist that needs the legs is not shown to an athlete who has the
    /// legs switched off. Tapping it would quietly overrule a decision they made
    /// in Settings; showing it greyed out would be a shop window for a switch
    /// two screens away. So it simply is not there, and appears the moment the
    /// switch goes on.
    static func available(for areas: Set<BodyArea>) -> [WorkoutPlaylist] {
        all.filter { $0.preferences.trainedAreas.isSubset(of: areas) }
    }

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
        ),
        // Below here the playlists reach outside the abdominal wall, so they
        // only appear once the athlete has switched those areas on.
        WorkoutPlaylist(
            id: "lower-body",
            title: "Bas du corps",
            detail: "Squats, fentes et fessiers. Rien d’autre qu’un tapis.",
            symbol: "figure.walk",
            tint: .haraMint,
            preferences: WorkoutPreferences(
                durationMinutes: 10,
                difficulty: .balanced,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false,
                trainedAreas: [.lowerBody]
            )
        ),
        WorkoutPlaylist(
            id: "upper-body",
            title: "Haut du corps",
            detail: "Pompes, dips et tirage : pousser et tirer au poids du corps.",
            symbol: "figure.arms.open",
            tint: .haraBlue,
            preferences: WorkoutPreferences(
                durationMinutes: 10,
                difficulty: .balanced,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false,
                trainedAreas: [.upperBody]
            )
        ),
        WorkoutPlaylist(
            id: "full-body",
            title: "Corps entier",
            detail: "Douze minutes qui passent partout, du gainage aux jambes.",
            symbol: "figure.mixed.cardio",
            tint: .haraCoral,
            preferences: WorkoutPreferences(
                durationMinutes: 12,
                difficulty: .balanced,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false,
                trainedAreas: [.core, .upperBody, .lowerBody]
            )
        ),
        WorkoutPlaylist(
            id: "conditioning",
            title: "Cardio complet",
            detail: "Burpees et jumping jacks : ça monte vite, et ça saute.",
            symbol: "flame.fill",
            tint: .haraOrange,
            preferences: WorkoutPreferences(
                durationMinutes: 8,
                difficulty: .advanced,
                focusZones: [.fullCore],
                // The one playlist that allows impact: it is what it is for, and
                // it says so on the card.
                apartmentFriendly: false,
                neckFriendly: false,
                extraRecovery: false,
                trainedAreas: [.core, .upperBody, .lowerBody]
            )
        )
    ]
}
