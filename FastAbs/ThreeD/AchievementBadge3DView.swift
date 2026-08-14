import Combine
import RealityKit
import SwiftUI
import UIKit

/// Reusable native 3D medallion for daily, monthly, and yearly rewards.
/// `symbol` is an SF Symbols name, rendered locally onto the RealityKit badge.
struct AchievementBadge3DView: View {
    let title: String
    let symbol: String
    var tint: Color
    var isUnlocked: Bool
    var isAnimated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(
        title: String,
        symbol: String,
        tint: Color = .fastCoral,
        isUnlocked: Bool = true,
        isAnimated: Bool = true
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.isUnlocked = isUnlocked
        self.isAnimated = isAnimated
    }

    var body: some View {
        BadgeRealityView(
            symbol: symbol,
            tint: tint,
            isUnlocked: isUnlocked,
            isAnimated: isAnimated && scenePhase == .active && !reduceMotion
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isUnlocked ? "Badge obtenu" : "Badge à débloquer")
        .accessibilityHint(
            reduceMotion
                ? "Médaillon 3D fixe selon votre réglage Réduire les animations."
                : "Médaillon 3D animé doucement."
        )
    }
}

@MainActor
private struct BadgeRealityView: UIViewRepresentable {
    let symbol: String
    let tint: Color
    let isUnlocked: Bool
    let isAnimated: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.install(
            in: view,
            symbol: symbol,
            tint: UIColor(tint),
            isUnlocked: isUnlocked,
            isAnimated: isAnimated
        )
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.renderer?.update(
            symbol: symbol,
            tint: UIColor(tint),
            isUnlocked: isUnlocked,
            isAnimated: isAnimated
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.renderer?.tearDown()
        coordinator.renderer = nil
    }

    @MainActor
    final class Coordinator {
        var renderer: BadgeRealityRenderer?

        func install(
            in view: ARView,
            symbol: String,
            tint: UIColor,
            isUnlocked: Bool,
            isAnimated: Bool
        ) {
            renderer = BadgeRealityRenderer(
                view: view,
                symbol: symbol,
                tint: tint,
                isUnlocked: isUnlocked,
                isAnimated: isAnimated
            )
        }
    }
}

@MainActor
private final class BadgeRealityRenderer {
    private weak var view: ARView?
    private let anchor = AnchorEntity(world: .zero)
    private let badgeRoot = Entity()
    private var updateSubscription: (any Cancellable)?
    private var symbol: String
    private var tint: UIColor
    private var isUnlocked: Bool
    private var isAnimated: Bool
    private var elapsed: Float = 0

