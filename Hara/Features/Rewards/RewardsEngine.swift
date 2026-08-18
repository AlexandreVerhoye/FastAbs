import Foundation
import SwiftUI

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
    /// What the day was mostly spent doing, so the medal records the work
    /// rather than being decoration drawn from the date.
    let pattern: CorePattern
    /// Every job the day touched, for the detail sheet.
    let patterns: Set<CorePattern>
    let exerciseIDs: [String]

    var id: Date { day }

    /// A day that covered every job the trunk does earns its own mark.
    var isComplete: Bool { patterns.count >= CorePattern.allCases.count }

    var symbol: String { isComplete ? "medal.fill" : pattern.symbol }

    var movements: [Exercise] { exerciseIDs.compactMap { ExerciseCatalog.byID[$0] } }
}

enum ChallengePeriod: String, Hashable, Sendable {
    case day
    case week
    case month
    case year

    /// The horizon shown above a goal, so a screen full of them reads as a
    /// ladder rather than a pile.
    var title: String {
        switch self {
        case .day: "Aujourd’hui"
        case .week: "Cette semaine"
        case .month: "Ce mois"
        case .year: "Cette année"
        }
    }
}

enum ChallengeUnit: Hashable, Sendable {
    case activeDays
    case activeMinutes
    case sessions
    case corePatterns
    case muscleZones
    /// A plain count of occurrences, for the rules that are not measured in any
    /// of the above — weeks touched, levels tried, sessions of a given shape.
    case times

    func formatted(_ value: Int) -> String {
        switch self {
        case .activeDays: "\(value) j"
        case .activeMinutes: "\(value) min"
        case .sessions: "\(value) séances"
        // Zero and one both take the singular in French.
        case .corePatterns: abs(value) < 2 ? "\(value) type" : "\(value) types"
        case .muscleZones: abs(value) < 2 ? "\(value) zone" : "\(value) zones"
        case .times: "\(value) fois"
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

    /// A goal with nothing behind it, so a summary can exist before any history
    /// has been read.
    static let none = ChallengeProgress(
        id: "none",
        title: "Objectif",
        detail: "Terminez une séance pour ouvrir un objectif.",
        period: .day,
        unit: .activeMinutes,
        currentValue: 0,
        targetValue: 0,
        startDate: .distantPast,
        endDate: .distantPast,
        symbol: "target"
    )
}

// MARK: - Rank

/// How far the athlete has come, in eight steps.
///
/// Streaks reward showing up and challenges reset every month, so neither of
/// them can say "you are further along than you were in March". This is the one
/// number that only ever goes up, which is what makes a long history feel like
/// it was worth keeping.
enum RewardRank: Int, CaseIterable, Comparable, Sendable {
    case appui = 0
    case ancrage
    case socle
    case pilier
    case armature
    case voute
    case rempart
    case monolithe

    static func < (lhs: RewardRank, rhs: RewardRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .appui: "Appui"
        case .ancrage: "Ancrage"
        case .socle: "Socle"
        case .pilier: "Pilier"
        case .armature: "Armature"
        case .voute: "Voûte"
        case .rempart: "Rempart"
        case .monolithe: "Monolithe"
        }
    }

    var detail: String {
        switch self {
        case .appui: "Les premiers repères sont posés."
        case .ancrage: "La séance a trouvé sa place dans la semaine."
        case .socle: "Le travail tient sans avoir à y penser."
        case .pilier: "La sangle porte le reste du corps."
        case .armature: "Tous les plans du tronc sont couverts."
        case .voute: "La charge se répartit d’elle-même."
        case .rempart: "Plus rien ne fait plier la ligne."
        case .monolithe: "Un seul bloc, du bassin aux épaules."
        }
    }

    var symbol: String {
        switch self {
        case .appui: "circle.bottomhalf.filled"
        case .ancrage: "arrow.down.to.line.compact"
        case .socle: "square.stack.3d.down.right.fill"
        case .pilier: "building.columns.fill"
        case .armature: "square.grid.3x3.fill"
        case .voute: "circle.hexagongrid.fill"
        case .rempart: "shield.lefthalf.filled"
        case .monolithe: "cube.fill"
        }
    }

    /// Points that open this rank.
    ///
    /// Sized against a real week: an ordinary seven-minute session is worth
    /// about thirteen points, so four a week is roughly two hundred a month.
    /// Appui is reached on the first session, Monolithe takes a couple of
    /// years of that — long enough that arriving there means something.
    var threshold: Int {
        switch self {
        case .appui: 0
        case .ancrage: 120
        case .socle: 320
        case .pilier: 700
        case .armature: 1_300
        case .voute: 2_200
        case .rempart: 3_600
        case .monolithe: 5_600
        }
    }

    var next: RewardRank? { RewardRank(rawValue: rawValue + 1) }

    var tint: Color {
        switch self {
        case .appui, .ancrage: .haraMint
        case .socle, .pilier: .haraBlue
        case .armature, .voute: .haraOrange
        case .rempart, .monolithe: .haraCoral
        }
    }
}

struct RewardLevel: Hashable {
    let rank: RewardRank
    let points: Int
    /// Points earned since this rank opened.
    let pointsIntoRank: Int
    /// The span of the current rank; nil once there is nothing above it.
    let rankSpan: Int?

