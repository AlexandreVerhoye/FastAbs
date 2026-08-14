import Foundation
import SwiftData
import SwiftUI

/// Which part of the body a zone belongs to, so a picker can group them and a
/// programme can be built around one area at a time.
enum BodyRegion: String, CaseIterable, Codable, Sendable {
    case core, lowerBody, upperBody

    var title: String {
        switch self {
        case .core: "Sangle abdominale"
        case .lowerBody: "Bas du corps"
        case .upperBody: "Haut du corps"
        }
    }
}

enum MuscleZone: String, CaseIterable, Codable, Identifiable, Sendable {
    case fullCore, upperAbs, lowerAbs, obliques, deepCore, lowerBack
    case glutes, quadriceps, hamstrings, calves
    case chest, shoulders, arms, upperBack

    var id: String { rawValue }

    var region: BodyRegion {
        switch self {
        case .fullCore, .upperAbs, .lowerAbs, .obliques, .deepCore, .lowerBack: .core
        case .glutes, .quadriceps, .hamstrings, .calves: .lowerBody
        case .chest, .shoulders, .arms, .upperBack: .upperBody
        }
    }

    /// Zones the catalog can currently build a workout from. The picker reads
    /// this, so it grows on its own as movements are added rather than offering
    /// a focus with no exercises behind it.
    static var available: [MuscleZone] {
        allCases.filter { zone in ExerciseCatalog.all.contains { $0.zones.contains(zone) } }
    }

    var title: String {
        switch self {
        case .fullCore: "Sangle abdominale"
        case .upperAbs: "Abdos supérieurs"
        case .lowerAbs: "Abdos inférieurs"
        case .obliques: "Obliques"
        case .deepCore: "Transverse"
        case .lowerBack: "Lombaires"
        case .glutes: "Fessiers"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Ischio-jambiers"
        case .calves: "Mollets"
        case .chest: "Pectoraux"
        case .shoulders: "Épaules"
        case .arms: "Bras"
        case .upperBack: "Haut du dos"
        }
    }

    var shortTitle: String {
        switch self {
        case .fullCore: "Complet"
        case .upperAbs: "Haut"
        case .lowerAbs: "Bas"
        case .obliques: "Obliques"
        case .deepCore: "Profond"
        case .lowerBack: "Lombaires"
        case .glutes: "Fessiers"
        case .quadriceps: "Quadris"
        case .hamstrings: "Ischios"
        case .calves: "Mollets"
        case .chest: "Pectoraux"
        case .shoulders: "Épaules"
        case .arms: "Bras"
        case .upperBack: "Dorsaux"
        }
    }

    var symbol: String {
        switch self {
        case .fullCore: "figure.core.training"
        case .upperAbs: "arrow.up.to.line.compact"
        case .lowerAbs: "arrow.down.to.line.compact"
        case .obliques: "arrow.left.and.right"
        case .deepCore: "circle.hexagongrid.fill"
        case .lowerBack: "figure.strengthtraining.traditional"
        case .glutes: "figure.cross.training"
        case .quadriceps: "figure.run"
        case .hamstrings: "figure.walk"
        case .calves: "shoeprints.fill"
        case .chest: "figure.strengthtraining.functional"
        case .shoulders: "figure.arms.open"
        case .arms: "dumbbell.fill"
        case .upperBack: "figure.stand"
        }
    }

    var color: Color {
        switch self {
        case .fullCore: .fastCoral
        case .upperAbs: .fastOrange
        case .lowerAbs: .fastBlue
        case .obliques: .purple
        case .deepCore: .fastMint
        case .lowerBack: .cyan
        case .glutes: Color(red: 0.95, green: 0.45, blue: 0.7)
        case .quadriceps: Color(red: 0.35, green: 0.72, blue: 0.35)
        case .hamstrings: Color(red: 0.2, green: 0.6, blue: 0.55)
        case .calves: Color(red: 0.55, green: 0.75, blue: 0.25)
        case .chest: Color(red: 0.98, green: 0.6, blue: 0.3)
        case .shoulders: Color(red: 0.62, green: 0.5, blue: 0.95)
        case .arms: Color(red: 0.9, green: 0.4, blue: 0.45)
        case .upperBack: Color(red: 0.3, green: 0.62, blue: 0.85)
        }
    }
}

enum WorkoutDifficulty: Int, CaseIterable, Codable, Identifiable, Comparable, Sendable {
    case beginner = 1, balanced, advanced, athlete

    var id: Int { rawValue }

