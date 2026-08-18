import Foundation
import Testing
import simd
@testable import Hara

@Suite("Pose solver")
struct PoseSolverTests {
    @Test("A stretched sketch comes back with correct bone lengths")
    func solvingRestoresBoneLengths() {
        var sketch = MotionLibrary.pose(for: .crunch, phase: 0)
        // Simulate the worst case: a naive blend that has pulled every joint
        // toward the body's centre, shortening every bone at once.
        sketch.leftKnee *= 0.5
        sketch.leftAnkle *= 0.5
        sketch.rightHand *= 1.8
        sketch.head *= 2.4

        let solved = PoseSolver.solve(sketch)

        for bone in BodyPose.bones {
            #expect(
                abs(solved.length(of: bone) - SkeletonMetrics.standard[keyPath: bone.length]) < 0.001,
                "\(bone.name) was not restored"
            )
        }
    }

    @Test("Solving is idempotent")
    func solvingTwiceChangesNothing() {
        let once = PoseSolver.solve(MotionLibrary.pose(for: .bicycle, phase: 0.4))
        let twice = PoseSolver.solve(once)

        for (first, second) in zip(once.joints, twice.joints) {
            #expect(simd_distance(first, second) < 0.0005)
        }
    }

    @Test("Degenerate input does not produce invalid coordinates")
    func degenerateInputStaysFinite() {
        let collapsed = BodyPose(
            head: .zero, neck: .zero, chest: .zero, pelvis: .zero,
            leftShoulder: .zero, rightShoulder: .zero,
            leftElbow: .zero, rightElbow: .zero,
            leftHand: .zero, rightHand: .zero,
            leftHip: .zero, rightHip: .zero,
            leftKnee: .zero, rightKnee: .zero,
            leftAnkle: .zero, rightAnkle: .zero
        )

        let solved = PoseSolver.solve(collapsed)

        for joint in solved.joints {
            #expect(joint.x.isFinite && joint.y.isFinite && joint.z.isFinite)
        }
        for bone in BodyPose.bones {
            #expect(
                abs(solved.length(of: bone) - SkeletonMetrics.standard[keyPath: bone.length]) < 0.001,
                "\(bone.name) collapsed"
            )
        }
    }

    @Test("A reachable target is hit exactly")
    func inverseKinematicsReachesItsTarget() {
        let root = SIMD3<Float>(0, 1, 0)
        let target = SIMD3<Float>(0.4, 0.5, 0.1)
        let result = PoseSolver.twoBone(
            root: root,
            target: target,
            poleHint: SIMD3<Float>(0.4, 1, 0),
            upper: 0.6,
            lower: 0.58,
            fallbackBend: SIMD3<Float>(0, 1, 0)
        )

        #expect(simd_distance(result.end, target) < 0.001)
        #expect(abs(simd_distance(root, result.joint) - 0.6) < 0.001)
        #expect(abs(simd_distance(result.joint, result.end) - 0.58) < 0.001)
    }

    @Test("An unreachable target clamps to a straight limb pointing at it")
    func inverseKinematicsClampsBeyondReach() {
        let root = SIMD3<Float>.zero
        let target = SIMD3<Float>(5, 0, 0)
        let result = PoseSolver.twoBone(
            root: root,
            target: target,
            poleHint: SIMD3<Float>(0, 1, 0),
            upper: 0.6,
            lower: 0.58,
            fallbackBend: SIMD3<Float>(0, 1, 0)
        )

        #expect(simd_distance(root, result.end) <= 1.18)
        #expect(abs(simd_distance(root, result.joint) - 0.6) < 0.001)
        #expect(abs(simd_distance(result.joint, result.end) - 0.58) < 0.001)
        // Still aimed at the target, just as far as the limb can go.
        #expect(result.end.x > 1.1 && abs(result.end.y) < 0.05)
    }

    @Test("A target on top of the root still yields valid bones")
    func inverseKinematicsHandlesZeroDistance() {
        let result = PoseSolver.twoBone(
            root: .zero,
            target: .zero,
            poleHint: .zero,
            upper: 0.6,
            lower: 0.58,
            fallbackBend: SIMD3<Float>(0, 1, 0)
        )

        #expect(result.joint.x.isFinite && result.joint.y.isFinite && result.joint.z.isFinite)
        #expect(abs(simd_distance(.zero, result.joint) - 0.6) < 0.001)
        #expect(abs(simd_distance(result.joint, result.end) - 0.58) < 0.001)
    }

    @Test("The pole hint decides which way the joint bends")
    func poleHintControlsBendDirection() {
        let root = SIMD3<Float>.zero
        let target = SIMD3<Float>(1, 0, 0)

        let up = PoseSolver.twoBone(
            root: root, target: target, poleHint: SIMD3<Float>(0.5, 1, 0),
            upper: 0.6, lower: 0.58, fallbackBend: SIMD3<Float>(0, 1, 0)
        )
        let down = PoseSolver.twoBone(
            root: root, target: target, poleHint: SIMD3<Float>(0.5, -1, 0),
            upper: 0.6, lower: 0.58, fallbackBend: SIMD3<Float>(0, 1, 0)
        )

        #expect(up.joint.y > 0.1)
        #expect(down.joint.y < -0.1)
    }

    @Test("Settling lifts a sunken pose without deforming it")
    func settlingPreservesShape() {
        let pose = MotionLibrary.pose(for: .plank, phase: 0.2)
        let sunken = PoseSolver.translate(pose, by: SIMD3<Float>(0, -0.4, 0))
        let settled = PoseSolver.settle(sunken, groundLevel: MotionLibrary.groundLevel)

        #expect((settled.joints.map(\.y).min() ?? 0) >= MotionLibrary.groundLevel - 0.001)
        for bone in BodyPose.bones {
            #expect(abs(settled.length(of: bone) - pose.length(of: bone)) < 0.0005)
        }
    }

    @Test("Settling leaves a pose already above the mat untouched")
    func settlingIsANoOpWhenClear() {
        let pose = MotionLibrary.pose(for: .legRaise, phase: 0.5)
        let settled = PoseSolver.settle(pose, groundLevel: -5)

        for (original, result) in zip(pose.joints, settled.joints) {
            #expect(simd_distance(original, result) < 0.0001)
        }
    }

    @Test("Anchoring plants the chosen joint exactly")
    func anchoringMovesTheWholeBody() {
        let pose = MotionLibrary.pose(for: .bridge, phase: 0.3)
        let target = SIMD3<Float>(-1, 2, 0.5)
        let anchored = PoseSolver.anchor(pose, joint: \.chest, to: target)

        #expect(simd_distance(anchored.chest, target) < 0.0001)
        for bone in BodyPose.bones {
            #expect(abs(anchored.length(of: bone) - pose.length(of: bone)) < 0.0005)
        }
    }

    @Test("Skeleton proportions are anatomically plausible")
    func proportionsAreSane() {
        let metrics = SkeletonMetrics.standard
        var worst: [String: (Float, String)] = [:]

        #expect(metrics.thigh > metrics.shin, "the femur is the longest bone in the body")
        #expect(metrics.upperArm > metrics.forearm)
        #expect(metrics.thigh > metrics.upperArm, "legs are longer than arms")
        #expect(metrics.shoulderHalfWidth > metrics.hipHalfWidth)
        #expect(metrics.spine > metrics.neck && metrics.neck > metrics.skull)
    }
}

