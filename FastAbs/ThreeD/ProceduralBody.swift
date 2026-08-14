import RealityKit
import UIKit
import simd

@MainActor
final class ProceduralBody {
    let root = Entity()

    private let head: ModelEntity
    private let neck: ModelEntity
    private let spine: ModelEntity
    private let shoulderLine: ModelEntity
    private let hipLine: ModelEntity
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
    private let jointMarkers: [ModelEntity]
    private let torso: ModelEntity
    private let pelvis: ModelEntity
    private let upperCore: ModelEntity
    private let lowerCore: ModelEntity
    private let leftOblique: ModelEntity
    private let rightOblique: ModelEntity

    private let bodyMaterial: SimpleMaterial
    private let jointMaterial: SimpleMaterial
    private let inactiveCoreMaterial: SimpleMaterial
    private let activeCoreMaterial: SimpleMaterial
    private let secondaryCoreMaterial: SimpleMaterial
    private var displayedZones: Set<MuscleZone> = []

    init(accent: UIColor) {
        bodyMaterial = SimpleMaterial(
            color: UIColor(red: 0.88, green: 0.9, blue: 0.98, alpha: 1),
            roughness: 0.58,
            isMetallic: false
        )
        let createdJointMaterial = SimpleMaterial(
            color: UIColor(red: 0.29, green: 0.3, blue: 0.42, alpha: 1),
            roughness: 0.45,
            isMetallic: true
        )
        jointMaterial = createdJointMaterial
        inactiveCoreMaterial = SimpleMaterial(
            color: UIColor(red: 0.24, green: 0.25, blue: 0.36, alpha: 1),
            roughness: 0.52,
            isMetallic: false
        )
        activeCoreMaterial = SimpleMaterial(color: accent, roughness: 0.34, isMetallic: true)
        secondaryCoreMaterial = SimpleMaterial(
            color: UIColor(red: 0.25, green: 0.84, blue: 0.65, alpha: 1),
            roughness: 0.38,
            isMetallic: true
        )

        head = Self.sphere(radius: 0.145, material: bodyMaterial)
        neck = Self.segment(material: jointMaterial)
        spine = Self.segment(material: bodyMaterial)
        shoulderLine = Self.segment(material: bodyMaterial)
        hipLine = Self.segment(material: bodyMaterial)
        leftUpperArm = Self.segment(material: bodyMaterial)
        leftForearm = Self.segment(material: bodyMaterial)
        rightUpperArm = Self.segment(material: bodyMaterial)
        rightForearm = Self.segment(material: bodyMaterial)
        leftThigh = Self.segment(material: bodyMaterial)
        leftShin = Self.segment(material: bodyMaterial)
        rightThigh = Self.segment(material: bodyMaterial)
        rightShin = Self.segment(material: bodyMaterial)
        leftHand = Self.sphere(radius: 0.075, material: jointMaterial)
        rightHand = Self.sphere(radius: 0.075, material: jointMaterial)
        leftFoot = Self.roundedBox(material: jointMaterial)
        rightFoot = Self.roundedBox(material: jointMaterial)

        torso = Self.roundedBox(material: bodyMaterial)
        pelvis = Self.roundedBox(material: bodyMaterial)
        upperCore = Self.roundedBox(material: inactiveCoreMaterial)
        lowerCore = Self.roundedBox(material: inactiveCoreMaterial)
        leftOblique = Self.roundedBox(material: inactiveCoreMaterial)
        rightOblique = Self.roundedBox(material: inactiveCoreMaterial)

        jointMarkers = (0..<10).map { _ in Self.sphere(radius: 0.082, material: createdJointMaterial) }

        let entities: [Entity] = [
            torso, pelvis, spine, shoulderLine, hipLine, neck, head,
            leftUpperArm, leftForearm, rightUpperArm, rightForearm,
            leftThigh, leftShin, rightThigh, rightShin,
            leftHand, rightHand, leftFoot, rightFoot,
            upperCore, lowerCore, leftOblique, rightOblique
        ] + jointMarkers
        entities.forEach { root.addChild($0) }
    }

