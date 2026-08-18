import SwiftData
import SwiftUI

struct RewardsView: View {
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(AppModel.self) private var appModel
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.scenePhase) private var scenePhase

    private var localCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    @State private var summary: RewardsSummary?
    /// What has already been shown, so a reward is announced once and then
    /// simply belongs to the athlete. Stored as ids rather than as a count:
    /// a count cannot tell which award arrived.
    @AppStorage("rewards-seen-achievements") private var seenAchievements = ""
    @AppStorage("rewards-seen-rank") private var seenRank = -1
    @State private var pending: [RewardCelebration] = []
    @State private var celebration: RewardCelebration?
    /// The tab shell keeps every tab alive, so a finished session would
    /// otherwise throw a full-screen reveal over whatever the athlete is
    /// actually looking at.
    @State private var isVisible = false

    var body: some View {
        Group {
            if let summary {
                RewardsDashboard(summary: summary)
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .navigationTitle("Récompenses")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isVisible = true
            Haptics.warmUp()
            refresh()
            presentNext()
        }
        .onDisappear { isVisible = false }
        .onChange(of: records.count) { _, _ in refresh() }
        // Badges only change on a new session or a new day, so the summary is
        // built on those two events instead of on every redraw of the tab.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                refresh()
            }
        }
        .fullScreenCover(item: $celebration) { celebration in
            RewardCelebrationView(celebration: celebration) { advance() }
        }
    }

    private func refresh() {
        let next = RewardsEngine(calendar: localCalendar)
            .summary(records: records, trainedAreas: appModel.preferences.trainedAreas)
        enqueueCelebrations(for: next)
        summary = next
        presentNext()
    }

    private func enqueueCelebrations(for summary: RewardsSummary) {
        let unlocked = summary.unlockedAchievements
        guard seenRank >= 0 else {
            // First visit. The shelf is already full of things earned before
            // this screen existed, and thirty reveals in a row is not a
            // celebration, it is a queue.
            seenAchievements = unlocked.map(\.id).joined(separator: "\n")
            seenRank = summary.level.rank.rawValue
            return
        }

        var seen = Set(seenAchievements.split(separator: "\n").map(String.init))
        // Oldest first, so a session that unlocked two awards tells them in the
        // order they happened.
        let fresh = unlocked.reversed().filter { !seen.contains($0.id) }

        if summary.level.rank.rawValue > seenRank {
            seenRank = summary.level.rank.rawValue
            pending.append(.rank(summary.level.rank))
        }
        guard !fresh.isEmpty else { return }
        seen.formUnion(fresh.map(\.id))
        seenAchievements = seen.sorted().joined(separator: "\n")
        pending.append(contentsOf: fresh.map(RewardCelebration.achievement))
    }

    private func presentNext() {
        guard isVisible, celebration == nil, !pending.isEmpty else { return }
        celebration = pending.removeFirst()
    }

    private func advance() {
        celebration = nil
        guard !pending.isEmpty else { return }
        // A beat between two reveals, otherwise the second one reads as the
        // first one flickering.
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            presentNext()
        }
    }
}

