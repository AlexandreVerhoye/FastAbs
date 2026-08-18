import Foundation

/// How one repetition is distributed across its cycle.
///
/// A raw cosine gives every repetition the same speed up and down, which reads
/// as a machine rather than a person. Real coaching cues a quicker concentric
/// (the effort), a brief squeeze at peak contraction, and a slower eccentric
/// (the controlled return). `MotionTempo` encodes that split.
///
/// Fractions are relative weights, not percentages: they are normalised so a
/// tempo always fills exactly one cycle.
struct MotionTempo: Equatable, Sendable {
    var concentric: Float
    var squeeze: Float
    var eccentric: Float
    var recover: Float

    init(concentric: Float, squeeze: Float, eccentric: Float, recover: Float) {
        self.concentric = max(0.0001, concentric)
        self.squeeze = max(0, squeeze)
        self.eccentric = max(0.0001, eccentric)
        self.recover = max(0, recover)
    }

    /// A brisk lift with a controlled return — the default for crunch-family work.
    static let controlled = MotionTempo(concentric: 0.28, squeeze: 0.10, eccentric: 0.44, recover: 0.18)

    /// Slow and even, for long-lever movements where momentum is the enemy.
    static let deliberate = MotionTempo(concentric: 0.34, squeeze: 0.14, eccentric: 0.40, recover: 0.12)

    /// Athletic and quick, for locomotion-style movements.
    static let explosive = MotionTempo(concentric: 0.20, squeeze: 0.06, eccentric: 0.30, recover: 0.44)

    /// A near-static hold that only breathes.
    static let isometric = MotionTempo(concentric: 0.40, squeeze: 0.10, eccentric: 0.40, recover: 0.10)

    var total: Float { concentric + squeeze + eccentric + recover }

    /// The point in the cycle where the muscle is most contracted.
    ///
    /// Used as the still frame when Reduce Motion is on: a frozen peak
    /// contraction teaches the movement, a frozen mid-rep teaches nothing.
    var peakPhase: Float { (concentric + squeeze * 0.5) / total }

    /// Effort at `phase`, in `0...1`.
    ///
    /// The curve reaches 0 with zero slope at both ends of the cycle, so a
    /// looping animation never shows a velocity pop at the seam.
    func envelope(at rawPhase: Float) -> Float {
        let phase = MotionTempo.wrap(rawPhase)
        let scale = total
        let rise = concentric / scale
        let hold = squeeze / scale
        let fall = eccentric / scale

        if phase < rise {
            return MotionTempo.smoothstep(phase / rise)
        }
        if phase < rise + hold {
            return 1
        }
        if phase < rise + hold + fall {
            return 1 - MotionTempo.smoothstep((phase - rise - hold) / fall)
        }
        return 0
    }

    /// A smooth `-1...1` oscillation that dwells at each extreme.
    ///
    /// Used by alternating movements (bicycle, flutter, heel taps) where both
    /// directions are the working half of the repetition. `dwell` is the share
    /// of the cycle spent held at an extreme, so 0 gives a pure ease and 0.4
    /// gives a pronounced pause on each side.
    static func oscillation(at rawPhase: Float, dwell: Float) -> Float {
        let phase = wrap(rawPhase)
        let hold = min(max(dwell, 0), 0.45) * 0.5
        let sweep = 0.5 - hold

        if phase < sweep {
            return -1 + 2 * smoothstep(phase / sweep)
        }
        if phase < sweep + hold {
            return 1
        }
        if phase < 2 * sweep + hold {
            return 1 - 2 * smoothstep((phase - sweep - hold) / sweep)
        }
        return -1
    }

    /// A gentle breathing ripple for holds, in `-1...1`.
    static func breath(at rawPhase: Float) -> Float {
        sin(wrap(rawPhase) * 2 * .pi)
    }

    static func wrap(_ phase: Float) -> Float {
        guard phase.isFinite else { return 0 }
        let wrapped = phase - floor(phase)
        return wrapped >= 1 ? 0 : wrapped
    }

    /// Hermite ease with zero slope at both ends.
    static func smoothstep(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
