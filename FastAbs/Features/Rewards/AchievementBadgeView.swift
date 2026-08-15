import SceneKit
import SwiftUI

/// A struck medal, rendered in 3D.
///
/// Two earlier versions of this were flat SwiftUI: gradients for the dome, an
/// ellipse for the thickness. Neither worked and no amount of tuning was going
/// to make them work — the Health and Fitness awards are real geometry with a
/// metallic material and an environment reflected in it, and what sells them is
/// exactly the part a gradient cannot fake: a highlight sliding across curved
/// metal as the object turns.
///
/// So it is real geometry. Deliberately SceneKit rather than the RealityKit
/// `ARView` this once was: that stood up an AR session and an entity system for
/// a single disc and cost every tab change, which is why it was removed. An
/// `SCNView` is a renderer and nothing else, it draws only while the medal is
/// moving, and it tears its scene down when the badge leaves the screen.
struct AchievementBadgeView: View {
    let title: String
    /// Engraved under the title on the back — a date, a tier, a count.
    var caption: String?
    let symbol: String
    var tint: Color = .fastCoral
    var isUnlocked: Bool = true
    var isAnimated: Bool = true
    /// False for the small gallery tiles, which are buttons rather than toys.
    var isInteractive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var settled: Double = 0
    /// The tab shell keeps every tab alive, so a badge on a tab you are not
    /// looking at would otherwise sway at sixty frames a second forever. This
    /// is the same trap the RealityKit version fell into.
    @State private var isOnScreen = false
    @GestureState private var dragging: Double = 0

    var body: some View {
        GeometryReader { proxy in
            BadgeScene(
                title: title,
                caption: caption,
                symbol: symbol,
                tint: tint,
                isUnlocked: isUnlocked,
                idles: isAnimated && !reduceMotion && dragging == 0
                    && isOnScreen && scenePhase == .active,
                yaw: settled + dragging
            )
            .contentShape(Rectangle())
            // High priority and sideways only: the badge sits inside a scroll
            // view on every screen that shows it, so a plain gesture either
            // loses to the scroll or blocks it.
            .highPriorityGesture(turn(across: proxy.size.width), isEnabled: isInteractive)
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            [isUnlocked ? "Badge obtenu" : "Badge à débloquer", caption]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityHint(isInteractive ? "Faites glisser pour retourner le badge." : "")
    }

    private func turn(across width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragging) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = Double(value.translation.width / max(width, 1)) * 220
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // Carries the throw, so a flick turns the medal the way a real
                // one would rather than stopping where the finger left off.
                let thrown = Double(value.predictedEndTranslation.width / max(width, 1)) * 220
                withAnimation(.spring(response: 0.6, dampingFraction: 0.74)) {
                    // Settles onto whichever face is nearer, so it never rests
                    // edge-on with nothing to read.
                    settled = ((settled + thrown) / 180).rounded() * 180
                }
                Haptics.selection()
            }
    }
}

// MARK: - The scene

private struct BadgeScene: UIViewRepresentable {
    let title: String
    let caption: String?
    let symbol: String
    let tint: Color
    let isUnlocked: Bool
    let idles: Bool
    let yaw: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = context.coordinator.scene
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 60
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.apply(yaw: yaw, idles: idles)
        // Draws only while there is something to draw. A medal at rest with its
        // idle sway switched off should cost nothing at all.
        view.isPlaying = idles
        view.rendersContinuously = idles
        if !idles { view.setNeedsDisplay() }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            title: title,
            caption: caption,
            symbol: symbol,
            tint: UIColor(tint),
            isUnlocked: isUnlocked
        )
    }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        private let medal = SCNNode()
        private var isSwaying = false

        init(title: String, caption: String?, symbol: String, tint: UIColor, isUnlocked: Bool) {
            let metal = isUnlocked ? tint : UIColor(white: 0.46, alpha: 1)

            // A disc extruded from a circle, with a chamfer. That chamfer is
            // the bevel a struck medal has, and it is what catches the light
            // around the rim as the thing turns.
            let radius: CGFloat = 1
            let circle = UIBezierPath(
                ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            )
            // SceneKit tessellates the path at its flatness. The default of
            // 0.6 turns this circle into a four-sided diamond; 0.01 still shows
            // its facets on the rim at the size the hero draws it.
            circle.flatness = 0.0015
            let shape = SCNShape(path: circle, extrusionDepth: 0.17)
            shape.chamferRadius = 0.04
            shape.chamferMode = .both

            // SCNShape hands out its materials in a fixed order: front face,
            // back face, then the extruded side and its chamfers.
            let face = BadgeMaterial.metal(metal)
            face.diffuse.contents = BadgeArtwork.front(symbol: symbol, tint: metal)
            let back = BadgeMaterial.metal(metal)
            back.diffuse.contents = BadgeArtwork.back(title: title, caption: caption, tint: metal)
            // The rim is left slightly rougher than the faces, which is what
            // separates it from them under the same light.
            let rim = BadgeMaterial.metal(metal, roughness: 0.34)
            shape.materials = [face, back, rim, rim, rim]

            medal.geometry = shape
            scene.rootNode.addChildNode(medal)

            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 32
            camera.camera?.wantsHDR = true
            camera.position = SCNVector3(0, 0, 4.2)
            scene.rootNode.addChildNode(camera)

            // The environment is what makes metal read as metal: the material
            // reflects it, so the highlight travels across the face as the
            // medal turns instead of sitting in one corner.
            scene.lightingEnvironment.contents = BadgeArtwork.environment()
            scene.lightingEnvironment.intensity = 3.2

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 700
            key.eulerAngles = SCNVector3(-0.5, 0.7, 0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 300
            fill.position = SCNVector3(-2.6, 1.6, 3)
            scene.rootNode.addChildNode(fill)
        }

        func apply(yaw: Double, idles: Bool) {
            if idles {
                guard !isSwaying else { return }
                isSwaying = true
                // A slow tilt, so a medal sitting on screen looks lit rather
                // than printed. Runs from the resting pose; a drag stops it.
                medal.eulerAngles = SCNVector3(-0.05, Float(yaw * .pi / 180), 0)
                let sway = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0.06, y: 0.3, z: 0, duration: 2.7),
                    SCNAction.rotateBy(x: -0.06, y: -0.3, z: 0, duration: 2.7)
                ])
                medal.runAction(.repeatForever(sway), forKey: "sway")
                return
            }

            if isSwaying {
                isSwaying = false
                medal.removeAction(forKey: "sway")
            }
            // SwiftUI is already animating the angle, so the node follows it
            // directly rather than running a second animation against it.
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            medal.eulerAngles = SCNVector3(-0.05, Float(yaw * .pi / 180), 0)
            SCNTransaction.commit()
        }
    }
}

