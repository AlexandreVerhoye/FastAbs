import SwiftUI

/// A medal you can turn over.
///
/// Was a RealityKit `ARView`. That meant standing up a full 3D rendering engine
/// for one decorative disc — on a tab the shell builds whether or not you ever
/// open it, which is most of why moving between tabs stuttered. It also refused
/// every touch, so the one thing a medal invites you to do was the one thing it
/// would not let you do.
///
/// Plain SwiftUI does the same job: a disc, a rim, a symbol, and a back face
/// carrying the inscription. Drag it and it turns; let go and it settles.
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

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                if showsBack {
                    back(size: size)
                        // Counter-turned, or the engraving comes out mirrored.
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    front(size: size)
                }
            }
            .frame(width: size, height: size)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(turn(across: proxy.size.width), isEnabled: isInteractive)
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
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: isBack
                            ? [metal.opacity(0.62), metal.opacity(0.95)]
                            : [metal.opacity(0.98), metal.opacity(0.55)],
                        center: isBack ? .bottomTrailing : .topLeading,
                        startRadius: size * 0.04,
                        endRadius: size * 0.62
                    )
                )
                .shadow(color: metal.opacity(isUnlocked ? 0.4 : 0.15), radius: size * 0.06, y: size * 0.03)

            // The rim, and the sheen that sells it as metal rather than paint.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .white.opacity(0.08), .white.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.035
                )

            Circle()
                .inset(by: size * 0.09)
                .strokeBorder(.white.opacity(0.16), lineWidth: size * 0.008)

            // Studs around the edge, the detail that reads as a struck medal.
            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: size * 0.022, height: size * 0.022)
                    .offset(y: -size * 0.435)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
            }
        }
    }

    // MARK: - Motion

    private func turn(across width: CGFloat) -> some Gesture {
        DragGesture()
            .updating($dragging) { value, state, _ in
                // A full drag across the badge is a little over half a turn, so
                // the back is reachable in one movement without flying past it.
                state = Double(value.translation.width / max(width, 1)) * 220
            }
            .onEnded { value in
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
