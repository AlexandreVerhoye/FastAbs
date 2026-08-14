import Combine
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class ExerciseRealityRenderer {
    private weak var view: ARView?
    private let anchor = AnchorEntity(world: .zero)
    private let body = ProceduralBody()
    private let camera = PerspectiveCamera()
    private var updateSubscription: (any Cancellable)?
    private var motion: MotionKind
    private var focusZones: Set<MuscleZone>
    private var isPlaying = true
    private var reduceMotion = false
    private var phase: Float = 0
    private var colorScheme: ColorScheme

    init(
        view: ARView,
        motion: MotionKind,
        focusZones: Set<MuscleZone>,
        colorScheme: ColorScheme
    ) {
        self.view = view
        self.motion = motion
        self.focusZones = focusZones
        self.colorScheme = colorScheme

        configure(view)
        buildStage()
        applyFraming()
        renderCurrentPose()
        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(deltaTime: event.deltaTime)
        }
    }

    func update(
        motion newMotion: MotionKind,
        focusZones: Set<MuscleZone>,
        isPlaying: Bool,
        reduceMotion: Bool,
        colorScheme: ColorScheme
    ) {
        let motionChanged = motion != newMotion
        let reduceMotionChanged = reduceMotion != self.reduceMotion
        motion = newMotion
        self.focusZones = focusZones
        self.isPlaying = isPlaying
        self.reduceMotion = reduceMotion
        self.colorScheme = colorScheme

        if motionChanged {
            // Movements begin at the start of the repetition rather than
            // mid-rep, so a new exercise reads from its opening position.
            phase = 0
            applyFraming()
        }
        if reduceMotion {
            phase = MotionLibrary.tempo(for: motion).peakPhase
        } else if reduceMotionChanged {
            phase = 0
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
        view.environment.background = .color(.clear)
        view.renderOptions.formUnion([
            .disableCameraGrain,
            .disableDepthOfField,
            .disableMotionBlur,
            .disablePersonOcclusion,
            .disableFaceMesh,
            .disableAREnvironmentLighting,
            .disableGroundingShadows
        ])
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            view.contentScaleFactor *= 0.78
        }
        view.scene.anchors.append(anchor)
    }

    func buildStage() {
        anchor.addChild(body.root)
        anchor.addChild(camera)
        camera.camera.fieldOfViewInDegrees = 32

        // Three neutral white lights. A white body needs shaping from direction
        // alone: any coloured light would tint the figure and compete with the
        // red muscle map, and a single source flattens the form into a cut-out.
        let key = DirectionalLight()
        var keyLight = key.light
        keyLight.color = .white
        keyLight.intensity = 3_200
        key.light = keyLight
        key.look(
            at: SIMD3<Float>(0, 0.45, 0),
            from: SIMD3<Float>(-1.5, 4.5, 4.5),
            relativeTo: nil
        )
        anchor.addChild(key)

        let fill = DirectionalLight()
        var fillLight = fill.light
        fillLight.color = UIColor(white: 0.92, alpha: 1)
        fillLight.intensity = 1_300
        fill.light = fillLight
        fill.look(
            at: SIMD3<Float>(0, 0.45, 0),
            from: SIMD3<Float>(3.5, 0.8, 3.5),
            relativeTo: nil
        )
        anchor.addChild(fill)

        // A rim from behind separates the white silhouette from the dark card
        // it sits on, which is what keeps the figure from looking pasted on.
        let rim = DirectionalLight()
        var rimLight = rim.light
        rimLight.color = .white
        rimLight.intensity = 1_800
        rim.light = rimLight
        rim.look(
            at: SIMD3<Float>(0, 0.5, 0),
            from: SIMD3<Float>(-1.5, 2.2, -4),
            relativeTo: nil
        )
        anchor.addChild(rim)
    }

    func applyFraming() {
        let metadata = MotionLibrary.metadata(for: motion)
        camera.look(
            at: metadata.cameraTarget,
            from: metadata.cameraPosition,
            upVector: SIMD3<Float>(0, 1, 0),
            relativeTo: nil
        )
    }

    func tick(deltaTime: TimeInterval) {
        guard isPlaying, !reduceMotion else { return }
        let cadence = MotionLibrary.metadata(for: motion).cyclesPerSecond
        phase += min(Float(deltaTime), 1 / 15) * cadence
        if phase >= 1 { phase -= floor(phase) }
        renderCurrentPose()
    }

    func renderCurrentPose() {
        body.update(
            pose: MotionLibrary.pose(for: motion, phase: phase),
            activation: MuscleActivation.make(for: motion, phase: phase, focus: focusZones),
            viewer: MotionLibrary.metadata(for: motion).cameraPosition
        )
    }
}
