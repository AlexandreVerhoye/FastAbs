import SwiftUI

/// A medal you can turn over.
///
/// Was a RealityKit `ARView`. That meant standing up a full 3D rendering engine
/// for one decorative disc — on a tab the shell builds whether or not you ever
/// open it, which is most of why moving between tabs stuttered. It also refused
/// every touch, so the one thing a medal invites you to do was the one thing it
/// would not let you do.
///
/// Plain SwiftUI does the same job, and does it as a solid object rather than a
/// picture of one: the disc has a thickness whose edge comes into view as it
/// turns, a domed face whose highlight travels across it, and a bevelled rim.
/// Drag it and it turns; let go and it settles.
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
    @State private var settled: Double = 0
    @State private var idle: Double = 0
    @GestureState private var dragging: Double = 0

    private var angle: Double { settled + dragging + idle }

    /// The back is showing when the disc has turned past a quarter turn.
    private var showsBack: Bool {
        let wrapped = (angle.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return wrapped > 90 && wrapped < 270
    }

    private var metal: Color { isUnlocked ? tint : Color(white: 0.42) }

    /// How far round it has turned, as the two numbers everything else needs:
    /// `turn` is how much of the edge has come into view, `facing` how much of
    /// the face is still pointed at you.
    private var turn: Double { sin(Angle(degrees: angle).radians) }
    private var facing: Double { cos(Angle(degrees: angle).radians) }

    /// A medal is a struck disc, not a sticker. Roughly a millimetre and a half
    /// against a forty-millimetre face.
    private var thicknessRatio: Double { 0.075 }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                // The edge is drawn outside the rotation on purpose: a rotated
                // flat shape has no side to show, so the thickness has to be
                // built from the angle rather than projected from it.
                edge(size: size)

                ZStack {
                    front(size: size)
                        .opacity(showsBack ? 0 : 1)
                    back(size: size)
                        // Counter-turned, or the engraving comes out mirrored.
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(showsBack ? 1 : 0)
                }
                .frame(width: size, height: size)
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // High priority and horizontal-only: the badge sits inside a scroll
            // view on both screens that show it, and a plain gesture there
            // either loses to the scroll or fights it.
            .highPriorityGesture(turn(across: proxy.size.width), isEnabled: isInteractive)
        }
        .task(id: isAnimated) { await breathe() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            [isUnlocked ? "Badge obtenu" : "Badge à débloquer", caption]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityHint(isInteractive ? "Faites glisser pour retourner le badge." : "")
    }

    // MARK: - Body of the medal

    /// The struck edge, revealed as the disc turns away from you.
    ///
    /// Built from the geometry rather than drawn beside it. A disc of diameter
    /// `d` and thickness `t` turned by θ has a silhouette `d·cos θ + t·sin θ`
    /// wide and still `d` tall; the face covers `d·cos θ` of that. So the edge
    /// is simply what the wider ellipse leaves showing — a true crescent,
    /// tapering to nothing at top and bottom, with no masking involved.
    ///
    /// Two earlier attempts drew a band of even height at the rim instead, and
    /// both stuck out past the poles as a straight-sided sliver glued to the
    /// medal. The second tried to cut it back with a mask, which does nothing:
    /// `.mask` after `.offset` works in the offset view's own space, so the
    /// circle travelled with the band it was meant to trim.
    private func edge(size: CGFloat) -> some View {
        let face = size * abs(facing)
        let band = size * thicknessRatio * abs(turn)
        let hull = face + band
        // The edge shows on the side turning away from the viewer.
        let shift = (turn < 0 ? 1.0 : -1.0) * band / 2

        return Ellipse()
            .fill(
                LinearGradient(
                    // Milled metal: the light catches both corners of the band
                    // and dies in the middle of it.
                    colors: [
                        metal.opacity(0.5),
                        metal.opacity(0.95),
                        metal.opacity(0.3),
                        metal.opacity(0.75),
                        metal.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: max(hull, 1), height: size)
            .offset(x: shift)
    }

    // MARK: - Faces

    private func front(size: CGFloat) -> some View {
        ZStack {
            disc(size: size)

            Image(systemName: symbol)
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.28), radius: size * 0.012, y: size * 0.006)
        }
    }

    private func back(size: CGFloat) -> some View {
        ZStack {
            disc(size: size, isBack: true)

            VStack(spacing: size * 0.028) {
                Text(title.uppercased())
                    .font(.system(size: size * 0.082, weight: .heavy, design: .rounded))
                    .tracking(size * 0.006)
                    .multilineTextAlignment(.center)
                if let caption {
                    Rectangle()
                        .fill(.white.opacity(0.32))
                        .frame(width: size * 0.26, height: 1)
                    Text(caption)
                        .font(.system(size: size * 0.062, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
            }
            // Cut into the metal rather than sitting on it: a dark body with a
            // lit top edge is what a stamped engraving looks like from above.
            // Black rather than the tint, so it holds up on any colour.
            .foregroundStyle(.black.opacity(0.4))
            .shadow(color: .white.opacity(0.4), radius: 0, y: -1)
            .padding(.horizontal, size * 0.17)
        }
    }

    private func disc(size: CGFloat, isBack: Bool = false) -> some View {
        // The lit point slides across the face as the medal turns, which is the
        // whole difference between a dome and a printed circle. Away from the
        // viewer on the far side, toward them on the near one.
        let lit = UnitPoint(x: 0.5 - turn * 0.42, y: isBack ? 0.68 : 0.3)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            metal.opacity(isBack ? 0.72 : 1),
                            metal.opacity(isBack ? 0.9 : 0.74),
                            metal.opacity(isBack ? 0.55 : 0.42)
                        ],
                        center: lit,
                        startRadius: size * 0.02,
                        endRadius: size * 0.72
                    )
                )
                .shadow(color: metal.opacity(isUnlocked ? 0.4 : 0.15), radius: size * 0.06, y: size * 0.03)

            // Bevel: an angular sweep round the rim, so the light runs round it
            // instead of sitting on one corner the way a flat gradient does.
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.68), .white.opacity(0.06),
                            .white.opacity(0.42), .white.opacity(0.04),
                            .white.opacity(0.68)
                        ],
                        center: .center,
                        angle: .degrees(-40 - turn * 60)
                    ),
                    lineWidth: size * 0.05
                )

            // The inner wall of the struck face, lit from the opposite side to
            // the dome — that opposition is what the eye reads as a hollow.
            Circle()
                .inset(by: size * 0.085)
                .strokeBorder(
                    LinearGradient(
                        colors: [.black.opacity(0.22), .clear, .white.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.018
                )

            // Studs around the edge, the detail that reads as a struck medal.
            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.42))
                    .frame(width: size * 0.024, height: size * 0.024)
                    .offset(y: -size * 0.418)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
            }

            // A soft sweep of specular light that travels with the turn.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.62, height: size * 0.34)
                .offset(x: -turn * size * 0.22, y: -size * 0.22)
                .blur(radius: size * 0.05)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .clipShape(Circle())
    }

    // MARK: - Motion

    private func turn(across width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragging) { value, state, _ in
                // Sideways drags only. Claiming a vertical one would stop the
                // page scrolling under the athlete's finger.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // A full drag across the badge is a little over half a turn, so
                // the back is reachable in one movement without flying past it.
                state = Double(value.translation.width / max(width, 1)) * 220
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // Carries the throw, not just where the finger stopped, so a
                // flick turns the medal over the way a real one would.
                let thrown = Double(value.predictedEndTranslation.width / max(width, 1)) * 220
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    // Settles to whichever face it is closest to, so it never
                    // rests edge-on where there is nothing to read.
                    settled = ((settled + thrown) / 180).rounded() * 180
                }
                Haptics.selection()
            }
    }

    /// A slow sway, so a medal sitting on screen looks lit rather than printed.
    private func breathe() async {
        guard isAnimated, !reduceMotion else {
            idle = 0
            return
        }
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 2.6)) { idle = 9 }
            try? await Task.sleep(for: .milliseconds(2_600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 2.6)) { idle = -9 }
            try? await Task.sleep(for: .milliseconds(2_600))
        }
    }
}
