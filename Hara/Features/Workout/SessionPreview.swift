import SwiftUI

/// The ten seconds before the first movement.
///
/// A bare three-two-one asks the athlete to be ready without ever having told
/// them what for: the session was chosen on a card that named a duration and a
/// level, and the movements themselves were a surprise arriving one at a time.
/// So the lead-in spends its seconds showing the programme — every movement, in
/// order, with the one about to start lit — and hands back the seconds it does
/// not deserve through a button that ends it early.
struct SessionPreview: View {
    let plan: WorkoutPlan
    let secondsRemaining: Double
    /// Nought to one across the whole lead-in. The highlight walks the
    /// programme on this rather than running a second timer that could drift
    /// away from the one that matters.
    let progress: Double
    let isPaused: Bool
    let onBegin: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var items: [PreviewItem] { PreviewItem.programme(of: plan) }

    private var second: Int { max(1, Int(ceil(secondsRemaining))) }

    private var isFinalCount: Bool { second <= 3 && !isPaused }

    private var featured: Int {
        guard !items.isEmpty else { return 0 }
        return min(items.count - 1, Int(progress * Double(items.count)))
    }

    var body: some View {
        ZStack {
            LinearGradient.haraNight.ignoresSafeArea()
            Color.haraNavy.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                // The lead-in covers the player's own close button, and ten
                // seconds you cannot leave is a trap rather than a preview.
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .accessibilityLabel("Quitter la séance")
                    Spacer()
                }

                header
                Spacer(minLength: 14)
                programme
                Spacer(minLength: 14)
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .foregroundStyle(.white)
        .accessibilityIdentifier("workout.sessionPreview")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(isPaused ? "EN PAUSE" : "PRÉPAREZ-VOUS")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(isPaused ? Color.haraOrange : Color.haraMint)
                .contentTransition(.opacity)

            Text("\(second)")
                .font(.system(size: 92, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(
                    isFinalCount
                        ? AnyShapeStyle(LinearGradient.haraHero)
                        : AnyShapeStyle(Color.white)
                )
                .contentTransition(.numericText(countsDown: true))
                .animation(.smooth(duration: 0.3), value: second)
                .scaleEffect(isFinalCount && !reduceMotion ? 1.06 : 1)
                .animation(.spring(response: 0.36, dampingFraction: 0.62), value: isFinalCount)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Départ dans \(second) secondes. \(summary)")
    }

    private var summary: String {
        let movements = items.count == 1 ? "1 mouvement" : "\(items.count) mouvements"
        let minutes = max(1, Int((Double(plan.duration) / 60).rounded()))
        return "\(movements) · \(minutes) min · \(plan.preferences.difficulty.cadenceDescription)"
    }

    private var programme: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AU PROGRAMME")
                .font(.caption2.weight(.heavy))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            tile(item, isFeatured: item.index == featured)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .onChange(of: featured) { _, index in
                    guard items.indices.contains(index) else { return }
                    // Without an explicit transaction the scroll jumps: the
                    // highlight is driven by a value that changes twelve times
                    // a second, and only this change is worth animating.
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
                        proxy.scrollTo(items[index].id, anchor: .center)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Au programme : " + items.map(\.exercise.name).joined(separator: ", ")
        )
    }

    private func tile(_ item: PreviewItem, isFeatured: Bool) -> some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        isFeatured
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        item.exercise.pattern.color.opacity(0.34),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.06))
                    )

                // Only the movement on show animates. Eight figures all playing
                // at forty frames a second is the whole lead-in spent on a
                // screen nobody is looking at yet.
                ExerciseMotionView(
                    motion: item.exercise.motion,
                    isPlaying: isFeatured && !isPaused,
                    focusZones: item.exercise.zones
                )
                .padding(7)
            }
            .frame(width: 116, height: 116)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isFeatured ? Color.haraCoral.opacity(0.85) : .white.opacity(0.09),
                        lineWidth: isFeatured ? 2 : 1
                    )
            }
            .overlay(alignment: .topLeading) {
                Text("\(item.index + 1)")
                    .font(.caption2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(isFeatured ? Color.haraNavy : .white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(
                        isFeatured ? AnyShapeStyle(Color.haraCoral) : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
                    .padding(8)
            }

            Text(item.exercise.name)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)
                .foregroundStyle(isFeatured ? .white : .white.opacity(0.55))

            Text(item.detail)
                .font(.caption2.weight(.heavy).monospacedDigit())
                .foregroundStyle(isFeatured ? Color.haraCoral : .white.opacity(0.4))
        }
        .frame(width: 124)
        .scaleEffect(reduceMotion ? 1 : (isFeatured ? 1 : 0.93))
        .opacity(isFeatured ? 1 : 0.7)
        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: isFeatured)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient.haraHero)
                            .frame(width: max(5, proxy.size.width * progress))
                    }
                }
                .accessibilityHidden(true)

            Button("Commencer maintenant") { onBegin() }
                .buttonStyle(HaraSecondaryButtonStyle(tint: .white))
        }
    }
}

/// One movement of the programme, as an athlete counts them.
///
/// Built from the steps rather than from `plan.movements` because the preview
/// also has to say how long each one runs — and a movement held per side runs
/// twice, which is one line of the programme, not two.
private struct PreviewItem: Identifiable {
    let index: Int
    let exercise: Exercise
    let seconds: Int
    let heldPerSide: Bool

    var id: String { "\(index)-\(exercise.id)" }

    var detail: String {
        heldPerSide ? "2 × \(seconds / 2) s" : "\(seconds) s"
    }

    static func programme(of plan: WorkoutPlan) -> [PreviewItem] {
        var items: [PreviewItem] = []
        for step in plan.steps {
            guard step.kind == .exercise, let exercise = step.exercise else { continue }
            if step.side == .right, let last = items.last, last.exercise.id == exercise.id {
                items[items.count - 1] = PreviewItem(
                    index: last.index,
                    exercise: exercise,
                    seconds: last.seconds + step.duration,
                    heldPerSide: true
                )
                continue
            }
            items.append(
                PreviewItem(
                    index: items.count,
                    exercise: exercise,
                    seconds: step.duration,
                    heldPerSide: false
                )
            )
        }
        return items
    }
}
