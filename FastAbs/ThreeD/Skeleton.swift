import Foundation
import simd

/// The compact, renderer-facing representation of a human pose.
///
/// Positions use RealityKit's right-handed coordinates: X runs from head to
/// feet, Y points up from the mat, and Z separates the left and right sides.
struct BodyPose: Equatable, Sendable {
    var head: SIMD3<Float>
    var neck: SIMD3<Float>
    var chest: SIMD3<Float>
    var pelvis: SIMD3<Float>
    var leftShoulder: SIMD3<Float>
    var rightShoulder: SIMD3<Float>
    var leftElbow: SIMD3<Float>
    var rightElbow: SIMD3<Float>
    var leftHand: SIMD3<Float>
    var rightHand: SIMD3<Float>
    var leftHip: SIMD3<Float>
    var rightHip: SIMD3<Float>
    var leftKnee: SIMD3<Float>
    var rightKnee: SIMD3<Float>
    var leftAnkle: SIMD3<Float>
    var rightAnkle: SIMD3<Float>
}

extension BodyPose {
    /// The direction the athlete's chest faces.
    var front: SIMD3<Float> {
        BodyPose.normalised(
            simd_cross(leftShoulder - rightShoulder, chest - pelvis),
            fallback: SIMD3<Float>(0, 0, 1)
        )
    }

    /// The direction from hips to shoulders.
    var up: SIMD3<Float> {
        BodyPose.normalised(chest - pelvis, fallback: SIMD3<Float>(0, 1, 0))
    }

    /// Height at which a joint is considered to be resting on the mat.
    static let matHeight: Float = 0.11

    var leftToe: SIMD3<Float> { toe(ankle: leftAnkle, knee: leftKnee) }
    var rightToe: SIMD3<Float> { toe(ankle: rightAnkle, knee: rightKnee) }

    /// The foot points the way the body faces, leaning a little further along
    /// the shin — lying on your back your toes point up, in a plank they point
    /// at the floor, standing they point ahead.
    ///
    /// It used to be the facing direction with the shin component projected out,
    /// which is square to the shin but collapses whenever the two line up —
    /// legs raised vertically while lying on your back is exactly that case, and
    /// there the direction flipped between frames. Two stable vectors in fixed
    /// proportion cannot collapse: the weights are chosen so they never cancel,
    /// even when the shin and the facing are opposed.
    private func toe(ankle: SIMD3<Float>, knee: SIMD3<Float>) -> SIMD3<Float> {
        let shin = BodyPose.normalised(ankle - knee, fallback: SIMD3<Float>(0, -1, 0))
        let forward = BodyPose.normalised(
            front * 0.9 + shin * 0.35,
            fallback: SIMD3<Float>(0, 0, 1)
        )
        let length: Float = 0.148
        var direction = BodyPose.normalised(forward * 0.98 + shin * 0.2, fallback: forward)

        // A foot that would go through the mat tilts up to lie along it rather
        // than being cut off at mat height, which left a backward stub instead
        // of a foot. Letting the toes pull the whole athlete up instead made the
        // body jump whenever a foot swung low, so the foot alone gives way.
        if ankle.y + direction.y * length < BodyPose.matHeight {
            let rise = min(max((BodyPose.matHeight - ankle.y) / length, -1), 1)
            let flat = SIMD3<Float>(direction.x, 0, direction.z)
            let flatLength = simd_length(flat)
            let spread = (1 - rise * rise).squareRoot()
            direction = flatLength > 1e-5
                ? SIMD3<Float>(flat.x / flatLength * spread, rise, flat.z / flatLength * spread)
                : SIMD3<Float>(0, rise, 0)
        }
        return ankle + direction * length
    }

    static func normalised(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 1e-5 ? vector / length : simd_normalize(fallback)
    }
}

/// Fixed bone lengths for the avatar.
///
/// Poses are authored as target *points* because that is how a movement reads
/// on screen, but points alone let a limb stretch whenever two keyframes are
/// blended. `SkeletonMetrics` is the single source of truth for how long each
/// bone may ever be; `PoseSolver` enforces it.
struct SkeletonMetrics: Equatable, Sendable {
    var spine: Float
    var neck: Float
    var skull: Float
    var shoulderHalfWidth: Float
    var hipHalfWidth: Float
    var upperArm: Float
    var forearm: Float
    var thigh: Float
    var shin: Float

