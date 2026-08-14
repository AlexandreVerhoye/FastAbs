import RealityKit
import UIKit
import simd

/// The white-to-red ramp used to show how hard a muscle is working.
///
/// Materials are precomputed into a ladder because intensity changes every
/// frame: building a `SimpleMaterial` per muscle per frame churns the renderer,
/// while quantising to a fixed number of steps is visually indistinguishable.
@MainActor
enum MuscleHeatPalette {
    static let stepCount = 18

    /// Resting muscle is the same white as the rest of the body, so an
    /// unworked group simply disappears into the silhouette.
    static let restingColor = UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
    static let workingColor = UIColor(red: 0.99, green: 0.36, blue: 0.31, alpha: 1)
    static let peakColor = UIColor(red: 0.83, green: 0.05, blue: 0.11, alpha: 1)

    static func step(for intensity: Float) -> Int {
        guard intensity.isFinite else { return 0 }
        let clamped = min(max(intensity, 0), 1)
        return Int((clamped * Float(stepCount - 1)).rounded())
    }

    static func material(atStep step: Int) -> SimpleMaterial {
        ladder[min(max(step, 0), stepCount - 1)]
    }

    static func color(for intensity: Float) -> UIColor {
        let clamped = min(max(intensity.isFinite ? intensity : 0, 0), 1)
        if clamped <= 0.5 {
            return blend(restingColor, workingColor, t: clamped * 2)
        }
        return blend(workingColor, peakColor, t: (clamped - 0.5) * 2)
    }

    private static let ladder: [SimpleMaterial] = (0..<stepCount).map { step in
        let intensity = Float(step) / Float(stepCount - 1)
        return SimpleMaterial(
            color: color(for: intensity),
            // A working muscle picks up a little more sheen, which reads as
            // tension rather than as a different material.
            roughness: .float(0.58 - intensity * 0.2),
            isMetallic: false
        )
    }

    private static func blend(_ from: UIColor, _ to: UIColor, t: Float) -> UIColor {
        var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        let amount = CGFloat(min(max(t, 0), 1))
        return UIColor(
            red: fromRed + (toRed - fromRed) * amount,
            green: fromGreen + (toGreen - fromGreen) * amount,
            blue: fromBlue + (toBlue - fromBlue) * amount,
            alpha: 1
        )
    }
}

/// Proportions of the on-screen athlete, in scene units.
///
/// Collected in one place because the figure only reads as a body when the
/// pieces agree: a joint has to be as wide as the limbs it connects, and the
/// torso has to be narrower than the shoulders sitting on top of it, or the
/// silhouette turns into a single blob.
@MainActor
enum AvatarProportions {
    static let torsoHalfWidth: Float = 0.215
    static let torsoWaistRatio: Float = 0.78
    static let torsoDepthScale: Float = 0.55

    static let shoulderJoint: Float = 0.09
    static let elbowJoint: Float = 0.062
    static let hipJoint: Float = 0.1
    static let kneeJoint: Float = 0.082

    static let headScale = SIMD3<Float>(0.1, 0.122, 0.096)
    static let handScale = SIMD3<Float>(0.052, 0.075, 0.045)
    static let footScale = SIMD3<Float>(0.068, 0.115, 0.058)
}

/// A faceless, non-gendered athlete rendered in a single white material, with
/// the abdominal wall picked out in a red heat map.
///
/// Segments are joined by spheres sized to the limbs they connect, so the body
/// reads as one continuous form rather than a pile of separate capsules. Every
/// mesh is shared and never changes; a frame only updates transforms and, when
/// a muscle crosses into the next intensity step, one material reference.
@MainActor
final class ProceduralBody {
    let root = Entity()

