import Foundation

/// Builds a session from a set of preferences.
///
/// The pipeline is organised around one identity:
///
///     target == work + gap time
///
/// with gap time defined as the *residual*. Every interval between two
/// movements carries exactly one thing: a recovery, or five seconds to change
/// position. Never both — the recovery already gave you the time to move. That is the difference from the
/// previous design, where the number of rests was decided up front by the same
/// expression that decided the duration budget — which meant rest placement
/// could never respond to what was actually programmed. Here the solver owns
/// seconds and the placer owns positions, and the two never need to agree on a
/// count: landing exactly on the requested duration stops being a property
/// every later stage has to preserve and becomes arithmetic.
struct WorkoutEngine: Sendable {
    private let catalog: [Exercise]

    init(catalog: [Exercise] = ExerciseCatalog.all) {
        self.catalog = catalog
    }

    /// The abdominal groups a complete session owes the athlete.
    static let essentialZones: Set<MuscleZone> = [.upperAbs, .lowerAbs, .obliques, .deepCore]

    static let transitionDuration = 5
    /// A rest shorter than this is not a rest, it is a stumble.
    static let minimumRest = 6
    /// Beyond this an athlete goes cold and starts checking their phone.
    static let maximumRest = 90

    func makePlan(
        preferences: WorkoutPreferences,
        seed: UInt64,
        guidance: CoachGuidance = .none
    ) -> WorkoutPlan {
        var random = SplitMix64(seed: seed)
        let target = max(300, min(1_800, preferences.durationMinutes * 60))
        let candidates = eligibleExercises(for: preferences)

        guard !candidates.isEmpty else {
            return fallbackPlan(preferences: preferences, target: target)
        }

        let budget = solveBudget(target: target, preferences: preferences)
        let slots = selectSlots(
            count: budget.slots,
            preferences: preferences,
            candidates: candidates,
            guidance: guidance,
            random: &random
        )
        let repaired = repairFamilyAdjacency(slots)
        let work = assignWork(
            to: repaired,
            budget: budget,
            difficulty: preferences.difficulty,
            random: &random
        )
        let gaps = scoreGaps(slots: repaired, work: work, budget: budget, difficulty: preferences.difficulty)
        let chosen = placeRecovery(gaps, budget: budget, difficulty: preferences.difficulty)
        // Whatever the unrested intervals do not spend on their five seconds.
        let restBudget = budget.gaps - budget.transitionCost * (budget.gapCount - chosen.count)
        let rests = splitRest(restBudget, across: chosen)

        let steps = assemble(
            slots: repaired,
            work: work,
            rests: Dictionary(uniqueKeysWithValues: zip(chosen.map(\.after), rests)),
            transitionCost: budget.transitionCost
        )

        return WorkoutPlan(
            preferences: preferences,
            steps: steps,
            estimatedCalories: calories(for: steps)
        )
    }

    // MARK: - Eligibility

    private func eligibleExercises(for preferences: WorkoutPreferences) -> [Exercise] {
        catalog.filter { exercise in
            exercise.minimumDifficulty <= preferences.difficulty &&
            (!preferences.apartmentFriendly || exercise.impact == .quiet) &&
            (!preferences.neckFriendly || exercise.neckFriendly)
        }
    }

    // MARK: - Stage 1: the budget

    /// How the session's seconds are divided, before anything is chosen.
    private struct Budget {
        /// Exercise steps. A movement held per side occupies two of these.
        let slots: Int
        let work: Int
        /// Everything that is not work: the gaps between movements, whatever
        /// each one turns out to carry.
        let gaps: Int
        /// The five seconds an interval costs when it carries no recovery.
        let transitionCost: Int

        var gapCount: Int { max(0, slots - 1) }
        /// What the intervals cost before a single second of rest is spent.
        var floor: Int { transitionCost * gapCount }
    }

