import Foundation

/// What a coach would have noticed since last time.
///
/// The engine builds an excellent single session and has no idea one happened
/// yesterday. That is the difference between a generator and a coach: a coach
/// remembers what you did, notices you have said "easy" three times running,
/// and knows you have not trained a side bend in nine days.
struct CoachGuidance: Sendable {
    /// Trained in the last two sessions. Not banned — a movement you did
    /// yesterday is not wrong today, it is just less interesting than one you
    /// have not done in a week.
    var recentMovementIDs: Set<String> = []
    /// Jobs the trunk has not been asked to do this week.
    var underworkedPatterns: Set<CorePattern> = []
    var note: CoachNote?

    static let none = CoachGuidance()
}

/// Something worth saying out loud on the home screen.
struct CoachNote: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case stepUp, easeOff, rest, streak, comeback, balance
    }

    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
    /// Set when the note is proposing a change the athlete can accept in a tap.
    var suggestedDifficulty: WorkoutDifficulty?

    var id: String { kind.rawValue + title }
}

struct CoachAdvisor: Sendable {
    let calendar: Calendar
    private let analytics: WorkoutHistoryAnalytics

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        analytics = WorkoutHistoryAnalytics(calendar: calendar)
    }

    func guidance(
        records: [WorkoutRecord],
        preferences: WorkoutPreferences,
        now: Date = .now
    ) -> CoachGuidance {
        let valid = analytics.qualifyingRecords(from: records)
            .sorted { $0.completedAt > $1.completedAt }

        return CoachGuidance(
            recentMovementIDs: Set(valid.prefix(2).flatMap(\.exerciseIDs)),
            underworkedPatterns: underworked(in: valid, now: now),
            note: note(from: valid, preferences: preferences, now: now)
        )
    }

    /// Jobs untouched so far this week. What a week owes you is broader than
    /// what a session can carry, which is exactly why it is tracked here rather
    /// than forced into every session.
    private func underworked(in records: [WorkoutRecord], now: Date) -> Set<CorePattern> {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let trained = records
            .filter { week.contains($0.completedAt) }
            .reduce(into: Set<CorePattern>()) { $0.formUnion($1.trainedPatterns) }
        return Set(CorePattern.allCases).subtracting(trained)
    }

    private func note(
        from records: [WorkoutRecord],
        preferences: WorkoutPreferences,
        now: Date
    ) -> CoachNote? {
        let streak = analytics.currentStreak(records: records, now: now)

        // Rest before progress. Six days in a row is where a coach starts
        // asking how you slept rather than adding load.
        if streak >= 6 {
            return CoachNote(
                kind: .rest,
                title: "Pensez à souffler",
                detail: "\(streak) jours d’affilée. Une journée de repos fait plus de bien qu’une séance de plus.",
                symbol: "moon.zzz.fill"
            )
        }

        let atCurrentLevel = records
            .filter { $0.difficulty == preferences.difficulty && $0.perceivedEffort != .unrated }
            .prefix(3)

        if atCurrentLevel.count >= 3, atCurrentLevel.allSatisfy({ $0.perceivedEffort == .easy }),
           let harder = preferences.difficulty.next {
            return CoachNote(
                kind: .stepUp,
                title: "Prêt pour le cran au-dessus",
                detail: "Trois séances de suite trouvées faciles. Passez en \(harder.title.lowercased()).",
                symbol: "arrow.up.right.circle.fill",
                suggestedDifficulty: harder
            )
        }

        if atCurrentLevel.prefix(2).count >= 2,
           atCurrentLevel.prefix(2).allSatisfy({ $0.perceivedEffort == .hard }),
           let gentler = preferences.difficulty.previous {
            return CoachNote(
                kind: .easeOff,
                title: "On lève le pied",
                detail: "Deux séances difficiles d’affilée. Le \(gentler.title.lowercased()) vous fera progresser plus vite.",
                symbol: "arrow.down.right.circle.fill",
                suggestedDifficulty: gentler
            )
        }

        if let last = records.first {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: last.completedAt),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            if days >= 7 {
                return CoachNote(
                    kind: .comeback,
                    title: "Content de vous revoir",
                    detail: "Une séance courte aujourd’hui vaut mieux qu’une longue dans trois jours.",
                    symbol: "hand.wave.fill"
                )
            }
        }

        let missing = underworked(in: records, now: now)
        if let neglected = CorePattern.allCases.first(where: missing.contains), !records.isEmpty {
            return CoachNote(
                kind: .balance,
                title: "Il manque du \(neglected.shortTitle.lowercased())",
                detail: neglected.detail,
                symbol: neglected.symbol
            )
        }

        if streak >= 2 {
            return CoachNote(
                kind: .streak,
                title: "\(streak) jours de suite",
                detail: "La régularité fait plus que l’intensité. Continuez comme ça.",
                symbol: "flame.fill"
            )
        }

        return nil
    }
}

extension WorkoutDifficulty {
    var next: WorkoutDifficulty? { WorkoutDifficulty(rawValue: rawValue + 1) }
    var previous: WorkoutDifficulty? { WorkoutDifficulty(rawValue: rawValue - 1) }
}
