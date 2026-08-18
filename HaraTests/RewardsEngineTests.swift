import Foundation
import Testing
@testable import Hara

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
        let tooShort = record(at: date(2026, 8, 14), activeSeconds: 90, plannedSeconds: 90)
        let abandoned = record(at: date(2026, 8, 15), activeSeconds: 240, plannedSeconds: 600)
        let valid = record(at: date(2026, 8, 16), activeSeconds: 300, plannedSeconds: 360)

        #expect(!analytics.isQualifying(tooShort))
        #expect(!analytics.isQualifying(abandoned))
        #expect(analytics.isQualifying(valid))
    }

    @Test("A session finished in full always counts")
    func completedSessionsQualify() {
        // The bug this guards: a completed session was filed with the seconds
        // actually worked and judged against the wall-clock length of the plan,
        // rests included. At the gentlest level that ratio is about 0.42 and
        // could never clear the bar, so finishing a workout recorded it and
        // then hid it from the streak, the charts, the badges and the coach.
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)

        for minutes in [5, 7, 12, 20] {
            for difficulty in WorkoutDifficulty.allCases {
                let plan = WorkoutEngine().makePlan(
                    preferences: TestSupport.preferences(
                        durationMinutes: minutes, difficulty: difficulty
                    ),
                    seed: 4
                )
                let finished = WorkoutRecord(
                    plan: plan,
                    completedAt: date(2026, 8, 16),
                    activeDuration: plan.workDuration
                )
                #expect(
                    analytics.isQualifying(finished),
                    "\(minutes) min at \(difficulty.title) did not count: \(plan.workDuration)s worked of \(plan.duration)s planned"
                )
            }
        }
    }

    @Test("A session barely started still does not count")
    func abandonedSessionsDoNotQualify() {
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)
        let plan = WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(durationMinutes: 12), seed: 4
        )
        let walkedOut = WorkoutRecord(
            plan: plan,
            completedAt: date(2026, 8, 16),
            activeDuration: plan.workDuration / 4,
            wasCompleted: false
        )
        #expect(!analytics.isQualifying(walkedOut))
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

    @Test("The weekly balance challenge counts jobs of the trunk, not sessions")
    func weeklyBalanceCountsPatterns() {
        let now = date(2026, 8, 14)
        let engine = RewardsEngine(calendar: calendar)

        // Three days of one movement is one job done three times, not three
        // jobs — the whole reason this challenge exists.
        let narrow = [
            record(at: date(2026, 8, 10), exercises: ["classic-crunch"]),
            record(at: date(2026, 8, 11), exercises: ["classic-crunch"]),
            record(at: date(2026, 8, 12), exercises: ["classic-crunch"])
        ]
        let narrowProgress = engine.weeklyBalance(records: narrow, now: now)

        #expect(narrowProgress.unit == .corePatterns)
        #expect(narrowProgress.targetValue == CorePattern.allCases.count)
        #expect(narrowProgress.currentValue == 1, "got \(narrowProgress.currentValue)")

        let varied = narrow + [
            record(at: date(2026, 8, 13), exercises: ["forearm-plank", "bird-dog"]),
            record(at: date(2026, 8, 13, hour: 18), exercises: ["side-plank", "glute-bridge"])
        ]
        #expect(engine.weeklyBalance(records: varied, now: now).currentValue == 5)
    }

    @Test("Last week's work does not count toward this week's balance")
    func weeklyBalanceResets() {
        let now = date(2026, 8, 14)
        let lastWeek = [
            record(at: date(2026, 8, 5), exercises: ["forearm-plank"]),
            record(at: date(2026, 8, 6), exercises: ["side-plank"])
        ]

        #expect(RewardsEngine(calendar: calendar).weeklyBalance(records: lastWeek, now: now).currentValue == 0)
    }

    @Test("A badge remembers what the day was spent on")
    func badgesCarryTheirPattern() {
        let engine = RewardsEngine(calendar: calendar)

        let lateral = engine.dailyBadges(records: [
            record(at: date(2026, 8, 14), exercises: ["side-plank", "side-plank-dip"])
        ])
        #expect(lateral.first?.pattern == .antiLateralFlexion)
        #expect(lateral.first?.isComplete == false)

        // A day that covers every job earns the whole-session mark, even though
        // no single movement could.
        let complete = engine.dailyBadges(records: [
            record(at: date(2026, 8, 14), exercises: [
                "forearm-plank", "bird-dog", "side-plank", "classic-crunch", "glute-bridge"
            ])
        ])
        #expect(complete.first?.isComplete == true)
        #expect(complete.first?.symbol == "medal.fill")
    }

    // MARK: - Rank

    @Test("A session is worth what it asked of the athlete")
    func sessionPoints() {
        let engine = RewardsEngine(calendar: calendar)

        // Five minutes at Équilibré is six, finishing what was started is four,
        // one job of the trunk earns no coverage bonus, an unrated session no
        // feedback bonus.
        let plain = record(at: date(2026, 8, 14), exercises: ["classic-crunch"])
        #expect(engine.points(for: plain) == 10)

        // Harder work is worth more of the same minutes, and saying how it felt
        // is worth a point because it is the one input the app cannot measure.
        let athlete = record(
            at: date(2026, 8, 14),
            exercises: ["classic-crunch"],
            difficulty: .athlete,
            effort: .right
        )
        #expect(engine.points(for: athlete) == 14)

        // Five jobs of the trunk in one session, which is the behaviour worth
        // paying for most.
        let broad = record(
            at: date(2026, 8, 14),
            exercises: ["forearm-plank", "bird-dog", "side-plank", "classic-crunch", "glute-bridge"]
        )
        #expect(engine.points(for: broad) == 18)

        // A session that never counted cannot pay either.
        #expect(engine.points(for: record(at: date(2026, 8, 14), activeSeconds: 90, plannedSeconds: 90)) == 0)
    }

    @Test("Ranks open in order and never close")
    func rankLadder() {
        let engine = RewardsEngine(calendar: calendar)

        #expect(engine.level(points: 0).rank == .appui)
        #expect(engine.level(points: 119).rank == .appui)
        #expect(engine.level(points: 120).rank == .ancrage)
        #expect(engine.level(points: 5_600).rank == .monolithe)
        #expect(engine.level(points: 99_999).rank == .monolithe)

        let middle = engine.level(points: 220)
        #expect(middle.rank == .ancrage)
        #expect(middle.pointsIntoRank == 100)
        #expect(middle.rankSpan == 200)
        #expect(abs(middle.progress - 0.5) < 0.001)
        #expect(middle.pointsToNextRank == 100)
        #expect(middle.next == .socle)

        // The top rank has nothing above it, so it must not report a fraction
        // of a rank that does not exist.
        let top = engine.level(points: 6_000)
        #expect(top.rankSpan == nil)
        #expect(top.next == nil)
        #expect(top.progress == 1)
        #expect(top.pointsToNextRank == 0)
    }

    @Test("The rank ladder is a ladder")
    func rankThresholdsAscend() {
        let thresholds = RewardRank.allCases.map(\.threshold)
        #expect(thresholds == thresholds.sorted())
        #expect(Set(thresholds).count == thresholds.count)
        #expect(RewardRank.appui.threshold == 0, "the first rank must be reachable from nothing")
    }

    @Test("Points accumulate over the whole history")
    func levelReadsEveryRecord() {
        let engine = RewardsEngine(calendar: calendar)
        let history = (0..<12).map { record(at: date(2026, 8, 1 + $0), exercises: ["classic-crunch"]) }

        #expect(engine.trainingPoints(records: history) == 120)
        #expect(engine.level(records: history).rank == .ancrage)
    }

    // MARK: - Streak

    @Test("One missed day inside a long run does not end it")
    func streakSurvivesASingleMissedDay() {
        let engine = RewardsEngine(calendar: calendar)
        let now = date(2026, 8, 20)
        // Eight days trained, one blank, seven more behind it.
        let records = streakRecords(daysAgo: Array(0...7) + Array(9...15), from: now)

        let status = engine.streakStatus(records: records, now: now)

        #expect(status.current == 15)
        #expect(status.restDaysUsed == 1)
        #expect(status.isSecuredToday)
        #expect(status.state == .secured)
        // The strict run is what the history charts still show, and it stops at
        // the gap. The two numbers are allowed to disagree; only one of them is
        // a promise to the athlete.
        #expect(WorkoutHistoryAnalytics(calendar: calendar).currentStreak(records: records, now: now) == 8)
    }

    @Test("Two blank days in a row end the series whatever is banked")
    func streakBreaksOnTwoBlanks() {
        let now = date(2026, 8, 20)
        let records = streakRecords(daysAgo: Array(0...7) + Array(10...16), from: now)

        #expect(RewardsEngine(calendar: calendar).streakStatus(records: records, now: now).current == 8)
    }

    @Test("A rest day has to be earned before it can be spent")
    func streakProtectionIsEarned() {
        let now = date(2026, 8, 20)
        // Five days is not yet a week, so the sixth-day gap is fatal.
        let records = streakRecords(daysAgo: Array(0...4) + Array(6...12), from: now)

        let status = RewardsEngine(calendar: calendar).streakStatus(records: records, now: now)

        #expect(status.current == 5)
        #expect(status.restDaysUsed == 0)
        #expect(status.restDaysEarned == 0)
    }

    @Test("The safety net stops at two days")
    func streakProtectionIsCapped() {
        let now = date(2026, 8, 20)
        // Three gaps, each after a full week of work. The third is not covered.
        let records = streakRecords(
            daysAgo: Array(0...6) + Array(8...14) + Array(16...22) + Array(24...30),
            from: now
        )

        let status = RewardsEngine(calendar: calendar).streakStatus(records: records, now: now)

        #expect(status.current == 21)
        #expect(status.restDaysUsed == 2)
        #expect(status.restDaysLeft == 0)
    }

    @Test("Today's empty square never counts against the series")
    func streakIsAtRiskRatherThanBroken() {
        let now = date(2026, 8, 20)
        let status = RewardsEngine(calendar: calendar)
            .streakStatus(records: streakRecords(daysAgo: Array(1...5), from: now), now: now)

        #expect(status.current == 5)
        #expect(!status.isSecuredToday)
        #expect(status.state == .atRisk)
        #expect(status.nextMilestone == 7)
        #expect(status.daysToMilestone == 2)
    }

    @Test("With no history there is no series and no punishment")
    func streakStartsIdle() {
        let status = RewardsEngine(calendar: calendar).streakStatus(records: [], now: date(2026, 8, 20))

        #expect(status.current == 0)
        #expect(status.state == .idle)
        #expect(status.nextMilestone == 3)
        #expect(status.restDaysLeft == 0)
    }

    @Test("Milestone progress is measured between two milestones")
    func milestoneProgressIsRelative() {
        let status = StreakStatus(
            current: 10,
            longest: 12,
            restDaysUsed: 0,
            restDaysEarned: 1,
            isSecuredToday: true
        )

        #expect(status.nextMilestone == 14)
        #expect(status.daysToMilestone == 4)
        // Ten days sits three days into the seven between the 7 and 14 marks,
        // not ten fourteenths of the way to the next one.
        #expect(abs(status.milestoneProgress - 3.0 / 7.0) < 0.001)
    }

    // MARK: - Goals

    @Test("The daily goal is the athlete's own middle day")
    func dailyGoalFollowsTheHabit() {
        let engine = RewardsEngine(calendar: calendar)
        let now = date(2026, 8, 20)
        let history = (1...7).map {
            record(at: date(2026, 8, 20 - $0), activeSeconds: 600, plannedSeconds: 600)
        }

        let goal = engine.dailyGoal(records: history, now: now)

        #expect(goal.period == .day)
        #expect(goal.unit == .activeMinutes)
        #expect(goal.targetValue == 10)
        #expect(goal.currentValue == 0, "today has not been trained yet")

        // Today's own work must not move today's bar, or the goal would run
        // away from whoever was clearing it.
        let withToday = history + [record(at: date(2026, 8, 20, hour: 7), activeSeconds: 480, plannedSeconds: 480)]
        let updated = engine.dailyGoal(records: withToday, now: now)
        #expect(updated.currentValue == 8)
        #expect(updated.targetValue == 10)
    }

    @Test("The daily goal stays inside a range anyone can read")
    func dailyGoalIsClamped() {
        let engine = RewardsEngine(calendar: calendar)
        let now = date(2026, 8, 20)

        #expect(engine.dailyGoal(records: [], now: now).targetValue == 7)

        let short = (1...5).map { record(at: date(2026, 8, 20 - $0), activeSeconds: 150, plannedSeconds: 150) }
        #expect(engine.dailyGoal(records: short, now: now).targetValue == 5)

        let long = (1...5).map { record(at: date(2026, 8, 20 - $0), activeSeconds: 3_600, plannedSeconds: 3_600) }
        #expect(engine.dailyGoal(records: long, now: now).targetValue == 20)
    }

    @Test("The weekly session goal follows last week")
    func weeklySessionGoalAdapts() {
        let engine = RewardsEngine(calendar: calendar)
        let now = date(2026, 8, 20)

        let empty = engine.weeklySessions(records: [], now: now)
        #expect(empty.period == .week)
        #expect(empty.unit == .sessions)
        #expect(empty.targetValue == 4)

        let lastWeek = (10...14).map { record(at: date(2026, 8, $0)) }
        let thisWeek = [record(at: date(2026, 8, 17)), record(at: date(2026, 8, 18))]
        let goal = engine.weeklySessions(records: lastWeek + thisWeek, now: now)

        #expect(goal.currentValue == 2)
        #expect(goal.targetValue == 6, "five sessions last week asks for six")
    }

    @Test("The weekly balance challenge is filed under the week")
    func weeklyBalanceIsWeekly() {
        #expect(RewardsEngine(calendar: calendar).weeklyBalance(records: [], now: date(2026, 8, 20)).period == .week)
    }

    // MARK: - Achievements

    @Test("An award is dated by the session that earned it")
    func achievementsCarryTheirDate() {
        let engine = RewardsEngine(calendar: calendar)
        let records = (0..<12).map { record(at: date(2026, 8, 1 + $0), exercises: ["classic-crunch"]) }

        let shelf = engine.achievements(records: records)

        let ten = shelf.first { $0.id == "sessions-10" }
        #expect(ten?.isUnlocked == true)
        #expect(ten?.unlockedAt == date(2026, 8, 10), "the tenth session is what earned it")
        #expect(ten?.currentValue == 12)

        let fifty = shelf.first { $0.id == "sessions-50" }
        #expect(fifty?.isUnlocked == false)
        #expect(fifty?.unlockedAt == nil)
        #expect(fifty?.currentValue == 12)
        #expect(abs((fifty?.progress ?? 0) - 0.24) < 0.001)
    }

    @Test("A session covering every plan of the trunk is worth its own award")
    func coverageAchievementNeedsRealCoverage() {
        let engine = RewardsEngine(calendar: calendar)
        let narrow = [record(at: date(2026, 8, 1), exercises: ["classic-crunch"])]

        #expect(engine.achievements(records: narrow).first { $0.id == "full-session" }?.isUnlocked == false)

        let complete = narrow + [
            record(at: date(2026, 8, 2), exercises: [
                "forearm-plank", "bird-dog", "side-plank", "classic-crunch", "glute-bridge"
            ])
        ]
        let award = engine.achievements(records: complete).first { $0.id == "full-session" }
        #expect(award?.isUnlocked == true)
        #expect(award?.unlockedAt == date(2026, 8, 2))
    }

    @Test("The least-trained plan of the trunk is what 'complete' means")
    func patternDepthMeasuresTheWeakestPlan() {
        let engine = RewardsEngine(calendar: calendar)
        // Ten days of planks alone: one job done ten times, not the trunk
        // covered ten times.
        let planks = (0..<10).map { record(at: date(2026, 8, 1 + $0), exercises: ["forearm-plank"]) }

        let award = engine.achievements(records: planks).first { $0.id == "pattern-depth-10" }
        #expect(award?.currentValue == 0)
        #expect(award?.isUnlocked == false)
    }

    @Test("Saying how a session felt is itself recorded")
    func ritualAchievementsReadTheFeedback() {
        let engine = RewardsEngine(calendar: calendar)
        let rated = (0..<10).map {
            record(at: date(2026, 8, 1 + $0), exercises: ["classic-crunch"], effort: .right)
        }

        let shelf = engine.achievements(records: rated)
        #expect(shelf.first { $0.id == "right-dose-10" }?.isUnlocked == true)
        #expect(shelf.first { $0.id == "rated-20" }?.currentValue == 10)
        #expect(engine.points(for: rated[0]) == 11, "a rated session is worth one more point")
    }

    @Test("The hour a session ended is part of the record")
    func ritualAchievementsReadTheClock() {
        let engine = RewardsEngine(calendar: calendar)
        let dawn = (0..<5).map { record(at: date(2026, 8, 1 + $0, hour: 6), exercises: ["classic-crunch"]) }
        let night = (0..<5).map { record(at: date(2026, 8, 10 + $0, hour: 22), exercises: ["classic-crunch"]) }

        let shelf = engine.achievements(records: dawn + night)
        #expect(shelf.first { $0.id == "morning-5" }?.isUnlocked == true)
        #expect(shelf.first { $0.id == "evening-5" }?.isUnlocked == true)
        #expect(shelf.first { $0.id == "morning-5" }?.currentValue == 5)
    }

    @Test("Nothing on the shelf is impossible, duplicated or already won")
    func achievementShelfIsWellFormed() {
        let shelf = RewardsEngine(calendar: calendar).achievements(records: [])

        #expect(!shelf.isEmpty)
        #expect(Set(shelf.map(\.id)).count == shelf.count, "duplicate award ids")

        for achievement in shelf {
            #expect(achievement.targetValue > 0, "\(achievement.id) can never be reached")
            #expect(!achievement.isUnlocked, "\(achievement.id) is already won with no history")
            #expect(achievement.progress == 0)
        }

        // Every family has something in it, so no section of the screen opens
        // empty.
        for family in AchievementFamily.allCases {
            #expect(shelf.contains { $0.family == family }, "\(family.rawValue) has no awards")
        }
    }

    @Test("The shelf is a function of the history, not of its order")
    func achievementsAreDerivedNotStored() {
        let engine = RewardsEngine(calendar: calendar)
        let records = (0..<9).map { record(at: date(2026, 8, 1 + $0), exercises: ["classic-crunch"]) }

        #expect(engine.achievements(records: records) == engine.achievements(records: records.reversed()))
    }

    @Test("The summary carries the whole system, not just the badges")
    func summaryIsComplete() {
        let engine = RewardsEngine(calendar: calendar)
        let now = date(2026, 8, 20)
        let records = (0..<6).map { record(at: date(2026, 8, 15 + $0), exercises: ["classic-crunch"]) }

        let summary = engine.summary(records: records, now: now)

        #expect(summary.level.points > 0)
        #expect(summary.streak.current == 6)
        #expect(summary.streak.isSecuredToday)
        #expect(summary.goals.map(\.period) == [.day, .week, .week, .month, .year])
        #expect(summary.unlockedAchievements.contains { $0.id == "streak-3" })
        #expect(summary.nextAchievements.count == 3)
        #expect(summary.nextAchievements.allSatisfy { !$0.isUnlocked })
        // Still the old contract, which other screens read.
        #expect(summary.currentStreak == 6)
        #expect(summary.dailyBadges.count == 6)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// One qualifying session for each of the given day offsets before `now`.
    private func streakRecords(daysAgo: [Int], from now: Date) -> [WorkoutRecord] {
        daysAgo.compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return record(at: day, exercises: ["classic-crunch"])
        }
    }

    /// Built from a real plan so the qualifying rules apply, then narrowed to
    /// the named movements when a test cares which jobs the day covered.
    private func record(
        at date: Date,
        activeSeconds: Int = 300,
        plannedSeconds: Int = 300,
        exercises: [String]? = nil,
        difficulty: WorkoutDifficulty = .balanced,
        effort: PerceivedEffort = .unrated
    ) -> WorkoutRecord {
        let plan = WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(
                durationMinutes: max(5, plannedSeconds / 60),
                difficulty: difficulty
            ),
            seed: 7
        )
        let record = WorkoutRecord(plan: plan, completedAt: date, activeDuration: activeSeconds)
        record.perceivedEffortRaw = effort.rawValue
        record.plannedDuration = plannedSeconds
        record.plannedActiveDuration = plannedSeconds
        if let exercises { record.exerciseIDs = exercises }
        return record
    }
}

