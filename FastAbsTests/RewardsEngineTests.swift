import Foundation
import Testing
@testable import FastAbs

@Suite("Rewards and progress")
struct RewardsEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    @Test("A qualifying day mints one badge even with several workouts")
    func dailyBadgeIsIdempotent() {
        let day = date(2026, 8, 14, hour: 8)
        let first = record(at: day, activeSeconds: 210, plannedSeconds: 210)
        let second = record(at: date(2026, 8, 14, hour: 18), activeSeconds: 240, plannedSeconds: 240)

        let badges = RewardsEngine(calendar: calendar).dailyBadges(records: [first, second])

        #expect(badges.count == 1)
        #expect(badges[0].sessionCount == 2)
        #expect(badges[0].activeSeconds == 450)
        #expect(badges[0].tier == .silver)
    }

    @Test("Short or largely abandoned workouts do not count")
    func incompleteWorkoutsDoNotQualify() {
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)
        let tooShort = record(at: date(2026, 8, 14), activeSeconds: 179, plannedSeconds: 179)
        let abandoned = record(at: date(2026, 8, 15), activeSeconds: 240, plannedSeconds: 600)
        let valid = record(at: date(2026, 8, 16), activeSeconds: 300, plannedSeconds: 360)

        #expect(!analytics.isQualifying(tooShort))
        #expect(!analytics.isQualifying(abandoned))
        #expect(analytics.isQualifying(valid))
    }

    @Test("The streak follows calendar days, not elapsed 24-hour blocks")
    func streakUsesCalendarDays() {
        let now = date(2026, 3, 30, hour: 7)
        let records = [
            record(at: date(2026, 3, 30, hour: 6)),
            record(at: date(2026, 3, 29, hour: 23)),
            record(at: date(2026, 3, 28, hour: 1))
        ]

        let overview = WorkoutHistoryAnalytics(calendar: calendar).overview(records: records, now: now)

        #expect(overview.currentStreak == 3)
        #expect(overview.longestStreak == 3)
        #expect(overview.activeDays == 3)
    }

    @Test("The current monthly challenge derives progress from valid records")
    func monthlyChallengeProgress() {
        let now = date(2026, 8, 14)
        let records = [
            record(at: date(2026, 8, 2)),
            record(at: date(2026, 8, 9)),
            record(at: date(2026, 7, 28))
        ]

        let challenge = RewardsEngine(calendar: calendar).monthlyChallenge(records: records, now: now)

        #expect(challenge.period == .month)
        #expect(challenge.unit == .sessions)
        #expect(challenge.currentValue == 2)
        #expect(challenge.targetValue >= 8)
        #expect(challenge.progress > 0 && challenge.progress < 1)
    }

    @Test("The annual challenge counts a day once")
    func annualChallengeCountsUniqueDays() {
        let now = date(2026, 8, 14)
        let records = [
            record(at: date(2026, 1, 2, hour: 7)),
            record(at: date(2026, 1, 2, hour: 19)),
            record(at: date(2026, 5, 12)),
            record(at: date(2026, 8, 14))
        ]

        let challenge = RewardsEngine(calendar: calendar).annualChallenge(records: records, now: now)

        #expect(challenge.unit == .activeDays)
        #expect(challenge.currentValue == 3)
        #expect(challenge.targetValue == 100)
    }

    @Test("The weekly balance challenge counts body areas, not sessions")
    func weeklyBalanceCountsAreas() {
        let now = date(2026, 8, 14)
        let engine = RewardsEngine(calendar: calendar)

        let coreOnly = [
            record(at: date(2026, 8, 10)),
            record(at: date(2026, 8, 11)),
            record(at: date(2026, 8, 12))
        ]
        let coreProgress = engine.weeklyBalance(records: coreOnly, now: now)

        #expect(coreProgress.unit == .bodyAreas)
        #expect(coreProgress.targetValue == BodyRegion.allCases.count)
        #expect(
            coreProgress.currentValue == 1,
            "three days of abs is still one area, not three (\(coreProgress.currentValue))"
        )

        let varied = coreOnly + [
            record(at: date(2026, 8, 13), programme: .lowerBody),
            record(at: date(2026, 8, 13, hour: 18), programme: .upperBody)
        ]
        #expect(engine.weeklyBalance(records: varied, now: now).currentValue == 3)
    }

    @Test("Last week's work does not count toward this week's balance")
    func weeklyBalanceResets() {
        let now = date(2026, 8, 14)
        let lastWeek = [
            record(at: date(2026, 8, 5), programme: .lowerBody),
            record(at: date(2026, 8, 6), programme: .upperBody)
        ]

        #expect(RewardsEngine(calendar: calendar).weeklyBalance(records: lastWeek, now: now).currentValue == 0)
    }

    @Test("A badge remembers what the day was spent on")
    func badgesCarryTheirProgramme() {
        let engine = RewardsEngine(calendar: calendar)

        let legs = engine.dailyBadges(records: [record(at: date(2026, 8, 14), programme: .lowerBody)])
        #expect(legs.first?.programme == .lowerBody)
        #expect(legs.first?.symbol == TrainingProgramme.lowerBody.symbol)

        // A day that ends up covering the whole body earns the whole-body mark
        // even though neither session was a full-body programme on its own.
        let both = engine.dailyBadges(records: [
            record(at: date(2026, 8, 14, hour: 8), programme: .lowerBody),
            record(at: date(2026, 8, 14, hour: 18), programme: .upperBody),
            record(at: date(2026, 8, 14, hour: 20), programme: .core)
        ])
        #expect(both.first?.programme == .fullBody)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func record(
        at date: Date,
        activeSeconds: Int = 300,
        plannedSeconds: Int = 300,
        programme: TrainingProgramme = .core
    ) -> WorkoutRecord {
        let plan = WorkoutEngine().makePlan(
            preferences: WorkoutPreferences(
                durationMinutes: max(5, plannedSeconds / 60),
                difficulty: .balanced,
                programme: programme,
                focusZones: [.fullCore],
                apartmentFriendly: true,
                neckFriendly: false,
                extraRecovery: false
            ),
            seed: 7
        )
        let record = WorkoutRecord(plan: plan, completedAt: date, activeDuration: activeSeconds)
        record.plannedDuration = plannedSeconds
        return record
    }
}