    func update(pose: BodyPose, highlightedZones: Set<MuscleZone>) {
        Self.placeSegment(neck, from: pose.neck, to: pose.head, radius: 0.072)
        Self.placeSegment(spine, from: pose.pelvis, to: pose.chest, radius: 0.12)
        Self.placeSegment(shoulderLine, from: pose.rightShoulder, to: pose.leftShoulder, radius: 0.1)
        Self.placeSegment(hipLine, from: pose.rightHip, to: pose.leftHip, radius: 0.11)
        Self.placeSegment(leftUpperArm, from: pose.leftShoulder, to: pose.leftElbow, radius: 0.073)
        Self.placeSegment(leftForearm, from: pose.leftElbow, to: pose.leftHand, radius: 0.062)
        Self.placeSegment(rightUpperArm, from: pose.rightShoulder, to: pose.rightElbow, radius: 0.073)
        Self.placeSegment(rightForearm, from: pose.rightElbow, to: pose.rightHand, radius: 0.062)
        Self.placeSegment(leftThigh, from: pose.leftHip, to: pose.leftKnee, radius: 0.09)
        Self.placeSegment(leftShin, from: pose.leftKnee, to: pose.leftAnkle, radius: 0.072)
        Self.placeSegment(rightThigh, from: pose.rightHip, to: pose.rightKnee, radius: 0.09)
        Self.placeSegment(rightShin, from: pose.rightKnee, to: pose.rightAnkle, radius: 0.072)

        head.position = pose.head
        leftHand.position = pose.leftHand
        rightHand.position = pose.rightHand
        Self.placeFoot(leftFoot, ankle: pose.leftAnkle, knee: pose.leftKnee)
        Self.placeFoot(rightFoot, ankle: pose.rightAnkle, knee: pose.rightKnee)

        let markerPositions = [
            pose.leftShoulder, pose.rightShoulder,
            pose.leftElbow, pose.rightElbow,
            pose.leftHip, pose.rightHip,
            pose.leftKnee, pose.rightKnee,
            pose.leftAnkle, pose.rightAnkle
        ]
        for (marker, position) in zip(jointMarkers, markerPositions) {
            marker.position = position
        }

        let shoulderAxis = pose.leftShoulder - pose.rightShoulder
        let torsoAxis = pose.chest - pose.pelvis
        let torsoCenter = (pose.chest + pose.pelvis) * 0.5
        Self.placeBox(
            torso,
            center: torsoCenter,
            widthAxis: shoulderAxis,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.48, max(simd_length(torsoAxis) * 0.92, 0.28), 0.19)
        )
        Self.placeBox(
            pelvis,
            center: pose.pelvis,
            widthAxis: pose.leftHip - pose.rightHip,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.36, 0.25, 0.2)
        )

        placeCorePanels(pose: pose, shoulderAxis: shoulderAxis, torsoAxis: torsoAxis)
        updateMusclesIfNeeded(highlightedZones)
    }
}

private extension ProceduralBody {
    static let cameraReference = SIMD3<Float>(3.25, 2.45, 4.15)

