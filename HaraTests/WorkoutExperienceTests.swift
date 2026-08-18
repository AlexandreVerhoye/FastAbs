import Foundation
import Testing
import simd
@testable import Hara

@Suite("Workout experience")
struct WorkoutExperienceTests {
    @Test("Russian twist rotates the whole upper body together")
    func russianTwistKeepsTheBodyConnected() {
        let left = MotionLibrary.pose(for: .twist, phase: 0.42)
        let right = MotionLibrary.pose(for: .twist, phase: 0.92)

        // The shoulder line swings one shoulder forward and the other back, so
        // its rotation shows up as a difference in reach rather than as a
        // sideways shift of its midpoint.
        func shoulderLead(_ pose: BodyPose) -> Float { pose.leftShoulder.x - pose.rightShoulder.x }
        func handsOffset(_ pose: BodyPose) -> Float { ((pose.leftHand + pose.rightHand) * 0.5).z }

        for pose in [left, right] {
            #expect(abs(handsOffset(pose)) > 0.05, "the hands barely travel")
            #expect(abs(shoulderLead(pose)) > 0.05, "the shoulder line barely rotates")
        }

        // Hands and shoulders belong to one rigid torso, so whichever way round
        // the sign works out it must be the same at both ends of the swing.
        #expect(
            (handsOffset(left) * shoulderLead(left)) * (handsOffset(right) * shoulderLead(right)) > 0,
            "the hands and the shoulder line do not turn together"
        )

        #expect(
            ((left.leftHand + left.rightHand) * 0.5).z
                * ((right.leftHand + right.rightHand) * 0.5).z < 0,
            "the twist never changes side"
        )
    }

    @Test("The cue that starts a movement is strong and free of invalid samples")
    func goCueHasAudibleHeadroom() {
        // The one cue that has to arrive through breathing, through a phone
        // lying on the floor and through whatever else is playing. It is
        // deliberately the loudest thing the app does.
        let samples = WorkoutCueWaveform.samples(for: .go)
        let peak = samples.map { abs($0) }.max() ?? 0
        let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)
        let rootMeanSquare = sqrt(meanSquare)

        #expect(samples.count == Int(0.35 * WorkoutCueWaveform.sampleRate))
        #expect(samples.allSatisfy { $0.isFinite })
        #expect(peak >= 0.85)
        #expect(rootMeanSquare >= 0.2)
    }

    @Test("Every cue is audible and never clips")
    func allCuesAreUsable() {
        for cue in WorkoutCue.allCases {
            let samples = WorkoutCueWaveform.samples(for: cue)

            #expect(!samples.isEmpty, "\(cue) is silent")
            #expect(samples.allSatisfy { $0.isFinite }, "\(cue) contains invalid samples")
            #expect(samples.allSatisfy { abs($0) <= 1.0001 }, "\(cue) clips")
            #expect((samples.map { abs($0) }.max() ?? 0) > 0.2, "\(cue) is too quiet to hear")
            // A cue that starts or ends at anything but silence pops in the
            // speaker. The envelope opens and closes on a raised cosine, so
            // these are exact zeroes rather than merely small.
            #expect(abs(samples.first ?? 1) < 0.002, "\(cue) starts with a click")
            #expect(abs(samples.last ?? 1) < 0.002, "\(cue) ends with a click")
            // And nothing in between is an edge either: at forty-eight
            // kilohertz the steepest legitimate slope belongs to the highest
            // partial in the set, and it is well under this.
            let steepest = zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
            #expect(steepest < 0.3, "\(cue) jumps \(steepest) between two samples")
        }
    }

    @Test("The cues are ranked rather than all shouting at once")
    func cuesCarryADeliberateHierarchy() {
        func peak(_ cue: WorkoutCue) -> Float {
            WorkoutCueWaveform.samples(for: cue).map { abs($0) }.max() ?? 0
        }

        #expect(peak(.go) > peak(.sideChange), "starting a movement is the loudest moment")
        #expect(peak(.sideChange) > peak(.opening))
        // The tick fires three times in a row; at the level of the others it
        // reads as an alarm rather than as a count.
        #expect(peak(.opening) > peak(.countdown))
        #expect(peak(.complete) > peak(.rest))
    }

    @Test("No cue outlasts the second it belongs to")
    func cuesFitBetweenTheSecondsTheyMark() {
        // Three ticks land a second apart, and the movement's own cue lands a
        // second after the last of them. Anything with a longer tail would be
        // playing over the next thing the session says.
        #expect(WorkoutCueWaveform.duration(of: .countdown) < 0.2)
        for cue in WorkoutCue.allCases where cue != .complete {
            #expect(
                WorkoutCueWaveform.duration(of: cue) < 0.7,
                "\(cue) runs \(WorkoutCueWaveform.duration(of: cue))s"
            )
        }
    }

    @Test("Every moment of a session says something of its own")
    func momentsAreNotInterchangeable() {
        let moments: [WorkoutMoment] = [
            .sessionOpening, .movementStarting, .recoveryStarting,
            .positionChange, .sideChange, .sessionComplete
        ]
        let cues = moments.map(WorkoutFeedback.cue(for:))
        #expect(Set(cues).count == cues.count, "two moments sound the same: \(cues)")

        let patterns = moments.map(WorkoutFeedback.pattern(for:))
        for (index, pattern) in patterns.enumerated() {
            for other in patterns[(index + 1)...] {
                #expect(pattern != other, "\(moments[index]) feels like another moment")
            }
        }
    }
}

