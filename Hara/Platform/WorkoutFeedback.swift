import AVFoundation
import UIKit

/// Something the session clock did, stated before it is decided what it should
/// sound or feel like.
///
/// The clock used to call `Haptics` and the audio player directly, which meant
/// the rule "a recovery ending deserves the same warning as a movement ending"
/// had to be argued inside a timer loop. Naming the moments separates the two
/// questions — and lets a test watch the clock speak without a Taptic Engine.
enum WorkoutMoment: Equatable, Sendable {
    /// The lead-in has begun: the session is about to start.
    case sessionOpening
    /// One of the last three seconds of anything — a movement, a recovery, a
    /// change of position, or the lead-in itself.
    case countdown(Int)
    case movementStarting
    case recoveryStarting
    /// The five seconds set aside to change position.
    case positionChange
    /// The second half of a movement held per side.
    case sideChange
    case sessionComplete
}

@MainActor
protocol WorkoutMomentReceiver: AnyObject {
    func receive(_ moment: WorkoutMoment)
    /// Warm the hardware up before the first moment arrives.
    func prepare()
    /// Hand the audio session and the Taptic Engine back.
    func release()
}

extension WorkoutMomentReceiver {
    func prepare() {}
    func release() {}
}

/// Sound and vibration for the moments the session engine produces on its own.
/// Anything triggered by a tap goes through `Haptics` directly.
@MainActor
final class WorkoutFeedback: WorkoutMomentReceiver {
    static let shared = WorkoutFeedback()

    private let audio = WorkoutCuePlayer()

    func prepare() {
        Haptics.warmUp()
        guard soundEnabled else { return }
        Task { await audio.warmUp() }
    }

    func release() {
        Task { await audio.relax() }
        Haptics.relax()
    }

    func receive(_ moment: WorkoutMoment) {
        if soundEnabled {
            let cue = Self.cue(for: moment)
            Task { await audio.play(cue) }
        }
        Haptics.play(Self.pattern(for: moment))
    }

    nonisolated static func cue(for moment: WorkoutMoment) -> WorkoutCue {
        switch moment {
        case .sessionOpening: .opening
        case .countdown: .countdown
        case .movementStarting: .go
        case .recoveryStarting: .rest
        case .positionChange: .place
        case .sideChange: .sideChange
        case .sessionComplete: .complete
        }
    }

    nonisolated static func pattern(for moment: WorkoutMoment) -> HapticPattern {
        switch moment {
        case .sessionOpening: HapticVocabulary.sessionOpening
        case let .countdown(second): HapticVocabulary.countdown(secondsLeft: second)
        case .movementStarting: HapticVocabulary.movementStarting
        case .recoveryStarting: HapticVocabulary.recoveryStarting
        case .positionChange: HapticVocabulary.positionChange
        case .sideChange: HapticVocabulary.sideChange
        case .sessionComplete: HapticVocabulary.sessionComplete
        }
    }

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "sound-enabled") as? Bool ?? true
    }
}

/// The seven sounds a session can make.
enum WorkoutCue: String, CaseIterable, Sendable {
    /// The lead-in begins.
    case opening
    /// One of the last three seconds. The shortest and quietest of the set: it
    /// fires three times in a row and anything with a tail runs into itself.
    case countdown
    /// A movement starts. The one that has to cut through effort.
    case go
    /// A recovery starts.
    case rest
    /// Five seconds to change position.
    case place
    /// The other side of a held movement.
    case sideChange
    /// The session is over.
    case complete
}

/// Generates the cues as PCM rather than shipping opaque audio assets.
///
/// The first version was a sine plus one harmonic under a linear envelope,
/// which is the recipe for a smoke-alarm blip: the attack clicks, the tone
/// sits in the band the ear is most sensitive to, and the release cuts. What
/// makes a cue sound like it came with the phone is the envelope — a raised
/// cosine opening over several milliseconds, an exponential body, and a taper
/// that guarantees the buffer ends at silence — plus intervals that belong to
/// the same chord, so two cues heard a second apart still agree with each
/// other. Every cue here is drawn from A major: A, C♯, E, F♯, B.
///
/// Amplitude is set by normalising the finished buffer to a stated peak rather
/// than by hoping the voices sum to something sensible, so a cue can never
/// clip and its loudness relative to its neighbours is a decision rather than
/// an accident.
enum WorkoutCueWaveform {
    static let sampleRate = 48_000.0

    static func samples(for cue: WorkoutCue) -> [Float] {
        let score = score(for: cue)
        let frameCount = Int(score.duration * sampleRate)
        guard frameCount > 0 else { return [] }

        var frames = [Double](repeating: 0, count: frameCount)
        for voice in score.voices {
            let first = max(0, Int(voice.start * sampleRate))
            let last = min(frameCount, Int((voice.start + voice.duration) * sampleRate))
            guard first < last else { continue }
            for frame in first..<last {
                let local = Double(frame) / sampleRate - voice.start
                frames[frame] += voice.sample(at: local)
            }
        }

        let loudest = frames.reduce(0.0) { max($0, abs($1)) }
        guard loudest > 0 else { return frames.map { Float($0) } }
        let gain = score.peak / loudest
        return frames.map { Float($0 * gain) }
    }

