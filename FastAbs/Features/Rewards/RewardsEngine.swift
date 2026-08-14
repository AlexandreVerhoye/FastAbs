import Foundation

enum DailyBadgeTier: Int, CaseIterable, Comparable {
    case bronze = 1
    case silver
    case gold

    static func < (lhs: DailyBadgeTier, rhs: DailyBadgeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .bronze: "Élan"
        case .silver: "Rythme"
        case .gold: "Sommet"
        }
    }
}

struct DailyBadge: Identifiable, Hashable {
    let day: Date
    let activeSeconds: Int
    let sessionCount: Int
    let tier: DailyBadgeTier
    /// What the day was mostly spent on, so the medal records the work rather
    /// than being decoration drawn from the date.
    let programme: TrainingProgramme

    var id: Date { day }

    var symbol: String {
        // A day that covered more than one programme earns its own mark.
        programme == .fullBody ? "medal.fill" : programme.symbol
    }
}

enum ChallengePeriod: String, Hashable {
    case month
    case year
}

enum ChallengeUnit: Hashable {
    case activeDays
    case activeMinutes
    case sessions
    case bodyAreas

    func formatted(_ value: Int) -> String {
        switch self {
        case .activeDays: "\(value) j"
        case .activeMinutes: "\(value) min"
        case .sessions: "\(value) séances"
        // Zero and one both take the singular in French.
        case .bodyAreas: abs(value) < 2 ? "\(value) zone" : "\(value) zones"
        }
    }
}

struct ChallengeProgress: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let period: ChallengePeriod
    let unit: ChallengeUnit
    let currentValue: Int
    let targetValue: Int
    let startDate: Date
    let endDate: Date
    let symbol: String

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1, max(0, Double(currentValue) / Double(targetValue)))
    }

    var isCompleted: Bool { currentValue >= targetValue }
    var valueDescription: String { "\(unit.formatted(currentValue)) / \(unit.formatted(targetValue))" }

    var remainingDescription: String {
        guard !isCompleted else { return "Défi accompli" }
        return "Encore \(unit.formatted(max(0, targetValue - currentValue)))"
    }
}

struct RewardsSummary {
    let currentStreak: Int
    let longestStreak: Int
    let todayBadge: DailyBadge?
    let dailyBadges: [DailyBadge]
    let weeklyBalance: ChallengeProgress
    let monthlyChallenge: ChallengeProgress
    let annualChallenge: ChallengeProgress

    var earnedBadgeCount: Int {
        dailyBadges.count + (monthlyChallenge.isCompleted ? 1 : 0) + (annualChallenge.isCompleted ? 1 : 0)
    }
}