// MARK: - Materials and artwork

private enum BadgeMaterial {
    static func metal(_ tint: UIColor, roughness: CGFloat = 0.18) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = tint
        // Polished rather than brushed: the lower the roughness, the more of
        // the environment the surface returns, and the environment is the only
        // reason it reads as metal at all.
        material.metalness.contents = 0.95
        material.roughness.contents = roughness
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        return material
    }
}

/// The two faces, drawn once as images and mapped onto the geometry.
private enum BadgeArtwork {
    static let side: CGFloat = 512

    static func front(symbol: String, tint: UIColor) -> UIImage {
        render { context, rect in
            tint.setFill()
            context.fill(rect)

            // An inset ring, struck into the face.
            UIColor(white: 1, alpha: 0.18).setStroke()
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: side * 0.1, dy: side * 0.1))
            ring.lineWidth = side * 0.014
            ring.stroke()

            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.32, weight: .bold)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            glyph.draw(
                in: CGRect(
                    x: rect.midX - glyph.size.width / 2,
                    y: rect.midY - glyph.size.height / 2,
                    width: glyph.size.width,
                    height: glyph.size.height
                )
            )
        }
    }

    static func back(title: String, caption: String?, tint: UIColor) -> UIImage {
        render { context, rect in
            tint.setFill()
            context.fill(rect)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            // Cut into the metal: a dark body with a lit edge above it is what
            // an engraving looks like from directly in front.
            func engrave(_ text: String, size fontSize: CGFloat, at y: CGFloat) {
                let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
                let box = CGRect(
                    x: side * 0.12,
                    y: y,
                    width: side * 0.76,
                    height: font.lineHeight * 2.4
                )
                for (offset, colour) in [
                    (CGFloat(-2), UIColor(white: 1, alpha: 0.36)),
                    (CGFloat(0), UIColor(white: 0, alpha: 0.5))
                ] {
                    text.draw(
                        with: box.offsetBy(dx: 0, dy: offset),
                        options: .usesLineFragmentOrigin,
                        attributes: [
                            .font: font,
                            .paragraphStyle: paragraph,
                            .foregroundColor: colour
                        ],
                        context: nil
                    )
                }
            }

            engrave(
                title.uppercased(),
                size: side * 0.085,
                at: side * (caption == nil ? 0.42 : 0.3)
            )

            if let caption {
                UIColor(white: 0, alpha: 0.32).setFill()
                UIBezierPath(
                    rect: CGRect(x: side * 0.37, y: side * 0.53, width: side * 0.26, height: 2)
                ).fill()
                engrave(caption, size: side * 0.062, at: side * 0.58)
            }
        }
    }

    /// A simple studio: a bright band across the middle, dark above and below.
    /// Reflected in the metal, this is what produces the sweep of light that
    /// crosses the face as the medal turns.
    static func environment() -> UIImage {
        let size = CGSize(width: 256, height: 128)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colours = [
                UIColor(white: 0.04, alpha: 1).cgColor,
                UIColor(white: 0.55, alpha: 1).cgColor,
                UIColor.white.cgColor,
                UIColor(white: 0.3, alpha: 1).cgColor,
                UIColor(white: 0.06, alpha: 1).cgColor
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours as CFArray,
                locations: [0, 0.33, 0.45, 0.6, 1]
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }

    private static func render(_ body: (CGContext, CGRect) -> Void) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        return UIGraphicsImageRenderer(size: rect.size).image { context in
            body(context.cgContext, rect)
        }
    }
}