    private let head: ModelEntity
    private let neck: ModelEntity
    private let torso: ModelEntity
    private let pelvis: ModelEntity
    private let leftUpperArm: ModelEntity
    private let leftForearm: ModelEntity
    private let rightUpperArm: ModelEntity
    private let rightForearm: ModelEntity
    private let leftThigh: ModelEntity
    private let leftShin: ModelEntity
    private let rightThigh: ModelEntity
    private let rightShin: ModelEntity
    private let leftHand: ModelEntity
    private let rightHand: ModelEntity
    private let leftFoot: ModelEntity
    private let rightFoot: ModelEntity

    /// Sphere caps that hide the seam where two segments meet.
    private let leftShoulderJoint: ModelEntity
    private let rightShoulderJoint: ModelEntity
    private let leftElbowJoint: ModelEntity
    private let rightElbowJoint: ModelEntity
    private let leftHipJoint: ModelEntity
    private let rightHipJoint: ModelEntity
    private let leftKneeJoint: ModelEntity
    private let rightKneeJoint: ModelEntity

    private var panels: [MusclePanel]

    init() {
        let skin = SimpleMaterial(
            color: MuscleHeatPalette.restingColor,
            roughness: .float(0.55),
            isMetallic: false
        )
        func part(_ mesh: MeshResource) -> ModelEntity {
            ModelEntity(mesh: mesh, materials: [skin])
        }

        head = part(AvatarMeshLibrary.sphere)
        neck = part(AvatarMeshLibrary.neck)
        torso = part(AvatarMeshLibrary.torso)
        pelvis = part(AvatarMeshLibrary.pelvis)
        leftUpperArm = part(AvatarMeshLibrary.upperArm)
        leftForearm = part(AvatarMeshLibrary.forearm)
        rightUpperArm = part(AvatarMeshLibrary.upperArm)
        rightForearm = part(AvatarMeshLibrary.forearm)
        leftThigh = part(AvatarMeshLibrary.thigh)
        leftShin = part(AvatarMeshLibrary.shin)
        rightThigh = part(AvatarMeshLibrary.thigh)
        rightShin = part(AvatarMeshLibrary.shin)
        leftHand = part(AvatarMeshLibrary.sphere)
        rightHand = part(AvatarMeshLibrary.sphere)
        leftFoot = part(AvatarMeshLibrary.sphere)
        rightFoot = part(AvatarMeshLibrary.sphere)

        leftShoulderJoint = part(AvatarMeshLibrary.sphere)
        rightShoulderJoint = part(AvatarMeshLibrary.sphere)
        leftElbowJoint = part(AvatarMeshLibrary.sphere)
        rightElbowJoint = part(AvatarMeshLibrary.sphere)
        leftHipJoint = part(AvatarMeshLibrary.sphere)
        rightHipJoint = part(AvatarMeshLibrary.sphere)
        leftKneeJoint = part(AvatarMeshLibrary.sphere)
        rightKneeJoint = part(AvatarMeshLibrary.sphere)

        panels = MusclePanel.abdominalWall()

        let entities: [Entity] = [
            torso, pelvis, neck, head,
            leftUpperArm, leftForearm, rightUpperArm, rightForearm,
            leftThigh, leftShin, rightThigh, rightShin,
            leftHand, rightHand, leftFoot, rightFoot,
            leftShoulderJoint, rightShoulderJoint,
            leftElbowJoint, rightElbowJoint,
            leftHipJoint, rightHipJoint,
            leftKneeJoint, rightKneeJoint
        ]
        entities.forEach { root.addChild($0) }
        panels.forEach { torso.addChild($0.entity) }
        seatMusclePanels()
    }

