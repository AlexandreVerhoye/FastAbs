import SwiftData
import SwiftUI

struct RewardsView: View {
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.calendar) private var environmentCalendar

    private var localCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = RewardsEngine(calendar: localCalendar).summary(records: records, now: context.date)
            RewardsDashboard(summary: summary)
        }
        .navigationTitle("Récompenses")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }
}

private struct RewardsDashboard: View {
    let summary: RewardsSummary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                DailyBadgeHero(badge: summary.todayBadge, streak: summary.currentStreak)

                RewardStatsStrip(summary: summary)

                VStack(spacing: 14) {
                    SectionHeader(
                        title: "Défis en cours",
                        subtitle: "Des objectifs adaptés à votre rythme"
                    )

                    ChallengeCard(challenge: summary.weeklyBalance, tint: .fastMint)
                    ChallengeCard(challenge: summary.monthlyChallenge, tint: .fastCoral)
                    ChallengeCard(challenge: summary.annualChallenge, tint: .fastBlue)
                }

                BadgeGallery(badges: Array(summary.dailyBadges.prefix(35)))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }
}

private struct DailyBadgeHero: View {
    let badge: DailyBadge?
    let streak: Int

    private var tint: Color { badge?.tier.tint ?? .fastCoral }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.fastNight)

                Circle()
                    .fill(tint.opacity(0.36))
                    .frame(width: 240, height: 240)
                    .blur(radius: 44)
                    .offset(y: -22)

                AchievementBadge3DView(
                    title: badge?.tier.title ?? "Badge du jour",
                    symbol: badge?.symbol ?? "flame.fill",
                    tint: tint,
                    isUnlocked: badge != nil,
                    isAnimated: true
                )
                .frame(height: 230)
                .padding(.top, 8)
            }
            .frame(height: 250)
            .clipped()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(badge == nil ? "Votre badge vous attend" : "Badge du jour obtenu")
                        .font(.title3.bold())
                    Text(heroDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Label("\(streak)", systemImage: "flame.fill")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.fastCoral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.fastCoral.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Série actuelle, \(streak) jours")
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.09), radius: 22, y: 9)
        )
        .accessibilityElement(children: .contain)
    }

    private var heroDetail: String {
        guard let badge else { return "Terminez votre programme pour le révéler." }
        let minutes = max(1, badge.activeSeconds / 60)
        return "\(minutes) min actives · niveau \(badge.tier.title.lowercased())"
    }
}

/// Presentation components below are internal rather than file-private so
/// `BadgeVisualTests` and `ProgressVisualTests` can rasterise them directly.
struct RewardStatsStrip: View {
    let summary: RewardsSummary

    var body: some View {
        HStack(spacing: 0) {
            MetricPill(icon: "flame.fill", value: "\(summary.currentStreak)", label: "Série")
            Divider().frame(height: 50)
            MetricPill(icon: "trophy.fill", value: "\(summary.longestStreak)", label: "Record")
            Divider().frame(height: 50)
            MetricPill(icon: "medal.fill", value: "\(summary.earnedBadgeCount)", label: "Badges")
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .glassCard()
    }
}

struct ChallengeCard: View {
    let challenge: ChallengeProgress
    let tint: Color

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.14), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: challenge.progress)
                    .stroke(
                        AngularGradient(colors: [tint.opacity(0.65), tint], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: challenge.isCompleted ? "checkmark" : challenge.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(challenge.title)
                        .font(.headline)
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(tint)
                    }
                }
                Text(challenge.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(challenge.valueDescription)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(challenge.title), \(challenge.valueDescription), \(challenge.remainingDescription)")
    }
}

struct BadgeGallery: View {
    let badges: [DailyBadge]

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 92), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Collection quotidienne",
                subtitle: badges.isEmpty ? "Votre première médaille apparaîtra ici" : "Vos 35 derniers jours actifs"
            )

            if badges.isEmpty {
                ContentUnavailableView(
                    "Aucun badge pour le moment",
                    systemImage: "medal",
                    description: Text("Une séance terminée suffit pour commencer votre collection.")
                )
                .frame(maxWidth: .infinity, minHeight: 190)
                .glassCard()
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(badges) { badge in
                        MiniBadgeView(badge: badge)
                    }
                }
                .padding(18)
                .glassCard()
            }
        }
    }
}

struct MiniBadgeView: View {
    let badge: DailyBadge

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [badge.tier.tint.opacity(0.95), badge.tier.tint.opacity(0.46)],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 36
                        )
                    )
                    .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 2))
                    .shadow(color: badge.tier.tint.opacity(0.3), radius: 7, y: 4)

                Image(systemName: badge.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .rotation3DEffect(.degrees(-8), axis: (x: 1, y: 0.25, z: 0))

            Text(badge.day, format: .dateTime.day().month(.abbreviated))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Badge \(badge.tier.title), obtenu le \(badge.day.formatted(date: .long, time: .omitted))")
    }
}

extension DailyBadgeTier {
    var tint: Color {
        switch self {
        case .bronze: .fastOrange
        case .silver: Color(red: 0.56, green: 0.68, blue: 0.78)
        case .gold: Color(red: 1.00, green: 0.76, blue: 0.18)
        }
    }
}
