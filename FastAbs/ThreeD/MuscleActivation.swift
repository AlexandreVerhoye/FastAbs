import Foundation

/// How hard each muscle group is working at one instant, in `0...1`.
///
/// Obliques are tracked per side because rotational work alternates: during a
/// bicycle crunch only the side turning toward the knee is loaded, and showing
/// both sides lit would misrepresent the movement.
struct MuscleActivation: Equatable, Sendable {
    var upperAbs: Float = 0
    var lowerAbs: Float = 0
    var leftOblique: Float = 0
    var rightOblique: Float = 0
    var deepCore: Float = 0
    var lowerBack: Float = 0

    static let idle = MuscleActivation()

    /// Peak intensity across the abdominal wall — what "sangle abdominale"
    /// means, and what the `.fullCore` zone reports.
    var abdominal: Float {
        max(max(upperAbs, lowerAbs), max(max(leftOblique, rightOblique), deepCore))
    }

    /// Peak intensity across every tracked group, including the lower back.
    /// Posterior-chain work such as a bridge or a superman barely touches the
    /// abdominal wall, so `abdominal` alone would under-report the effort.
    var overall: Float { max(abdominal, lowerBack) }

    subscript(zone: MuscleZone) -> Float {
        switch zone {
        case .fullCore: abdominal
        case .upperAbs: upperAbs
        case .lowerAbs: lowerAbs
        case .obliques: max(leftOblique, rightOblique)
        case .deepCore: deepCore
        case .lowerBack: lowerBack
        }
    }

    var isValid: Bool {
        [upperAbs, lowerAbs, leftOblique, rightOblique, deepCore, lowerBack]
            .allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
    }
}

/// The anatomical signature of a movement: which groups it loads, how hard,
/// and whether the load trades sides within a cycle.
struct MuscleLoad: Equatable, Sendable {
    var upperAbs: Float = 0
    var lowerAbs: Float = 0
    var obliques: Float = 0
    var deepCore: Float = 0
    var lowerBack: Float = 0

    /// Baseline tension held even at the easiest point of the cycle. Isometric
    /// work never fully relaxes, so a plank should not flicker dark.
    var restingTone: Float = 0

    /// True when the two obliques take turns rather than firing together.
    var alternatesSides: Bool = false

    /// Repetitions completed per animation cycle. Alternating movements run two.
    var repetitionsPerCycle: Float = 1
}

extension MuscleActivation {
    /// Activation for a movement at a point in its cycle.
    ///
    /// - Parameters:
    ///   - motion: the movement being rendered.
    ///   - phase: position in the cycle, wrapped to `0..<1`.
    ///   - focus: the muscle zones the catalog attributes to the exercise.
    ///     Groups outside the focus stay visible but dimmer, because they do
    ///     assist — they are just not what the exercise is for.
    static func make(
        for motion: MotionKind,
        phase: Float,
        focus: Set<MuscleZone> = []
    ) -> MuscleActivation {
        let load = MotionLibrary.load(for: motion)
        let tempo = MotionLibrary.tempo(for: motion)
        let effort: Float
        let sideBias: Float

        if load.alternatesSides {
            let swing = MotionTempo.oscillation(at: phase, dwell: 0.3)
            effort = MotionTempo.smoothstep(abs(swing))
            sideBias = swing
        } else {
            effort = tempo.envelope(at: phase * load.repetitionsPerCycle)
            sideBias = 0
        }

        let drive = load.restingTone + (1 - load.restingTone) * effort

        func intensity(_ weight: Float, _ zone: MuscleZone, side: Float = 1) -> Float {
            guard weight > 0 else { return 0 }
            let emphasis = emphasis(for: zone, focus: focus)
            return clamp(weight * drive * emphasis * side)
        }

        let leftShare: Float
        let rightShare: Float
        if load.alternatesSides {
            // The trailing side keeps a little tension: it is decelerating the
            // torso, not resting.
            leftShare = sideBias > 0 ? 1 : 0.35
            rightShare = sideBias > 0 ? 0.35 : 1
        } else {
            leftShare = 1
            rightShare = 1
        }

        return MuscleActivation(
            upperAbs: intensity(load.upperAbs, .upperAbs),
            lowerAbs: intensity(load.lowerAbs, .lowerAbs),
            leftOblique: intensity(load.obliques, .obliques, side: leftShare),
            rightOblique: intensity(load.obliques, .obliques, side: rightShare),
            deepCore: intensity(load.deepCore, .deepCore),
            lowerBack: intensity(load.lowerBack, .lowerBack)
        )
    }

    private static func emphasis(for zone: MuscleZone, focus: Set<MuscleZone>) -> Float {
        guard !focus.isEmpty else { return 1 }
        if focus.contains(.fullCore) || focus.contains(zone) { return 1 }
        return 0.45
    }

    private static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