    /// The full duration a cue occupies, which callers need to know a cue will
    /// have finished before the next second arrives.
    static func duration(of cue: WorkoutCue) -> Double { score(for: cue).duration }

    private static func score(for cue: WorkoutCue) -> Score {
        switch cue {
        case .opening:
            // Two soft notes rising a fifth, opened slowly enough that neither
            // has an attack you could call a click. Nothing has been asked of
            // the athlete yet, so nothing here is sharp.
            Score(duration: 0.58, peak: 0.70, voices: [
                Voice(start: 0, duration: 0.40, frequency: .a4, amplitude: 0.62,
                      attack: 0.034, overtone: 0.22, decay: 2.6),
                Voice(start: 0.17, duration: 0.41, frequency: .e5, amplitude: 0.72,
                      attack: 0.030, overtone: 0.20, decay: 2.4)
            ])

        case .countdown:
            // A short body under an even shorter top. The top is what makes it
            // read as a tick rather than a beep, and it is gone in thirty
            // milliseconds so three in a row never blur together.
            Score(duration: 0.10, peak: 0.62, voices: [
                Voice(start: 0, duration: 0.10, frequency: .a5, amplitude: 1,
                      attack: 0.006, overtone: 0.26, decay: 5.2),
                Voice(start: 0, duration: 0.03, frequency: .a6, amplitude: 0.32,
                      attack: 0.002, overtone: 0, decay: 6.5)
            ])

        case .go:
            // The brightest cue in the set, because it is the only one that has
            // to arrive through effort and through a phone lying on the floor.
            // A rising fifth: unmistakably an opening rather than an ending.
            Score(duration: 0.35, peak: 0.94, voices: [
                Voice(start: 0, duration: 0.14, frequency: .a5, amplitude: 0.85,
                      attack: 0.006, overtone: 0.24, decay: 3.4),
                Voice(start: 0.085, duration: 0.265, frequency: .e6, amplitude: 0.95,
                      attack: 0.008, overtone: 0.16, decay: 3.0)
            ])

        case .rest:
            // The only falling interval in the set. A minor third downwards is
            // the shape of an exhale, and it cannot be mistaken for the cue
            // that starts a movement even when both are heard through breathing.
            Score(duration: 0.50, peak: 0.62, voices: [
                Voice(start: 0, duration: 0.30, frequency: .e5, amplitude: 0.70,
                      attack: 0.024, overtone: 0.14, decay: 2.6),
                Voice(start: 0.13, duration: 0.37, frequency: .csharp5, amplitude: 0.76,
                      attack: 0.026, overtone: 0.12, decay: 2.4)
            ])

        case .place:
            // A doorway, not a rest: a small step upward, softer and blunter
            // than the cue that starts a movement, so five seconds from now the
            // difference between them is obvious.
            Score(duration: 0.32, peak: 0.66, voices: [
                Voice(start: 0, duration: 0.16, frequency: .fsharp5, amplitude: 0.64,
                      attack: 0.014, overtone: 0.16, decay: 3.6),
                Voice(start: 0.115, duration: 0.20, frequency: .b5, amplitude: 0.68,
                      attack: 0.014, overtone: 0.14, decay: 3.4)
            ])

        case .sideChange:
            // Two knocks on the same note and then a jump: it asks for an
            // action, so it repeats itself before it resolves.
            Score(duration: 0.50, peak: 0.86, voices: [
                Voice(start: 0, duration: 0.13, frequency: .b5, amplitude: 0.80,
                      attack: 0.005, overtone: 0.26, decay: 4.2),
                Voice(start: 0.115, duration: 0.13, frequency: .b5, amplitude: 0.80,
                      attack: 0.005, overtone: 0.26, decay: 4.2),
                Voice(start: 0.235, duration: 0.265, frequency: .e6, amplitude: 0.86,
                      attack: 0.007, overtone: 0.18, decay: 3.0)
            ])

        case .complete:
            // An arpeggio that resolves upward, and the only cue allowed a tail
            // long enough to be heard as a chord rather than as a sequence.
            Score(duration: 1.05, peak: 0.90, voices: [
                Voice(start: 0, duration: 0.31, frequency: .e5, amplitude: 0.62,
                      attack: 0.012, overtone: 0.20, decay: 3.0),
                Voice(start: 0.15, duration: 0.35, frequency: .a5, amplitude: 0.66,
                      attack: 0.012, overtone: 0.18, decay: 2.8),
                Voice(start: 0.30, duration: 0.41, frequency: .csharp6, amplitude: 0.70,
                      attack: 0.012, overtone: 0.16, decay: 2.6),
                Voice(start: 0.46, duration: 0.59, frequency: .e6, amplitude: 0.78,
                      attack: 0.014, overtone: 0.14, decay: 2.2)
            ])
        }
    }
}