    /// Proportions of the on-screen athlete, tuned so the standing height and
    /// the mat footprint match the camera framing used by the renderer.
    /// Taken from adult human ratios scaled so the hip-to-sternum span is 0.58.
    /// The earlier set gave the athlete legs more than twice the length of the
    /// torso and a neck a third of its height, which is why it read as a puppet.
    static let standard = SkeletonMetrics(
        spine: 0.58,
        neck: 0.26,
        skull: 0.13,
        shoulderHalfWidth: 0.25,
        hipHalfWidth: 0.155,
        upperArm: 0.38,
        forearm: 0.32,
        thigh: 0.52,
        shin: 0.5
    )
}

/// Describes one rigid segment so anatomy can be walked generically.
struct BoneDescriptor: Sendable {
    let name: String
    let start: any KeyPath<BodyPose, SIMD3<Float>> & Sendable
    let end: any KeyPath<BodyPose, SIMD3<Float>> & Sendable
    let length: any KeyPath<SkeletonMetrics, Float> & Sendable
}

extension BodyPose {
    /// Every rigid segment of the avatar, parent before child.
    static let bones: [BoneDescriptor] = [
        BoneDescriptor(name: "spine", start: \.pelvis, end: \.chest, length: \.spine),
        BoneDescriptor(name: "neck", start: \.chest, end: \.neck, length: \.neck),
        BoneDescriptor(name: "skull", start: \.neck, end: \.head, length: \.skull),
        BoneDescriptor(name: "leftClavicle", start: \.chest, end: \.leftShoulder, length: \.shoulderHalfWidth),
        BoneDescriptor(name: "rightClavicle", start: \.chest, end: \.rightShoulder, length: \.shoulderHalfWidth),
        BoneDescriptor(name: "leftPelvis", start: \.pelvis, end: \.leftHip, length: \.hipHalfWidth),
        BoneDescriptor(name: "rightPelvis", start: \.pelvis, end: \.rightHip, length: \.hipHalfWidth),
        BoneDescriptor(name: "leftUpperArm", start: \.leftShoulder, end: \.leftElbow, length: \.upperArm),
        BoneDescriptor(name: "rightUpperArm", start: \.rightShoulder, end: \.rightElbow, length: \.upperArm),
        BoneDescriptor(name: "leftForearm", start: \.leftElbow, end: \.leftHand, length: \.forearm),
        BoneDescriptor(name: "rightForearm", start: \.rightElbow, end: \.rightHand, length: \.forearm),
        BoneDescriptor(name: "leftThigh", start: \.leftHip, end: \.leftKnee, length: \.thigh),
        BoneDescriptor(name: "rightThigh", start: \.rightHip, end: \.rightKnee, length: \.thigh),
        BoneDescriptor(name: "leftShin", start: \.leftKnee, end: \.leftAnkle, length: \.shin),
        BoneDescriptor(name: "rightShin", start: \.rightKnee, end: \.rightAnkle, length: \.shin)
    ]

    /// All joints, for bulk numeric checks.
    var joints: [SIMD3<Float>] {
        [
            head, neck, chest, pelvis,
            leftShoulder, rightShoulder,
            leftElbow, rightElbow,
            leftHand, rightHand,
            leftHip, rightHip,
            leftKnee, rightKnee,
            leftAnkle, rightAnkle
        ]
    }

    func length(of bone: BoneDescriptor) -> Float {
        simd_distance(self[keyPath: bone.start], self[keyPath: bone.end])
    }
}