    static func < (lhs: WorkoutDifficulty, rhs: WorkoutDifficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .beginner: "Débutant"
        case .balanced: "Équilibré"
        case .advanced: "Intense"
        case .athlete: "Athlète"
        }
    }

    var detail: String {
        switch self {
        case .beginner: "Contrôle et récupération"
        case .balanced: "Rythme quotidien idéal"
        case .advanced: "Enchaînements exigeants"
        case .athlete: "Puissance et gainage long"
        }
    }

    var interval: ClosedRange<Int> {
        switch self {
        case .beginner: 24...30
        case .balanced: 32...38
        case .advanced: 40...46
        case .athlete: 46...54
        }
    }

    var rest: Int {
        switch self {
        case .beginner: 18
        case .balanced: 14
        case .advanced: 11
        case .athlete: 8
        }
    }
}

enum MovementFamily: String, Codable, Sendable {
    case flexion, antiExtension, rotation, lateral, hipFlexion, posterior, locomotion
}

enum MotionKind: String, Codable, Sendable {
    case crunch, reverseCrunch, toeReach, legRaise, hipRaise, flutter, scissors
    case bicycle, twist, obliqueCrunch, heelTap
    case plank, sidePlank, plankReach, mountainClimber, hollowHold
    case deadBug, birdDog, bearHold, vSit, seatedTuck, superman, bridge, bridgeMarch, squat, rest
}

enum ExerciseImpact: String, Codable, Sendable {
    case quiet, dynamic
}

struct Exercise: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let zones: Set<MuscleZone>
    let family: MovementFamily
    let minimumDifficulty: WorkoutDifficulty
    let impact: ExerciseImpact
    let motion: MotionKind
    /// How to get into position before the first repetition.
    let setup: String
    let instruction: String
    let breathing: String
    /// The mistake this movement invites, so it can be named before it happens.
    let mistake: String
    let unilateral: Bool
    let neckFriendly: Bool
    let intensity: Double
}

struct WorkoutPreferences: Codable, Hashable, Sendable {
    var durationMinutes: Int
    var difficulty: WorkoutDifficulty
    var focusZones: Set<MuscleZone>
    var apartmentFriendly: Bool
    var neckFriendly: Bool
    var extraRecovery: Bool

    static let recommended = WorkoutPreferences(
        durationMinutes: 7,
        difficulty: .balanced,
        focusZones: [.fullCore],
        apartmentFriendly: true,
        neckFriendly: false,
        extraRecovery: false
    )
}

enum WorkoutStepKind: String, Codable, Sendable {
    case exercise, recovery
}

struct WorkoutStep: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let kind: WorkoutStepKind
    let exercise: Exercise?
    let duration: Int

    init(id: UUID = UUID(), kind: WorkoutStepKind, exercise: Exercise?, duration: Int) {
        self.id = id
        self.kind = kind
        self.exercise = exercise
        self.duration = duration
    }

    var title: String { exercise?.name ?? "Récupération" }
    var motion: MotionKind { exercise?.motion ?? .rest }
}

struct WorkoutPlan: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let preferences: WorkoutPreferences
    let steps: [WorkoutStep]
    let estimatedCalories: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        preferences: WorkoutPreferences,
        steps: [WorkoutStep],
        estimatedCalories: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.preferences = preferences
        self.steps = steps
        self.estimatedCalories = estimatedCalories
    }

    var duration: Int { steps.reduce(0) { $0 + $1.duration } }
    var exerciseCount: Int { steps.filter { $0.kind == .exercise }.count }
    var focusDescription: String {
        let zones = preferences.focusZones.filter { $0 != .fullCore }
        return zones.isEmpty ? "Sangle abdominale" : zones.map(\.shortTitle).sorted().joined(separator: " · ")
    }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var plannedDuration: Int
    var activeDuration: Int
    var difficultyRaw: Int
    var exerciseIDs: [String]
    var focusZoneRaws: [String]
    var estimatedCalories: Int

    init(plan: WorkoutPlan, completedAt: Date = .now, activeDuration: Int? = nil) {
        id = UUID()
        self.completedAt = completedAt
        plannedDuration = plan.duration
        self.activeDuration = activeDuration ?? plan.duration
        difficultyRaw = plan.preferences.difficulty.rawValue
        exerciseIDs = plan.steps.compactMap { $0.exercise?.id }
        focusZoneRaws = plan.preferences.focusZones.map(\.rawValue)
        estimatedCalories = plan.estimatedCalories
    }

    var difficulty: WorkoutDifficulty {
        WorkoutDifficulty(rawValue: difficultyRaw) ?? .balanced
    }
}