extension WorkoutCueWaveform {
    struct Score {
        let duration: Double
        /// What the finished buffer is normalised to. Relative loudness across
        /// the set is set here and nowhere else.
        let peak: Double
        let voices: [Voice]
    }

    struct Voice {
        let start: Double
        let duration: Double
        let frequency: Double
        let amplitude: Double
        /// How long the tone takes to open, shaped as a raised cosine. Below
        /// about four milliseconds the speaker clicks; above about thirty the
        /// cue stops feeling like a cue.
        let attack: Double
        /// How much second and third partial to mix in. A pure sine reads as a
        /// test tone; a little of both gives the cue a body without pushing it
        /// into the band that makes a phone speaker sound shrill.
        let overtone: Double
        /// How fast the body falls away. Larger is more percussive.
        let decay: Double

        func sample(at local: Double) -> Double {
            guard local >= 0, local < duration else { return 0 }
            return amplitude * envelope(at: local) * wave(at: local)
        }

        private func envelope(at local: Double) -> Double {
            let opening = attack > 0 ? min(1, local / attack) : 1
            let attackShape = 0.5 - 0.5 * cos(.pi * opening)
            let span = max(0.0001, duration - attack)
            let progress = min(1, max(0, (local - attack) / span))
            let body = exp(-decay * progress)
            // The last fifth is faded to true zero. An exponential never gets
            // there on its own, and a buffer that stops mid-swing pops.
            let tail = 0.2
            let closing = progress > 1 - tail
                ? 0.5 - 0.5 * cos(.pi * (1 - progress) / tail)
                : 1
            return attackShape * body * closing
        }

        private func wave(at local: Double) -> Double {
            let angle = 2 * .pi * frequency * local
            return sin(angle)
                + overtone * sin(2 * angle)
                + overtone * 0.22 * sin(3 * angle)
        }
    }
}

/// The notes the cues are drawn from, so the set stays inside one chord.
private extension Double {
    static let a4 = 440.0
    static let csharp5 = 554.37
    static let e5 = 659.25
    static let fsharp5 = 739.99
    static let a5 = 880.0
    static let b5 = 987.77
    static let csharp6 = 1_108.73
    static let e6 = 1_318.51
    static let a6 = 1_760.0
}

/// Deliberately off the main actor.
///
/// Configuring the audio session and starting the engine are synchronous calls
/// that can block for the better part of a second on a cold session. Run on the
/// main thread — which is where they were — they stall the very clock the cues
/// exist to mark, and the session it belongs to arrives late to its own first
/// movement. Nothing in here is ever touched from anywhere else, so isolating
/// it costs one hop per cue and buys a clock that cannot be sat on.
private actor WorkoutCuePlayer {
    private let engine = AVAudioEngine()
    /// Three voices in rotation. One player node meant every cue had to stop
    /// the previous one, which chopped the tail off the cue that mattered most
    /// — the movement starting, a second after the last countdown tick.
    private let players = (0..<3).map { _ in AVAudioPlayerNode() }
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: WorkoutCueWaveform.sampleRate,
        channels: 1
    )!
    private var buffers: [WorkoutCue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var isSessionConfigured = false

    init() {
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = 1
    }

    /// Renders every cue and starts the engine, so the first cue of a session
    /// is not also the one that pays for all of them.
    func warmUp() {
        configureSessionIfNeeded()
        startEngineIfNeeded()
        for cue in WorkoutCue.allCases where buffers[cue] == nil {
            buffers[cue] = makeBuffer(WorkoutCueWaveform.samples(for: cue))
        }
    }

    func play(_ cue: WorkoutCue) {
        configureSessionIfNeeded()
        guard let buffer = buffers[cue] ?? renderNow(cue) else { return }
        guard startEngineIfNeeded() else { return }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    func relax() {
        for player in players { player.stop() }
        engine.stop()
        guard isSessionConfigured else { return }
        isSessionConfigured = false
        // Told rather than merely dropped, so whatever was ducked comes back up
        // instead of staying quiet until the user touches it.
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func renderNow(_ cue: WorkoutCue) -> AVAudioPCMBuffer? {
        let buffer = makeBuffer(WorkoutCueWaveform.samples(for: cue))
        buffers[cue] = buffer
        return buffer
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            // Haptics still carry the cue if the audio hardware is unavailable.
            return false
        }
    }

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            isSessionConfigured = true
        } catch {
            isSessionConfigured = false
        }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(samples.count)
        guard
            frameCount > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frameCount
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }
}
