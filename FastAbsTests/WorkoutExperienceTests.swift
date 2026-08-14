import Foundation
import Testing
import simd
@testable import FastAbs

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

    @Test("The transition cue is strong and free of invalid samples")
    func transitionCueHasAudibleHeadroom() {
        let samples = WorkoutCueWaveform.samples(for: .transition)
        let peak = samples.map { abs($0) }.max() ?? 0
        let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)
        let rootMeanSquare = sqrt(meanSquare)

        #expect(samples.count == 14_400)
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
            // A cue that starts or ends at full amplitude pops in the speaker.
            #expect(abs(samples.first ?? 1) < 0.2, "\(cue) starts with a click")
            #expect(abs(samples.last ?? 1) < 0.2, "\(cue) ends with a click")
        }
    }
}
