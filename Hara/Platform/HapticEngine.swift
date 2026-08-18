import CoreHaptics
import UIKit

/// A vibration described as data rather than as a call to a generator.
///
/// `UIFeedbackGenerator` only offers a handful of fixed knocks, and a workout
/// needs a vocabulary: starting, one second closer, go, rest, change sides,
/// finished — each legible without looking at the screen. Those differences
/// live in shape, not in strength, so the shape has to be expressible.
///
/// Keeping it as a value also makes it testable. The Taptic Engine cannot be
/// observed from a test, but the pattern it is handed can.
struct HapticPattern: Equatable, Sendable {
    /// What a device without CoreHaptics plays instead. Every pattern names
    /// one, so the vocabulary degrades to something rather than to silence.
    enum Fallback: Equatable, Sendable {
        case light(Double)
        case medium(Double)
        case rigid(Double)
        case soft(Double)
        case selection
        case success
        case warning
        /// Two knocks a moment apart, for the cues that ask for an action.
        case doubleRigid
    }

    struct Event: Equatable, Sendable {
        enum Shape: Equatable, Sendable {
            /// A tap. Duration is ignored by the hardware.
            case transient
            /// A sustained buzz, which is where the shaping lives.
            case continuous
        }

        let shape: Shape
        let time: TimeInterval
        let duration: TimeInterval
        let intensity: Float
        let sharpness: Float

        static func tap(
            at time: TimeInterval,
            intensity: Float,
            sharpness: Float
        ) -> Event {
            Event(shape: .transient, time: time, duration: 0, intensity: intensity, sharpness: sharpness)
        }

        static func swell(
            from time: TimeInterval,
            for duration: TimeInterval,
            intensity: Float,
            sharpness: Float
        ) -> Event {
            Event(
                shape: .continuous,
                time: time,
                duration: duration,
                intensity: intensity,
                sharpness: sharpness
            )
        }
    }

    /// A point on the pattern's intensity envelope.
    struct Ramp: Equatable, Sendable {
        let time: TimeInterval
        let value: Float
    }

    let events: [Event]
    /// Applied across the whole pattern, so at most one continuous event may
    /// rely on it. CoreHaptics parameter curves are timeline-wide, not
    /// per-event, and two of them fighting is how a shaped buzz turns to mush.
    let intensityRamp: [Ramp]
    let fallback: Fallback

    init(events: [Event], intensityRamp: [Ramp] = [], fallback: Fallback) {
        self.events = events
        self.intensityRamp = intensityRamp
        self.fallback = fallback
    }

    var duration: TimeInterval {
        events.map { $0.time + $0.duration }.max() ?? 0
    }
}

/// The app's vibration vocabulary.
///
/// Read them as a set rather than one at a time: the point is that the athlete
/// can tell them apart face down on a mat. Sharpness separates the crisp
/// instructions (go, tick, change sides) from the soft ones (rest, pause), and
/// the number of taps separates "time passed" from "do something now".
enum HapticVocabulary {
    /// The session is opening. A slow swell rather than a knock — nothing has
    /// been asked of the athlete yet.
    static let sessionOpening = HapticPattern(
        events: [
            .swell(from: 0, for: 0.34, intensity: 0.55, sharpness: 0.2),
            .tap(at: 0.30, intensity: 0.6, sharpness: 0.45)
        ],
        intensityRamp: [
            Ramp(time: 0, value: 0.15),
            Ramp(time: 0.22, value: 1),
            Ramp(time: 0.34, value: 0.5)
        ],
        fallback: .soft(0.7)
    )

    /// One second closer. Firms up as the count runs down, so three, two and
    /// one are three different sensations rather than the same tap repeated —
    /// which is the whole point of counting out loud.
    static func countdown(secondsLeft: Int) -> HapticPattern {
        let step = max(1, min(3, secondsLeft))
        let intensity: Float = [0.55, 0.72, 0.92][3 - step]
        let sharpness: Float = [0.55, 0.68, 0.82][3 - step]
        return HapticPattern(
            events: [.tap(at: 0, intensity: intensity, sharpness: sharpness)],
            fallback: .light(Double(intensity))
        )
    }

    /// Go. A sharp tap with a very short body behind it, so it reads as a
    /// push rather than as a notification.
    static let movementStarting = HapticPattern(
        events: [
            .tap(at: 0, intensity: 1, sharpness: 0.9),
            .swell(from: 0.01, for: 0.13, intensity: 0.8, sharpness: 0.7)
        ],
        intensityRamp: [
            Ramp(time: 0, value: 1),
            Ramp(time: 0.14, value: 0)
        ],
        fallback: .medium(1)
    )

    /// Rest. The one cue in the set that has no attack: it fades in and out,
    /// which is what makes it unmistakable next to everything else.
    static let recoveryStarting = HapticPattern(
        events: [.swell(from: 0, for: 0.42, intensity: 0.62, sharpness: 0.08)],
        intensityRamp: [
            Ramp(time: 0, value: 0.1),
            Ramp(time: 0.14, value: 1),
            Ramp(time: 0.42, value: 0)
        ],
        fallback: .soft(0.8)
    )