    func update(pose: BodyPose, activation: MuscleActivation, viewer: SIMD3<Float>) {
        let shoulderCenter = (pose.leftShoulder + pose.rightShoulder) * 0.5
        let torsoAxis = shoulderCenter - pose.pelvis
        let torsoDirection = Self.safeNormalize(torsoAxis, fallback: SIMD3<Float>(0, 1, 0))
        let shoulderAxis = pose.leftShoulder - pose.rightShoulder

        Self.placeVolume(
            torso,
            from: pose.pelvis - torsoDirection * 0.04,
            to: shoulderCenter + torsoDirection * 0.06,
            widthAxis: shoulderAxis,
            depthScale: AvatarProportions.torsoDepthScale,
            viewer: viewer
        )
        Self.placeCenteredVolume(
            pelvis,
            center: pose.pelvis - torsoDirection * 0.03,
            heightAxis: torsoAxis,
            widthAxis: pose.leftHip - pose.rightHip,
            length: 0.3,
            depthScale: 0.66,
            viewer: viewer
        )

        // The rendered neck is shorter than the anatomical one: a full-length
        // neck on a stylised figure reads as a giraffe.
        let visualNeck = shoulderCenter + (pose.neck - shoulderCenter) * 0.2
        let headDirection = Self.safeNormalize(pose.head - pose.neck, fallback: torsoDirection)
        let visualHead = visualNeck + headDirection * min(simd_distance(pose.head, pose.neck) * 0.82, 0.2)
        // The neck starts inside the torso so the two always overlap; the head
        // then caps it. Starting at the joint itself left a gap at the collar.
        Self.placeLimb(neck, from: shoulderCenter - torsoDirection * 0.06, to: visualHead)

        Self.placeLimb(leftUpperArm, from: pose.leftShoulder, to: pose.leftElbow)
        Self.placeLimb(leftForearm, from: pose.leftElbow, to: pose.leftHand)
        Self.placeLimb(rightUpperArm, from: pose.rightShoulder, to: pose.rightElbow)
        Self.placeLimb(rightForearm, from: pose.rightElbow, to: pose.rightHand)
        Self.placeLimb(leftThigh, from: pose.leftHip, to: pose.leftKnee)
        Self.placeLimb(leftShin, from: pose.leftKnee, to: pose.leftAnkle)
        Self.placeLimb(rightThigh, from: pose.rightHip, to: pose.rightKnee)
        Self.placeLimb(rightShin, from: pose.rightKnee, to: pose.rightAnkle)

        Self.placeJoint(leftShoulderJoint, at: pose.leftShoulder, radius: AvatarProportions.shoulderJoint)
        Self.placeJoint(rightShoulderJoint, at: pose.rightShoulder, radius: AvatarProportions.shoulderJoint)
        Self.placeJoint(leftElbowJoint, at: pose.leftElbow, radius: AvatarProportions.elbowJoint)
        Self.placeJoint(rightElbowJoint, at: pose.rightElbow, radius: AvatarProportions.elbowJoint)
        Self.placeJoint(leftHipJoint, at: pose.leftHip, radius: AvatarProportions.hipJoint)
        Self.placeJoint(rightHipJoint, at: pose.rightHip, radius: AvatarProportions.hipJoint)
        Self.placeJoint(leftKneeJoint, at: pose.leftKnee, radius: AvatarProportions.kneeJoint)
        Self.placeJoint(rightKneeJoint, at: pose.rightKnee, radius: AvatarProportions.kneeJoint)

        Self.placeHead(head, at: visualHead, neck: visualNeck)
        Self.placeHand(leftHand, at: pose.leftHand, elbow: pose.leftElbow)
        Self.placeHand(rightHand, at: pose.rightHand, elbow: pose.rightElbow)
        Self.placeFoot(leftFoot, ankle: pose.leftAnkle, knee: pose.leftKnee)
        Self.placeFoot(rightFoot, ankle: pose.rightAnkle, knee: pose.rightKnee)

        applyHeat(activation)
    }
}

// MARK: - Muscle panels

/// One band of the abdominal wall and the group whose intensity drives it.
///
/// Panels live as children of the torso, so they follow it automatically and
/// inherit its elliptical cross-section instead of having to reconstruct it.
@MainActor
struct MusclePanel {
    enum Group {
        case upperAbs, lowerAbs, leftOblique, rightOblique
    }