    private func solveBudget(target: Int, preferences: WorkoutPreferences) -> Budget {
        let difficulty = preferences.difficulty
        let low = difficulty.interval.lowerBound
        let high = difficulty.interval.upperBound
        let midpoint = Double(low + high) / 2
        let ratio = difficulty.restRatio * (preferences.extraRecovery ? 1.3 : 1)
        let transitionCost = preferences.positionTransitions ? Self.transitionDuration : 0

        var best: (budget: Budget, cost: Double)?

        for slots in 1...80 {
            let floor = transitionCost * (slots - 1)
            let spendable = target - floor
            guard spendable >= slots * low else { break }

            let ideal = Double(spendable) / (1 + ratio)
            let work = min(max(Int(ideal.rounded()), slots * low), slots * high)
            let gaps = target - work
            guard gaps >= floor else { continue }

            // What is left once every interval has paid for its own five
            // seconds is what can become recovery.
            let restable = gaps - floor
            let ratioError = abs(Double(restable) / Double(work) - ratio) / max(ratio, 0.01)
            let lengthError = abs(Double(work) / Double(slots) - midpoint) / Double(high - low + 1)
            let cost = ratioError + 0.15 * lengthError

            if best == nil || cost < best!.cost {
                best = (
                    Budget(slots: slots, work: work, gaps: gaps, transitionCost: transitionCost),
                    cost
                )
            }
        }

        return best?.budget
            ?? Budget(slots: 1, work: target, gaps: 0, transitionCost: transitionCost)
    }

    // MARK: - Stage 2: selection

    /// One exercise step before it has a duration.
    private struct Slot {
        let exercise: Exercise
        let side: BodySide?
    }

    private func selectSlots(
        count: Int,
        preferences: WorkoutPreferences,
        candidates: [Exercise],
        guidance: CoachGuidance,
        random: inout SplitMix64
    ) -> [Slot] {
        var slots: [Slot] = []
        var chosenIDs: [String] = []
        var recentFamilies: [MovementFamily] = []
        var coveredPatterns: Set<CorePattern> = []
        var coveredZones: Set<MuscleZone> = []
        var patternCounts: [CorePattern: Int] = [:]
        var focusMatches = 0

        let explicitFocus = preferences.focusZones.subtracting([.fullCore])

        while slots.count < count {
            let remaining = count - slots.count
            let exercise = chooseExercise(
                preferences: preferences,
                candidates: candidates,
                chosenIDs: chosenIDs,
                slotIndex: slots.count,
                recentFamilies: recentFamilies,
                coveredPatterns: coveredPatterns,
                coveredZones: coveredZones,
                patternCounts: patternCounts,
                movementCount: chosenIDs.count,
                focusMatches: focusMatches,
                explicitFocus: explicitFocus,
                slotsRemaining: remaining,
                slotCount: count,
                guidance: guidance,
                random: &random
            )

            if exercise.sideMode == .heldPerSide, remaining >= 2 {
                slots.append(Slot(exercise: exercise, side: .left))
                slots.append(Slot(exercise: exercise, side: .right))
            } else {
                slots.append(Slot(exercise: exercise, side: nil))
            }

            chosenIDs.append(exercise.id)
            recentFamilies.append(exercise.family)
            if recentFamilies.count > 3 { recentFamilies.removeFirst() }
            coveredPatterns.insert(exercise.pattern)
            coveredZones.formUnion(exercise.zones)
            patternCounts[exercise.pattern, default: 0] += 1
            if !explicitFocus.isEmpty, !exercise.zones.intersection(explicitFocus).isEmpty {
                focusMatches += 1
            }
        }

        return slots
    }

