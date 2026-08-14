import Foundation

struct WorkoutHistoryDay: Identifiable, Hashable {
    let date: Date
    let sessionCount: Int
    let activeSeconds: Int
    let calories: Int

    var id: Date { date }
    var activeMinutes: Double { Double(activeSeconds) / 60 }
    var isActive: Bool { sessionCount > 0 }
}

struct WorkoutFocusBreakdown: Identifiable, Hashable {
    let zone: MuscleZone
    let sessionCount: Int

    var id: MuscleZone { zone }
}

struct WorkoutHistoryOverview {
    let totalSessions: Int
    let totalActiveSeconds: Int
    let totalCalories: Int
    let activeDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let currentWeekSeconds: Int
    let previousWeekSeconds: Int
    let currentMonthSessions: Int

    var totalActiveMinutes: Int { totalActiveSeconds / 60 }
    var averageMinutesPerActiveDay: Int {
        guard activeDays > 0 else { return 0 }
        return Int((Double(totalActiveSeconds) / Double(activeDays) / 60).rounded())
    }

    var weeklyChange: Double? {
        guard previousWeekSeconds > 0 else { return nil }
        return Double(currentWeekSeconds - previousWeekSeconds) / Double(previousWeekSeconds)
    }
}

/// How much work each job of the trunk has taken.
///
/// Measured on patterns rather than muscles: a week of nothing but crunches
/// lights every abdominal zone while training one skill, so a zone split would
/// have reported that week as balanced.
struct PatternLoad: Identifiable, Hashable {
    let pattern: CorePattern
    let sessions: Int
    let activeSeconds: Int

    var id: CorePattern { pattern }
    var activeMinutes: Int { activeSeconds / 60 }
}

/// The best the athlete has managed, which is what a history is for.
struct PersonalRecords: Hashable {
    let longestStreak: Int
    let bestWeekMinutes: Int
    let longestSessionSeconds: Int
    let busiestDaySessions: Int
    let totalSessions: Int

    var longestSessionMinutes: Int { longestSessionSeconds / 60 }
    var hasAny: Bool { totalSessions > 0 }
}

/// Calendar-aware analytics reconstructed from immutable workout records.
///
/// All comparisons are performed using `Calendar.startOfDay(for:)` rather than
/// elapsed 24-hour periods so streaks stay correct across daylight-saving time
/// changes and while the user travels.
struct WorkoutHistoryAnalytics {
    static let minimumActiveDuration = 180
    static let minimumCompletionRatio = 0.75

    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func isQualifying(_ record: WorkoutRecord) -> Bool {
        guard record.activeDuration >= Self.minimumActiveDuration else { return false }
        guard record.plannedDuration > 0 else { return true }
        return Double(record.activeDuration) / Double(record.plannedDuration) >= Self.minimumCompletionRatio
    }

    func qualifyingRecords(from records: [WorkoutRecord]) -> [WorkoutRecord] {
        records.filter(isQualifying)
    }