    static func segment(material: SimpleMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: 1, cornerRadius: 0.48), materials: [material])
    }

    static func sphere(radius: Float, material: SimpleMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
    }

    static func roundedBox(material: SimpleMaterial) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: 1, cornerRadius: 0.22), materials: [material])
    }

    static func placeSegment(
        _ entity: ModelEntity,
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        radius: Float
    ) {
        let vector = end - start
        let length = max(simd_length(vector), 0.001)
        entity.position = (start + end) * 0.5
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: vector / length)
        entity.scale = SIMD3<Float>(radius, length, radius)
    }

    static func placeFoot(_ entity: ModelEntity, ankle: SIMD3<Float>, knee: SIMD3<Float>) {
        let legDirection = simd_normalize(ankle - knee)
        let footCenter = ankle + SIMD3<Float>(0.08, 0.015, 0)
        placeBox(
            entity,
            center: footCenter,
            widthAxis: SIMD3<Float>(0, 0, 1),
            heightAxis: legDirection,
            size: SIMD3<Float>(0.12, 0.2, 0.1)
        )
    }

    static func placeBox(
        _ entity: ModelEntity,
        center: SIMD3<Float>,
        widthAxis: SIMD3<Float>,
        heightAxis: SIMD3<Float>,
        size: SIMD3<Float>
    ) {
        let yAxis = safeNormalize(heightAxis, fallback: SIMD3<Float>(0, 1, 0))
        var xAxis = safeNormalize(widthAxis, fallback: SIMD3<Float>(0, 0, 1))
        var zAxis = safeNormalize(simd_cross(xAxis, yAxis), fallback: SIMD3<Float>(0, 0, 1))
        if simd_dot(zAxis, cameraReference - center) < 0 {
            zAxis *= -1
        }
        xAxis = safeNormalize(simd_cross(yAxis, zAxis), fallback: xAxis)
        entity.position = center
        entity.orientation = simd_quatf(simd_float3x3(columns: (xAxis, yAxis, zAxis)))
        entity.scale = size
    }

    static func safeNormalize(_ value: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(value)
        return length > 0.0001 ? value / length : fallback
    }

    func placeCorePanels(
        pose: BodyPose,
        shoulderAxis: SIMD3<Float>,
        torsoAxis: SIMD3<Float>
    ) {
        let height = max(simd_length(torsoAxis), 0.3)
        let direction = Self.safeNormalize(torsoAxis, fallback: SIMD3<Float>(0, 1, 0))
        var normal = Self.safeNormalize(simd_cross(shoulderAxis, direction), fallback: SIMD3<Float>(0, 0, 1))
        let torsoCenter = (pose.chest + pose.pelvis) * 0.5
        if simd_dot(normal, Self.cameraReference - torsoCenter) < 0 {
            normal *= -1
        }
        let surfaceOffset = normal * 0.115
        let upperCenter = pose.pelvis + torsoAxis * 0.67 + surfaceOffset
        let lowerCenter = pose.pelvis + torsoAxis * 0.35 + surfaceOffset
        let sideDirection = Self.safeNormalize(shoulderAxis, fallback: SIMD3<Float>(0, 0, 1))

        Self.placeBox(
            upperCore,
            center: upperCenter,
            widthAxis: shoulderAxis,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.18, height * 0.24, 0.035)
        )
        Self.placeBox(
            lowerCore,
            center: lowerCenter,
            widthAxis: shoulderAxis,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.17, height * 0.24, 0.035)
        )
        Self.placeBox(
            leftOblique,
            center: (upperCenter + lowerCenter) * 0.5 + sideDirection * 0.14,
            widthAxis: shoulderAxis,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.075, height * 0.42, 0.032)
        )
        Self.placeBox(
            rightOblique,
            center: (upperCenter + lowerCenter) * 0.5 - sideDirection * 0.14,
            widthAxis: shoulderAxis,
            heightAxis: torsoAxis,
            size: SIMD3<Float>(0.075, height * 0.42, 0.032)
        )
    }

    func updateMusclesIfNeeded(_ zones: Set<MuscleZone>) {
        guard zones != displayedZones else { return }
        displayedZones = zones
        let all = zones.contains(.fullCore)
        upperCore.model?.materials = [all || zones.contains(.upperAbs) ? activeCoreMaterial : inactiveCoreMaterial]
        lowerCore.model?.materials = [all || zones.contains(.lowerAbs) ? activeCoreMaterial : inactiveCoreMaterial]
        let obliquesActive = all || zones.contains(.obliques)
        leftOblique.model?.materials = [obliquesActive ? activeCoreMaterial : inactiveCoreMaterial]
        rightOblique.model?.materials = [obliquesActive ? activeCoreMaterial : inactiveCoreMaterial]

        if zones.contains(.deepCore), !all {
            upperCore.model?.materials = [secondaryCoreMaterial]
            lowerCore.model?.materials = [secondaryCoreMaterial]
        }
    }
}