    private func chooseExercise(
        preferences: WorkoutPreferences,
        candidates: [Exercise],
        chosenIDs: [String],
        slotIndex: Int,
        recentFamilies: [MovementFamily],
        coveredPatterns: Set<CorePattern>,
        coveredZones: Set<MuscleZone>,
        patternCounts: [CorePattern: Int],
        movementCount: Int,
        focusMatches: Int,
        explicitFocus: Set<MuscleZone>,
        slotsRemaining: Int,
        slotCount: Int,
        guidance: CoachGuidance,
        random: inout SplitMix64
    ) -> Exercise {
        // A movement may only come back when the pool genuinely runs out, and
        // even then only after three others have gone by, drawn from the
        // gentlest third. The catalog cannot fill a long beginner session
        // otherwise, and repeating silently was worse than repeating on terms.
        let recentIDs = Set(chosenIDs.suffix(3))
        let unused = candidates.filter { !chosenIDs.contains($0.id) }
        var pool: [Exercise]
        if unused.isEmpty {
            let gentle = candidates
                .sorted { $0.intensity < $1.intensity }
                .prefix(max(1, candidates.count / 3))
            let spaced = gentle.filter { !recentIDs.contains($0.id) }
            pool = spaced.isEmpty ? Array(gentle) : spaced
        } else {
            pool = unused
        }

        // Coverage before preference: a session owes the athlete every job the
        // trunk does, and zone coverage alone is trivially satisfied by five
        // different crunches.
        if explicitFocus.isEmpty {
            let missing = CorePattern.allCases.filter { pattern in
                !coveredPatterns.contains(pattern) && pool.contains { $0.pattern == pattern }
            }
            let covering = pool.filter { missing.contains($0.pattern) }
            // How many jobs a session of this length can honestly promise. All
            // five in a seven-minute session means five or six movements — two
            // of which may be the halves of one held movement — every one of
            // them spoken for, and no room left to touch the abdominal groups
            // themselves. A coach covers the main jobs and rotates the rest
            // across the week rather than cramming them into one short session.
            let promised = min(CorePattern.allCases.count, max(3, slotCount / 2))
            if !covering.isEmpty, movementCount < promised { pool = covering }
        } else if focusMatches < 2 {
            let focused = pool.filter { !$0.zones.intersection(explicitFocus).isEmpty }
            if !focused.isEmpty { pool = focused }
        }

        if let lastFamily = recentFamilies.last {
            let different = pool.filter { $0.family != lastFamily }
            if !different.isEmpty { pool = different }
        }

        let totalMovements = max(1, movementCount)
        let scored = pool.map { exercise -> (Exercise, Double) in
            let matches = explicitFocus.isEmpty ? 1 : exercise.zones.intersection(explicitFocus).count
            let focusScore = explicitFocus.isEmpty
                ? Double(exercise.zones.count) * 0.35
                : Double(matches) * 4.5
            let levelDistance = abs(exercise.minimumDifficulty.rawValue - preferences.difficulty.rawValue)
            let levelScore = 2.2 - Double(levelDistance) * 0.65
            let novelty = chosenIDs.contains(exercise.id) ? -9.0 : 2.0
            let familyPenalty = recentFamilies.last == exercise.family ? -5.0 :
                (recentFamilies.contains(exercise.family) ? -1.7 : 1.2)
            let fullCoreBonus = exercise.zones.contains(.fullCore) ? 0.8 : 0
            let breadth = Double(exercise.zones.count)
            let compoundBonus = preferences.durationMinutes <= 8 ? breadth * 1.1 : breadth * 0.2

            let patternGap = coveredPatterns.contains(exercise.pattern) ? 0.0 : 3.2
            // Patterns decide what a session covers; zones still decide what it
            // feels like. Weighted per untouched essential group rather than as
            // a flat bonus — with a wider catalog every pattern has several
            // candidates, and a flat nudge stopped deciding between them.
            let missingZones = Self.essentialZones
                .subtracting(coveredZones)
                .intersection(exercise.zones)
            // Heavy enough to decide inside a pattern-restricted pool, which is
            // where it has to work: the first picks of a short session are
            // already narrowed to one pattern each, so a gentle nudge never got
            // to choose between the candidates.
            let zoneGap = Double(missingZones.count) * 5.0
            let share = Double(patternCounts[exercise.pattern] ?? 0) / Double(totalMovements)
            let patternGlut = -25.0 * max(0, share - 0.45)
            // A held movement needs both its halves; it cannot take the last slot.
            let sideGate = exercise.sideMode == .heldPerSide && slotsRemaining < 2 ? -1_000.0 : 0

            // What yesterday changes about today. A movement done in the last
            // two sessions is not wrong, it is just less interesting than one
            // untouched for a week; and a job the week has not asked for is
            // worth more than one it already has.
            let staleness = guidance.recentMovementIDs.contains(exercise.id) ? -3.4 : 0.0
            let weeklyGap = guidance.underworkedPatterns.contains(exercise.pattern) ? 2.8 : 0.0

            let jitter = Double.random(in: 0...1.6, using: &random)
            return (
                exercise,
                focusScore + levelScore + novelty + familyPenalty + fullCoreBonus
                    + compoundBonus + patternGap + zoneGap + patternGlut + sideGate
                    + staleness + weeklyGap + jitter
            )
        }

        return scored.max { $0.1 < $1.1 }?.0 ?? pool[0]
    }

