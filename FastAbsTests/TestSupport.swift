import Foundation
@testable import FastAbs

enum TestSupport {
    static let seeds: [UInt64] = [
        0, 1, 2, 7, 42, 99, 2_026, 9_001,
        0xDEAD_BEEF, UInt64.max - 1
    ]

    static func preferences(
        durationMinutes: Int = 7,
        difficulty: WorkoutDifficulty = .balanced,
        focusZones: Set<MuscleZone> = [.fullCore],
        apartmentFriendly: Bool = true,
        neckFriendly: Bool = false,
        extraRecovery: Bool = false
    ) -> WorkoutPreferences {
        WorkoutPreferences(
            durationMinutes: durationMinutes,
            difficulty: difficulty,
            focusZones: focusZones,
            apartmentFriendly: apartmentFriendly,
            neckFriendly: neckFriendly,
            extraRecovery: extraRecovery
        )
    }

    static func signature(of plan: WorkoutPlan) -> [String] {
        plan.steps.map { step in
            [
                step.kind.rawValue,
                step.exercise?.id ?? "recovery",
                String(step.duration)
            ].joined(separator: ":")
        }
    }

    static func exercise(
        id: String,
        zones: Set<MuscleZone> = [.deepCore],
        family: MovementFamily = .antiExtension,
        minimumDifficulty: WorkoutDifficulty = .beginner,
        impact: ExerciseImpact = .quiet,
        neckFriendly: Bool = true
    ) -> Exercise {
        Exercise(
            id: id,
            name: "Exercise \(id)",
            zones: zones,
            family: family,
            minimumDifficulty: minimumDifficulty,
            impact: impact,
            motion: .plank,
            setup: "Start from a stable position.",
            instruction: "Keep a controlled position.",
            breathing: "Breathe continuously.",
            mistake: "Letting the hips drop.",
            unilateral: false,
            neckFriendly: neckFriendly,
            intensity: 1
        )
    }
}
