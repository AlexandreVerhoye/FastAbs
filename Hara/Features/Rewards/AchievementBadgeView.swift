import QuartzCore
import SceneKit
import SwiftUI

/// A struck medal, rendered in 3D and turned by hand.
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
///
/// The angle is owned by the renderer, not by SwiftUI. It used to live in
/// `@GestureState`, which is reset to zero the instant a gesture ends, and the
/// end handler rounded the result to the nearest half turn — so a small drag
/// rounded straight back to where it started and the medal sprang home. SwiftUI
/// now sends the drag as events and the coordinator integrates them, which is
/// what lets a flick carry momentum and lets the medal simply stay put.
struct AchievementBadgeView: View {
    let title: String
    /// Engraved under the title on the back — a date, a tier, a count.
    var caption: String?
    let symbol: String
    var tint: Color = .haraCoral
    var isUnlocked: Bool = true
    var isAnimated: Bool = true
    /// False for the small gallery tiles, which are buttons rather than toys.
    var isInteractive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// The tab shell keeps every tab alive, so a badge on a tab you are not
    /// looking at would otherwise sway at sixty frames a second forever. This
    /// is the same trap the RealityKit version fell into.
    @State private var isOnScreen = false
    @State private var command = BadgeCommand()
    /// True once the drag has proved itself horizontal. Until then the badge
    /// stays still and the scroll view underneath keeps the touch.
    @State private var isClaimed = false

    var body: some View {
        GeometryReader { proxy in
            // The medal is fitted to the shorter side of the frame, so that is
            // also the distance a full turn of the wrist should cover.
            let metric = max(1, min(proxy.size.width, proxy.size.height))

            BadgeScene(
                title: title,
                caption: caption,
                symbol: symbol,
                tint: tint,
                isUnlocked: isUnlocked,
                command: command,
                metric: metric,
                allowsSway: isAnimated && !reduceMotion,
                allowsMomentum: !reduceMotion,
                isLive: isOnScreen && scenePhase == .active
            )
            .contentShape(Rectangle())
            // High priority and sideways only: the badge sits inside a scroll
            // view on every screen that shows it, so a plain gesture either
            // loses to the scroll or blocks it.
            .highPriorityGesture(turn(across: metric), isEnabled: isInteractive)
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
        // VoiceOver cannot drag, so the same object is offered as something to
        // step through: each adjustment turns the medal a quarter turn.
        .accessibilityAdjustableAction { direction in
            guard isInteractive else { return }
            switch direction {
            case .increment: command.send(.nudge(turns: 0.25))
            case .decrement: command.send(.nudge(turns: -0.25))
            @unknown default: break
            }
        }
    }

    private func turn(across metric: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isClaimed {
                    // Claimed on the horizontal, then free in both axes.
                    // Deciding per-frame instead made a diagonal drag stutter
                    // between moving and not moving; deciding never would have
                    // taken the scroll.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    isClaimed = true
                    command.send(.grab(dx: value.translation.width, dy: value.translation.height))
                }
                command.send(.drag(dx: value.translation.width, dy: value.translation.height))
            }
            .onEnded { value in
                guard isClaimed else { return }
                isClaimed = false
                // The gesture's own velocity, not a projected end point. The
                // old code guessed the throw from `predictedEndTranslation` and
                // then threw the guess away by rounding it.
                command.send(.release(vx: value.velocity.width, vy: value.velocity.height))
            }
    }
}

// MARK: - Drag as events

/// One instruction from the finger to the renderer.
///
/// The medal's angle deliberately does not live in SwiftUI state: a value that
/// SwiftUI owns is a value SwiftUI resets, and it cannot be integrated against
/// friction without re-rendering the whole view once per frame. So the view
/// sends what happened and the coordinator decides where the medal ends up.
private struct BadgeCommand: Equatable {
    enum Kind: Equatable {
        case idle
        /// Translation at the moment the drag proved itself horizontal, which
        /// becomes the origin the rest of the drag is measured from.
        case grab(dx: CGFloat, dy: CGFloat)
        case drag(dx: CGFloat, dy: CGFloat)
        case release(vx: CGFloat, vy: CGFloat)
        case nudge(turns: Double)
    }