    /// Five seconds to change position. Two soft taps — an instruction, but a
    /// small one, and deliberately blunter than the change of sides.
    static let positionChange = HapticPattern(
        events: [
            .tap(at: 0, intensity: 0.7, sharpness: 0.35),
            .tap(at: 0.11, intensity: 0.62, sharpness: 0.35)
        ],
        fallback: .rigid(0.8)
    )

    /// Change sides. A buzz that sharpens as it travels, then lands on two
    /// firm taps: something moves across, then stops on the other side.
    static let sideChange = HapticPattern(
        events: [
            .swell(from: 0, for: 0.22, intensity: 0.75, sharpness: 0.25),
            .tap(at: 0.24, intensity: 1, sharpness: 0.85),
            .tap(at: 0.37, intensity: 0.85, sharpness: 0.85)
        ],
        intensityRamp: [
            Ramp(time: 0, value: 0.2),
            Ramp(time: 0.22, value: 1)
        ],
        fallback: .doubleRigid
    )

    /// Finished. Three rising taps with a tail, and the only pattern in the
    /// set that is allowed to last more than half a second.
    static let sessionComplete = HapticPattern(
        events: [
            .tap(at: 0, intensity: 0.65, sharpness: 0.4),
            .tap(at: 0.13, intensity: 0.8, sharpness: 0.55),
            .tap(at: 0.26, intensity: 1, sharpness: 0.75),
            .swell(from: 0.28, for: 0.36, intensity: 0.7, sharpness: 0.3)
        ],
        intensityRamp: [
            Ramp(time: 0.28, value: 0.9),
            Ramp(time: 0.64, value: 0)
        ],
        fallback: .success
    )

    /// Something the athlete started — a session, a resume.
    static let begin = HapticPattern(
        events: [
            .tap(at: 0, intensity: 0.85, sharpness: 0.6),
            .swell(from: 0.01, for: 0.11, intensity: 0.6, sharpness: 0.45)
        ],
        intensityRamp: [
            Ramp(time: 0, value: 0.9),
            Ramp(time: 0.12, value: 0)
        ],
        fallback: .medium(1)
    )

    /// Something stopped. The mirror of `begin`: it fades out instead of in,
    /// so the pair is legible without looking at the screen.
    static let halt = HapticPattern(
        events: [.swell(from: 0, for: 0.16, intensity: 0.55, sharpness: 0.12)],
        intensityRamp: [
            Ramp(time: 0, value: 1),
            Ramp(time: 0.16, value: 0)
        ],
        fallback: .soft(0.85)
    )

    /// A step boundary inside a session, when nothing more specific applies.
    static let step = HapticPattern(
        events: [.tap(at: 0, intensity: 0.85, sharpness: 0.7)],
        fallback: .rigid(0.9)
    )
}

private typealias Ramp = HapticPattern.Ramp

/// Plays `HapticPattern`s on the Taptic Engine.
///
/// Kept alive for the whole session rather than built per pattern: CoreHaptics
/// shuts an idle engine down on its own, and the first pattern after that
/// arrives late and weak — which is exactly the tap that matters, the one that
/// says a movement has started.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    let isSupported: Bool
    private var engine: CHHapticEngine?

    private init() {
        isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Spins the engine up ahead of the first pattern.
    func warmUp() {
        _ = startedEngine()
    }

    /// Lets the engine go once a session is over, so the app is not holding
    /// hardware awake behind a summary screen.
    func relax() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }

    /// False when the pattern could not be played at all, which is the signal
    /// for the caller to fall back to a plain generator.
    @discardableResult
    func play(_ pattern: HapticPattern) -> Bool {
        guard let engine = startedEngine() else { return false }
        do {
            let player = try engine.makePlayer(with: try makePattern(pattern))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            // A failed play usually means the engine was reclaimed underneath
            // us. Drop it so the next call rebuilds rather than failing again.
            self.engine = nil
            return false
        }
    }

    private func startedEngine() -> CHHapticEngine? {
        guard isSupported else { return nil }
        if let engine { return engine }
        do {
            let created = try CHHapticEngine()
            created.playsHapticsOnly = true
            // Nothing captures self: these handlers arrive on the engine's own
            // queue, and reaching the actor through the shared instance is the
            // only way to keep that safe under strict concurrency.
            created.resetHandler = {
                Task { @MainActor in HapticEngine.shared.handleReset() }
            }
            created.stoppedHandler = { _ in
                Task { @MainActor in HapticEngine.shared.engine = nil }
            }
            try created.start()
            engine = created
            return created
        } catch {
            return nil
        }
    }

    private func handleReset() {
        try? engine?.start()
    }

    private func makePattern(_ pattern: HapticPattern) throws -> CHHapticPattern {
        let events = pattern.events.map { event in
            CHHapticEvent(
                eventType: event.shape == .transient ? .hapticTransient : .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                ],
                relativeTime: event.time,
                duration: event.shape == .transient ? 0 : event.duration
            )
        }

        guard pattern.intensityRamp.count >= 2 else {
            return try CHHapticPattern(events: events, parameters: [])
        }

        let points = pattern.intensityRamp.map {
            CHHapticParameterCurve.ControlPoint(relativeTime: $0.time, value: $0.value)
        }
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points,
            relativeTime: 0
        )
        return try CHHapticPattern(events: events, parameterCurves: [curve])
    }
}