    var next: RewardRank? { rank.next }

    var progress: Double {
        guard let rankSpan, rankSpan > 0 else { return 1 }
        return min(1, max(0, Double(pointsIntoRank) / Double(rankSpan)))
    }

    var pointsToNextRank: Int {
        guard let rankSpan else { return 0 }
        return max(0, rankSpan - pointsIntoRank)
    }

    var progressDescription: String {
        guard let rankSpan else { return "\(points) points" }
        return "\(pointsIntoRank) / \(rankSpan) points"
    }

    var remainingDescription: String {
        guard let next else { return "Rang le plus haut atteint" }
        return "Encore \(pointsToNextRank) points avant \(next.title)"
    }

    static let start = RewardLevel(
        rank: .appui,
        points: 0,
        pointsIntoRank: 0,
        rankSpan: RewardRank.ancrage.threshold
    )
}

// MARK: - Streak

/// The streak, with somewhere to fall.
///
/// A run that dies the first time life gets in the way stops being motivating
/// after the first death, so the athlete banks a protected rest day for every
/// seven days trained, two at most. Two blank days in a row still end it —
/// otherwise it is not a streak.
struct StreakStatus: Hashable {
    enum State: Hashable {
        case idle
        /// Trained today: nothing can take it away before midnight.
        case secured
        /// Alive on yesterday's session and waiting for today's.
        case atRisk
    }

    static let milestones = [3, 7, 14, 30, 60, 100, 180, 365]
    /// One protected rest day per seven days trained.
    static let daysPerRestDay = 7
    static let maximumRestDays = 2

    let current: Int
    let longest: Int
    let restDaysUsed: Int
    let restDaysEarned: Int
    let isSecuredToday: Bool

    var restDaysLeft: Int { max(0, restDaysEarned - restDaysUsed) }

    var state: State {
        if current == 0 { return .idle }
        return isSecuredToday ? .secured : .atRisk
    }

    var nextMilestone: Int? { Self.milestones.first { $0 > current } }

    var daysToMilestone: Int {
        guard let nextMilestone else { return 0 }
        return max(0, nextMilestone - current)
    }

    var milestoneProgress: Double {
        guard let nextMilestone, nextMilestone > 0 else { return 1 }
        let floorValue = Self.milestones.last { $0 <= current } ?? 0
        let span = nextMilestone - floorValue
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(current - floorValue) / Double(span)))
    }

    var headline: String {
        switch state {
        case .idle: "Série à lancer"
        case .secured, .atRisk: current == 1 ? "1 jour d’affilée" : "\(current) jours d’affilée"
        }
    }

    var detail: String {
        switch state {
        case .idle:
            return "Une séance aujourd’hui ouvre la série."
        case .atRisk:
            return "Terminez une séance aujourd’hui pour la garder."
        case .secured:
            guard let nextMilestone else { return "Record absolu, jour après jour." }
            let days = daysToMilestone == 1 ? "1 jour" : "\(daysToMilestone) jours"
            return "Encore \(days) avant le palier de \(nextMilestone)."
        }
    }

    /// What the safety net looks like right now, said plainly.
    var protectionDescription: String {
        switch restDaysLeft {
        case 0 where restDaysEarned == 0:
            return "Un jour de repos protégé tous les \(Self.daysPerRestDay) jours."
        case 0:
            return "Jours de repos épuisés, ne manquez pas demain."
        case 1:
            return "1 jour de repos protégé en réserve."
        default:
            return "\(restDaysLeft) jours de repos protégés en réserve."
        }
    }

    static let idle = StreakStatus(
        current: 0,
        longest: 0,
        restDaysUsed: 0,
        restDaysEarned: 0,
        isSecuredToday: false
    )
}

// MARK: - Achievements