    func overview(records: [WorkoutRecord], now: Date = .now) -> WorkoutHistoryOverview {
        let validRecords = qualifyingRecords(from: records)
        let completedDays = Set(validRecords.map { calendar.startOfDay(for: $0.completedAt) })
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        let currentMonth = calendar.dateInterval(of: .month, for: now)
        let previousWeek = currentWeek.flatMap {
            calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .day, value: -1, to: $0.start) ?? $0.start)
        }

        return WorkoutHistoryOverview(
            totalSessions: validRecords.count,
            totalActiveSeconds: validRecords.reduce(0) { $0 + max(0, $1.activeDuration) },
            totalCalories: validRecords.reduce(0) { $0 + max(0, $1.estimatedCalories) },
            activeDays: completedDays.count,
            currentStreak: currentStreak(completedDays: completedDays, now: now),
            longestStreak: longestStreak(completedDays: completedDays),
            currentWeekSeconds: activeSeconds(in: currentWeek, records: validRecords),
            previousWeekSeconds: activeSeconds(in: previousWeek, records: validRecords),
            currentMonthSessions: count(in: currentMonth, records: validRecords)
        )
    }

    func days(records: [WorkoutRecord], endingAt endDate: Date = .now, count dayCount: Int) -> [WorkoutHistoryDay] {
        guard dayCount > 0 else { return [] }
        let validRecords = qualifyingRecords(from: records)
        let recordsByDay = Dictionary(grouping: validRecords) {
            calendar.startOfDay(for: $0.completedAt)
        }
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: end) else { return [] }

        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayRecords = recordsByDay[date, default: []]
            return WorkoutHistoryDay(
                date: date,
                sessionCount: dayRecords.count,
                activeSeconds: dayRecords.reduce(0) { $0 + max(0, $1.activeDuration) },
                calories: dayRecords.reduce(0) { $0 + max(0, $1.estimatedCalories) }
            )
        }
    }

    func focusBreakdown(records: [WorkoutRecord]) -> [WorkoutFocusBreakdown] {
        var counts: [MuscleZone: Int] = [:]

        for record in qualifyingRecords(from: records) {
            let zones = Set(record.focusZoneRaws.compactMap(MuscleZone.init(rawValue:)))
            let normalizedZones = zones.isEmpty ? Set([MuscleZone.fullCore]) : zones
            for zone in normalizedZones {
                counts[zone, default: 0] += 1
            }
        }

        return counts
            .map { WorkoutFocusBreakdown(zone: $0.key, sessionCount: $0.value) }
            .sorted {
                if $0.sessionCount == $1.sessionCount { return $0.zone.rawValue < $1.zone.rawValue }
                return $0.sessionCount > $1.sessionCount
            }
    }

    /// Work split across the jobs of the trunk, from the movements actually
    /// performed.
    func patternLoad(records: [WorkoutRecord]) -> [PatternLoad] {
        var sessions: [CorePattern: Int] = [:]
        var seconds: [CorePattern: Int] = [:]

        for record in qualifyingRecords(from: records) {
            let patterns = record.trainedPatterns
            guard !patterns.isEmpty else { continue }
            // A session that trained three patterns gives each a third of its
            // time, so the split reads as effort spent rather than sessions
            // counted three times over.
            let share = max(0, record.activeDuration) / patterns.count
            for pattern in patterns {
                sessions[pattern, default: 0] += 1
                seconds[pattern, default: 0] += share
            }
        }

        return CorePattern.allCases.compactMap { pattern in
            guard let count = sessions[pattern], count > 0 else { return nil }
            return PatternLoad(pattern: pattern, sessions: count, activeSeconds: seconds[pattern] ?? 0)
        }
        .sorted { $0.activeSeconds > $1.activeSeconds }
    }

    /// Personal bests, which is the part of a history worth coming back for.
    func personalRecords(records: [WorkoutRecord]) -> PersonalRecords {
        let valid = qualifyingRecords(from: records)
        let byDay = Dictionary(grouping: valid) { calendar.startOfDay(for: $0.completedAt) }
        let byWeek = Dictionary(grouping: valid) {
            calendar.dateInterval(of: .weekOfYear, for: $0.completedAt)?.start ?? $0.completedAt
        }

        return PersonalRecords(
            longestStreak: longestStreak(records: records),
            bestWeekMinutes: byWeek.values
                .map { week in week.reduce(0) { $0 + max(0, $1.activeDuration) } / 60 }
                .max() ?? 0,
            longestSessionSeconds: valid.map { max(0, $0.activeDuration) }.max() ?? 0,
            busiestDaySessions: byDay.values.map(\.count).max() ?? 0,
            totalSessions: valid.count
        )
    }

    func currentStreak(records: [WorkoutRecord], now: Date = .now) -> Int {
        let completedDays = Set(qualifyingRecords(from: records).map { calendar.startOfDay(for: $0.completedAt) })
        return currentStreak(completedDays: completedDays, now: now)
    }

    func longestStreak(records: [WorkoutRecord]) -> Int {
        let completedDays = Set(qualifyingRecords(from: records).map { calendar.startOfDay(for: $0.completedAt) })
        return longestStreak(completedDays: completedDays)
    }

    private func currentStreak(completedDays: Set<Date>, now: Date) -> Int {
        let today = calendar.startOfDay(for: now)
        var cursor = today

        if !completedDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  completedDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func longestStreak(completedDays: Set<Date>) -> Int {
        let sortedDays = completedDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for index in sortedDays.indices.dropFirst() {
            let previous = sortedDays[sortedDays.index(before: index)]
            let dayDifference = calendar.dateComponents([.day], from: previous, to: sortedDays[index]).day
            current = dayDifference == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }

    private func activeSeconds(in interval: DateInterval?, records: [WorkoutRecord]) -> Int {
        guard let interval else { return 0 }
        return records
            .filter { interval.contains($0.completedAt) }
            .reduce(0) { $0 + max(0, $1.activeDuration) }
    }

    private func count(in interval: DateInterval?, records: [WorkoutRecord]) -> Int {
        guard let interval else { return 0 }
        return records.count { interval.contains($0.completedAt) }
    }
}