private struct RewardsDashboard: View {
    let summary: RewardsSummary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Metric.section) {
                RankHero(level: summary.level, todayBadge: summary.todayBadge)

                RewardStatsStrip(summary: summary)

                StreakCard(streak: summary.streak)

                GoalsSection(goals: summary.goals)

                AchievementsSection(achievements: summary.achievements)

                BadgeGallery(badges: Array(summary.dailyBadges.prefix(35)))
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Rank

/// The one thing on this screen that only ever goes up.
///
/// It leads because it is the answer to "am I getting anywhere": streaks reset,
/// months reset, and a shelf of daily medals says how many days rather than how
/// far. The medal itself is the rank's, not the day's, which is also what gives
/// the athlete something worth picking up and turning over.
struct RankHero: View {
    let level: RewardLevel
    var todayBadge: DailyBadge?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous)
                    .fill(.haraNight)

                Circle()
                    .fill(level.rank.tint.opacity(0.34))
                    .frame(width: 250, height: 250)
                    .blur(radius: 48)
                    .offset(y: -18)

                AchievementBadgeView(
                    title: level.rank.title,
                    caption: "\(level.points) points",
                    symbol: level.rank.symbol,
                    tint: level.rank.tint
                )
                .frame(height: 232)
                .padding(.top, 6)
            }
            .frame(height: 248)
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RANG")
                            .font(.haraEyebrow)
                            .foregroundStyle(.secondary)
                        Text(level.rank.title)
                            .font(.haraCardTitle)
                    }
                    Spacer(minLength: 0)
                    Text(level.progressDescription)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(level.rank.tint)
                        .contentTransition(.numericText())
                }

                Text(level.rank.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressTrack(progress: level.progress, tint: level.rank.tint)
                    .animation(.spring(response: 0.8, dampingFraction: 0.85), value: level.points)

                HStack(spacing: 8) {
                    Text(level.remainingDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if let badge = todayBadge {
                        Label(badge.tier.title, systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(badge.tier.tint)
                    }
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.09), radius: 22, y: 9)
        )
        .accessibilityElement(children: .contain)
    }
}

/// A capsule that fills. Used everywhere a goal has a fraction, so the same
/// amount of progress always looks like the same amount of progress.
struct ProgressTrack: View {
    let progress: Double
    var tint: Color = .haraCoral
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: min(1, max(0, progress)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Streak

/// The streak, and the fact that it can survive a bad day.
///
/// Shown with its safety net rather than as a bare number: a run that dies
/// silently the first time life gets in the way stops motivating anybody, and
/// an athlete who does not know they have a rest day banked cannot spend it.
struct StreakCard: View {
    let streak: StreakStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Image(systemName: streak.state == .secured ? "flame.fill" : "flame")
                        .font(.title2)
                        .foregroundStyle(tint)
                        .modifier(PulseWhenLive(isActive: streak.state == .secured && !reduceMotion))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(streak.headline)
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text(streak.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(spacing: 2) {
                    Text("\(streak.longest)")
                        .font(.headline.monospacedDigit())
                    Text("record")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Record, \(streak.longest) jours")
            }

            if let milestone = streak.nextMilestone {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressTrack(progress: streak.milestoneProgress, tint: tint, height: 8)
                        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: streak.current)
                    Text("Prochain palier à \(milestone) jours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 7) {
                ForEach(0..<StreakStatus.maximumRestDays, id: \.self) { index in
                    Image(systemName: index < streak.restDaysLeft ? "shield.fill" : "shield")
                        .font(.caption)
                        .foregroundStyle(
                            index < streak.restDaysLeft ? Color.haraMint : Color.secondary.opacity(0.45)
                        )
                }
                Text(streak.protectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Série, \(streak.headline)")
    }

    private var tint: Color {
        switch streak.state {
        case .idle: .secondary
        case .secured: .haraCoral
        case .atRisk: .haraOrange
        }
    }
}

/// Applied rather than inlined so the symbol effect can be switched off whole
/// for Reduce Motion without duplicating the icon.
private struct PulseWhenLive: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.symbolEffect(.pulse, options: .repeating)
        } else {
            content
        }
    }
}

// MARK: - Goals

/// Every horizon on one screen, shortest first.
///
/// A single monthly challenge was the whole system before, which meant an
/// athlete opening the app on the second of the month had nothing to do today
/// and nothing to finish this week.
struct GoalsSection: View {
    let goals: [ChallengeProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Objectifs",
                subtitle: "Du jour à l’année, calés sur votre rythme"
            )

            if goals.isEmpty {
                ContentUnavailableView(
                    "Pas encore d’objectif",
                    systemImage: "target",
                    description: Text("Une première séance ouvre les objectifs du jour et de la semaine.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
                .glassCard()
            } else {
                ForEach(goals) { goal in
                    ChallengeCard(challenge: goal, tint: tint(for: goal.period))
                }
            }
        }
    }

