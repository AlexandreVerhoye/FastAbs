import Foundation
@testable import Hara

/// Stands in for sound and vibration, which a test cannot hear or feel.
///
/// The session states what happened rather than calling the Taptic Engine, so
/// the rules worth pinning — that the last three seconds are counted out on
/// every kind of step, that the lead-in speaks before it starts — can be
/// asserted on the transcript.
@MainActor
final class CueRecorder: WorkoutMomentReceiver {
    private(set) var moments: [WorkoutMoment] = []
    private(set) var didPrepare = false
    private(set) var didRelease = false

    func receive(_ moment: WorkoutMoment) { moments.append(moment) }
    func prepare() { didPrepare = true }
    func release() { didRelease = true }

    func count(of moment: WorkoutMoment) -> Int {
        moments.filter { $0 == moment }.count
    }
}

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
        extraRecovery: Bool = false,
        positionTransitions: Bool = true,
        adaptiveCoaching: Bool = true
    ) -> WorkoutPreferences {
        WorkoutPreferences(
            durationMinutes: durationMinutes,
            difficulty: difficulty,
            focusZones: focusZones,
            apartmentFriendly: apartmentFriendly,
            neckFriendly: neckFriendly,
            extraRecovery: extraRecovery,
            positionTransitions: positionTransitions,
            adaptiveCoaching: adaptiveCoaching
        )
    }

    /// Includes the side: without it, a plan that put the right half first and
    /// a plan that put the left half first would sign identically, and the
    /// determinism test would stop testing determinism.
    static func signature(of plan: WorkoutPlan) -> [String] {
        plan.steps.map { step in
            [
                step.kind.rawValue,
                step.exercise?.id ?? "none",
                step.side?.rawValue ?? "-",
                String(step.duration)
            ].joined(separator: ":")
        }
    }

    static func exercise(
        id: String,
        zones: Set<MuscleZone> = [.deepCore],
        family: MovementFamily = .antiExtension,
        pattern: CorePattern = .antiExtension,
        minimumDifficulty: WorkoutDifficulty = .beginner,
        impact: ExerciseImpact = .quiet,
        sideMode: SideMode = .bilateral,
        neckFriendly: Bool = true,
        intensity: Double = 1
    ) -> Exercise {
        Exercise(
            id: id,
            name: "Exercise \(id)",
            zones: zones,
            family: family,
            pattern: pattern,
            minimumDifficulty: minimumDifficulty,
            impact: impact,
            motion: .plank,
            setup: "Start from a stable position.",
            instruction: "Keep a controlled position.",
            breathing: "Breathe continuously.",
            mistake: "Letting the hips drop.",
            tips: ["Keep breathing.", "Stop when the line breaks."],
            sideMode: sideMode,
            neckFriendly: neckFriendly,
            intensity: intensity
        )
    }
}
