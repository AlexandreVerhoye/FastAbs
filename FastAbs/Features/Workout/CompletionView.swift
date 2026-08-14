import SwiftUI

struct CompletionView: View {
    let plan: WorkoutPlan
    let onDone: () -> Void
    @State private var feedback: EffortFeedback?
    @State private var revealsContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("SÉANCE TERMINÉE")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.fastMint)
                    Text("Magnifique élan !")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Votre sangle abdominale a travaillé sous plusieurs angles.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                AchievementBadge3DView(
                    title: "Badge quotidien FastAbs",
                    symbol: "bolt.heart.fill",
                    tint: .fastCoral,
                    isUnlocked: true,
                    isAnimated: true
                )
                    .frame(height: 280)
                    .accessibilityLabel("Badge quotidien FastAbs remporté")

                HStack(spacing: 0) {
                    MetricPill(icon: "clock.fill", value: plan.duration.clockText, label: "durée")
                    Divider().frame(height: 48).overlay(.white.opacity(0.18))
                    MetricPill(icon: "figure.run", value: "\(plan.exerciseCount)", label: "exercices")
                    Divider().frame(height: 48).overlay(.white.opacity(0.18))
                    MetricPill(icon: "flame.fill", value: "≈\(plan.estimatedCalories)", label: "kcal")
                }
                .padding(.vertical, 16)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 14) {
                    Text("Comment était l’intensité ?").font(.headline)
                    HStack(spacing: 10) {
                        ForEach(EffortFeedback.allCases) { item in
                            Button {
                                withAnimation(.snappy) { feedback = item }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(systemName: item.symbol).font(.title3)
                                    Text(item.title).font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(feedback == item ? Color.fastCoral : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: onDone) {
                    Text("Continuer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .background(.white, in: Capsule())
                .foregroundStyle(Color.fastNavy)
            }
            .padding(24)
            .opacity(revealsContent ? 1 : 0)
            .offset(y: revealsContent ? 0 : 16)
        }
        .foregroundStyle(.white)
        .onAppear { withAnimation(.smooth(duration: 0.7)) { revealsContent = true } }
    }
}

private enum EffortFeedback: String, CaseIterable, Identifiable {
    case easy, right, hard
    var id: String { rawValue }
    var title: String { switch self { case .easy: "Facile"; case .right: "Parfait"; case .hard: "Difficile" } }
    var symbol: String { switch self { case .easy: "leaf.fill"; case .right: "hand.thumbsup.fill"; case .hard: "flame.fill" } }
}