    /// Warm for the near horizons, cool for the far ones, so the stack reads as
    /// a ladder before a single word is read.
    private func tint(for period: ChallengePeriod) -> Color {
        switch period {
        case .day: .haraCoral
        case .week: .haraMint
        case .month: .haraOrange
        case .year: .haraBlue
        }
    }
}

// MARK: - Achievements

struct AchievementsSection: View {
    let achievements: [Achievement]

    @State private var selected: Achievement?

    private let columns = [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: 12)]

    private var unlockedCount: Int { achievements.count(where: \.isUnlocked) }

    /// The three closest to falling, so the section always opens on something
    /// that is genuinely within reach rather than on a wall of grey discs.
    private var withinReach: [Achievement] {
        achievements
            .filter { !$0.isUnlocked && $0.progress > 0 }
            .sorted {
                if $0.progress == $1.progress { return $0.targetValue < $1.targetValue }
                return $0.progress > $1.progress
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Hauts faits",
                subtitle: "\(unlockedCount) sur \(achievements.count) obtenus"
            )

            if !withinReach.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("À PORTÉE")
                        .font(.haraEyebrow)
                        .foregroundStyle(.secondary)
                    ForEach(withinReach) { achievement in
                        Button {
                            Haptics.tap()
                            selected = achievement
                        } label: {
                            AchievementRow(achievement: achievement)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(18)
                .glassCard()
            }

            ForEach(AchievementFamily.allCases) { family in
                let items = achievements.filter { $0.family == family }
                if !items.isEmpty {
                    familyCard(family, items: items)
                }
            }
        }
        .sheet(item: $selected) { achievement in
            AchievementDetailView(achievement: achievement)
        }
    }

    private func familyCard(_ family: AchievementFamily, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: family.symbol)
                    .font(.subheadline)
                    .foregroundStyle(family.tint)
                    .frame(width: 34, height: 34)
                    .background(family.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(family.title).font(.subheadline.weight(.semibold))
                    Text(family.detail).font(.caption).foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(items.count(where: \.isUnlocked))/\(items.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(family.title), \(items.count(where: \.isUnlocked)) sur \(items.count) obtenus"
            )

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { achievement in
                    Button {
                        Haptics.tap()
                        selected = achievement
                    } label: {
                        AchievementTile(achievement: achievement)
                    }
                    .buttonStyle(.card)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(18)
        .glassCard()
    }
}

/// A flat medal. Deliberately not the 3D one: a screen with thirty `SCNView`s
/// on it is a screen that drops frames, and the geometry is worth paying for
/// exactly once — on the award the athlete opened.
struct AchievementTile: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                if achievement.isUnlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    achievement.family.tint.opacity(0.95),
                                    achievement.family.tint.opacity(0.5)
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 40
                            )
                        )
                        .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 2))
                        .shadow(color: achievement.family.tint.opacity(0.3), radius: 7, y: 4)
                } else {
                    Circle().fill(Color.secondary.opacity(0.13))
                    // The ring is the whole point of a locked tile: it turns a
                    // grey disc into a number of sessions away.
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(
                            achievement.family.tint.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: achievement.progress)
                }

                Image(systemName: achievement.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(
                        achievement.isUnlocked ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary)
                    )
            }
            .frame(width: 58, height: 58)

            Text(achievement.title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(
            achievement.isUnlocked
                ? "Obtenu, \(achievement.detail)"
                : "À débloquer, \(achievement.valueDescription)"
        )
    }
}

/// The wide form, used for the awards the athlete is closest to.
struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(achievement.family.tint.opacity(0.13))
                Circle()
                    .trim(from: 0, to: achievement.progress)
                    .stroke(
                        achievement.family.tint,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                Image(systemName: achievement.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(achievement.family.tint)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title).font(.subheadline.weight(.semibold))
                Text(achievement.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(achievement.valueDescription)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(achievement.family.tint)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title), \(achievement.remainingDescription)")
    }
}

