import Combine
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class ExerciseRealityRenderer {
    private weak var view: ARView?
    private let anchor = AnchorEntity(world: .zero)
    private let body: ProceduralBody
    private var updateSubscription: (any Cancellable)?
    private var motion: MotionKind
    private var highlightedZones: Set<MuscleZone>
    private var isPlaying = true
    private var reduceMotion = false
    private var phase: Float = 0.12
    private var colorScheme: ColorScheme

    init(
        view: ARView,
        motion: MotionKind,
        highlightedZones: Set<MuscleZone>,
        accent: UIColor,
        colorScheme: ColorScheme
    ) {
        self.view = view
        self.motion = motion
        self.highlightedZones = highlightedZones
        self.colorScheme = colorScheme
        body = ProceduralBody(accent: accent)

        configure(view)
        buildStage()
        renderCurrentPose()
        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(deltaTime: event.deltaTime)
        }
    }

    func update(
        motion newMotion: MotionKind,
        highlightedZones: Set<MuscleZone>,
        isPlaying: Bool,
        reduceMotion: Bool,
        colorScheme: ColorScheme
    ) {
        let motionChanged = motion != newMotion
        motion = newMotion
        self.highlightedZones = highlightedZones
        self.isPlaying = isPlaying
        self.reduceMotion = reduceMotion

        if colorScheme != self.colorScheme {
            self.colorScheme = colorScheme
            updateBackground()
        }
        if motionChanged || reduceMotion {
            phase = reduceMotion ? 0.28 : 0.06
        }
        renderCurrentPose()
    }

    func tearDown() {
        updateSubscription?.cancel()
        updateSubscription = nil
        anchor.removeFromParent()
    }
}

private extension ExerciseRealityRenderer {
    func configure(_ view: ARView) {
        view.isOpaque = false
        view.backgroundColor = .clear
        view.renderOptions.formUnion([
            .disableCameraGrain,
            .disableDepthOfField,
            .disableMotionBlur,
            .disablePersonOcclusion,
            .disableFaceMesh,
            .disableAREnvironmentLighting
        ])
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            view.contentScaleFactor *= 0.78
            view.renderOptions.insert(.disableGroundingShadows)
        }
        updateBackground()
        view.scene.anchors.append(anchor)
    }

    func buildStage() {
        let matMaterial = SimpleMaterial(
            color: UIColor(red: 0.075, green: 0.07, blue: 0.19, alpha: 1),
            roughness: 0.82,
            isMetallic: false
        )
        let mat = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(3.15, 0.055, 1.42), cornerRadius: 0.18),
            materials: [matMaterial]
        )
        mat.position = SIMD3<Float>(0, 0.045, 0)
        anchor.addChild(mat)
        anchor.addChild(body.root)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 34
        let metadata = MotionLibrary.metadata(for: motion)
        camera.look(
            at: metadata.cameraTarget,
            from: metadata.cameraPosition,
            upVector: SIMD3<Float>(0, 1, 0),
            relativeTo: nil
        )
        anchor.addChild(camera)

        let key = DirectionalLight()
        var keyLight = key.light
        keyLight.color = UIColor(red: 1, green: 0.91, blue: 0.82, alpha: 1)
        keyLight.intensity = 2_700
        key.light = keyLight
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 5, depthBias: 1.4)
        key.look(
            at: SIMD3<Float>(0, 0.35, 0),
            from: SIMD3<Float>(-2.4, 4, 3.2),
            relativeTo: nil
        )
        anchor.addChild(key)

        let fill = PointLight()
        fill.light = PointLightComponent(
            color: UIColor(red: 0.5, green: 0.64, blue: 1, alpha: 1),
            intensity: 1_450,
            attenuationRadius: 7
        )
        fill.position = SIMD3<Float>(2.4, 2.2, -2.6)
        anchor.addChild(fill)
    }

    func updateBackground() {
        let color: UIColor
        switch colorScheme {
        case .dark:
            color = UIColor(red: 0.026, green: 0.024, blue: 0.085, alpha: 1)
        default:
            color = UIColor(red: 0.94, green: 0.945, blue: 0.985, alpha: 1)
        }
        view?.environment.background = .color(color)
    }

    func tick(deltaTime: TimeInterval) {
        guard isPlaying, !reduceMotion else { return }
        let cadence = MotionLibrary.metadata(for: motion).cyclesPerSecond
        phase += min(Float(deltaTime), 1 / 15) * cadence * 1.2
        if phase >= 1 { phase -= floor(phase) }
        renderCurrentPose()
    }

    func renderCurrentPose() {
        body.update(
            pose: MotionLibrary.pose(for: motion, phase: phase),
            highlightedZones: highlightedZones
        )
    }
}