    private(set) var sequence = 0
    private(set) var kind: Kind = .idle

    mutating func send(_ kind: Kind) {
        sequence &+= 1
        self.kind = kind
    }
}

// MARK: - The scene

private struct BadgeScene: UIViewRepresentable {
    let title: String
    let caption: String?
    let symbol: String
    let tint: Color
    let isUnlocked: Bool
    let command: BadgeCommand
    let metric: CGFloat
    let allowsSway: Bool
    let allowsMomentum: Bool
    let isLive: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = context.coordinator.scene
        view.antialiasingMode = .multisampling4X
        // SwiftUI owns the gesture; the renderer only draws.
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 60
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.attach(to: view)
        context.coordinator.configure(
            metric: Double(metric),
            allowsMomentum: allowsMomentum,
            allowsSway: allowsSway,
            isLive: isLive
        )
        context.coordinator.handle(command)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        // The only place the display link is guaranteed to be torn down: it
        // retains its target, so a link left running keeps the whole scene
        // alive on a screen nobody is looking at.
        coordinator.tearDown()
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
    final class Coordinator: NSObject {
        let scene = SCNScene()
        /// Carries the ambient drift and nothing else.
        private let cradle = SCNNode()
        /// Carries the athlete's rotation and nothing else.
        private let medal = SCNNode()

        // MARK: Tuning

        /// The slight downward tilt the medal rests at, so it never reads as a
        /// flat disc pasted onto the card.
        private static let restPitch: Double = -0.05
        /// How far the medal may be tipped toward or away from the athlete. A
        /// medal that can only spin about one axis feels like a page turning;
        /// one that can be tipped freely ends up edge-on with nothing to read.
        private static let pitchLimit: Double = 0.44
        /// Radians of yaw per length of the badge. Roughly two-thirds of a turn
        /// across the medal, which is the point where a drag stops feeling like
        /// pushing something heavy and does not yet outrun the finger.
        private static let sweep: Double = 4.2
        /// Vertical drags turn into tilt at about half the rate, because the
        /// tilt has a hard limit and hitting it early feels like a jam.
        private static let pitchRate: Double = 0.55
        /// Exponential decay of the throw, per second. UIScrollView's
        /// deceleration is the reference: a fast flick runs for about two
        /// seconds and slows the whole way.
        private static let friction: Double = 2.6
        private static let stopSpeed: Double = 0.15
        /// A hard flick is clamped rather than allowed to blur the artwork.
        private static let maxSpeed: Double = 13
        /// A release this slow counts as the athlete putting the medal down.
        private static let settleSpeed: Double = 1.1
        /// And it only settles if a face was nearly square-on already, so the
        /// medal is never dragged somewhere the athlete did not put it.
        private static let settleWindow: Double = 0.32

        // MARK: State

        private weak var view: SCNView?
        private var link: CADisplayLink?
        private var lastSequence = 0

        private var metric: Double = 240
        private var allowsMomentum = true
        private var allowsSway = false
        private var isLive = false
        private var isSwaying = false
        /// Once the athlete has turned the medal by hand the ambient drift does
        /// not come back. They put it at a particular angle on purpose, and a
        /// badge that keeps moving afterwards is a badge that did not stay
        /// where it was left.
        private var hasBeenTurned = false