enum AchievementFamily: String, CaseIterable, Identifiable, Hashable, Sendable {
    case regularity
    case volume
    case coverage
    case intensity
    case mastery
    case ritual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regularity: "Régularité"
        case .volume: "Volume"
        case .coverage: "Couverture"
        case .intensity: "Intensité"
        case .mastery: "Maîtrise"
        case .ritual: "Rituel"
        }
    }

    var detail: String {
        switch self {
        case .regularity: "Revenir, encore et encore."
        case .volume: "Le temps que le tronc a passé sous tension."
        case .coverage: "Travailler le tronc sous tous ses angles."
        case .intensity: "Monter les niveaux et y rester."
        case .mastery: "Les sommets personnels."
        case .ritual: "L’heure, le retour, l’habitude."
        }
    }

    var symbol: String {
        switch self {
        case .regularity: "flame.fill"
        case .volume: "timer"
        case .coverage: "square.grid.2x2.fill"
        case .intensity: "bolt.fill"
        case .mastery: "trophy.fill"
        case .ritual: "sunrise.fill"
        }
    }

    var tint: Color {
        switch self {
        case .regularity: .haraCoral
        case .volume: .haraOrange
        case .coverage: .haraMint
        case .intensity: .haraBlue
        // Deliberately the same gold as the top daily tier: the two mean the
        // same thing on two different clocks.
        case .mastery: Color(red: 1.00, green: 0.76, blue: 0.18)
        case .ritual: .purple
        }
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let family: AchievementFamily
    let unit: ChallengeUnit
    let currentValue: Int
    let targetValue: Int
    /// The moment the counter first crossed the line, read back out of the
    /// history rather than stored — so the date survives a reinstall and can
    /// never disagree with the sessions it was earned from.
    let unlockedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1, max(0, Double(currentValue) / Double(targetValue)))
    }

    var valueDescription: String {
        "\(unit.formatted(min(currentValue, targetValue))) / \(unit.formatted(targetValue))"
    }

    var remainingDescription: String {
        guard !isUnlocked else { return "Obtenu" }
        return "Encore \(unit.formatted(max(0, targetValue - currentValue)))"
    }
}

// MARK: - Summary

struct RewardsSummary {
    let currentStreak: Int
    let longestStreak: Int
    let todayBadge: DailyBadge?
    let dailyBadges: [DailyBadge]
    let weeklyBalance: ChallengeProgress
    let monthlyChallenge: ChallengeProgress
    let annualChallenge: ChallengeProgress
    let level: RewardLevel
    let streak: StreakStatus
    let dailyGoal: ChallengeProgress
    let weeklySessions: ChallengeProgress
    let achievements: [Achievement]

    /// The new members carry defaults so a summary can still be built from the
    /// four values a preview or a test actually cares about.
    init(
        currentStreak: Int,
        longestStreak: Int,
        todayBadge: DailyBadge?,
        dailyBadges: [DailyBadge],
        weeklyBalance: ChallengeProgress,
        monthlyChallenge: ChallengeProgress,
        annualChallenge: ChallengeProgress,
        level: RewardLevel = .start,
        streak: StreakStatus = .idle,
        dailyGoal: ChallengeProgress = .none,
        weeklySessions: ChallengeProgress = .none,
        achievements: [Achievement] = []
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.todayBadge = todayBadge
        self.dailyBadges = dailyBadges
        self.weeklyBalance = weeklyBalance
        self.monthlyChallenge = monthlyChallenge
        self.annualChallenge = annualChallenge
        self.level = level
        self.streak = streak
        self.dailyGoal = dailyGoal
        self.weeklySessions = weeklySessions
        self.achievements = achievements
    }

    var earnedBadgeCount: Int {
        dailyBadges.count + (monthlyChallenge.isCompleted ? 1 : 0) + (annualChallenge.isCompleted ? 1 : 0)
    }

    /// Every goal, shortest horizon first, which is the order they are worth
    /// reading in: today is actionable, the year is a promise.
    var goals: [ChallengeProgress] {
        [dailyGoal, weeklyBalance, weeklySessions, monthlyChallenge, annualChallenge]
            .filter { $0.targetValue > 0 }
    }

    var unlockedAchievements: [Achievement] {
        achievements
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }

    /// The three the athlete is closest to, so the screen always has something
    /// to point at that is genuinely within reach.
    var nextAchievements: [Achievement] {
        achievements
            .filter { !$0.isUnlocked }
            .sorted {
                if $0.progress == $1.progress { return $0.targetValue < $1.targetValue }
                return $0.progress > $1.progress
            }
            .prefix(3)
            .map { $0 }
    }
}