    let entity: ModelEntity
    let group: Group
    /// Centre of the band along the torso, in the torso's own mesh space where
    /// -0.5 is the hips and +0.5 the shoulders.
    let height: Float
    /// How much of the torso's length the band covers.
    let bandHeight: Float
    /// Angle around the torso, measured from the front of the body. Positive
    /// angles wrap toward the athlete's left.
    let centerAngle: Float
    let halfWidth: Float

    fileprivate var appliedStep: Int = -1

    /// Four rectus segments in two rows, plus the two oblique bands.
    static func abdominalWall() -> [MusclePanel] {
        let column = Float.pi / 180 * 21
        let rectusHalfWidth = Float.pi / 180 * 18
        let obliqueHalfWidth = Float.pi / 180 * 21

        return [
            make(group: .upperAbs, height: 0.07, bandHeight: 0.19, centerAngle: column, halfWidth: rectusHalfWidth),
            make(group: .upperAbs, height: 0.07, bandHeight: 0.19, centerAngle: -column, halfWidth: rectusHalfWidth),
            make(group: .lowerAbs, height: -0.15, bandHeight: 0.19, centerAngle: column, halfWidth: rectusHalfWidth),
            make(group: .lowerAbs, height: -0.15, bandHeight: 0.19, centerAngle: -column, halfWidth: rectusHalfWidth),
            make(
                group: .leftOblique,
                height: -0.05,
                bandHeight: 0.32,
                centerAngle: .pi / 180 * 62,
                halfWidth: obliqueHalfWidth
            ),
            make(
                group: .rightOblique,
                height: -0.05,
                bandHeight: 0.32,
                centerAngle: .pi / 180 * -62,
                halfWidth: obliqueHalfWidth
            )
        ]
    }

    private static func make(
        group: Group,
        height: Float,
        bandHeight: Float,
        centerAngle: Float,
        halfWidth: Float
    ) -> MusclePanel {
        MusclePanel(
            entity: ModelEntity(
                mesh: AvatarMeshLibrary.muscleShell(centerAngle: centerAngle, halfWidth: halfWidth).resource,
                materials: [MuscleHeatPalette.material(atStep: 0)]
            ),
            group: group,
            height: height,
            bandHeight: bandHeight,
            centerAngle: centerAngle,
            halfWidth: halfWidth
        )
    }

    func intensity(in activation: MuscleActivation) -> Float {
        switch group {
        case .upperAbs: activation.upperAbs
        case .lowerAbs: activation.lowerAbs
        case .leftOblique: activation.leftOblique
        case .rightOblique: activation.rightOblique
        }
    }
}

private extension ProceduralBody {
    /// Seats every band on the torso's surface at its own height.
    ///
    /// Called once at build time: because the panels are children of the torso,
    /// nothing here has to be recomputed as the athlete moves.
    func seatMusclePanels() {
        for panel in panels {
            // The torso tapers, so a band low on the abdomen sits on a narrower
            // section than one up by the ribs.
            let along = panel.height + 0.5
            let radius = AvatarMeshLibrary.torsoBottomRadius
                + (AvatarMeshLibrary.torsoTopRadius - AvatarMeshLibrary.torsoBottomRadius) * along

            panel.entity.position = SIMD3<Float>(0, panel.height, 0)
            panel.entity.scale = SIMD3<Float>(radius, panel.bandHeight, radius)
        }
    }

    func applyHeat(_ activation: MuscleActivation) {
        for index in panels.indices {
            let step = MuscleHeatPalette.step(for: panels[index].intensity(in: activation))
            guard step != panels[index].appliedStep else { continue }
            panels[index].appliedStep = step
            panels[index].entity.model?.materials = [MuscleHeatPalette.material(atStep: step)]
        }
    }
}

// MARK: - Placement

