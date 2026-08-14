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
            roughness: .float(0.55 - intensity * 0.2),
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

/// Where the abdominal map sits on the trunk, in the trunk's own space.
@MainActor
enum TorsoGeometry {
    /// Extent of the trunk volume along the spine, in rest space.
    static let base: Float = -0.06
    static let top: Float = 0.6
    static var span: Float { top - base }
    static var centre: Float { (base + top) * 0.5 }

    static let depthRatio: Float = 0.62

    /// Half-width of the trunk at a height along the spine, matching the
    /// volumes `BodySculpt` sculpts the body from.
    static func radius(atHeight height: Float) -> Float {
        let y = centre + height * span
        if y < 0.42 {
            let t = min(max((y - 0.02) / 0.4, 0), 1)
            return 0.15 + (0.163 - 0.15) * t
        }
        let t = min(max((y - 0.42) / 0.18, 0), 1)
        return 0.163 + (0.185 - 0.163) * t
    }
}

/// A faceless, non-gendered athlete rendered as one continuous white surface,
/// with the abdominal wall picked out in a red heat map.
///
/// The surface comes from `BodySculpt` and is deformed by skinning, so there are
/// no seams and no joint spheres to bulge — the silhouette stays unbroken in
/// every pose.
@MainActor
final class ProceduralBody {
    let root = Entity()

    /// Built once per process: sculpting is far too expensive to repeat, and
    /// the result never changes.
    private static let sculpt = BodySculpt.build()

    private let skin: ModelEntity
    private let torsoFrame = Entity()
    private var panels: [MusclePanel]

    private var positions: [SIMD3<Float>]
    private var normals: [SIMD3<Float>]

    init() {
        let sculpt = Self.sculpt
        positions = sculpt.positions
        normals = sculpt.normals

        let material = SimpleMaterial(
            color: MuscleHeatPalette.restingColor,
            roughness: .float(0.55),
            isMetallic: false
        )
        skin = ModelEntity(
            mesh: Self.makeMesh(
                positions: sculpt.positions,
                normals: sculpt.normals,
                indices: sculpt.indices
            ),
            materials: [material]
        )
        panels = MusclePanel.abdominalWall()

        root.addChild(skin)
        root.addChild(torsoFrame)
        panels.forEach { torsoFrame.addChild($0.entity) }
        seatMusclePanels()
    }

    func update(pose: BodyPose, activation: MuscleActivation, viewer: SIMD3<Float>) {
        let transforms = BodySkinner.transforms(for: pose)
        BodySkinner.apply(transforms, to: Self.sculpt, positions: &positions, normals: &normals)

        skin.model?.mesh = Self.makeMesh(
            positions: positions,
            normals: normals,
            indices: Self.sculpt.indices
        )

        placeTorsoFrame(pose: pose)
        applyHeat(activation)
    }
}

private extension ProceduralBody {
    static func makeMesh(
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32]
    ) -> MeshResource {
        var descriptor = MeshDescriptor(name: "FastAbs athlete")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            return .generateSphere(radius: 0.2)
        }
    }

    /// Aligns the abdominal map with the trunk of the skinned body.
    func placeTorsoFrame(pose: BodyPose) {
        let up = pose.chest - pose.pelvis
        let across = pose.leftShoulder - pose.rightShoulder
        let yAxis = Self.safeNormalize(up, fallback: SIMD3<Float>(0, 1, 0))
        let zAxis = Self.safeNormalize(simd_cross(across, up), fallback: SIMD3<Float>(0, 0, 1))
        let xAxis = simd_cross(yAxis, zAxis)

        torsoFrame.position = pose.pelvis
        torsoFrame.orientation = simd_quatf(simd_float3x3(columns: (xAxis, yAxis, zAxis)))
    }

    /// Seats every band on the trunk. Called once: the bands are children of the
    /// torso frame, so they follow the body without further work.
    func seatMusclePanels() {
        for panel in panels {
            let radius = TorsoGeometry.radius(atHeight: panel.height)
            panel.entity.position = SIMD3<Float>(
                0,
                TorsoGeometry.centre + panel.height * TorsoGeometry.span,
                0
            )
            panel.entity.scale = SIMD3<Float>(
                radius * 1.02,
                panel.bandHeight * TorsoGeometry.span,
                radius * TorsoGeometry.depthRatio * 1.02
            )
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

    static func safeNormalize(_ value: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(value)
        return length > 0.0001 ? value / length : fallback
    }
}

// MARK: - Muscle panels

/// One band of the abdominal wall and the group whose intensity drives it.
@MainActor
struct MusclePanel {
    enum Group {
        case upperAbs, lowerAbs, leftOblique, rightOblique
    }

    let entity: ModelEntity
    let group: Group
    /// Centre of the band along the trunk, where -0.5 is the hips and +0.5 the
    /// shoulders.
    let height: Float
    /// How much of the trunk's length the band covers.
    let bandHeight: Float
    /// Angle around the trunk, measured from the front of the body. Positive
    /// angles wrap toward the athlete's left.
    let centerAngle: Float
    let halfWidth: Float

    fileprivate var appliedStep: Int = -1

    /// Four rectus segments in two rows, plus the two oblique bands.
    static func abdominalWall() -> [MusclePanel] {
        let column = Float.pi / 180 * 20
        let rectusHalfWidth = Float.pi / 180 * 17
        let obliqueHalfWidth = Float.pi / 180 * 20

        return [
            make(group: .upperAbs, height: 0.09, bandHeight: 0.17, centerAngle: column, halfWidth: rectusHalfWidth),
            make(group: .upperAbs, height: 0.09, bandHeight: 0.17, centerAngle: -column, halfWidth: rectusHalfWidth),
            make(group: .lowerAbs, height: -0.11, bandHeight: 0.17, centerAngle: column, halfWidth: rectusHalfWidth),
            make(group: .lowerAbs, height: -0.11, bandHeight: 0.17, centerAngle: -column, halfWidth: rectusHalfWidth),
            make(
                group: .leftOblique,
                height: -0.02,
                bandHeight: 0.3,
                centerAngle: .pi / 180 * 60,
                halfWidth: obliqueHalfWidth
            ),
            make(
                group: .rightOblique,
                height: -0.02,
                bandHeight: 0.3,
                centerAngle: .pi / 180 * -60,
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