/// The vibration vocabulary, which the Taptic Engine cannot be asked about but
/// the patterns handed to it can.
@Suite("Haptic vocabulary")
struct HapticVocabularyTests {
    static let vocabulary: [(name: String, pattern: HapticPattern)] = [
        ("sessionOpening", HapticVocabulary.sessionOpening),
        ("countdown", HapticVocabulary.countdown(secondsLeft: 2)),
        ("movementStarting", HapticVocabulary.movementStarting),
        ("recoveryStarting", HapticVocabulary.recoveryStarting),
        ("positionChange", HapticVocabulary.positionChange),
        ("sideChange", HapticVocabulary.sideChange),
        ("sessionComplete", HapticVocabulary.sessionComplete),
        ("begin", HapticVocabulary.begin),
        ("halt", HapticVocabulary.halt),
        ("step", HapticVocabulary.step)
    ]

    @Test("Every pattern is something CoreHaptics will accept")
    func patternsAreWellFormed() {
        for (name, pattern) in Self.vocabulary {
            #expect(!pattern.events.isEmpty, "\(name) is silent")
            #expect(pattern.events.allSatisfy { (0...1).contains($0.intensity) }, "\(name) is out of range")
            #expect(pattern.events.allSatisfy { (0...1).contains($0.sharpness) }, "\(name) is out of range")
            #expect(pattern.events.allSatisfy { $0.time >= 0 }, "\(name) starts before it starts")
            #expect(
                pattern.events.allSatisfy { $0.shape == .transient || $0.duration > 0 },
                "\(name) holds a continuous event for no time"
            )
            #expect(pattern.duration < 1, "\(name) runs \(pattern.duration)s")
            #expect(pattern.intensityRamp.allSatisfy { (0...1).contains($0.value) })
            // A parameter curve is stated over the whole timeline, so its
            // points have to run forwards or the engine reads them as one.
            #expect(
                zip(pattern.intensityRamp, pattern.intensityRamp.dropFirst())
                    .allSatisfy { $0.time < $1.time },
                "\(name) has an envelope that runs backwards"
            )
        }
    }

    @Test("The count-out firms up as it runs down")
    func countdownIntensifies() {
        let three = HapticVocabulary.countdown(secondsLeft: 3)
        let two = HapticVocabulary.countdown(secondsLeft: 2)
        let one = HapticVocabulary.countdown(secondsLeft: 1)

        // Three identical taps say only that time is passing; three taps that
        // firm up say how much of it is left, which is the point.
        #expect(three.events[0].intensity < two.events[0].intensity)
        #expect(two.events[0].intensity < one.events[0].intensity)
        #expect(three.events[0].sharpness < one.events[0].sharpness)

        // Nothing outside one to three can reach the table behind them.
        #expect(HapticVocabulary.countdown(secondsLeft: 9) == three)
        #expect(HapticVocabulary.countdown(secondsLeft: 0) == one)
        #expect(HapticVocabulary.countdown(secondsLeft: -4) == one)
    }

    @Test("Starting and stopping are opposites rather than the same knock")
    func beginAndHaltAreMirrored() {
        // Legible face down on a mat: one opens with a tap, the other only
        // fades away.
        #expect(HapticVocabulary.begin.events.contains { $0.shape == .transient })
        #expect(HapticVocabulary.halt.events.allSatisfy { $0.shape == .continuous })
        #expect(HapticVocabulary.recoveryStarting.events.allSatisfy { $0.shape == .continuous })
        // And the cues that ask for an action knock more than once.
        #expect(HapticVocabulary.sideChange.events.filter { $0.shape == .transient }.count >= 2)
        #expect(HapticVocabulary.positionChange.events.filter { $0.shape == .transient }.count >= 2)
    }
}