        private var yaw: Double = 0
        private var pitch = Coordinator.restPitch
        private var yawVelocity: Double = 0
        private var pitchVelocity: Double = 0
        private var isDragging = false
        private var yawAtGrab: Double = 0
        private var pitchAtGrab: Double = 0
        private var grabX: Double = 0
        private var grabY: Double = 0
        private var settleTarget: Double?
        /// Which half turn the medal is in, so a face arriving square-on can be
        /// felt as well as seen.
        private var detent = 0
        private var lastDetentTime: CFTimeInterval = 0

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
            // The drift lives on the parent and the athlete's rotation on the
            // child, so the two never write to the same value. Sharing one node
            // meant the drift's accumulated rotation was still there when a
            // touch landed — the badge jumped — and restarting it after a
            // release cut the settling spring off mid-flight.
            cradle.addChildNode(medal)
            scene.rootNode.addChildNode(cradle)

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

            super.init()
            apply()
        }

        // MARK: Wiring

        func attach(to view: SCNView) {
            guard self.view !== view else { return }
            self.view = view
            apply()
            draw()
        }

        func configure(metric: Double, allowsMomentum: Bool, allowsSway: Bool, isLive: Bool) {
            self.metric = max(1, metric)
            self.allowsMomentum = allowsMomentum
            self.allowsSway = allowsSway
            let becameLive = isLive != self.isLive
            self.isLive = isLive

            guard isLive else {
                // Off screen, or the app is in the background: nothing about
                // this medal is worth a frame.
                guard becameLive else { return }
                stopLink()
                stopSway()
                yawVelocity = 0
                pitchVelocity = 0
                pitch = Self.restPitch
                apply()
                return
            }
            updateSway()
            if becameLive { draw() }
        }

        func tearDown() {
            stopLink()
            stopSway()
            view?.isPlaying = false
            view?.rendersContinuously = false
            view = nil
        }

        // MARK: The finger

        func handle(_ command: BadgeCommand) {
            guard command.sequence != lastSequence else { return }
            lastSequence = command.sequence

            switch command.kind {
            case .idle:
                break

            case let .grab(dx, dy):
                isDragging = true
                hasBeenTurned = true
                stopLink()
                stopSway()
                settleTarget = nil
                yawVelocity = 0
                pitchVelocity = 0
                yawAtGrab = yaw
                pitchAtGrab = pitch
                grabX = Double(dx)
                grabY = Double(dy)
                Haptics.tap()

            case let .drag(dx, dy):
                guard isDragging else { return }
                let scale = Self.sweep / metric
                yaw = yawAtGrab + (Double(dx) - grabX) * scale
                pitch = min(
                    Self.restPitch + Self.pitchLimit,
                    max(
                        Self.restPitch - Self.pitchLimit,
                        pitchAtGrab - (Double(dy) - grabY) * scale * Self.pitchRate
                    )
                )
                feelDetents()
                apply()
                draw()

            case let .release(vx, _):
                guard isDragging else { return }
                isDragging = false
                guard allowsMomentum else {
                    // Reduce Motion keeps the direct manipulation — that is not
                    // decoration — and drops everything that keeps moving on
                    // its own afterwards.
                    pitch = Self.restPitch
                    pitchVelocity = 0
                    apply()
                    draw()
                    return
                }
                let scale = Self.sweep / metric
                yawVelocity = min(Self.maxSpeed, max(-Self.maxSpeed, Double(vx) * scale))
                if abs(yawVelocity) < Self.settleSpeed {
                    let nearest = (yaw / .pi).rounded() * .pi
                    if abs(nearest - yaw) < Self.settleWindow { settleTarget = nearest }
                }
                startLink()

            case let .nudge(turns):
                guard !isDragging else { return }
                hasBeenTurned = true
                stopSway()
                settleTarget = yaw + turns * 2 * .pi
                yawVelocity = 0
                startLink()
            }
        }

        // MARK: Motion