/// What is behind an award, the way the Fitness app opens one: the medal in
/// three dimensions, what it took, and when it was earned.
struct AchievementDetailView: View {
    let achievement: Achievement

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AchievementBadgeView(
                        title: achievement.title,
                        caption: achievement.unlockedAt
                            .map { $0.formatted(.dateTime.day().month(.wide).year()) }
                            ?? achievement.valueDescription,
                        symbol: achievement.symbol,
                        tint: achievement.family.tint,
                        isUnlocked: achievement.isUnlocked
                    )
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient.haraNight,
                        in: RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous)
                    )

                    VStack(spacing: 6) {
                        Text(achievement.title).font(.haraCardTitle)
                        Text(achievement.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(achievement.family.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(achievement.family.tint)
                            Spacer()
                            Text(achievement.valueDescription)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressTrack(progress: achievement.progress, tint: achievement.family.tint)
                        Text(achievement.remainingDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .glassCard()

                    if let unlockedAt = achievement.unlockedAt {
                        Label(
                            "Obtenu le \(unlockedAt.formatted(date: .long, time: .omitted))",
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(achievement.family.tint)
                    }
                }
                .padding(Metric.gutter)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Haut fait")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Celebration

enum RewardCelebration: Identifiable, Hashable {
    case achievement(Achievement)
    case rank(RewardRank)

    var id: String {
        switch self {
        case let .achievement(achievement): "achievement-\(achievement.id)"
        case let .rank(rank): "rank-\(rank.rawValue)"
        }
    }
}

/// The moment something is earned.
///
/// A full screen rather than a banner on purpose: the whole point is that the
/// athlete stops for two seconds. The medal arrives before the words, the ring
/// closes behind it, and the haptic lands on the same beat as the spring.
struct RewardCelebrationView: View {
    let celebration: RewardCelebration
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            LinearGradient.haraNight.ignoresSafeArea()

            Circle()
                .fill(tint.opacity(0.3))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(y: -70)
                .opacity(revealed ? 1 : 0)

            VStack(spacing: 22) {
                Text(eyebrow)
                    .font(.haraEyebrow)
                    .foregroundStyle(Color.haraMint)
                    .opacity(revealed ? 1 : 0)

                ZStack {
                    Circle()
                        .trim(from: 0, to: revealed ? 1 : 0)
                        .stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 244, height: 244)

                    AchievementBadgeView(
                        title: title,
                        caption: caption,
                        symbol: symbol,
                        tint: tint
                    )
                    .frame(height: 250)
                    .scaleEffect(revealed ? 1 : 0.45)
                    .opacity(revealed ? 1 : 0)
                }
                .frame(height: 260)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.haraHeroTitle)
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 16)

                Button("Continuer") {
                    Haptics.tap()
                    onDismiss()
                }
                .buttonStyle(.haraPrimary(tint: Color.white, foreground: .haraNavy))
                .opacity(revealed ? 1 : 0)
            }
            .padding(28)
        }
        .foregroundStyle(.white)
        .task { await reveal() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(eyebrow). \(title). \(detail)")
    }

    private func reveal() async {
        guard !reduceMotion else {
            revealed = true
            Haptics.success()
            return
        }
        // A held beat before the medal lands, so the reveal is an arrival
        // rather than something that was already there.
        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) { revealed = true }
        Haptics.success()
    }

    private var eyebrow: String {
        switch celebration {
        case .achievement: "NOUVEAU HAUT FAIT"
        case .rank: "NOUVEAU RANG"
        }
    }

    private var title: String {
        switch celebration {
        case let .achievement(achievement): achievement.title
        case let .rank(rank): rank.title
        }
    }

    private var detail: String {
        switch celebration {
        case let .achievement(achievement): achievement.detail
        case let .rank(rank): rank.detail
        }
    }

    private var caption: String? {
        switch celebration {
        case let .achievement(achievement):
            achievement.unlockedAt.map { $0.formatted(.dateTime.day().month(.abbreviated)) }
        case .rank:
            "Rang atteint"
        }
    }

    private var symbol: String {
        switch celebration {
        case let .achievement(achievement): achievement.symbol
        case let .rank(rank): rank.symbol
        }
    }

    private var tint: Color {
        switch celebration {
        case let .achievement(achievement): achievement.family.tint
        case let .rank(rank): rank.tint
        }
    }
}

