import Foundation
import simd
import Testing
@testable import FastAbs

@Suite("Workout experience")
struct WorkoutExperienceTests {
    @Test("Every 3D motion changes the articulated pose")
    func everyMotionIsAnimated() {
        let motions = Set(ExerciseCatalog.all.map(\.motion)).union([.rest])

        for motion in motions {
            let start = MotionLibrary.pose(for: motion, phase: 0)
            let quarter = MotionLibrary.pose(for: motion, phase: 0.25)
            let maximumDelta = zip(points(in: start), points(in: quarter))
                .map { simd_distance($0.0, $0.1) }
                .max() ?? 0

            #expect(maximumDelta > 0.01, "\(motion.rawValue) is visually static")
        }
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

    private func points(in pose: BodyPose) -> [SIMD3<Float>] {
        [
            pose.head, pose.neck, pose.chest, pose.pelvis,
            pose.leftShoulder, pose.rightShoulder,
            pose.leftElbow, pose.rightElbow,
            pose.leftHand, pose.rightHand,
            pose.leftHip, pose.rightHip,
            pose.leftKnee, pose.rightKnee,
            pose.leftAnkle, pose.rightAnkle
        ]
    }
}