        @objc
        private func step(_ link: CADisplayLink) {
            // Clamped: a dropped frame must not teleport the medal a half turn.
            let dt = min(1.0 / 30, max(1.0 / 240, link.targetTimestamp - link.timestamp))
            var moving = false

            if let target = settleTarget {
                let stiffness = 90.0
                let damping = 2 * stiffness.squareRoot()
                yawVelocity += (-stiffness * (yaw - target) - damping * yawVelocity) * dt
                yaw += yawVelocity * dt
                if abs(yaw - target) < 0.004, abs(yawVelocity) < 0.05 {
                    yaw = target
                    yawVelocity = 0
                    settleTarget = nil
                } else {
                    moving = true
                }
            } else if abs(yawVelocity) > Self.stopSpeed {
                yaw += yawVelocity * dt
                // Exponential rather than linear: a throw should lose most of
                // its speed early and then coast, which is what a spun object
                // does and what a constant deceleration never looks like.
                yawVelocity *= exp(-Self.friction * dt)
                moving = true
            } else {
                yawVelocity = 0
            }

            let offset = pitch - Self.restPitch
            if abs(offset) > 0.0015 || abs(pitchVelocity) > 0.01 {
                let stiffness = 130.0
                let damping = 2 * stiffness.squareRoot()
                pitchVelocity += (-stiffness * offset - damping * pitchVelocity) * dt
                pitch += pitchVelocity * dt
                moving = true
            } else {
                pitch = Self.restPitch
                pitchVelocity = 0
            }

            feelDetents()
            apply()
            draw()

            guard !moving else { return }
            stopLink()
            // The medal has come to rest exactly where it was thrown, which is
            // worth one quiet confirmation.
            Haptics.tap()
        }

        /// A notch each time a face comes square-on, the way a dial has them.
        /// Deliberately the selection haptic: it is the one iOS already uses
        /// for a picker passing a value, so the medal reads as something with
        /// positions rather than something being scrubbed.
        private func feelDetents() {
            let index = Int(((yaw + .pi / 2) / .pi).rounded(.down))
            guard index != detent else { return }
            detent = index
            // A hard flick crosses a face every few frames; at that speed the
            // notches merge into a buzz, so the fast part of a throw is silent.
            guard abs(yawVelocity) < 9 else { return }
            let now = CACurrentMediaTime()
            guard now - lastDetentTime > 0.05 else { return }
            lastDetentTime = now
            Haptics.selection()
        }

        private func apply() {
            // SceneKit would otherwise animate a change to `eulerAngles` on its
            // own, which fights the integration above and lags it by a frame.
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            medal.eulerAngles = SCNVector3(Float(pitch), Float(yaw), 0)
            SCNTransaction.commit()
        }

        /// One frame, without leaving the renderer running. A medal at rest
        /// should cost nothing at all.
        private func draw() {
            guard !isSwaying else { return }
            view?.setNeedsDisplay()
        }

        private func startLink() {
            guard link == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            // Common mode, so a throw keeps decelerating while the athlete
            // scrolls the screen it lives on.
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        private func stopLink() {
            link?.invalidate()
            link = nil
        }

        // MARK: Ambient drift

        private func updateSway() {
            if allowsSway, !hasBeenTurned, !isDragging, link == nil {
                startSway()
            } else {
                stopSway()
            }
        }

        private func startSway() {
            guard !isSwaying else { return }
            isSwaying = true
            // A slow drift on the cradle, so a medal sitting on screen looks
            // lit rather than printed.
            let sway = SCNAction.sequence([
                SCNAction.rotateBy(x: 0.04, y: 0.22, z: 0, duration: 3.1),
                SCNAction.rotateBy(x: -0.04, y: -0.22, z: 0, duration: 3.1)
            ])
            cradle.runAction(.repeatForever(sway), forKey: "sway")
            view?.isPlaying = true
            view?.rendersContinuously = true
        }

        private func stopSway() {
            guard isSwaying else { return }
            isSwaying = false
            // Stops where it stands rather than snapping home, so letting go of
            // the badge does not twitch.
            cradle.removeAction(forKey: "sway")
            view?.isPlaying = false
            view?.rendersContinuously = false
            view?.setNeedsDisplay()
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