    // MARK: - Stage 3: adjacency repair

    /// Swaps neighbours apart when the picker was cornered into two movements
    /// of the same family in a row. Evaluated over movements, so the two halves
    /// of a held movement are never treated as a clash with each other.
    private func repairFamilyAdjacency(_ slots: [Slot]) -> [Slot] {
        var result = slots
        var index = 1
        while index < result.count {
            let previous = result[index - 1]
            let current = result[index]
            let sameMovement = previous.exercise.id == current.exercise.id
            guard !sameMovement, previous.exercise.family == current.exercise.family else {
                index += 1
                continue
            }

            let swap = result.indices.dropFirst(index + 1).first { candidate in
                let held = result[candidate].side != nil
                guard !held else { return false }
                let fits = result[candidate].exercise.family != previous.exercise.family
                let leaves = candidate + 1 >= result.count
                    || result[candidate + 1].exercise.family != current.exercise.family
                return fits && leaves
            }

            if let swap, current.side == nil {
                result.swapAt(index, swap)
            } else if current.side != nil, previous.side == nil, index > 1 {
                // The clash is against a held pair, which cannot be moved: the
                // two halves have to stay together and in order. Move the
                // single movement in front of it instead.
                let alternative = result.indices.dropFirst(index + 2).first { candidate in
                    result[candidate].side == nil
                        && result[candidate].exercise.family != current.exercise.family
                        && result[candidate].exercise.family != result[index - 2].exercise.family
                }
                if let alternative { result.swapAt(index - 1, alternative) }
            }
            index += 1
        }
        return result
    }

    // MARK: - Stage 4: work durations

    private func assignWork(
        to slots: [Slot],
        budget: Budget,
        difficulty: WorkoutDifficulty,
        random: inout SplitMix64
    ) -> [Int] {
        let low = difficulty.interval.lowerBound
        let high = difficulty.interval.upperBound
        guard !slots.isEmpty else { return [] }

        // Allocated per movement rather than per step: a movement held on one
        // side owns two slots, and splitting its budget afterwards is what
        // leaves the two sides a second apart. Keeping its total even means the
        // halves are equal by construction.
        var units: [[Int]] = []
        var index = 0
        while index < slots.count {
            if isHeldPair(slots, at: index) {
                units.append([index, index + 1])
                index += 2
            } else {
                units.append([index])
                index += 1
            }
        }

        var totals = units.map { low * $0.count }
        var extra = budget.work - totals.reduce(0, +)

        // Harder movements take the surplus last: a hollow hold does not need
        // to be the longest thing in the session.
        var order = Array(units.indices)
        order.sort { lhs, rhs in
            slots[units[lhs][0]].exercise.intensity < slots[units[rhs][0]].exercise.intensity
        }

        while extra > 0 {
            var spent = false
            for unit in order where extra > 0 {
                let size = units[unit].count
                let room = high * size - totals[unit]
                guard room >= size else { continue }
                let wanted = Int.random(in: 1...3, using: &random) * size
                let step = min(room, min(extra - extra % size, wanted))
                guard step >= size else { continue }
                totals[unit] += step
                extra -= step
                spent = true
            }
            if !spent { break }
        }

        // Anything the step size could not place goes to the first single slot
        // with room, so the session still lands exactly on its budget.
        if extra > 0 {
            for unit in units.indices where extra > 0 && units[unit].count == 1 {
                let room = high - totals[unit]
                let step = min(room, extra)
                totals[unit] += step
                extra -= step
            }
        }

        var durations = Array(repeating: low, count: slots.count)
        for (unit, indices) in units.enumerated() {
            let share = totals[unit] / indices.count
            for slot in indices { durations[slot] = share }
        }
        return durations
    }

