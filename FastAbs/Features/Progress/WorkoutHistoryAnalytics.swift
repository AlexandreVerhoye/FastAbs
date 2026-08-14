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
