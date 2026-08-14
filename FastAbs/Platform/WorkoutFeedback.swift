import AVFoundation
import UIKit

@MainActor
enum WorkoutFeedback {
    private static let audio = WorkoutCuePlayer()

    static func start() {
        if soundEnabled {
            audio.play(.start)
        }
        haptic(.medium)
    }

    static func transition() {
        if soundEnabled {
            audio.play(.transition)
        }
        haptic(.rigid, intensity: 0.9)
    }

    static func success() {
        if soundEnabled {
            audio.play(.success)
        }
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "sound-enabled") as? Bool ?? true
    }

    private static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics-enabled") as? Bool ?? true
    }

    private static func haptic(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat = 1
    ) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
}

enum WorkoutCue: CaseIterable {
    case start
    case transition
    case success
}

/// Generates short, high-clarity PCM cues without shipping opaque audio assets.
/// The transition cue deliberately peaks well above a system tick so it remains
/// audible during movement and on small iPhone speakers.
enum WorkoutCueWaveform {
    static let sampleRate = 48_000.0

    static func samples(for cue: WorkoutCue) -> [Float] {
        let notes: [Note]
        let duration: Double

        switch cue {
        case .start:
            duration = 0.42
            notes = [
                Note(start: 0, duration: 0.19, frequency: 660, amplitude: 0.66),
                Note(start: 0.17, duration: 0.25, frequency: 990, amplitude: 0.78)
            ]
        case .transition:
            duration = 0.30
            notes = [
                Note(start: 0, duration: 0.16, frequency: 880, amplitude: 0.82),
                Note(start: 0.11, duration: 0.19, frequency: 1_320, amplitude: 0.92)
            ]
        case .success:
            duration = 0.76
            notes = [
                Note(start: 0, duration: 0.28, frequency: 659.25, amplitude: 0.68),
                Note(start: 0.18, duration: 0.32, frequency: 830.61, amplitude: 0.72),
                Note(start: 0.38, duration: 0.38, frequency: 987.77, amplitude: 0.78)
            ]
        }

        let frameCount = Int(duration * sampleRate)
        return (0..<frameCount).map { frame in
            let time = Double(frame) / sampleRate
            let mixed = notes.reduce(0.0) { partial, note in
                partial + note.sample(at: time)
            }
            return Float(max(-0.98, min(0.98, mixed)))
        }
    }
}

private extension WorkoutCueWaveform {
    struct Note {
        let start: Double
        let duration: Double
        let frequency: Double
        let amplitude: Double

        func sample(at time: Double) -> Double {
            let localTime = time - start
            guard localTime >= 0, localTime < duration else { return 0 }

            let attack = min(1, localTime / 0.012)
            let release = pow(max(0, 1 - localTime / duration), 0.72)
            let fundamental = sin(2 * .pi * frequency * localTime)
            let harmonic = sin(2 * .pi * frequency * 2 * localTime) * 0.16
            return (fundamental + harmonic) * amplitude * attack * release
        }
    }
}

@MainActor
private final class WorkoutCuePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: WorkoutCueWaveform.sampleRate,
        channels: 1
    )!
    private var buffers: [WorkoutCue: AVAudioPCMBuffer] = [:]
    private var isConfigured = false

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        for cue in WorkoutCue.allCases {
            buffers[cue] = makeBuffer(for: cue)
        }
    }

    func play(_ cue: WorkoutCue) {
        configureAudioSessionIfNeeded()
        guard let buffer = buffers[cue] else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // Haptics still provide a transition cue if audio hardware is unavailable.
        }
    }

    private func configureAudioSessionIfNeeded() {
        guard !isConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            isConfigured = true
        } catch {
            isConfigured = false
        }
    }

    private func makeBuffer(for cue: WorkoutCue) -> AVAudioPCMBuffer? {
        let samples = WorkoutCueWaveform.samples(for: cue)
        let frameCount = AVAudioFrameCount(samples.count)
        guard
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