// MARK: - Daily collection

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
            MetricPill(
                icon: "medal.fill",
                value: "\(summary.unlockedAchievements.count)",
                label: "Hauts faits"
            )
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .glassCard()
    }
}

struct ChallengeCard: View {
    let challenge: ChallengeProgress
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .animation(Motion.honouring(reduceMotion, Motion.reveal), value: challenge.progress)

                Image(systemName: challenge.isCompleted ? "checkmark" : challenge.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                // No horizon chip. It repeated what the title already said —
                // "Rendez-vous de la semaine" next to "Cette semaine" — and it
                // took enough width from the title to wrap every one of them
                // onto a second line. The ring's tint carries the horizon for
                // anyone looking, and the accessibility label below carries it
                // in words for anyone who is not.
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.headline)
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(tint)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                Text(challenge.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(challenge.valueDescription)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(challenge.period.title), \(challenge.title), \(challenge.valueDescription), \(challenge.remainingDescription)"
        )
    }
}

struct BadgeGallery: View {
    let badges: [DailyBadge]

    @State private var selected: DailyBadge?

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 92), spacing: 14)]
    /// Ties each medal to the sheet it opens, so the detail grows out of the
    /// one that was tapped instead of sliding up over all of them.
    @Namespace private var medals

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
                        Button {
                            Haptics.tap()
                            selected = badge
                        } label: {
                            MiniBadgeView(badge: badge)
                        }
                        .buttonStyle(.card)
                        .matchedTransitionSource(id: badge.id, in: medals)
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(18)
                .glassCard()
            }
        }
        .sheet(item: $selected) { badge in
            BadgeDetailView(badge: badge)
                .navigationTransition(.zoom(sourceID: badge.id, in: medals))
        }
    }
}

/// What is behind a medal, the way the Health app opens an award: the medallion
/// itself, the day it stands for, and the work that earned it.
struct BadgeDetailView: View {
    let badge: DailyBadge

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AchievementBadgeView(
                        title: badge.tier.title,
                        caption: badge.day.formatted(.dateTime.day().month(.wide).year()),
                        symbol: badge.symbol,
                        tint: badge.tier.tint
                    )
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient.haraNight, in: RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous))

                    VStack(spacing: 6) {
                        Text(badge.tier.title)
                            .font(.haraCardTitle)
                        Text(badge.day, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 0) {
                        MetricPill(
                            icon: "clock.fill",
                            value: badge.activeSeconds.clockText,
                            label: "effort"
                        )
                        Divider().frame(height: 44)
                        MetricPill(
                            icon: "figure.core.training",
                            value: "\(badge.sessionCount)",
                            label: badge.sessionCount > 1 ? "séances" : "séance"
                        )
                        Divider().frame(height: 44)
                        MetricPill(
                            icon: "square.grid.2x2.fill",
                            value: "\(badge.sections.count)",
                            label: "types"
                        )
                    }
                    .padding(.vertical, 14)
                    .glassCard()

                    if !badge.sections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Travail de la journée")
                            ForEach(badge.sections) { section in
                                HStack(spacing: 12) {
                                    Image(systemName: section.symbol)
                                        .font(.subheadline)
                                        .foregroundStyle(section.color)
                                        .frame(width: 34, height: 34)
                                        .background(section.color.opacity(0.14), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(section.title).font(.subheadline.weight(.semibold))
                                        Text(section.detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(18)
                        .glassCard()
                    }

                    let movements = badge.movements
                    if !movements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Mouvements")
                            ForEach(Array(movements.enumerated()), id: \.offset) { _, movement in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(movement.accent.opacity(0.16))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            Image(systemName: CatalogSection.of(movement).symbol)
                                                .font(.caption)
                                                .foregroundStyle(movement.accent)
                                        }
                                    Text(movement.name).font(.subheadline)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(18)
                        .glassCard()
                    }
                }
                .padding(Metric.gutter)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
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
        case .bronze: .haraOrange
        case .silver: Color(red: 0.56, green: 0.68, blue: 0.78)
        case .gold: Color(red: 1.00, green: 0.76, blue: 0.18)
        }
    }
}