/// Re-projects a sketched pose onto a rigid skeleton.
///
/// Choreography blends between keyframes, and a naive blend of two joint
/// positions shortens the bone between them — the limb visibly rubber-bands.
///
/// The axial skeleton (pelvis, spine, neck, skull, shoulder and hip spans) is
/// resolved forward: each joint keeps the direction the choreography asked for
/// and gets its canonical length back. The four limbs are resolved by two-bone
/// inverse kinematics instead, because for a limb it is the *end* that carries
/// the intent — a hand planted on the mat has to stay planted, and only the
/// elbow is free to move. The authored elbow and knee positions survive as pole
/// hints that decide which way the joint bends.
enum PoseSolver {
    static func solve(_ pose: BodyPose, metrics: SkeletonMetrics = .standard) -> BodyPose {
        var solved = pose
        let up = SIMD3<Float>(0, 1, 0)

        solved.chest = project(from: pose.pelvis, toward: pose.chest, length: metrics.spine, fallback: up)
        let spineDirection = direction(from: pose.pelvis, to: solved.chest, fallback: up)

        solved.neck = project(from: solved.chest, toward: pose.neck, length: metrics.neck, fallback: spineDirection)
        let neckDirection = direction(from: solved.chest, to: solved.neck, fallback: spineDirection)
        solved.head = project(from: solved.neck, toward: pose.head, length: metrics.skull, fallback: neckDirection)

        solved.leftShoulder = project(
            from: solved.chest,
            toward: pose.leftShoulder,
            length: metrics.shoulderHalfWidth,
            fallback: SIMD3<Float>(0, 0, 1)
        )
        solved.rightShoulder = project(
            from: solved.chest,
            toward: pose.rightShoulder,
            length: metrics.shoulderHalfWidth,
            fallback: SIMD3<Float>(0, 0, -1)
        )
        solved.leftHip = project(
            from: pose.pelvis,
            toward: pose.leftHip,
            length: metrics.hipHalfWidth,
            fallback: SIMD3<Float>(0, 0, 1)
        )
        solved.rightHip = project(
            from: pose.pelvis,
            toward: pose.rightHip,
            length: metrics.hipHalfWidth,
            fallback: SIMD3<Float>(0, 0, -1)
        )

        // A knee bends toward the belly and an elbow away from it. Deriving both
        // from the torso frame gives every limb a stable bend direction even
        // when the authored hint happens to line up with the limb itself.
        let bodyFront = safeDirection(
            simd_cross(spineDirection, solved.leftShoulder - solved.rightShoulder),
            fallback: up
        )

        let leftArm = twoBone(
            root: solved.leftShoulder,
            target: pose.leftHand,
            poleHint: pose.leftElbow,
            upper: metrics.upperArm,
            lower: metrics.forearm,
            fallbackBend: -bodyFront
        )
        solved.leftElbow = leftArm.joint
        solved.leftHand = leftArm.end

        let rightArm = twoBone(
            root: solved.rightShoulder,
            target: pose.rightHand,
            poleHint: pose.rightElbow,
            upper: metrics.upperArm,
            lower: metrics.forearm,
            fallbackBend: -bodyFront
        )
        solved.rightElbow = rightArm.joint
        solved.rightHand = rightArm.end

        let leftLeg = twoBone(
            root: solved.leftHip,
            target: pose.leftAnkle,
            poleHint: pose.leftKnee,
            upper: metrics.thigh,
            lower: metrics.shin,
            fallbackBend: bodyFront
        )
        solved.leftKnee = leftLeg.joint
        solved.leftAnkle = leftLeg.end

        let rightLeg = twoBone(
            root: solved.rightHip,
            target: pose.rightAnkle,
            poleHint: pose.rightKnee,
            upper: metrics.thigh,
            lower: metrics.shin,
            fallbackBend: bodyFront
        )
        solved.rightKnee = rightLeg.joint
        solved.rightAnkle = rightLeg.end

        return solved
    }

    /// Places a two-bone chain so its end reaches `target` without either bone
    /// changing length.
    ///
    /// Targets beyond reach clamp to a straight limb pointing at them, and
    /// targets too close to the root push out to the minimum fold, so the chain
    /// degrades gracefully instead of producing NaN.
    static func twoBone(
        root: SIMD3<Float>,
        target: SIMD3<Float>,
        poleHint: SIMD3<Float>,
        upper: Float,
        lower: Float,
        fallbackBend: SIMD3<Float>
    ) -> (joint: SIMD3<Float>, end: SIMD3<Float>) {
        let reach = direction(from: root, to: target, fallback: fallbackBend)
        let minimum = abs(upper - lower) + 0.002
        let maximum = upper + lower - 0.002
        let distance = min(max(simd_distance(root, target), minimum), maximum)
        let end = root + reach * distance

        // Law of cosines: how far along the root-to-end axis the joint sits,
        // and how far it swings off that axis.
        let axial = (distance * distance + upper * upper - lower * lower) / (2 * distance)
        let radial = (upper * upper - axial * axial).squareRoot()
        let offset = radial.isFinite ? radial : 0

        return (root + reach * axial + bendDirection(
            poleHint: poleHint - root,
            fallback: fallbackBend,
            axis: reach
        ) * offset, end)
    }

