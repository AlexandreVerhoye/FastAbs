import RealityKit
import SwiftUI
import UIKit

/// Native 3D exercise illustration. Callers only choose the domain motion and
/// playback state; RealityKit scene construction stays behind this interface.
struct ExerciseMotionView: View {
    let motion: MotionKind
    var isPlaying: Bool
    var highlightedZones: Set<MuscleZone>
    var accessibilityName: String?
    var accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    init(
        motion: MotionKind,
        isPlaying: Bool = true,
        highlightedZones: Set<MuscleZone> = [.fullCore],
        accessibilityName: String? = nil,
        accent: Color = .fastCoral
    ) {
        self.motion = motion
        self.isPlaying = isPlaying
        self.highlightedZones = highlightedZones
        self.accessibilityName = accessibilityName
        self.accent = accent
    }

    init(exercise: Exercise, isPlaying: Bool = true, accent: Color = .fastCoral) {
        self.init(
            motion: exercise.motion,
            isPlaying: isPlaying,
            highlightedZones: exercise.zones,
            accessibilityName: exercise.name,
            accent: accent
        )
    }

    var body: some View {
        let metadata = MotionLibrary.metadata(for: motion)
        ExerciseRealityView(
            motion: motion,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            highlightedZones: highlightedZones,
            accent: accent,
            colorScheme: colorScheme
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Démonstration 3D — \(accessibilityName ?? metadata.title)")
        .accessibilityValue(metadata.accessibilityDescription)
        .accessibilityHint(
            reduceMotion
                ? "Illustration fixe affichée selon votre réglage Réduire les animations."
                : "Le mouvement est présenté en boucle."
        )
    }
}

@MainActor
private struct ExerciseRealityView: UIViewRepresentable {
    let motion: MotionKind
    let isPlaying: Bool
    let reduceMotion: Bool
    let highlightedZones: Set<MuscleZone>
    let accent: Color
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
            zones: highlightedZones,
            accent: UIColor(accent),
            colorScheme: colorScheme
        )
        context.coordinator.update(
            motion: motion,
            zones: highlightedZones,
            isPlaying: isPlaying,
            reduceMotion: reduceMotion,
            colorScheme: colorScheme
        )
        return view
    }

    func updateUIView(_ uiView: RealityKit.ARView, context: Context) {
        context.coordinator.update(
            motion: motion,
            zones: highlightedZones,
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
            zones: Set<MuscleZone>,
            accent: UIColor,
            colorScheme: ColorScheme
        ) {
            renderer = ExerciseRealityRenderer(
                view: view,
                motion: motion,
                highlightedZones: zones,
                accent: accent,
                colorScheme: colorScheme
            )
        }

        func update(
            motion: MotionKind,
            zones: Set<MuscleZone>,
            isPlaying: Bool,
            reduceMotion: Bool,
            colorScheme: ColorScheme
        ) {
            renderer?.update(
                motion: motion,
                highlightedZones: zones,
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
