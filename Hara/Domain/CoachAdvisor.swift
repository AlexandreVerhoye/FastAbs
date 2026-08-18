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
    /// What the athlete asked for, before the coach touched anything.
    var base: WorkoutPreferences
    var guidance: CoachGuidance
    /// One line per decision worth explaining.
    var rationale: [String] = []

    /// Whether the day's settings differ from the athlete's own.
    ///
    /// Kept apart from `hasRationale` on purpose. The coach also steers the
    /// *selection* — reaching for the job the week has skipped, standing off
    /// yesterday's movements — and something is nearly always true of a week in
    /// progress, so a badge driven by the rationale would be lit permanently
    /// and mean nothing. This one lights only when the session the athlete
    /// asked for is not the session they are getting, which is the case that
    /// needs defending.
    var isAdapted: Bool { preferences != base }

    /// Whether there is anything to explain at all.
    var hasRationale: Bool { !rationale.isEmpty }
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

    /// The shortest and longest session the coach may ever prescribe. The same
    /// bounds the customisation slider offers, because a coach who hands back a
    /// number the athlete cannot set themselves has stopped being legible.
    static let durationBounds = 5...20

    /// The day's session: the athlete's settings, adjusted by what the history
    /// shows, with a reason attached to every adjustment.
    ///
    /// The rules run in a fixed order and each one may only speak once it has
    /// actually moved something. Both matter. The order, because a fortnight
    /// away and a run of easy sessions can be true at the same time, and firing
    /// both would hand someone coming back from a break a longer, harder
    /// session on the strength of how three-week-old sessions felt. The silence,
    /// because a bullet explaining an adjustment nobody made is worse than no
    /// bullet at all — it teaches the athlete that the reasons are decoration.
    func recipe(
        records: [WorkoutRecord],
        base: WorkoutPreferences,
        now: Date = .now
    ) -> SessionRecipe {
        let guidance = guidance(records: records, preferences: base, now: now)
        guard base.adaptiveCoaching else {
            return SessionRecipe(preferences: base, base: base, guidance: guidance)
        }

        let valid = analytics.qualifyingRecords(from: records)
            .sorted { $0.completedAt > $1.completedAt }
        // A coach who adjusts your very first session has not adjusted
        // anything, they have guessed.
        guard let latest = valid.first else {
            return SessionRecipe(preferences: base, base: base, guidance: guidance)
        }

        var adapted = base
        var rationale: [String] = []
        let trend = effortTrend(of: valid)
        let awayDays = dayGap(from: latest.completedAt, to: now)
        let streak = analytics.currentStreak(records: records, now: now)
        // A week off is the one signal loud enough to overrule everything the
        // sessions before it said.
        let isComeback = awayDays >= 7

        // 1. Coming back. Shorter and one level gentler, because the session
        //    that gets done today is worth more than the one that was fair.
        if isComeback {
            let before = adapted
            if let gentler = base.difficulty.previous { adapted.difficulty = gentler }
            adapted.durationMinutes = clampDuration(Int((Double(base.durationMinutes) * 0.6).rounded()))
            if adapted != before {
                var moved: [String] = []
                if adapted.durationMinutes != before.durationMinutes {
                    moved.append("\(adapted.durationMinutes) min")
                }
                if adapted.difficulty != before.difficulty {
                    moved.append("niveau \(adapted.difficulty.title.lowercased())")
                }
                rationale.append(
                    "Reprise en douceur : \(awayDays) jours sans séance, on repart sur \(moved.joined(separator: ", "))."
                )
            }
        }

        // 2. A long run without a day off. Rest is training too, and the way to
        //    protect a streak someone is proud of is to make today cost less
        //    rather than to tell them to skip it.
        if !isComeback, streak >= 6 {
            let before = adapted
            adapted.extraRecovery = true
            adapted.durationMinutes = clampDuration(base.durationMinutes - 3)
            if adapted != before {
                rationale.append("Séance allégée : \(streak) jours d’affilée, on lève le pied sans casser la série.")
            }
        }

        // 3. Difficulty follows the answers, one step at a time and never more
        //    than one from what the athlete chose — an adaptation that can run
        //    away from its starting point stops being an adjustment.
        if !isComeback {
            if trend.readsEasy, let harder = base.difficulty.next {
                adapted.difficulty = harder
                rationale.append("\(harder.title) plutôt que \(base.difficulty.title.lowercased()) : vos dernières séances vous ont paru faciles.")
            } else if trend.readsHard, let gentler = base.difficulty.previous {
                adapted.difficulty = gentler
                rationale.append("\(gentler.title) aujourd’hui : les deux dernières séances ont été dures.")
            } else if trend.readsHard, !adapted.extraRecovery {
                // Nothing left below: the level cannot give, so the recovery
                // does. Saying nothing here is how an athlete at the gentlest
                // setting learns the app has run out of answers.
                adapted.extraRecovery = true
                rationale.append("Récupération renforcée : le niveau ne descend pas plus bas et les dernières séances ont été dures.")
            }
        }

        // 4. Duration follows what actually gets finished rather than what was
        //    asked for. Someone who stops halfway through twelve minutes does
        //    not need twelve minutes, they need nine they will complete.
        //
        //    Read from every attempt, not only the ones long enough to count as
        //    training: quitting after ninety seconds leaves no qualifying
        //    record at all, which is precisely the case the athlete most needs
        //    the coach to notice.
        if adapted.durationMinutes == base.durationMinutes {
            let attempts = records.sorted { $0.completedAt > $1.completedAt }.prefix(3)
            let unfinished = attempts.filter { !$0.wasCompleted }.count
            if attempts.count >= 2, unfinished >= 2 {
                adapted.durationMinutes = clampDuration(Int(Double(base.durationMinutes) * 0.75))
                if adapted.durationMinutes != base.durationMinutes {
                    rationale.append("\(adapted.durationMinutes) min : mieux vaut une séance finie qu’une séance abandonnée.")
                }
            } else if valid.count >= 3,
                      valid.prefix(3).allSatisfy({ $0.wasCompleted }),
                      trend.score > 0.4,
                      base.durationMinutes < Self.durationBounds.upperBound {
                adapted.durationMinutes = clampDuration(base.durationMinutes + 2)
                rationale.append("\(adapted.durationMinutes) min : vous finissez confortablement, on allonge un peu.")
            }
        }

        // 5. Zones follow whichever part of the wall has waited longest — but
        //    only when the athlete has not named one themselves. An explicit
        //    choice is an instruction, not a hint.
        if base.focusZones == [.fullCore], let debt = neglectedZone(in: valid, now: now) {
            adapted.focusZones = [debt.zone]
            rationale.append(
                debt.days.map { "\(debt.zone.title) en priorité : \($0) jours sans y toucher." }
                    ?? "\(debt.zone.title) en priorité : encore jamais travaillés."
            )
        }

        // 6. What the selection itself will do differently. The engine already
        //    leans on both of these; without a sentence they are invisible, and
        //    an invisible adaptation reads as a shuffled list.
        if let gap = stalest(of: guidance.underworkedPatterns, in: valid) {
            rationale.append("\(gap.title) au programme : ce travail manque à votre semaine.")
        } else if !guidance.recentMovementIDs.isEmpty {
            rationale.append("Les mouvements de vos deux dernières séances passent leur tour.")
        }

        // Belt and braces. Every rule above already derives the level from
        // `base`, so this cannot fire today — it is here so that a rule added
        // tomorrow cannot quietly walk someone from beginner to athlete.
        adapted.difficulty = clamp(adapted.difficulty, within: 1, of: base.difficulty)

        return SessionRecipe(preferences: adapted, base: base, guidance: guidance, rationale: rationale)
    }

    private func clampDuration(_ minutes: Int) -> Int {
        min(Self.durationBounds.upperBound, max(Self.durationBounds.lowerBound, minutes))
    }

    private func clamp(
        _ difficulty: WorkoutDifficulty,
        within steps: Int,
        of base: WorkoutDifficulty
    ) -> WorkoutDifficulty {
        let bounded = min(base.rawValue + steps, max(base.rawValue - steps, difficulty.rawValue))
        return WorkoutDifficulty(rawValue: bounded) ?? base
    }

    private func dayGap(from start: Date, to end: Date) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
    }

    /// Of several untouched jobs, the one that has genuinely waited longest.
    ///
    /// Reading the first case out of the set would name the same job every
    /// Monday morning — a set has no order, and `allCases` order is alphabetical
    /// accident rather than coaching. Ties break on the identifier so the
    /// sentence is the same on two consecutive launches.
    private func stalest(
        of patterns: Set<CorePattern>,
        in records: [WorkoutRecord]
    ) -> CorePattern? {
        guard !patterns.isEmpty else { return nil }
        func lastSeen(_ pattern: CorePattern) -> Int {
            records.firstIndex { $0.trainedPatterns.contains(pattern) } ?? Int.max
        }
        return patterns.sorted { lhs, rhs in
            let left = lastSeen(lhs), right = lastSeen(rhs)
            return left == right ? lhs.rawValue < rhs.rawValue : left > right
        }.first
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
            let days = last.map { dayGap(from: $0.completedAt, to: now) }
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
            let days = dayGap(from: last.completedAt, to: now)
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
        if !records.isEmpty, let neglected = stalest(of: missing, in: records) {
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