/// Rebuilds badges and challenges solely from workout history.
///
/// This makes reward state idempotent: inserting the same workout twice can
/// change session totals, but a date can still mint at most one daily badge.
struct RewardsEngine {
    let calendar: Calendar
    private let analytics: WorkoutHistoryAnalytics

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        analytics = WorkoutHistoryAnalytics(calendar: calendar)
    }

    func summary(records: [WorkoutRecord], now: Date = .now) -> RewardsSummary {
        let badges = dailyBadges(records: records)
        let today = calendar.startOfDay(for: now)
        let overview = analytics.overview(records: records, now: now)

        return RewardsSummary(
            currentStreak: overview.currentStreak,
            longestStreak: overview.longestStreak,
            todayBadge: badges.first { calendar.isDate($0.day, inSameDayAs: today) },
            dailyBadges: badges.sorted { $0.day > $1.day },
            weeklyBalance: weeklyBalance(records: records, now: now),
            monthlyChallenge: monthlyChallenge(records: records, now: now),
            annualChallenge: annualChallenge(records: records, now: now)
        )
    }

    func dailyBadges(records: [WorkoutRecord]) -> [DailyBadge] {
        let validRecords = analytics.qualifyingRecords(from: records)
        let grouped = Dictionary(grouping: validRecords) {
            calendar.startOfDay(for: $0.completedAt)
        }

        return grouped.map { day, dayRecords in
            let seconds = dayRecords.reduce(0) { $0 + max(0, $1.activeDuration) }
            return DailyBadge(
                day: day,
                activeSeconds: seconds,
                sessionCount: dayRecords.count,
                tier: badgeTier(activeSeconds: seconds),
                programme: dominantProgramme(of: dayRecords)
            )
        }
    }

    /// How much of the body this week has touched.
    ///
    /// Streaks and minutes both reward showing up, and someone can show up for
    /// a month training nothing but abs. This is the one challenge that asks
    /// what you trained rather than how often.
    func weeklyBalance(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisWeek = recordsWithin(week, from: analytics.qualifyingRecords(from: records))
        let areas = coveredAreas(of: thisWeek)

        return ChallengeProgress(
            id: "balance-\(dateComponentsID(for: week?.start ?? now))",
            title: "Semaine complète",
            detail: "Entraînez la sangle, le haut et le bas du corps.",
            period: .month,
            unit: .bodyAreas,
            currentValue: areas.count,
            targetValue: BodyRegion.allCases.count,
            startDate: week?.start ?? now,
            endDate: week?.end ?? now,
            symbol: "figure.mixed.cardio"
        )
    }

    func monthlyChallenge(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now) else {
            return fallbackMonthlyChallenge(now: now)
        }
        let validRecords = analytics.qualifyingRecords(from: records)
        let previousReference = calendar.date(byAdding: .day, value: -1, to: currentMonth.start) ?? currentMonth.start
        let previousMonth = calendar.dateInterval(of: .month, for: previousReference)
        let monthNumber = calendar.component(.month, from: currentMonth.start)

        switch monthNumber % 3 {
        case 0:
            let previousDays = uniqueActiveDays(records: recordsWithin(previousMonth, from: validRecords)).count
            let target = adaptiveTarget(previousValue: previousDays, fallback: 12, lowerBound: 8, upperBound: 20)
            let current = uniqueActiveDays(records: recordsWithin(currentMonth, from: validRecords)).count
            return ChallengeProgress(
                id: monthID(for: currentMonth.start),
                title: "Mois régulier",
                detail: "Bougez souvent, même quelques minutes.",
                period: .month,
                unit: .activeDays,
                currentValue: current,
                targetValue: target,
                startDate: currentMonth.start,
                endDate: currentMonth.end,
                symbol: "calendar.badge.checkmark"
            )

        case 1:
            let previousMinutes = activeSeconds(records: recordsWithin(previousMonth, from: validRecords)) / 60
            let target = roundedToFive(
                adaptiveTarget(previousValue: previousMinutes, fallback: 84, lowerBound: 60, upperBound: 300)
            )
            let current = activeSeconds(records: recordsWithin(currentMonth, from: validRecords)) / 60
            return ChallengeProgress(
                id: monthID(for: currentMonth.start),
                title: "Minutes puissantes",
                detail: "Cumulez du temps actif à votre rythme.",
                period: .month,
                unit: .activeMinutes,
                currentValue: current,
                targetValue: target,
                startDate: currentMonth.start,
                endDate: currentMonth.end,
                symbol: "timer"
            )

        default:
            let previousSessions = recordsWithin(previousMonth, from: validRecords).count
            let target = adaptiveTarget(previousValue: previousSessions, fallback: 12, lowerBound: 8, upperBound: 24)
            let current = recordsWithin(currentMonth, from: validRecords).count
            return ChallengeProgress(
                id: monthID(for: currentMonth.start),
                title: "Rendez-vous du mois",
                detail: "Chaque séance rapproche de la médaille.",
                period: .month,
                unit: .sessions,
                currentValue: current,
                targetValue: target,
                startDate: currentMonth.start,
                endDate: currentMonth.end,
                symbol: "checkmark.seal.fill"
            )
        }
    }

    func annualChallenge(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        let validRecords = analytics.qualifyingRecords(from: records)
        let firstDay = validRecords
            .map { calendar.startOfDay(for: $0.completedAt) }
            .min() ?? calendar.startOfDay(for: now)
        let cycle = annualCycle(startingAt: firstDay, containing: now)
        let cycleRecords = recordsWithin(cycle, from: validRecords)
        let activeDays = uniqueActiveDays(records: cycleRecords).count

        return ChallengeProgress(
            id: "annual-\(dateComponentsID(for: cycle.start))",
            title: "Constellation annuelle",
            detail: "100 jours actifs sur votre année Hara.",
            period: .year,
            unit: .activeDays,
            currentValue: activeDays,
            targetValue: 100,
            startDate: cycle.start,
            endDate: cycle.end,
            symbol: "sparkles"
        )
    }

    /// Which parts of the body a set of sessions set out to train.
    ///
    /// Deliberately read from the programme rather than from the muscles the
    /// movements happened to load: almost every abs session brushes the glutes
    /// on a bridge, and counting that as leg day would make a balanced week
    /// something you complete by accident.
    private func coveredAreas(of records: [WorkoutRecord]) -> Set<BodyRegion> {
        Set(records.flatMap(\.programme.regions))
    }

    /// The programme a day is remembered by: whichever took the most time, or
    /// whole-body when the day genuinely spanned the body.
    private func dominantProgramme(of records: [WorkoutRecord]) -> TrainingProgramme {
        if coveredAreas(of: records).count >= BodyRegion.allCases.count { return .fullBody }

        var seconds: [TrainingProgramme: Int] = [:]
        for record in records {
            seconds[record.programme, default: 0] += max(0, record.activeDuration)
        }
        return seconds.max { $0.value < $1.value }?.key ?? .core
    }

    private func badgeTier(activeSeconds: Int) -> DailyBadgeTier {
        if activeSeconds >= 720 { return .gold }
        if activeSeconds >= 420 { return .silver }
        return .bronze
    }

    private func adaptiveTarget(previousValue: Int, fallback: Int, lowerBound: Int, upperBound: Int) -> Int {
        guard previousValue > 0 else { return fallback }
        let improved = Int((Double(previousValue) * 1.08).rounded(.up))
        return min(upperBound, max(lowerBound, improved))
    }

    private func roundedToFive(_ value: Int) -> Int {
        Int((Double(value) / 5).rounded(.up)) * 5
    }

    private func activeSeconds(records: [WorkoutRecord]) -> Int {
        records.reduce(0) { $0 + max(0, $1.activeDuration) }
    }

    private func uniqueActiveDays(records: [WorkoutRecord]) -> Set<Date> {
        Set(records.map { calendar.startOfDay(for: $0.completedAt) })
    }

    private func recordsWithin(_ interval: DateInterval?, from records: [WorkoutRecord]) -> [WorkoutRecord] {
        guard let interval else { return [] }
        return records.filter { interval.contains($0.completedAt) }
    }

    private func annualCycle(startingAt firstDay: Date, containing now: Date) -> DateInterval {
        var start = calendar.startOfDay(for: firstDay)
        var end = calendar.date(byAdding: .year, value: 1, to: start) ?? now

        while now >= end {
            start = end
            end = calendar.date(byAdding: .year, value: 1, to: start) ?? end
        }
        return DateInterval(start: start, end: end)
    }

    private func fallbackMonthlyChallenge(now: Date) -> ChallengeProgress {
        let day = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .month, value: 1, to: day) ?? day
        return ChallengeProgress(
            id: "monthly-fallback",
            title: "Rendez-vous du mois",
            detail: "Chaque séance rapproche de la médaille.",
            period: .month,
            unit: .sessions,
            currentValue: 0,
            targetValue: 12,
            startDate: day,
            endDate: end,
            symbol: "checkmark.seal.fill"
        )
    }

    private func monthID(for date: Date) -> String {
        "monthly-\(dateComponentsID(for: date))"
    }

    private func dateComponentsID(for date: Date) -> String {
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(values.year ?? 0)-\(values.month ?? 0)-\(values.day ?? 0)"
    }
}