private extension ProceduralBody {
    /// Segments run corner to corner with no overlap: the joint spheres cover
    /// the seam, so extending the capsules would only fatten the limb.
    static func placeLimb(_ entity: ModelEntity, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let vector = end - start
        let length = max(simd_length(vector), 0.001)
        entity.position = (start + end) * 0.5
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: vector / length)
        entity.scale = SIMD3<Float>(1, length, 1)
    }

    static func placeJoint(_ entity: ModelEntity, at point: SIMD3<Float>, radius: Float) {
        entity.position = point
        entity.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        entity.scale = SIMD3<Float>(repeating: radius)
    }

    static func placeVolume(
        _ entity: ModelEntity,
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        widthAxis: SIMD3<Float>,
        depthScale: Float,
        viewer: SIMD3<Float>
    ) {
        let heightAxis = end - start
        orient(
            entity,
            center: (start + end) * 0.5,
            widthAxis: widthAxis,
            heightAxis: heightAxis,
            scale: SIMD3<Float>(1, max(simd_length(heightAxis), 0.001), depthScale),
            viewer: viewer
        )
    }

    static func placeCenteredVolume(
        _ entity: ModelEntity,
        center: SIMD3<Float>,
        heightAxis: SIMD3<Float>,
        widthAxis: SIMD3<Float>,
        length: Float,
        depthScale: Float,
        viewer: SIMD3<Float>
    ) {
        orient(
            entity,
            center: center,
            widthAxis: widthAxis,
            heightAxis: heightAxis,
            scale: SIMD3<Float>(1, length, depthScale),
            viewer: viewer
        )
    }

    static func placeHead(_ entity: ModelEntity, at point: SIMD3<Float>, neck: SIMD3<Float>) {
        let direction = safeNormalize(point - neck, fallback: SIMD3<Float>(0, 1, 0))
        entity.position = point
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
        entity.scale = AvatarProportions.headScale
    }

    static func placeHand(_ entity: ModelEntity, at point: SIMD3<Float>, elbow: SIMD3<Float>) {
        let direction = safeNormalize(point - elbow, fallback: SIMD3<Float>(0, 1, 0))
        entity.position = point + direction * 0.02
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
        entity.scale = AvatarProportions.handScale
    }

    static func placeFoot(_ entity: ModelEntity, ankle: SIMD3<Float>, knee: SIMD3<Float>) {
        let shin = safeNormalize(ankle - knee, fallback: SIMD3<Float>(0, -1, 0))
        // The foot continues forward along the floor rather than along the shin,
        // otherwise a standing leg ends in a spike pointing into the mat.
        let forward = safeNormalize(
            SIMD3<Float>(shin.x, 0, shin.z) + SIMD3<Float>(0.6, 0, 0),
            fallback: SIMD3<Float>(1, 0, 0)
        )
        entity.position = ankle + forward * 0.055 - SIMD3<Float>(0, 0.02, 0)
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: forward)
        entity.scale = AvatarProportions.footScale
    }

    static func orient(
        _ entity: ModelEntity,
        center: SIMD3<Float>,
        widthAxis: SIMD3<Float>,
        heightAxis: SIMD3<Float>,
        scale: SIMD3<Float>,
        viewer: SIMD3<Float>
    ) {
        let yAxis = safeNormalize(heightAxis, fallback: SIMD3<Float>(0, 1, 0))
        var xAxis = safeNormalize(widthAxis, fallback: SIMD3<Float>(0, 0, 1))
        var zAxis = safeNormalize(simd_cross(xAxis, yAxis), fallback: SIMD3<Float>(0, 0, 1))
        if simd_dot(zAxis, viewer - center) < 0 {
            zAxis *= -1
        }
        xAxis = safeNormalize(simd_cross(yAxis, zAxis), fallback: xAxis)
        entity.position = center
        entity.orientation = simd_quatf(simd_float3x3(columns: (xAxis, yAxis, zAxis)))
        entity.scale = scale
    }

    static func safeNormalize(_ value: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(value)
        return length > 0.0001 ? value / length : fallback
    }
}