/// Rebuilds badges, goals, rank and achievements solely from workout history.
///
/// This makes reward state idempotent: inserting the same workout twice can
/// change session totals, but a date can still mint at most one daily badge,
/// and an achievement can still only be earned once. Nothing about the reward
/// system is stored, so nothing about it can drift out of step with the
/// sessions it claims to describe.
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
            annualChallenge: annualChallenge(records: records, now: now),
            level: level(records: records),
            streak: streakStatus(records: records, now: now),
            dailyGoal: dailyGoal(records: records, now: now),
            weeklySessions: weeklySessions(records: records, now: now),
            achievements: achievements(records: records)
        )
    }

    func dailyBadges(records: [WorkoutRecord]) -> [DailyBadge] {
        let validRecords = analytics.qualifyingRecords(from: records)
        let grouped = Dictionary(grouping: validRecords) {
            calendar.startOfDay(for: $0.completedAt)
        }

        return grouped.map { day, dayRecords in
            let seconds = dayRecords.reduce(0) { $0 + max(0, $1.activeDuration) }
            let patterns = dayRecords.reduce(into: Set<CorePattern>()) { $0.formUnion($1.trainedPatterns) }
            return DailyBadge(
                day: day,
                activeSeconds: seconds,
                sessionCount: dayRecords.count,
                tier: badgeTier(activeSeconds: seconds),
                pattern: dominantPattern(of: dayRecords),
                patterns: patterns,
                exerciseIDs: dayRecords.flatMap(\.exerciseIDs)
            )
        }
    }

    // MARK: Rank

    /// What one session is worth.
    ///
    /// Minutes are the base, because that is the work. The rest is there to
    /// stop the number from rewarding only one behaviour: a level multiplier so
    /// hard sessions are not worth the same as easy ones, a bonus for finishing
    /// what was started, one for covering several jobs of the trunk in the same
    /// session, and one for saying how it felt — which is the input the coach
    /// needs and the only one the app cannot measure by itself.
    func points(for record: WorkoutRecord) -> Int {
        guard analytics.isQualifying(record) else { return 0 }
        let minutes = Double(max(0, record.activeDuration)) / 60
        let effort = Int((minutes * difficultyWeight(record.difficulty)).rounded())
        let completion = record.wasCompleted ? 4 : 0
        let coverage = 2 * max(0, record.trainedPatterns.count - 1)
        let rated = record.perceivedEffort == .unrated ? 0 : 1
        return effort + completion + coverage + rated
    }

    func trainingPoints(records: [WorkoutRecord]) -> Int {
        records.reduce(0) { $0 + points(for: $1) }
    }

    func level(records: [WorkoutRecord]) -> RewardLevel {
        level(points: trainingPoints(records: records))
    }

    func level(points: Int) -> RewardLevel {
        let rank = RewardRank.allCases.last { points >= $0.threshold } ?? .appui
        guard let next = rank.next else {
            return RewardLevel(
                rank: rank,
                points: points,
                pointsIntoRank: points - rank.threshold,
                rankSpan: nil
            )
        }
        return RewardLevel(
            rank: rank,
            points: points,
            pointsIntoRank: points - rank.threshold,
            rankSpan: next.threshold - rank.threshold
        )
    }

    private func difficultyWeight(_ difficulty: WorkoutDifficulty) -> Double {
        switch difficulty {
        case .beginner: 1
        case .balanced: 1.2
        case .advanced: 1.45
        case .athlete: 1.75
        }
    }

    // MARK: Streak

    /// The streak the athlete is actually shown, protected rest days included.
    ///
    /// Walked backwards from today rather than derived from the raw run in
    /// `WorkoutHistoryAnalytics`, because the allowance is earned by the recent
    /// part of the run: seven days trained buys one blank day, fourteen buys
    /// the second, and that is as far as it goes. Two blanks back to back end
    /// it whatever is banked — a streak that cannot break is not a streak.
    func streakStatus(records: [WorkoutRecord], now: Date = .now) -> StreakStatus {
        let validRecords = analytics.qualifyingRecords(from: records)
        let days = Set(validRecords.map { calendar.startOfDay(for: $0.completedAt) })
        guard let earliest = days.min() else { return .idle }

        let today = calendar.startOfDay(for: now)
        let isSecuredToday = days.contains(today)
        // Today is not over, so its blank square cannot count against anything.
        guard var cursor = isSecuredToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)
        else { return .idle }

        var streak = 0
        var restDaysUsed = 0
        var blanksInARow = 0

        while cursor >= earliest {
            if days.contains(cursor) {
                streak += 1
                blanksInARow = 0
            } else {
                blanksInARow += 1
                let earned = min(StreakStatus.maximumRestDays, streak / StreakStatus.daysPerRestDay)
                guard blanksInARow < 2, restDaysUsed < earned else { break }
                restDaysUsed += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return StreakStatus(
            current: streak,
            longest: analytics.longestStreak(records: records),
            restDaysUsed: restDaysUsed,
            restDaysEarned: min(StreakStatus.maximumRestDays, streak / StreakStatus.daysPerRestDay),
            isSecuredToday: isSecuredToday
        )
    }

    // MARK: Goals

    /// Today's minutes, against a bar the athlete set themselves.
    ///
    /// The target is the middle of their own recent days rather than a round
    /// number chosen here: a bar somebody has already cleared eight times is
    /// one they believe in, and it moves with them without ever being announced.
    func dailyGoal(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        let validRecords = analytics.qualifyingRecords(from: records)
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: validRecords) { calendar.startOfDay(for: $0.completedAt) }
        let todaySeconds = byDay[today]?.reduce(0) { $0 + max(0, $1.activeDuration) } ?? 0

        let recentMinutes = byDay
            .filter { $0.key < today }
            .sorted { $0.key > $1.key }
            .prefix(14)
            .map { _, dayRecords in dayRecords.reduce(0) { $0 + max(0, $1.activeDuration) } / 60 }
            .sorted()
        // Seven minutes with nothing to go on, which is the length the app
        // recommends; then the athlete's own middle day takes over.
        let median = recentMinutes.isEmpty ? 7 : recentMinutes[recentMinutes.count / 2]
        let target = min(20, max(5, median))

        return ChallengeProgress(
            id: "daily-\(dateComponentsID(for: today))",
            title: "Objectif du jour",
            detail: "Le temps de travail que vous tenez d’habitude.",
            period: .day,
            unit: .activeMinutes,
            currentValue: todaySeconds / 60,
            targetValue: target,
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
            symbol: "target"
        )
    }

    /// How many times the week has been shown up for.
    func weeklySessions(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        let validRecords = analytics.qualifyingRecords(from: records)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let previousReference = week.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.start) }
        let previousWeek = previousReference.flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
        let previousCount = recordsWithin(previousWeek, from: validRecords).count

        return ChallengeProgress(
            id: "week-sessions-\(dateComponentsID(for: week?.start ?? now))",
            title: "Rendez-vous de la semaine",
            detail: "Des séances réparties, pas entassées sur un jour.",
            period: .week,
            unit: .sessions,
            currentValue: recordsWithin(week, from: validRecords).count,
            targetValue: adaptiveTarget(previousValue: previousCount, fallback: 4, lowerBound: 3, upperBound: 6),
            startDate: week?.start ?? now,
            endDate: week?.end ?? now,
            symbol: "calendar"
        )
    }

    /// How many of the trunk's jobs this week has touched.
    ///
    /// Streaks and minutes both reward showing up, and someone can show up
    /// every day for a month doing nothing but crunches. This is the one
    /// challenge that asks what you trained rather than how often.
    func weeklyBalance(records: [WorkoutRecord], now: Date = .now) -> ChallengeProgress {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisWeek = recordsWithin(week, from: analytics.qualifyingRecords(from: records))
        let patterns = thisWeek.reduce(into: Set<CorePattern>()) { $0.formUnion($1.trainedPatterns) }

        return ChallengeProgress(
            id: "balance-\(dateComponentsID(for: week?.start ?? now))",
            title: "Semaine complète",
            detail: "Gainage, stabilité, latéral, flexion et extension.",
            period: .week,
            unit: .corePatterns,
            currentValue: patterns.count,
            targetValue: CorePattern.allCases.count,
            startDate: week?.start ?? now,
            endDate: week?.end ?? now,
            symbol: "square.grid.2x2.fill"
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

    // MARK: Achievements

    /// The whole shelf, earned or not, with the date each one was earned.
    ///
    /// Replayed in order rather than measured against today's totals, because
    /// an award with no date on it is an award nobody believes they earned. One
    /// pass over the history feeds every rule.
    func achievements(records: [WorkoutRecord]) -> [Achievement] {
        let ordered = analytics.qualifyingRecords(from: records)
            .sorted { $0.completedAt < $1.completedAt }

        var tally = HistoryTally()
        var unlockedAt: [String: Date] = [:]

        for record in ordered {
            tally.absorb(record, calendar: calendar)
            for rule in Self.achievementRules where unlockedAt[rule.id] == nil {
                guard rule.value(tally) >= rule.target else { continue }
                unlockedAt[rule.id] = record.completedAt
            }
        }

        return Self.achievementRules.map { rule in
            Achievement(
                id: rule.id,
                title: rule.title,
                detail: rule.detail,
                symbol: rule.symbol,
                family: rule.family,
                unit: rule.unit,
                currentValue: rule.value(tally),
                targetValue: rule.target,
                unlockedAt: unlockedAt[rule.id]
            )
        }
    }

    // MARK: - Private

    /// The job a day is remembered by: whichever the most movements served.
    /// Ties break on the pattern order so the same day always looks the same.
    private func dominantPattern(of records: [WorkoutRecord]) -> CorePattern {
        var counts: [CorePattern: Int] = [:]
        for id in records.flatMap(\.exerciseIDs) {
            guard let exercise = ExerciseCatalog.byID[id] else { continue }
            counts[exercise.pattern, default: 0] += 1
        }
        let ranked = CorePattern.allCases.map { ($0, counts[$0] ?? 0) }
        return ranked.max { lhs, rhs in lhs.1 < rhs.1 }?.0 ?? .antiExtension
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

// MARK: - The one pass over history

/// Everything the achievement rules are allowed to ask about a history.
///
/// One structure rather than a query per rule: twenty-nine rules each scanning
/// the records would turn opening the Rewards tab into a hundred passes over
/// the same array, and the unlock dates need the counters as they stood at each
/// session anyway.
private struct HistoryTally: Sendable {
    var sessions = 0
    var activeSeconds = 0
    var longestSessionSeconds = 0
    var fullSessions = 0
    var patternSessions: [CorePattern: Int] = [:]
    var zones: Set<MuscleZone> = []
    var difficulties: Set<WorkoutDifficulty> = []
    var advancedSessions = 0
    var athleteSessions = 0
    var ratedSessions = 0
    var wellDosedSessions = 0
    var hardSessions = 0
    var morningSessions = 0
    var eveningSessions = 0

    var bestStreak = 0
    var busiestDaySessions = 0
    var bestWeekSeconds = 0
    var bestMonthDays = 0
    var activeWeeks: Set<Date> = []
    var balancedWeeks = 0

    private var currentRun = 0
    private var lastDay: Date?
    private var sessionsByDay: [Date: Int] = [:]
    private var secondsByWeek: [Date: Int] = [:]
    private var daysByMonth: [Date: Set<Date>] = [:]
    private var patternsByWeek: [Date: Set<CorePattern>] = [:]

    var activeMinutes: Int { activeSeconds / 60 }
    var longestSessionMinutes: Int { longestSessionSeconds / 60 }
    var bestWeekMinutes: Int { bestWeekSeconds / 60 }
    var zoneCount: Int { zones.count }
    var difficultyCount: Int { difficulties.count }
    var activeWeekCount: Int { activeWeeks.count }

    /// The least-trained job of the trunk, which is the honest measure of
    /// whether the whole thing has been covered.
    var leastTrainedPatternSessions: Int {
        CorePattern.allCases.map { patternSessions[$0] ?? 0 }.min() ?? 0
    }

    /// Records arrive oldest first, which is what lets the streak and the
    /// per-week totals be maintained incrementally instead of re-derived.
    mutating func absorb(_ record: WorkoutRecord, calendar: Calendar) {
        let seconds = max(0, record.activeDuration)
        let day = calendar.startOfDay(for: record.completedAt)
        let patterns = record.trainedPatterns

        sessions += 1
        activeSeconds += seconds
        longestSessionSeconds = max(longestSessionSeconds, seconds)
        if patterns.count >= CorePattern.allCases.count { fullSessions += 1 }
        for pattern in patterns { patternSessions[pattern, default: 0] += 1 }
        zones.formUnion(record.trainedZones)
        difficulties.insert(record.difficulty)
        if record.difficulty >= .advanced { advancedSessions += 1 }
        if record.difficulty == .athlete { athleteSessions += 1 }

        switch record.perceivedEffort {
        case .unrated: break
        case .easy: ratedSessions += 1
        case .right: ratedSessions += 1; wellDosedSessions += 1
        case .hard: ratedSessions += 1; hardSessions += 1
        }

        let hour = calendar.component(.hour, from: record.completedAt)
        if hour < 8 { morningSessions += 1 }
        if hour >= 21 { eveningSessions += 1 }

        if day != lastDay {
            let isConsecutive = lastDay.flatMap {
                calendar.dateComponents([.day], from: $0, to: day).day == 1
            } ?? false
            currentRun = isConsecutive ? currentRun + 1 : 1
            bestStreak = max(bestStreak, currentRun)
            lastDay = day
        }

        sessionsByDay[day, default: 0] += 1
        busiestDaySessions = max(busiestDaySessions, sessionsByDay[day] ?? 0)

        if let week = calendar.dateInterval(of: .weekOfYear, for: record.completedAt)?.start {
            activeWeeks.insert(week)
            secondsByWeek[week, default: 0] += seconds
            bestWeekSeconds = max(bestWeekSeconds, secondsByWeek[week] ?? 0)

            let before = patternsByWeek[week]?.count ?? 0
            patternsByWeek[week, default: []].formUnion(patterns)
            let after = patternsByWeek[week]?.count ?? 0
            if before < CorePattern.allCases.count, after >= CorePattern.allCases.count {
                balancedWeeks += 1
            }
        }

        if let month = calendar.dateInterval(of: .month, for: record.completedAt)?.start {
            daysByMonth[month, default: []].insert(day)
            bestMonthDays = max(bestMonthDays, daysByMonth[month]?.count ?? 0)
        }
    }
}

private struct AchievementRule: Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let family: AchievementFamily
    let unit: ChallengeUnit
    let target: Int
    let value: @Sendable (HistoryTally) -> Int
}

private extension RewardsEngine {
    /// The shelf.
    ///
    /// Every rule reads something the app already writes down — no rule asks
    /// for equipment, a weight, a heart rate or a location, because none of
    /// those are recorded and an award nobody can ever earn is worse than no
    /// award at all.
    static let achievementRules: [AchievementRule] = [
        // Régularité
        AchievementRule(
            id: "streak-3",
            title: "Trois jours",
            detail: "Trois jours actifs d’affilée.",
            symbol: "flame",
            family: .regularity,
            unit: .activeDays,
            target: 3,
            value: { $0.bestStreak }
        ),
        AchievementRule(
            id: "streak-7",
            title: "Semaine pleine",
            detail: "Sept jours actifs d’affilée.",
            symbol: "flame.fill",
            family: .regularity,
            unit: .activeDays,
            target: 7,
            value: { $0.bestStreak }
        ),
        AchievementRule(
            id: "streak-14",
            title: "Quinzaine",
            detail: "Quatorze jours actifs d’affilée.",
            symbol: "calendar",
            family: .regularity,
            unit: .activeDays,
            target: 14,
            value: { $0.bestStreak }
        ),
        AchievementRule(
            id: "streak-30",
            title: "Trente jours",
            detail: "Un mois entier sans rompre la série.",
            symbol: "calendar.badge.checkmark",
            family: .regularity,
            unit: .activeDays,
            target: 30,
            value: { $0.bestStreak }
        ),
        AchievementRule(
            id: "streak-100",
            title: "Cent jours",
            detail: "Cent jours actifs d’affilée.",
            symbol: "crown.fill",
            family: .regularity,
            unit: .activeDays,
            target: 100,
            value: { $0.bestStreak }
        ),
        AchievementRule(
            id: "weeks-12",
            title: "Douze semaines",
            detail: "Douze semaines différentes avec au moins une séance.",
            symbol: "calendar.badge.clock",
            family: .regularity,
            unit: .times,
            target: 12,
            value: { $0.activeWeekCount }
        ),

        // Volume
        AchievementRule(
            id: "minutes-60",
            title: "Première heure",
            detail: "Soixante minutes de travail cumulées.",
            symbol: "timer",
            family: .volume,
            unit: .activeMinutes,
            target: 60,
            value: { $0.activeMinutes }
        ),
        AchievementRule(
            id: "minutes-300",
            title: "Cinq heures",
            detail: "Trois cents minutes de travail cumulées.",
            symbol: "hourglass",
            family: .volume,
            unit: .activeMinutes,
            target: 300,
            value: { $0.activeMinutes }
        ),
        AchievementRule(
            id: "minutes-600",
            title: "Dix heures",
            detail: "Six cents minutes de travail cumulées.",
            symbol: "stopwatch.fill",
            family: .volume,
            unit: .activeMinutes,
            target: 600,
            value: { $0.activeMinutes }
        ),
        AchievementRule(
            id: "minutes-1800",
            title: "Trente heures",
            detail: "Mille huit cents minutes de travail cumulées.",
            symbol: "infinity",
            family: .volume,
            unit: .activeMinutes,
            target: 1_800,
            value: { $0.activeMinutes }
        ),
        AchievementRule(
            id: "sessions-10",
            title: "Dix séances",
            detail: "Dix séances menées à leur terme.",
            symbol: "checkmark.seal",
            family: .volume,
            unit: .sessions,
            target: 10,
            value: { $0.sessions }
        ),
        AchievementRule(
            id: "sessions-50",
            title: "Cinquante séances",
            detail: "Cinquante séances au compteur.",
            symbol: "checkmark.seal.fill",
            family: .volume,
            unit: .sessions,
            target: 50,
            value: { $0.sessions }
        ),
        AchievementRule(
            id: "sessions-150",
            title: "Cent cinquante séances",
            detail: "Cent cinquante séances au compteur.",
            symbol: "seal.fill",
            family: .volume,
            unit: .sessions,
            target: 150,
            value: { $0.sessions }
        ),

        // Couverture
        AchievementRule(
            id: "full-session",
            title: "Séance complète",
            detail: "Les cinq plans du tronc dans une même séance.",
            symbol: "square.grid.2x2.fill",
            family: .coverage,
            unit: .times,
            target: 1,
            value: { $0.fullSessions }
        ),
        AchievementRule(
            id: "balanced-weeks-4",
            title: "Équilibre tenu",
            detail: "Quatre semaines couvrant les cinq plans du tronc.",
            symbol: "chart.pie.fill",
            family: .coverage,
            unit: .times,
            target: 4,
            value: { $0.balancedWeeks }
        ),
        AchievementRule(
            id: "zones-all",
            title: "Toute la sangle",
            detail: "Les six zones abdominales travaillées au moins une fois.",
            symbol: "figure.core.training",
            family: .coverage,
            unit: .muscleZones,
            target: MuscleZone.allCases.count,
            value: { $0.zoneCount }
        ),
        AchievementRule(
            id: "pattern-depth-10",
            title: "Tour du tronc",
            detail: "Chaque plan du tronc travaillé au moins dix fois.",
            symbol: "circle.hexagongrid.fill",
            family: .coverage,
            unit: .times,
            target: 10,
            value: { $0.leastTrainedPatternSessions }
        ),

        // Intensité
        AchievementRule(
            id: "difficulty-all",
            title: "Quatre régimes",
            detail: "Une séance terminée à chacun des quatre niveaux.",
            symbol: "dial.high.fill",
            family: .intensity,
            unit: .times,
            target: WorkoutDifficulty.allCases.count,
            value: { $0.difficultyCount }
        ),
        AchievementRule(
            id: "advanced-25",
            title: "Vingt-cinq intenses",
            detail: "Vingt-cinq séances au niveau Intense ou au-dessus.",
            symbol: "bolt.fill",
            family: .intensity,
            unit: .sessions,
            target: 25,
            value: { $0.advancedSessions }
        ),
        AchievementRule(
            id: "athlete-10",
            title: "Dix fois athlète",
            detail: "Dix séances au niveau Athlète.",
            symbol: "bolt.horizontal.fill",
            family: .intensity,
            unit: .sessions,
            target: 10,
            value: { $0.athleteSessions }
        ),

        // Maîtrise
        AchievementRule(
            id: "long-session-15",
            title: "Longue tenue",
            detail: "Quinze minutes de travail dans une seule séance.",
            symbol: "figure.core.training",
            family: .mastery,
            unit: .activeMinutes,
            target: 15,
            value: { $0.longestSessionMinutes }
        ),
        AchievementRule(
            id: "best-week-90",
            title: "Grosse semaine",
            detail: "Quatre-vingt-dix minutes de travail en sept jours.",
            symbol: "chart.bar.fill",
            family: .mastery,
            unit: .activeMinutes,
            target: 90,
            value: { $0.bestWeekMinutes }
        ),
        AchievementRule(
            id: "triple-day",
            title: "Triplé",
            detail: "Trois séances dans la même journée.",
            symbol: "square.stack.3d.up.fill",
            family: .mastery,
            unit: .sessions,
            target: 3,
            value: { $0.busiestDaySessions }
        ),
        AchievementRule(
            id: "month-20-days",
            title: "Mois plein",
            detail: "Vingt jours actifs dans un même mois.",
            symbol: "calendar.badge.plus",
            family: .mastery,
            unit: .activeDays,
            target: 20,
            value: { $0.bestMonthDays }
        ),

        // Rituel
        AchievementRule(
            id: "morning-5",
            title: "Lever tôt",
            detail: "Cinq séances terminées avant huit heures.",
            symbol: "sunrise.fill",
            family: .ritual,
            unit: .sessions,
            target: 5,
            value: { $0.morningSessions }
        ),
        AchievementRule(
            id: "evening-5",
            title: "Séance du soir",
            detail: "Cinq séances terminées après vingt et une heures.",
            symbol: "moon.stars.fill",
            family: .ritual,
            unit: .sessions,
            target: 5,
            value: { $0.eveningSessions }
        ),
        AchievementRule(
            id: "rated-20",
            title: "Vingt retours",
            detail: "Vingt séances notées après l’effort.",
            symbol: "hand.thumbsup.fill",
            family: .ritual,
            unit: .sessions,
            target: 20,
            value: { $0.ratedSessions }
        ),
        AchievementRule(
            id: "right-dose-10",
            title: "Bon dosage",
            detail: "Dix séances notées parfaites.",
            symbol: "checkmark.circle.fill",
            family: .ritual,
            unit: .sessions,
            target: 10,
            value: { $0.wellDosedSessions }
        ),
        AchievementRule(
            id: "hard-10",
            title: "Zone rouge",
            detail: "Dix séances notées difficiles.",
            symbol: "flame.circle.fill",
            family: .ritual,
            unit: .sessions,
            target: 10,
            value: { $0.hardSessions }
        )
    ]
}