    /// Which way the middle joint swings off the root-to-end axis.
    ///
    /// The authored hint decides, because it carries the choreography's intent.
    /// A hint lying almost along the limb has an almost-zero perpendicular and
    /// its direction becomes numerically unstable, so the anatomical fallback
    /// takes over — but the real defence is that `MotionSystemTests` fails on
    /// any hint weak enough to make a joint snap between frames.
    private static func bendDirection(
        poleHint: SIMD3<Float>,
        fallback: SIMD3<Float>,
        axis: SIMD3<Float>
    ) -> SIMD3<Float> {
        for candidate in [poleHint, fallback, SIMD3<Float>(0, 1, 0), SIMD3<Float>(1, 0, 0)] {
            let offAxis = perpendicular(of: candidate, relativeTo: axis)
            if simd_length(offAxis) > 0.0005 {
                return simd_normalize(offAxis)
            }
        }
        return SIMD3<Float>(0, 1, 0)
    }

    private static func perpendicular(
        of vector: SIMD3<Float>,
        relativeTo axis: SIMD3<Float>
    ) -> SIMD3<Float> {
        guard vector.x.isFinite, vector.y.isFinite, vector.z.isFinite else { return .zero }
        return vector - axis * simd_dot(vector, axis)
    }

    static func safeDirection(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 0.0001 ? vector / length : simd_normalize(fallback)
    }

    /// Shifts the whole pose so `joint` lands exactly on `target`.
    ///
    /// The solver is rooted at the pelvis, which is wrong for movements where
    /// something else is planted: during a glute bridge the shoulders stay on
    /// the mat and the hips travel, not the reverse. Re-anchoring after solving
    /// restores the contact the choreography intended.
    static func anchor(
        _ pose: BodyPose,
        joint: KeyPath<BodyPose, SIMD3<Float>>,
        to target: SIMD3<Float>
    ) -> BodyPose {
        translate(pose, by: target - pose[keyPath: joint])
    }

    /// Lifts a solved pose so nothing sinks below the mat.
    ///
    /// Applied after solving because restoring bone lengths can push a heel or
    /// a wrist through the floor, and a limb clipping the ground reads as a
    /// glitch far more than a body resting a few millimetres high.
    static func settle(_ pose: BodyPose, groundLevel: Float) -> BodyPose {
        let lowest = pose.joints.map(\.y).min() ?? groundLevel
        guard lowest < groundLevel else { return pose }

        return translate(pose, by: SIMD3<Float>(0, groundLevel - lowest, 0))
    }

    static func translate(_ pose: BodyPose, by offset: SIMD3<Float>) -> BodyPose {
        var moved = pose
        moved.head += offset
        moved.neck += offset
        moved.chest += offset
        moved.pelvis += offset
        moved.leftShoulder += offset
        moved.rightShoulder += offset
        moved.leftElbow += offset
        moved.rightElbow += offset
        moved.leftHand += offset
        moved.rightHand += offset
        moved.leftHip += offset
        moved.rightHip += offset
        moved.leftKnee += offset
        moved.rightKnee += offset
        moved.leftAnkle += offset
        moved.rightAnkle += offset
        return moved
    }

    private static func project(
        from origin: SIMD3<Float>,
        toward target: SIMD3<Float>,
        length: Float,
        fallback: SIMD3<Float>
    ) -> SIMD3<Float> {
        origin + direction(from: origin, to: target, fallback: fallback) * length
    }

    private static func direction(
        from origin: SIMD3<Float>,
        to target: SIMD3<Float>,
        fallback: SIMD3<Float>
    ) -> SIMD3<Float> {
        let vector = target - origin
        let distance = simd_length(vector)
        guard distance > 0.0001, vector.x.isFinite, vector.y.isFinite, vector.z.isFinite else {
            return simd_normalize(fallback)
        }
        return vector / distance
    }
}