    private func isHeldPair(_ slots: [Slot], at index: Int) -> Bool {
        guard index + 1 < slots.count else { return false }
        return slots[index].side == .left
            && slots[index + 1].side == .right
            && slots[index].exercise.id == slots[index + 1].exercise.id
    }

    // MARK: - Stage 5: where the rest goes

    private struct Gap {
        /// Sits between exercise step `after` and `after + 1`.
        let after: Int
        let allowsRecovery: Bool
        let score: Double
        let bothHard: Bool
    }

    private func scoreGaps(
        slots: [Slot],
        work: [Int],
        budget: Budget,
        difficulty: WorkoutDifficulty
    ) -> [Gap] {
        guard slots.count > 1 else { return [] }

        let midpoint = Double(difficulty.interval.lowerBound + difficulty.interval.upperBound) / 2
        let demands = slots.indices.map { index in
            slots[index].exercise.intensity * Double(work[index]) / midpoint
        }
        let mean = demands.reduce(0, +) / Double(demands.count)
        let restable = max(0, budget.gaps - budget.floor)
        let restTarget = max(1, restable / max(1, difficulty.preferredRest))
        let decay = exp(-Double(restable) / Double(max(1, restTarget)) / 40)

        // Fatigue accumulates forward. The nominal rest length has to stand in
        // for the real one here: the true lengths are not known until the split,
        // and the split depends on this placement.
        var fatigue: [Double] = []
        var running = 0.0
        for index in demands.indices {
            running = running * (index == 0 ? 0 : decay) + demands[index]
            fatigue.append(running)
        }

        return (0..<(slots.count - 1)).map { index in
            let held = slots[index].side == .left && slots[index + 1].side == .right
                && slots[index].exercise.id == slots[index + 1].exercise.id
            let out = demands[index]
            let into = demands[index + 1]
            let bothHard = min(out, into) > mean * 1.15
            let score = 1.00 * out / mean
                + 0.55 * into / mean
                + 0.70 * fatigue[index] / mean
                + (bothHard ? 1.20 : 0)
                - (index == 0 ? 0.80 : 0)
            return Gap(after: index, allowsRecovery: !held, score: score, bothHard: bothHard)
        }
    }

    private func placeRecovery(
        _ gaps: [Gap],
        budget: Budget,
        difficulty: WorkoutDifficulty
    ) -> [Gap] {
        let restable = budget.gaps - budget.floor
        guard restable > 0 else { return [] }
        let allowed = gaps.filter(\.allowsRecovery)
        guard !allowed.isEmpty else { return [] }

        // A rested interval stops paying for its own five seconds, so each one
        // chosen adds that back to the purse: r rests share `restable + 5r`,
        // and every rest must still clear the floor.
        let affordable = restable / max(1, Self.minimumRest - budget.transitionCost)
        let ceiling = min(allowed.count, max(0, affordable))
        guard ceiling > 0 else { return [] }
        let target = min(
            ceiling,
            max(1, Int((Double(restable) / Double(difficulty.preferredRest)).rounded()))
        )

        // Two demanding movements never land back to back — the promise that
        // justifies scoring gaps rather than counting them.
        var chosen = Set(allowed.filter(\.bothHard).map(\.after))

        // And no run of three movements without a break. Walked over positions
        // rather than over the gap list: the gap inside a held pair cannot take
        // a rest, so counting gaps alone would let a pair stretch a run to four.
        var run = 1
        for gap in gaps {
            if chosen.contains(gap.after) { run = 1; continue }
            let nextIsBlocked = gap.after + 1 < gaps.count && !gaps[gap.after + 1].allowsRecovery
            if gap.allowsRecovery, run >= 3 || (run >= 2 && nextIsBlocked) {
                chosen.insert(gap.after)
                run = 1
            } else {
                run += 1
            }
        }

        let byScore = allowed.sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.after < rhs.after : lhs.score > rhs.score
        }
        for gap in byScore where chosen.count < target {
            chosen.insert(gap.after)
        }
        if chosen.count > ceiling {
            chosen = Set(byScore.filter { chosen.contains($0.after) }.prefix(ceiling).map(\.after))
        }

