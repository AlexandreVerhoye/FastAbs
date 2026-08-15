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

/// The session the coach actually prescribes, and why.
///
/// The athlete's settings are the starting point, not the last word: a coach who
/// gives you the same session at the same level however it went is a timer with
/// opinions. What comes out is the settings adjusted by what the history shows,
/// plus the sentences that explain the adjustment — because an adaptation you
/// cannot see is indistinguishable from a bug.
struct SessionRecipe: Sendable {
    /// What the session is actually built from.
    var preferences: WorkoutPreferences
    var guidance: CoachGuidance
    /// One line per adjustment made. Empty when nothing was changed.
    var rationale: [String] = []

    var isAdapted: Bool { !rationale.isEmpty }
}

/// How the last few sessions went, on one axis.
///
/// Positive means they have been landing easy, negative means they have been
/// landing hard. Recency-weighted, because how last week felt matters less than
/// how yesterday felt.
struct EffortTrend: Sendable {
    var score: Double = 0
    var ratedCount: Int = 0
    var abandonedCount: Int = 0

    var readsEasy: Bool { score >= 0.75 && ratedCount >= 3 }
    var readsHard: Bool { score <= -0.75 && ratedCount >= 2 }
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

    // MARK: - The prescription

    /// The day's session: the athlete's settings, adjusted by what the history
    /// shows, with a reason attached to every adjustment.
    func recipe(
        records: [WorkoutRecord],
        base: WorkoutPreferences,
        now: Date = .now
    ) -> SessionRecipe {
        let guidance = guidance(records: records, preferences: base, now: now)
        guard base.adaptiveCoaching else {
            return SessionRecipe(preferences: base, guidance: guidance)
        }

        let valid = analytics.qualifyingRecords(from: records)
            .sorted { $0.completedAt > $1.completedAt }
        var adapted = base
        var rationale: [String] = []

        // Difficulty follows the answers, one step at a time and never more
        // than one from what the athlete chose — an adaptation that can run
        // away from its starting point stops being an adjustment.
        let trend = effortTrend(of: valid)
        if trend.readsEasy, let harder = base.difficulty.next {
            adapted.difficulty = harder
            rationale.append("\(harder.title) plutôt que \(base.difficulty.title.lowercased()) : vos dernières séances vous ont paru faciles.")
        } else if trend.readsHard, let gentler = base.difficulty.previous {
            adapted.difficulty = gentler
            rationale.append("\(gentler.title) aujourd’hui : les deux dernières séances ont été dures.")
        }

        // Duration follows what actually gets finished rather than what was
        // asked for. Someone who stops halfway through twelve minutes does not
        // need twelve minutes, they need eight they will complete.
        let recent = Array(valid.prefix(3))
        if recent.count >= 2, recent.filter({ !$0.wasCompleted }).count >= 2 {
            adapted.durationMinutes = max(5, Int(Double(base.durationMinutes) * 0.75))
            rationale.append("\(adapted.durationMinutes) min : mieux vaut une séance finie qu’une séance abandonnée.")
        } else if recent.count >= 3,
                  recent.allSatisfy({ $0.wasCompleted }),
                  trend.score > 0.4,
                  base.durationMinutes < 20 {
            adapted.durationMinutes = min(20, base.durationMinutes + 2)
            rationale.append("\(adapted.durationMinutes) min : vous finissez confortablement, on allonge un peu.")
        }

        // Zones follow whichever part of the wall has waited longest — but only
        // when the athlete has not named one themselves. An explicit choice is
        // an instruction, not a hint.
        if base.focusZones == [.fullCore], let debt = neglectedZone(in: valid, now: now) {
            adapted.focusZones = [debt.zone]
            rationale.append(
                debt.days.map { "\(debt.zone.title) en priorité : \($0) jours sans y toucher." }
                    ?? "\(debt.zone.title) en priorité : encore jamais travaillés."
            )
        }

        return SessionRecipe(preferences: adapted, guidance: guidance, rationale: rationale)
    }

    /// Recency-weighted read of the last five rated sessions.
    func effortTrend(of records: [WorkoutRecord]) -> EffortTrend {
        var trend = EffortTrend()
        var weightTotal = 0.0

        for (index, record) in records.prefix(5).enumerated() {
            let weight = 1.0 / (1.0 + Double(index) * 0.6)
            if !record.wasCompleted {
                // Stopping early is a verdict too, and a plainer one than a tap.
                trend.score -= weight * 0.6
                weightTotal += weight
                trend.abandonedCount += 1
                continue
            }
            switch record.perceivedEffort {
            case .easy: trend.score += weight
            case .hard: trend.score -= weight
            case .right: break
            case .unrated: continue
            }
            trend.ratedCount += 1
            weightTotal += weight
        }

        if weightTotal > 0 { trend.score /= weightTotal }
        return trend
    }

    /// The abdominal group that has waited longest, if it has waited long
    /// enough to be worth naming. `days` is nil when it has never been trained.
    ///
    /// Requires a history to speak from: on day one every group has waited
    /// forever, and telling a new athlete their obliques are neglected is both
    /// true and useless.
    func neglectedZone(
        in records: [WorkoutRecord],
        now: Date
    ) -> (zone: MuscleZone, days: Int?)? {
        guard !records.isEmpty else { return nil }
        let essential: [MuscleZone] = [.upperAbs, .lowerAbs, .obliques, .deepCore]
        var oldest: (zone: MuscleZone, days: Int?, rank: Int)?

        for zone in essential {
            let last = records.first { $0.trainedZones.contains(zone) }
            let days = last.map { record in
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: record.completedAt),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            }
            // Never trained outranks anything merely stale.
            let rank = days ?? Int.max
            if rank > (oldest?.rank ?? 0) { oldest = (zone, days, rank) }
        }

        guard let oldest, oldest.rank >= 3 else { return nil }
        return (oldest.zone, oldest.days)
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
