import Foundation
import SwiftData
import SwiftUI

enum MuscleZone: String, CaseIterable, Codable, Identifiable, Sendable {
    case fullCore, upperAbs, lowerAbs, obliques, deepCore, lowerBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullCore: "Centre complet"
        case .upperAbs: "Haut des abdos"
        case .lowerAbs: "Bas des abdos"
        case .obliques: "Obliques"
        case .deepCore: "Gainage profond"
        case .lowerBack: "Lombaires"
        }
    }

    var shortTitle: String {
        switch self {
        case .fullCore: "Complet"
        case .upperAbs: "Haut"
        case .lowerAbs: "Bas"
        case .obliques: "Obliques"
        case .deepCore: "Profond"
        case .lowerBack: "Dos"
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
    case deadBug, birdDog, bearHold, vSit, superman, bridge, rest
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
    let instruction: String
    let breathing: String
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
        return zones.isEmpty ? "Centre complet" : zones.map(\.shortTitle).sorted().joined(separator: " · ")
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
