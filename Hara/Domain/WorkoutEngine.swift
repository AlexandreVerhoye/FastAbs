import Foundation

/// Builds a session from a set of preferences.
///
/// The session is built from a **cadence** — a work/rest pair and the number of
/// movements that run between two rests — rather than from a pool of seconds
/// that rests are carved out of afterwards.
///
/// That is the whole difference from the previous design. There, rest length
/// was a residual: whatever the work did not spend, divided by however many
/// gaps had been judged to deserve it. Nothing in that expression had the
/// authority to say that a hard session simply does not rest for thirty
/// seconds, so a seven-minute session at Intense handed out five recoveries of
/// up to thirty-one, each a different length from the last. Real protocols are
/// quoted the other way round and always have been — 30/30, 40/20, 45/15,
/// Tabata's 20/10 — so that is what this generates:
///
///     target == slots × work + recoveries × rest + transitions × 5
///
/// with the *work* absorbing the remainder. Rest length is a promise the level
/// makes and the solver may not break; how long you work is what flexes.
struct WorkoutEngine: Sendable {
    private let catalog: [Exercise]

    init(catalog: [Exercise] = ExerciseCatalog.all) {
        self.catalog = catalog
    }

    /// The groups a complete session owes the athlete, given what they train.
    ///
    /// Was a constant naming the four abdominal groups, which is the right
    /// answer only for as long as the abdomen is the only thing the app can
    /// programme. Read from the areas instead, so switching the legs on adds a
    /// promise rather than leaving the leg session measured against a
    /// checklist of abdominal groups it can never tick.
    static func essentialZones(for areas: Set<BodyArea>) -> Set<MuscleZone> {
        areas.reduce(into: Set<MuscleZone>()) { $0.formUnion($1.essentialZones) }
    }

    /// Seconds to change position between two movements of the same block.
    /// A doorway, not a rest: it is spent moving.
    static let transitionDuration = 5

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

        let cadence = solveCadence(target: target, preferences: preferences)

        // The cadence is solved before a movement is chosen, so it cannot know
        // that two slots will turn out to be the halves of one held movement —
        // and the gap between those two is not a place a rest may go. When that
        // costs the session enough rest that the work would have to run past
        // what the level promises, one more movement is added and the whole
        // thing is drawn again. Cheaper than letting an interval overshoot.
        var attempt = 0
        var ordered: [Slot] = []
        var legal: [Int] = []
        var schedule: (recoveryCount: Int, restLength: Int, workTotal: Int) = (0, 0, target)

        while attempt < 6 {
            var draw = SplitMix64(seed: seed &+ UInt64(attempt))
            let selected = selectSlots(
                count: cadence.slots + attempt,
                preferences: preferences,
                candidates: candidates,
                guidance: guidance,
                random: &draw
            )
            // Family first, then load. Both only ever swap two single slots, so
            // a movement held per side keeps its halves together and in order.
            ordered = spreadHardWork(repairFamilyAdjacency(selected))
            legal = legalGaps(in: ordered)
            schedule = fitSchedule(
                target: target,
                slots: ordered.count,
                legalGaps: legal.count,
                cadence: cadence,
                difficulty: preferences.difficulty
            )
            random = draw
            let band = preferences.difficulty.work
            if schedule.workTotal >= band.lowerBound * ordered.count,
               schedule.workTotal <= band.upperBound * ordered.count { break }
            attempt += 1
        }

        let recoveries = placeRecoveries(
            in: ordered,
            count: schedule.recoveryCount,
            legal: legal
        )
        let work = assignWork(
            to: ordered,
            total: schedule.workTotal,
            difficulty: preferences.difficulty,
            random: &random
        )

