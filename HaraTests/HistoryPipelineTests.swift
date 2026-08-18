import Foundation
import Testing
@testable import Hara

/// End to end over the history: sessions go in, and every screen that reads
/// them back has something true to show.
///
/// Written after the whole pipeline turned out to be silently empty. A record
/// was filed with the seconds actually worked and judged against the
/// wall-clock length of the plan — rests included — so a finished seven-minute
/// session scored about 0.42 against a 0.75 bar and was discarded by
/// `isQualifying`. Everything downstream reads through that one function, so
/// the streak stayed at zero, the charts stayed flat, no badge was ever earned
/// and the coach had no history to adapt to. Each individual piece had tests
/// and each one passed; nothing tested the seam between them.
@Suite("History pipeline")
struct HistoryPipelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: now) ?? now
    }

    /// A fortnight of training, finished honestly every day.
    private func fortnight(now: Date) -> [WorkoutRecord] {
        (0..<14).map { offset in
            let plan = WorkoutEngine().makePlan(
                preferences: TestSupport.preferences(
                    durationMinutes: [5, 7, 12].randomElement(using: &Self.fixed) ?? 7,
                    difficulty: WorkoutDifficulty.allCases[offset % 4]
                ),
                seed: UInt64(offset + 1)
            )
            let record = WorkoutRecord(
                plan: plan,
                completedAt: day(offset, from: now),
                activeDuration: plan.workDuration
            )
            record.perceivedEffortRaw = PerceivedEffort.right.rawValue
            return record
        }
    }

    /// Seeded so the fixture is the same fortnight on every run.
    nonisolated(unsafe) private static var fixed = SeededGenerator(seed: 99)

    @Test("A fortnight of finished sessions reaches every screen")
    func finishedSessionsReachEveryScreen() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 9))!
        let records = fortnight(now: now)
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)

        #expect(analytics.qualifyingRecords(from: records).count == 14,
                "only \(analytics.qualifyingRecords(from: records).count) of 14 sessions counted")

        let overview = analytics.overview(records: records, now: now)
        #expect(overview.totalSessions == 14)
        #expect(overview.currentStreak == 14, "streak read \(overview.currentStreak)")
        #expect(overview.longestStreak == 14)
        #expect(overview.activeDays == 14)
        #expect(overview.totalActiveSeconds > 0)
        #expect(overview.totalCalories > 0)
        #expect(overview.currentWeekSeconds > 0)

        // The charts.
        let days = analytics.days(records: records, endingAt: now, count: 14)
        #expect(days.count == 14)
        #expect(days.allSatisfy { $0.isActive }, "a trained day charted as rest")

        // The balance and the records.
        #expect(!analytics.patternLoad(records: records).isEmpty)
        #expect(!analytics.focusBreakdown(records: records).isEmpty)
        let bests = analytics.personalRecords(records: records)
        #expect(bests.hasAny)
        #expect(bests.longestStreak == 14)
        #expect(bests.longestSessionSeconds > 0)
        #expect(bests.bestWeekMinutes > 0)

        // The rewards.
        let badges = RewardsEngine(calendar: calendar).dailyBadges(records: records)
        #expect(badges.count == 14, "\(badges.count) badges for 14 finished sessions")

        // And the coach, which has to have something to adapt to.
        let guidance = CoachAdvisor(calendar: calendar)
            .guidance(records: records, preferences: .recommended, now: now)
        #expect(!guidance.recentMovementIDs.isEmpty, "the coach remembers nothing")
    }

    @Test("Every level and length produces a session that counts when finished")
    func everySessionShapeCounts() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 9))!
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)

        for minutes in [5, 7, 8, 10, 12, 15, 16, 20] {
            for difficulty in WorkoutDifficulty.allCases {
                for extraRecovery in [false, true] {
                    let plan = WorkoutEngine().makePlan(
                        preferences: TestSupport.preferences(
                            durationMinutes: minutes,
                            difficulty: difficulty,
                            extraRecovery: extraRecovery
                        ),
                        seed: 12
                    )
                    let record = WorkoutRecord(
                        plan: plan, completedAt: now, activeDuration: plan.workDuration
                    )
                    #expect(
                        analytics.isQualifying(record),
                        "\(minutes) min \(difficulty.title) extra=\(extraRecovery) did not count: \(plan.workDuration)s of \(plan.duration)s"
                    )
                }
            }
        }
    }

    @Test("Stopping a third of the way in does not earn the day")
    func partialSessionsDoNotCount() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 9))!
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)
        let plan = WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(durationMinutes: 12), seed: 3
        )
        let quit = WorkoutRecord(
            plan: plan,
            completedAt: now,
            activeDuration: plan.workDuration / 3,
            wasCompleted: false
        )
        #expect(!analytics.isQualifying(quit))
        #expect(analytics.overview(records: [quit], now: now).currentStreak == 0)
    }
}

/// Deterministic, so the fixture above is one fortnight rather than a new one
/// every run.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