    init(
        view: ARView,
        symbol: String,
        tint: UIColor,
        isUnlocked: Bool,
        isAnimated: Bool
    ) {
        self.view = view
        self.symbol = symbol
        self.tint = tint
        self.isUnlocked = isUnlocked
        self.isAnimated = isAnimated

        configure(view)
        rebuildBadge()
        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(deltaTime: event.deltaTime)
        }
    }

    func update(symbol: String, tint: UIColor, isUnlocked: Bool, isAnimated: Bool) {
        let appearanceChanged = self.symbol != symbol || self.tint != tint || self.isUnlocked != isUnlocked
        self.symbol = symbol
        self.tint = tint
        self.isUnlocked = isUnlocked
        self.isAnimated = isAnimated
        if appearanceChanged {
            rebuildBadge()
        }
        if !isAnimated {
            badgeRoot.orientation = simd_quatf(angle: 0.12, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    func tearDown() {
        updateSubscription?.cancel()
        updateSubscription = nil
        anchor.removeFromParent()
    }
}

private extension BadgeRealityRenderer {
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
        anchor.addChild(badgeRoot)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 31
        camera.look(
            at: .zero,
            from: SIMD3<Float>(0, 0.05, 3.35),
            upVector: SIMD3<Float>(0, 1, 0),
            relativeTo: nil
        )
        anchor.addChild(camera)

        let key = DirectionalLight()
        var light = key.light
        light.color = UIColor(red: 1, green: 0.94, blue: 0.8, alpha: 1)
        light.intensity = 3_200
        key.light = light
        key.look(at: .zero, from: SIMD3<Float>(-2, 3, 2.5), relativeTo: nil)
        anchor.addChild(key)

        let fill = PointLight()
        fill.light = PointLightComponent(
            color: UIColor(red: 0.45, green: 0.57, blue: 1, alpha: 1),
            intensity: 1_350,
            attenuationRadius: 6
        )
        fill.position = SIMD3<Float>(1.8, -1.5, 2.2)
        anchor.addChild(fill)
    }

    func rebuildBadge() {
        badgeRoot.children.removeAll()
        let faceColor = isUnlocked ? tint : UIColor(white: 0.37, alpha: 1)
        let edgeColor = isUnlocked
            ? UIColor(red: 0.98, green: 0.73, blue: 0.25, alpha: 1)
            : UIColor(white: 0.27, alpha: 1)
        let edgeMaterial = SimpleMaterial(color: edgeColor, roughness: 0.24, isMetallic: true)
        let faceMaterial = SimpleMaterial(color: faceColor, roughness: 0.38, isMetallic: true)
        let insetMaterial = SimpleMaterial(
            color: isUnlocked ? faceColor.withAlphaComponent(0.84) : UIColor(white: 0.31, alpha: 1),
            roughness: 0.5,
            isMetallic: true
        )

        let edge = ModelEntity(mesh: .generateSphere(radius: 1), materials: [edgeMaterial])
        edge.scale = SIMD3<Float>(0.78, 0.78, 0.12)
        badgeRoot.addChild(edge)

        let face = ModelEntity(mesh: .generateSphere(radius: 1), materials: [faceMaterial])
        face.scale = SIMD3<Float>(0.69, 0.69, 0.1)
        face.position.z = 0.06
        badgeRoot.addChild(face)

        let inset = ModelEntity(mesh: .generateSphere(radius: 1), materials: [insetMaterial])
        inset.scale = SIMD3<Float>(0.56, 0.56, 0.035)
        inset.position.z = 0.15
        badgeRoot.addChild(inset)

        addPearlRing(material: edgeMaterial)
        addSymbol(symbol, color: isUnlocked ? .white : UIColor(white: 0.72, alpha: 1))
    }

    func addPearlRing(material: SimpleMaterial) {
        let pearlMesh = MeshResource.generateSphere(radius: 0.038)
        for index in 0..<14 {
            let angle = Float(index) / 14 * 2 * .pi
            let pearl = ModelEntity(mesh: pearlMesh, materials: [material])
            pearl.position = SIMD3<Float>(cos(angle) * 0.72, sin(angle) * 0.72, 0.17)
            badgeRoot.addChild(pearl)
        }
    }

    func addSymbol(_ name: String, color: UIColor) {
        guard let image = symbolImage(name: name, color: color),
              let texture = try? TextureResource.generate(
                  from: image,
                  options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
              ) else {
            addFallbackSymbol(color: color)
            return
        }

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(scale: 1))
        let plane = ModelEntity(
            mesh: .generatePlane(width: 0.72, height: 0.72, cornerRadius: 0),
            materials: [material]
        )
        plane.position.z = 0.205
        badgeRoot.addChild(plane)
    }

    func addFallbackSymbol(color: UIColor) {
        let material = SimpleMaterial(color: color, roughness: 0.32, isMetallic: true)
        let vertical = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.12, 0.52, 0.07), cornerRadius: 0.04),
            materials: [material]
        )
        vertical.position.z = 0.21
        let horizontal = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.44, 0.12, 0.07), cornerRadius: 0.04),
            materials: [material]
        )
        horizontal.position.z = 0.21
        badgeRoot.addChild(vertical)
        badgeRoot.addChild(horizontal)
    }

    func symbolImage(name: String, color: UIColor) -> CGImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 154, weight: .bold, scale: .large)
        let source = UIImage(systemName: name, withConfiguration: configuration)
            ?? UIImage(systemName: "star.fill", withConfiguration: configuration)
        guard let source else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
        let image = renderer.image { _ in
            let tinted = source.withTintColor(color, renderingMode: .alwaysOriginal)
            let size = tinted.size
            let scale = min(184 / max(size.width, 1), 184 / max(size.height, 1))
            let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
            let rect = CGRect(
                x: (256 - drawSize.width) * 0.5,
                y: (256 - drawSize.height) * 0.5,
                width: drawSize.width,
                height: drawSize.height
            )
            tinted.draw(in: rect)
        }
        return image.cgImage
    }

    func tick(deltaTime: TimeInterval) {
        guard isAnimated else { return }
        elapsed += min(Float(deltaTime), 1 / 15)
        let yaw = sin(elapsed * 0.72) * 0.19
        let pitch = cos(elapsed * 0.51) * 0.045
        badgeRoot.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        badgeRoot.position.y = sin(elapsed * 0.9) * 0.035
    }
}