        let steps = assemble(
            slots: ordered,
            work: work,
            recoveries: recoveries,
            restLength: schedule.restLength,
            transitionCost: cadence.transitionCost
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
            // Every area a movement trains has to be switched on, not just one
            // of them. A burpee trains the chest whether or not you came for
            // the chest, so an athlete who turned the upper body off has to
            // stop seeing burpees — anything looser would quietly hand back the
            // work they just declined.
            exercise.areas.isSubset(of: preferences.trainedAreas) &&
            exercise.minimumDifficulty <= preferences.difficulty &&
            (!preferences.apartmentFriendly || exercise.impact == .quiet) &&
            (!preferences.neckFriendly || exercise.neckFriendly) &&
            !preferences.excludedExerciseIDs.contains(exercise.id)
        }
    }

    // MARK: - Stage 1: the cadence

    /// The shape of the session before anything is chosen: how many movements,
    /// how many of the gaps between them are real recoveries, and how long one
    /// of those recoveries runs.
    private struct Cadence {
        let slots: Int
        let recoveryCount: Int
        let restLength: Int
        /// The five seconds an interval costs when it carries no recovery.
        let transitionCost: Int
    }

    private func solveCadence(target: Int, preferences: WorkoutPreferences) -> Cadence {
        let difficulty = preferences.difficulty
        let work = difficulty.work
        let midpoint = Double(work.lowerBound + work.upperBound) / 2
        let transitionCost = preferences.positionTransitions ? Self.transitionDuration : 0
        // Reinforced recovery earns a rest one movement sooner and prefers the
        // long end of the level's range. It buys more rest, never a different
        // session length.
        let block = max(1, difficulty.movementsPerRecovery - (preferences.extraRecovery ? 1 : 0))

        var best: (cadence: Cadence, cost: Double)?

        for slots in 2...40 {
            let gaps = slots - 1
            let recoveries = gaps / block
            let transitions = gaps - recoveries

            for rest in difficulty.recovery {
                let workTotal = target - recoveries * rest - transitions * transitionCost
                guard workTotal > 0 else { continue }
                let per = Double(workTotal) / Double(slots)
                guard per >= Double(work.lowerBound), per <= Double(work.upperBound) else { continue }

                // Land near the middle of the level's band, and break ties
                // toward the shorter recovery — or the longer one when extra
                // recovery was asked for.
                let reach = Double(rest - difficulty.recovery.lowerBound)
                let cost = abs(per - midpoint) + (preferences.extraRecovery ? -0.30 : 0.25) * reach

                if best == nil || cost < best!.cost {
                    best = (
                        Cadence(
                            slots: slots,
                            recoveryCount: recoveries,
                            restLength: rest,
                            transitionCost: transitionCost
                        ),
                        cost
                    )
                }
            }
        }

        if let best { return best.cadence }

        // Nothing in the level's band fits the requested length exactly. Take
        // the movement count that comes closest and let `fitSchedule` settle the
        // seconds; a session is still owed its exact duration.
        let slots = max(2, min(40, Int((Double(target) / midpoint).rounded())))
        let gaps = slots - 1
        return Cadence(
            slots: slots,
            recoveryCount: gaps / block,
            restLength: difficulty.recovery.lowerBound,
            transitionCost: transitionCost
        )
    }

    /// The seconds, once it is known which gaps can carry a recovery.
    ///
    /// The solver picks a cadence before a single movement is chosen, so it
    /// cannot know that two of the slots will turn out to be the halves of one
    /// held movement — and the gap between those is not a place a rest may go.
    /// Rather than let that shortfall land on the work and push an interval
    /// past what the level promises, the recovery *count* is what gives: the
    /// session takes one break more or fewer, each still exactly as long as the
    /// level said it would be.
    private func fitSchedule(
        target: Int,
        slots: Int,
        legalGaps: Int,
        cadence: Cadence,
        difficulty: WorkoutDifficulty
    ) -> (recoveryCount: Int, restLength: Int, workTotal: Int) {
        let gaps = max(0, slots - 1)
        let floor = difficulty.work.lowerBound * slots
        let ceiling = difficulty.work.upperBound * slots

        func workTotal(count: Int, rest: Int) -> Int {
            target - count * rest - (gaps - count) * cadence.transitionCost
        }

        // Two passes. The first keeps the work a couple of seconds clear of the
        // band's edges: durations are handed out per movement, and a movement
        // held per side takes its seconds two at a time, so a total sitting
        // exactly on the ceiling can still round one interval past it.
        for margin in [2, 0] {
        var best: (count: Int, rest: Int, work: Int, cost: Double)?
        for count in 0...min(legalGaps, gaps) {
            for rest in difficulty.recovery {
                let total = workTotal(count: count, rest: rest)
                guard total >= floor, total <= ceiling - margin else { continue }
                // Stay as close as the seconds allow to the cadence the level
                // asked for, then to the rest length the solver chose.
                let cost = Double(abs(count - cadence.recoveryCount)) * 2
                    + Double(abs(rest - cadence.restLength)) * 0.25
                if best == nil || cost < best!.cost {
                    best = (count, rest, total, cost)
                }
            }
        }

        if let best { return (best.count, best.rest, best.work) }
        }

        // No combination inside the level's own bands lands on the requested
        // duration. Keep the promise the athlete can feel — rest never runs
        // longer than the level allows — and let the work carry the remainder.
        let count = min(legalGaps, cadence.recoveryCount)
        let rest = min(
            difficulty.recovery.upperBound,
            max(difficulty.recovery.lowerBound, cadence.restLength)
        )
        return (count, rest, max(slots, workTotal(count: count, rest: rest)))
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
        var coveredAreas: Set<BodyArea> = []
        var patternCounts: [CorePattern: Int] = [:]
        var coreMovements = 0
        var focusMatches = 0
        var heldPairs = 0

        let explicitFocus = preferences.explicitFocus

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
                coveredAreas: coveredAreas,
                patternCounts: patternCounts,
                movementCount: chosenIDs.count,
                coreMovements: coreMovements,
                focusMatches: focusMatches,
                explicitFocus: explicitFocus,
                slotsRemaining: remaining,
                slotCount: count,
                heldPairs: heldPairs,
                guidance: guidance,
                random: &random
            )

            if exercise.sideMode == .heldPerSide, remaining >= 2 {
                slots.append(Slot(exercise: exercise, side: .left))
                slots.append(Slot(exercise: exercise, side: .right))
                heldPairs += 1
            } else {
                slots.append(Slot(exercise: exercise, side: nil))
            }

            chosenIDs.append(exercise.id)
            recentFamilies.append(exercise.family)
            if recentFamilies.count > 3 { recentFamilies.removeFirst() }
            if let pattern = exercise.pattern {
                coveredPatterns.insert(pattern)
                patternCounts[pattern, default: 0] += 1
                coreMovements += 1
            }
            coveredZones.formUnion(exercise.zones)
            coveredAreas.formUnion(exercise.areas)
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
        coveredAreas: Set<BodyArea>,
        patternCounts: [CorePattern: Int],
        movementCount: Int,
        coreMovements: Int,
        focusMatches: Int,
        explicitFocus: Set<MuscleZone>,
        slotsRemaining: Int,
        slotCount: Int,
        heldPairs: Int,
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

        // The coarsest promise first: a session must touch every part of the
        // body the athlete switched on. Left to the score alone, an eight-slot
        // session drawn from a pool where four fifths of the movements are
        // abdominal will spend every slot there and never reach the legs — and
        // "I train my legs too" is a much louder instruction than any of the
        // finer preferences below it.
        let missingAreas = preferences.trainedAreas.subtracting(coveredAreas)
        if !missingAreas.isEmpty {
            let reaching = pool.filter { !$0.areas.isDisjoint(with: missingAreas) }
            // Only while there are slots left for the areas still waiting.
            if !reaching.isEmpty, slotsRemaining <= missingAreas.count + 1 {
                pool = reaching
            }
        }

        // Coverage before preference: a session owes the athlete every job the
        // trunk does, and zone coverage alone is trivially satisfied by five
        // different crunches.
        if explicitFocus.isEmpty {
            let missing = CorePattern.allCases.filter { pattern in
                !coveredPatterns.contains(pattern) && pool.contains { $0.pattern == pattern }
            }
            let covering = pool.filter { $0.pattern.map(missing.contains) ?? false }
            // How many jobs a session of this length can honestly promise. All
            // five in a seven-minute session means five or six movements — two
            // of which may be the halves of one held movement — every one of
            // them spoken for, and no room left to touch the abdominal groups
            // themselves. A coach covers the main jobs and rotates the rest
            // across the week rather than cramming them into one short session.
            // Counted over the core movements rather than over all of them: in
            // a whole-body session half the slots are not trunk work at all, and
            // measuring the promise against those would have the session chasing
            // five trunk jobs it never had the slots for.
            let coreShare = max(1, Int((Double(slotCount) * coreSlotShare(of: preferences)).rounded()))
            let promised = min(CorePattern.allCases.count, max(2, coreShare / 2))
            if !covering.isEmpty, coreMovements < promised { pool = covering }
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

            let patternGap: Double = if let pattern = exercise.pattern {
                coveredPatterns.contains(pattern) ? 0.0 : 3.2
            } else {
                0.0
            }
            // What the athlete can see at a glance: whether the session went
            // anywhere near the part of the body they asked for.
            let areaGap = Double(exercise.areas.subtracting(coveredAreas).count) * 4.2
            // Patterns decide what a session covers; zones still decide what it
            // feels like. Weighted per untouched essential group rather than as
            // a flat bonus — with a wider catalog every pattern has several
            // candidates, and a flat nudge stopped deciding between them.
            let missingZones = Self.essentialZones(for: preferences.trainedAreas)
                .subtracting(coveredZones)
                .intersection(exercise.zones)
            let zoneGap = Double(missingZones.count) * 5.0
            let share = exercise.pattern
                .map { Double(patternCounts[$0] ?? 0) / Double(totalMovements) } ?? 0
            let patternGlut = -25.0 * max(0, share - 0.45)
            // A held movement needs both its halves; it cannot take the last slot.
            let sideGate = exercise.sideMode == .heldPerSide && slotsRemaining < 2 ? -1_000.0 : 0
            // And a short session wants at most one of them. Two side planks in
            // seven minutes is a narrow session, and each held movement also
            // spends a gap that can never carry a recovery — enough of them and
            // the rest the level promised has nowhere left to go. A long session
            // has room for both the variety and the gaps.
            let heldAllowance = max(1, slotCount / 6)
            let heldGlut = exercise.sideMode == .heldPerSide && heldPairs >= heldAllowance
                ? -7.0 * Double(heldPairs - heldAllowance + 1)
                : 0

            // What yesterday changes about today. A movement done in the last
            // two sessions is not wrong, it is just less interesting than one
            // untouched for a week; and a job the week has not asked for is
            // worth more than one it already has.
            let staleness = guidance.recentMovementIDs.contains(exercise.id) ? -3.4 : 0.0
            let weeklyGap = exercise.pattern.map(guidance.underworkedPatterns.contains) ?? false
                ? 2.8 : 0.0
            let weeklyAreaGap = exercise.areas.isDisjoint(with: guidance.underworkedAreas)
                ? 0.0 : 2.4

            let jitter = Double.random(in: 0...1.6, using: &random)
            return (
                exercise,
                focusScore + levelScore + novelty + familyPenalty + fullCoreBonus
                    + compoundBonus + patternGap + areaGap + zoneGap + patternGlut
                    + sideGate + heldGlut + staleness + weeklyGap + weeklyAreaGap
                    + jitter
            )
        }

        return scored.max { $0.1 < $1.1 }?.0 ?? pool[0]
    }

    /// The share of a session that trunk work should take.
    ///
    /// Not a third each when three areas are on: the core is what this app is,
    /// and it also carries by far the deepest part of the catalog. Half the
    /// session when it is one of several areas, all of it when it is alone.
    private func coreSlotShare(of preferences: WorkoutPreferences) -> Double {
        guard preferences.trainedAreas.contains(.core) else { return 0 }
        return preferences.trainedAreas.count == 1 ? 1.0 : 0.5
    }

    // MARK: - Stage 3: ordering

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

    /// Keeps the hardest things in the session away from each other.
    ///
    /// Under the old design this was the rests' job: a gap between two
    /// demanding movements scored highly and bought itself a recovery. A
    /// session that only rests every third or fourth movement cannot pay for
    /// that and should not have to — ordering is the cheaper instrument, and
    /// the one a coach reaches for first. Alternating heavy and light is also
    /// simply how a circuit is written.
    ///
    /// A hill climb rather than a sweep: breaking one stack can make another,
    /// and the lighter movement that would fix a run of three is as often
    /// behind it as in front of it. Only single slots move, so a movement held
    /// per side keeps its two halves together and in order.
    private func spreadHardWork(_ slots: [Slot]) -> [Slot] {
        guard slots.count > 2 else { return slots }
        let intensities = slots.map(\.exercise.intensity)
        let mean = intensities.reduce(0, +) / Double(intensities.count)
        let threshold = mean * 1.12

        var result = slots
        var best = strain(of: result, threshold: threshold)
        let movable = result.indices.filter { result[$0].side == nil }

        for _ in 0..<6 {
            guard best > 0 else { break }
            var improvement: (lhs: Int, rhs: Int, strain: Int)?

            for (offset, lhs) in movable.enumerated() {
                for rhs in movable.dropFirst(offset + 1) {
                    result.swapAt(lhs, rhs)
                    let candidate = strain(of: result, threshold: threshold)
                    result.swapAt(lhs, rhs)
                    if candidate < (improvement?.strain ?? best) {
                        improvement = (lhs, rhs, candidate)
                    }
                }
            }

            guard let improvement else { break }
            result.swapAt(improvement.lhs, improvement.rhs)
            best = improvement.strain
        }
        return result
    }

    /// What is wrong with a running order, as one number: demanding movements
    /// side by side, and neighbours that move the same way. The two halves of
    /// one held movement are a single effort and never count against either.
    private func strain(of slots: [Slot], threshold: Double) -> Int {
        var total = 0
        for index in slots.indices.dropFirst() {
            let previous = slots[index - 1]
            let current = slots[index]
            if previous.exercise.id == current.exercise.id, current.side != nil { continue }
            if previous.exercise.intensity > threshold, current.exercise.intensity > threshold {
                total += 3
            }
            if previous.exercise.family == current.exercise.family { total += 2 }
        }
        return total
    }

    // MARK: - Stage 4: where the recoveries go

    /// Recoveries split the session into blocks as even as the count allows.
    ///
    /// Deliberately arithmetic rather than a fatigue model. The level already
    /// said how often it rests; a scorer that could move that around was how
    /// "one rest every third movement" turned into five rests of five different
    /// lengths. What varies between two sessions at the same level is which
    /// movements are in them, not where the breaks fall.
    private func placeRecoveries(in slots: [Slot], count: Int, legal: [Int]) -> Set<Int> {
        guard count > 0, !legal.isEmpty else { return [] }
        let blocks = count + 1
        var positions: Set<Int> = []
        var cursor = 0

        for block in 0..<count {
            cursor += slots.count / blocks + (block < slots.count % blocks ? 1 : 0)
            let ideal = cursor - 1
            guard let gap = legal
                .filter({ !positions.contains($0) })
                .min(by: { abs($0 - ideal) < abs($1 - ideal) })
            else { break }
            positions.insert(gap)
        }
        return positions
    }

    /// Every gap a recovery may occupy. The one between the two halves of a
    /// held movement may not: the change of side is the middle of one effort,
    /// not the end of it.
    private func legalGaps(in slots: [Slot]) -> [Int] {
        guard slots.count > 1 else { return [] }
        return (0..<(slots.count - 1)).filter { !isInsideHeldPair(slots, gap: $0) }
    }

    private func isInsideHeldPair(_ slots: [Slot], gap: Int) -> Bool {
        guard gap + 1 < slots.count else { return false }
        return slots[gap].side == .left
            && slots[gap + 1].side == .right
            && slots[gap].exercise.id == slots[gap + 1].exercise.id
    }

    // MARK: - Stage 5: work durations

    private func assignWork(
        to slots: [Slot],
        total: Int,
        difficulty: WorkoutDifficulty,
        random: inout SplitMix64
    ) -> [Int] {
        guard !slots.isEmpty else { return [] }
        let low = difficulty.work.lowerBound
        let high = difficulty.work.upperBound

        // Allocated per movement rather than per step: a movement held on one
        // side owns two slots, and splitting its budget afterwards is what
        // leaves the two sides a second apart. Keeping its total a multiple of
        // two means the halves come out equal by construction.
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
        let ceilings = units.map { high * $0.count }
        var remaining = total - totals.reduce(0, +)

        // Held movements take their seconds two at a time, and that parity is
        // the whole difficulty here: hand the singles their fill first and the
        // session can finish one odd second short, with nowhere left to put it
        // but past the ceiling. So the split between the two kinds is settled
        // before either is served.
        let singles = units.indices.filter { units[$0].count == 1 }
        let pairs = units.indices.filter { units[$0].count > 1 }
        let singleRoom = singles.reduce(0) { $0 + ceilings[$1] - totals[$1] }
        let pairRoom = pairs.reduce(0) { $0 + ceilings[$1] - totals[$1] }

        if remaining > 0 {
            // Whatever the singles cannot absorb has to go to the held
            // movements, rounded up to something they can actually take.
            var toPairs = max(0, remaining - singleRoom)
            if toPairs % 2 != 0 { toPairs += 1 }
            // Past that they take a share of what is left, so two sessions of
            // the same shape are not the same session.
            if pairRoom > toPairs, remaining > toPairs {
                let headroom = min(pairRoom - toPairs, remaining - toPairs)
                toPairs += Int.random(in: 0...(headroom / 2), using: &random) * 2
            }
            toPairs = min(toPairs, min(pairRoom, remaining))
            toPairs -= toPairs % 2

            remaining -= hand(&totals, ceilings: ceilings, units: units, to: pairs, amount: toPairs)
            // Easier movements take the rest first: a hollow hold does not need
            // to be the longest thing in the session.
            let gentleFirst = singles.sorted { lhs, rhs in
                let left = slots[units[lhs][0]].exercise.intensity
                let right = slots[units[rhs][0]].exercise.intensity
                return left == right ? lhs < rhs : left < right
            }
            remaining -= hand(
                &totals, ceilings: ceilings, units: units, to: gentleFirst, amount: remaining
            )
            if remaining > 0 {
                remaining -= hand(
                    &totals, ceilings: ceilings, units: units,
                    to: Array(units.indices), amount: remaining
                )
            }
        }

        var durations = Array(repeating: low, count: slots.count)
        for (unit, indices) in units.enumerated() {
            let share = totals[unit] / indices.count
            for slot in indices { durations[slot] = share }
        }
        return durations
    }

    /// Hands `amount` seconds to the listed movements, an even share at a time,
    /// each taking whole steps of its own size and none ever passing the
    /// level's ceiling. Returns how many seconds it placed.
    ///
    /// Spread rather than poured: an interval session reads as a cadence, so
    /// the movements in one should come out close to the same length. The old
    /// distribution handed out random one-to-three second chunks, which is why
    /// a single session could run 32, 35, 36, 35 and back again.
    private func hand(
        _ totals: inout [Int],
        ceilings: [Int],
        units: [[Int]],
        to order: [Int],
        amount: Int
    ) -> Int {
        guard amount > 0, !order.isEmpty else { return 0 }
        var left = amount

        for _ in 0..<8 {
            guard left > 0 else { break }
            let live = order.filter { ceilings[$0] - totals[$0] >= units[$0].count }
            guard !live.isEmpty else { break }

            var placed = false
            for unit in live where left > 0 {
                let size = units[unit].count
                let capacity = ceilings[unit] - totals[unit]
                let even = max(size, (left / live.count) - (left / live.count) % size)
                let step = min(capacity - capacity % size, min(left - left % size, even))
                guard step >= size else { continue }
                totals[unit] += step
                left -= step
                placed = true
            }
            if !placed { break }
        }
        return amount - left
    }

    private func isHeldPair(_ slots: [Slot], at index: Int) -> Bool {
        guard index + 1 < slots.count else { return false }
        return slots[index].side == .left
            && slots[index + 1].side == .right
            && slots[index].exercise.id == slots[index + 1].exercise.id
    }

    // MARK: - Stage 6: assembly

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
        recoveries: Set<Int>,
        restLength: Int,
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
            if recoveries.contains(index), restLength > 0 {
                steps.append(WorkoutStep(kind: .recovery, exercise: nil, duration: restLength))
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
