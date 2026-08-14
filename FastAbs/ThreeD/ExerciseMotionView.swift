import RealityKit
import SwiftUI
import UIKit

/// Native 3D exercise illustration. Callers only choose the domain motion and
/// playback state; RealityKit scene construction stays behind this interface.
struct ExerciseMotionView: View {
    let motion: MotionKind
    var isPlaying: Bool
    var focusZones: Set<MuscleZone>
    var accessibilityName: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(
        motion: MotionKind,
        isPlaying: Bool = true,
        focusZones: Set<MuscleZone> = [.fullCore],
        accessibilityName: String? = nil
    ) {
        self.motion = motion
        self.isPlaying = isPlaying
        self.focusZones = focusZones
        self.accessibilityName = accessibilityName
    }

    init(exercise: Exercise, isPlaying: Bool = true) {
        self.init(
            motion: exercise.motion,
            isPlaying: isPlaying,
            focusZones: exercise.zones,
            accessibilityName: exercise.name
        )
    }

    var body: some View {
        let metadata = MotionLibrary.metadata(for: motion)
        ExerciseRealityView(
            motion: motion,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            focusZones: focusZones,
            colorScheme: colorScheme
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Démonstration 3D — \(accessibilityName ?? metadata.title)")
        .accessibilityValue(metadata.accessibilityDescription)
        .accessibilityHint(
            reduceMotion
                ? "Image fixe sur la contraction maximale, selon votre réglage Réduire les animations."
                : "Le mouvement est présenté en boucle. Les muscles sollicités passent du blanc au rouge."
        )
    }
}

@MainActor
private struct ExerciseRealityView: UIViewRepresentable {
    let motion: MotionKind
    let isPlaying: Bool
    let reduceMotion: Bool
    let focusZones: Set<MuscleZone>
    let colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> RealityKit.ARView {
        let view = RealityKit.ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        context.coordinator.install(
            in: view,
            motion: motion,
            focusZones: focusZones,
            colorScheme: colorScheme
        )
        context.coordinator.update(
            motion: motion,
            focusZones: focusZones,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            colorScheme: colorScheme
        )
        return view
    }

    func updateUIView(_ uiView: RealityKit.ARView, context: Context) {
        context.coordinator.update(
            motion: motion,
            focusZones: focusZones,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            colorScheme: colorScheme
        )
    }

    static func dismantleUIView(_ uiView: RealityKit.ARView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator {
        private var renderer: ExerciseRealityRenderer?

        func install(
            in view: RealityKit.ARView,
            motion: MotionKind,
            focusZones: Set<MuscleZone>,
            colorScheme: ColorScheme
        ) {
            renderer = ExerciseRealityRenderer(
                view: view,
                motion: motion,
                focusZones: focusZones,
                colorScheme: colorScheme
            )
        }

        func update(
            motion: MotionKind,
            focusZones: Set<MuscleZone>,
            isPlaying: Bool,
            reduceMotion: Bool,
            colorScheme: ColorScheme
        ) {
            renderer?.update(
                motion: motion,
                focusZones: focusZones,
                isPlaying: isPlaying,
                reduceMotion: reduceMotion,
                colorScheme: colorScheme
            )
        }

        func tearDown() {
            renderer?.tearDown()
            renderer = nil
        }
    }
}