        return allowed.filter { chosen.contains($0.after) }.sorted { $0.after < $1.after }
    }

    // MARK: - Stage 6: splitting the rest

    private func splitRest(_ budget: Int, across gaps: [Gap]) -> [Int] {
        guard !gaps.isEmpty else { return [] }
        var seconds = Array(repeating: Self.minimumRest, count: gaps.count)
        var surplus = budget - Self.minimumRest * gaps.count
        guard surplus > 0 else { return seconds }

        let weights = gaps.map { max(0.5, $0.score) }
        let total = weights.reduce(0, +)
        var shares = weights.map { Double(surplus) * $0 / total }

        for index in seconds.indices {
            let whole = Int(shares[index])
            seconds[index] += whole
            surplus -= whole
            shares[index] -= Double(whole)
        }

        // Largest remainder first, index-tiebroken so it stays deterministic.
        let order = shares.indices.sorted { lhs, rhs in
            shares[lhs] == shares[rhs] ? lhs < rhs : shares[lhs] > shares[rhs]
        }
        var cursor = 0
        while surplus > 0 {
            seconds[order[cursor % order.count]] += 1
            surplus -= 1
            cursor += 1
        }

        return seconds
    }

    // MARK: - Stage 7: assembly

    /// Grammar: `E ( (R | X) E )*`. Every interval carries one thing — a
    /// recovery, or five seconds to change position, never both. A recovery
    /// already gives you time to move, and stacking a placement on top of one
    /// only makes the session feel like it is waiting for you.
    ///
    /// First and last step are exercises, and two rests can never touch, both
    /// by construction rather than by assertion.
    private func assemble(
        slots: [Slot],
        work: [Int],
        rests: [Int: Int],
        transitionCost: Int
    ) -> [WorkoutStep] {
        var steps: [WorkoutStep] = []
        for index in slots.indices {
            steps.append(
                WorkoutStep(
                    kind: .exercise,
                    exercise: slots[index].exercise,
                    side: slots[index].side,
                    duration: work[index]
                )
            )
            guard index < slots.count - 1 else { continue }
            if let rest = rests[index], rest > 0 {
                steps.append(WorkoutStep(kind: .recovery, exercise: nil, duration: rest))
            } else if transitionCost > 0 {
                steps.append(WorkoutStep(kind: .transition, exercise: nil, duration: transitionCost))
            }
        }
        return steps
    }

    // MARK: - Support

    private func calories(for steps: [WorkoutStep]) -> Int {
        let activeSeconds = steps.filter { $0.kind == .exercise }.reduce(0) { $0 + $1.duration }
        let intensities = steps.compactMap(\.exercise?.intensity)
        let average = intensities.isEmpty ? 1 : intensities.reduce(0, +) / Double(intensities.count)
        return max(12, Int((Double(activeSeconds) / 60) * average * 4.8))
    }

    private func fallbackPlan(preferences: WorkoutPreferences, target: Int) -> WorkoutPlan {
        let hold = Exercise(
            id: "safe-core-hold",
            name: "Gainage doux",
            zones: [.deepCore, .fullCore],
            family: .antiExtension,
            pattern: .antiExtension,
            minimumDifficulty: .beginner,
            impact: .quiet,
            motion: .plank,
            setup: "Sur les avant-bras, coudes sous les épaules, genoux au sol si besoin.",
            instruction: "Tiens la position en respirant calmement, sans laisser le bassin descendre.",
            breathing: "Respire lentement et régulièrement.",
            mistake: "Bloquer la respiration pour tenir plus longtemps.",
            tips: ["Pose les genoux dès que la ligne se casse.", "Respire, ne bloque jamais."],
            sideMode: .bilateral,
            neckFriendly: true,
            intensity: 0.9
        )
        let steps = [WorkoutStep(kind: .exercise, exercise: hold, duration: target)]
        return WorkoutPlan(
            preferences: preferences,
            steps: steps,
            estimatedCalories: calories(for: steps)
        )
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