/// Guards the choreography itself, before the solver gets a chance to hide it.
///
/// Scoped deliberately to the axial attachment bones. Limbs and the head are
/// authored by aiming them at targets — a hand reaches for a heel — so their
/// authored lengths drift and the solver normalising them is the design. The
/// spine, the clavicles and the pelvis half-spans aim at nothing: they are body
/// constants, so authoring them wrong is always a mistake.
///
/// This is what the squat did. Moving the pelvis without the hips and chest
/// stretched the spine from 0.58 to 0.85; the solver rescaled it back to
/// canonical length, so every bone assertion on the finished pose passed while
/// the figure rendered as a slab tipped hard forward — rescaling preserved the
/// wrong direction. The same mistake was in the bridge, both push-ups and the
/// calf raise.
@Suite("Choreography consistency")
struct ChoreographyTests {
    static let axialBones = ["spine", "leftClavicle", "rightClavicle", "leftPelvis", "rightPelvis"]

    @Test("Body constants are authored at their real size")
    func sketchesRespectAxialBones() {
        let metrics = SkeletonMetrics.standard

        for motion in MotionSystemTests.allMotions {
            for step in 0..<32 {
                let phase = Float(step) / 32
                let pose = MotionLibrary.sketch(for: motion, phase: phase).pose

                for bone in BodyPose.bones where Self.axialBones.contains(bone.name) {
                    let authored = length(of: pose[keyPath: bone.end] - pose[keyPath: bone.start])
                    let canonical = metrics[keyPath: bone.length]
                    #expect(
                        abs(authored - canonical) <= canonical * 0.25,
                        "\(motion.rawValue) at \(phase) authors \(bone.name) at \(authored), not \(canonical)"
                    )
                }
            }
        }
    }

    @Test("Feet stay planted when the hips rise over them")
    func plantedFeetDoNotFollowTheHips() {
        // A glute bridge that lifts the feet is not a glute bridge. The thigh
        // is a fixed bone, so raising the hips without rotating it stretches
        // the thigh, and the solver pays for the extra length by dragging the
        // ankle off the mat.
        for motion in [MotionKind.bridge, .bridgeMarch] {
            let planted = (0..<32).map { step -> Float in
                let pose = MotionLibrary.pose(for: motion, phase: Float(step) / 32)
                return min(pose.leftAnkle.y, pose.rightAnkle.y)
            }
            let lift = (planted.max() ?? 0) - (planted.min() ?? 0)
            #expect(lift < 0.06, "\(motion.rawValue) lifts its planted foot by \(lift)")
        }
    }

    private func length(of vector: SIMD3<Float>) -> Float {
        (vector * vector).sum().squareRoot()
    }
}
