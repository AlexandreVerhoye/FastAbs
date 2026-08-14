import SwiftData
import SwiftUI

/// The end of a session, revealed a beat at a time.
///
/// Everything arriving at once is a wall of numbers nobody reads. Staged — the
/// medal, then what you did, then what it unlocked — each part gets a moment,
/// and each moment gets its own tap on the wrist.
struct CompletionView: View {
    let plan: WorkoutPlan
    /// What was actually worked, not what the plan asked for.
    let activeSeconds: Int
    let onRate: (PerceivedEffort) -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @State private var effort: PerceivedEffort = .unrated
    @State private var stage = 0

    private var summary: RewardsSummary {
        RewardsEngine().summary(records: records)
    }

    private var patterns: [CorePattern] {
        let trained = Set(plan.movements.map(\.pattern))
        return CorePattern.allCases.filter(trained.contains)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                header
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 14)

                AchievementBadgeView(
                    title: "Séance du jour",
                    caption: Date.now.formatted(.dateTime.day().month(.wide)),
                    symbol: "bolt.heart.fill",
                    tint: .fastCoral
                )
                .frame(height: 260)
                .accessibilityLabel("Badge quotidien Hara remporté")
                .scaleEffect(stage >= 1 ? 1 : 0.82)
                .opacity(stage >= 1 ? 1 : 0)

                metrics
                    .opacity(stage >= 2 ? 1 : 0)
                    .offset(y: stage >= 2 ? 0 : 14)

                patternsWorked
                    .opacity(stage >= 2 ? 1 : 0)

                unlocked
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 ? 0 : 14)

                effortPoll
                    .opacity(stage >= 4 ? 1 : 0)

                Button("Continuer") {
                    Haptics.tap()
                    onDone()
                }
                .buttonStyle(.fastPrimary(tint: Color.white, foreground: .fastNavy))
                .opacity(stage >= 4 ? 1 : 0)
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .task { await reveal() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("SÉANCE TERMINÉE")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.fastMint)
            Text("Magnifique élan !")
                .font(.fastHeroTitle)
            Text("Votre sangle a travaillé sous \(patterns.count) angles différents.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            MetricPill(icon: "clock.fill", value: activeSeconds.clockText, label: "effort")
            Divider().frame(height: 48).overlay(.white.opacity(0.18))
            MetricPill(icon: "figure.core.training", value: "\(plan.exerciseCount)", label: "mouvements")
            Divider().frame(height: 48).overlay(.white.opacity(0.18))
            MetricPill(icon: "flame.fill", value: "≈\(plan.estimatedCalories)", label: "kcal")
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Metric.Radius.card))
    }

    private var patternsWorked: some View {
        HStack(spacing: 8) {
            ForEach(patterns) { pattern in
                Label(pattern.shortTitle, systemImage: pattern.symbol)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(pattern.color.opacity(0.2), in: Capsule())
                    .foregroundStyle(pattern.color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var unlocked: some View {
        let highlights = highlights()
        if !highlights.isEmpty {
            VStack(spacing: 12) {
                ForEach(highlights, id: \.text) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol)
                            .font(.headline)
                            .foregroundStyle(item.tint)
                            .frame(width: 38, height: 38)
                            .background(item.tint.opacity(0.16), in: Circle())
                        Text(item.text)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Metric.Radius.card))
        }
    }

    private var effortPoll: some View {
        VStack(spacing: 14) {
            Text("Comment était l’intensité ?").font(.headline)
            HStack(spacing: 10) {
                ForEach([PerceivedEffort.easy, .right, .hard], id: \.rawValue) { item in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) { effort = item }
                        onRate(item)
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.symbol).font(.title3)
                            Text(item.title).font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            effort == item ? Color.fastCoral : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Metric.Radius.small)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(effort == item ? .isSelected : [])
                }
            }
        }
    }

    /// What this session changed, rather than what it was.
    private func highlights() -> [(symbol: String, tint: Color, text: String)] {
        var items: [(String, Color, String)] = []
        let overview = WorkoutHistoryAnalytics().overview(records: records)

        if overview.currentStreak > 1 {
            items.append(("flame.fill", .fastOrange, "Série de \(overview.currentStreak) jours."))
        }
        let balance = summary.weeklyBalance
        if balance.currentValue > 0, !balance.isCompleted {
            items.append((
                "square.grid.2x2.fill",
                .fastMint,
                "Semaine complète : \(balance.valueDescription)."
            ))
        } else if balance.isCompleted {
            items.append(("checkmark.seal.fill", .fastMint, "Semaine complète accomplie."))
        }
        let monthly = summary.monthlyChallenge
        if monthly.currentValue > 0 {
            items.append(("target", .fastCoral, "\(monthly.title) : \(monthly.valueDescription)."))
        }
        return items.map { (symbol: $0.0, tint: $0.1, text: $0.2) }
    }

    private func reveal() async {
        let beats: [(stage: Int, haptic: () -> Void)] = [
            (1, { Haptics.success() }),
            (2, { Haptics.tap() }),
            (3, { Haptics.step() }),
            (4, {})
        ]
        for beat in beats {
            withAnimation(.smooth(duration: reduceMotion ? 0.2 : 0.55)) { stage = beat.stage }
            beat.haptic()
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 620))
        }
    }
}
