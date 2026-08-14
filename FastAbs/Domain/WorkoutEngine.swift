import Foundation

struct WorkoutEngine: Sendable {
    private let catalog: [Exercise]

    init(catalog: [Exercise] = ExerciseCatalog.all) {
        self.catalog = catalog
    }

    func makePlan(preferences: WorkoutPreferences, seed: UInt64) -> WorkoutPlan {
        var random = SplitMix64(seed: seed)
        let target = max(300, min(1_800, preferences.durationMinutes * 60))
        let candidates = eligibleExercises(for: preferences)

        var steps: [WorkoutStep] = []
        var selectedIDs: Set<String> = []
        var recentFamilies: [MovementFamily] = []
        var recentAreas: [BodyRegion] = []
        var coveredZones: Set<MuscleZone> = []
        var focusMatches = 0
        let recovery = recoveryDuration(for: preferences)
        let workDurations = makeWorkDurations(
            target: target,
            difficulty: preferences.difficulty,
            recovery: recovery,
            random: &random
        )

        for (exerciseIndex, workDuration) in workDurations.enumerated() where !candidates.isEmpty {

            var exercise = chooseExercise(
                from: candidates,
                preferences: preferences,
                selectedIDs: selectedIDs,
                recentFamilies: recentFamilies,
                recentAreas: recentAreas,
                coveredZones: coveredZones,
                focusMatches: focusMatches,
                random: &random
            )
            if let previousFamily = recentFamilies.last, exercise.family == previousFamily {
                let unselectedAlternatives = candidates.filter {
                    $0.family != previousFamily && !selectedIDs.contains($0.id)
                }
                if !unselectedAlternatives.isEmpty {
                    exercise = unselectedAlternatives[Int.random(in: unselectedAlternatives.indices, using: &random)]
                }
            }
            steps.append(WorkoutStep(kind: .exercise, exercise: exercise, duration: workDuration))
            selectedIDs.insert(exercise.id)
            coveredZones.formUnion(exercise.zones)
            if !exercise.zones.intersection(preferences.focusZones.subtracting([.fullCore])).isEmpty {
                focusMatches += 1
            }
            recentFamilies.append(exercise.family)
            recentFamilies = Array(recentFamilies.suffix(3))
            recentAreas.append(WorkoutEngine.area(of: exercise))
            recentAreas = Array(recentAreas.suffix(2))

            let isLastExercise = exerciseIndex == workDurations.count - 1
            let shouldRecover = !isLastExercise && (exerciseIndex + 1).isMultiple(of: 2)
            if shouldRecover {
                steps.append(WorkoutStep(kind: .recovery, exercise: nil, duration: recovery))
            }
        }

        if steps.isEmpty {
            let fallback = Exercise(
                id: "safe-core-hold", name: "Gainage doux", zones: [.deepCore], family: .antiExtension,
                minimumDifficulty: .beginner, impact: .quiet, motion: .plank,
                setup: "Installez-vous à quatre pattes ou sur les avant-bras, dos plat.",
                instruction: "Maintenez une posture confortable.", breathing: "Respirez régulièrement.",
                mistake: "Retenir sa respiration pendant le maintien.",
                unilateral: false, neckFriendly: true, intensity: 0.7
            )
            steps = [WorkoutStep(kind: .exercise, exercise: fallback, duration: target)]
        } else {
            steps = reorderedForFamilyDiversity(steps, programme: preferences.programme)
            steps = weightedRecovery(steps)
        }

        let activeSeconds = steps.filter { $0.kind == .exercise }.reduce(0) { $0 + $1.duration }
        let averageIntensity = steps.compactMap(\.exercise?.intensity).average ?? 1
        let calories = max(12, Int((Double(activeSeconds) / 60) * averageIntensity * 4.8))
        return WorkoutPlan(
            preferences: preferences,
            steps: steps,
            estimatedCalories: calories
        )
    }

    /// The part of the body an exercise mostly belongs to.
    static func area(of exercise: Exercise) -> BodyRegion {
        exercise.zones.map(\.region).first { $0 != .core } ?? .core
    }

    private func eligibleExercises(for preferences: WorkoutPreferences) -> [Exercise] {
        let regions = preferences.programme.regions
        return catalog.filter { exercise in
            exercise.minimumDifficulty <= preferences.difficulty &&
            (!preferences.apartmentFriendly || exercise.impact == .quiet) &&
            (!preferences.neckFriendly || exercise.neckFriendly) &&
            exercise.zones.contains { regions.contains($0.region) }
        }
    }

    /// Recovery is redistributed so it follows effort rather than being handed
    /// out evenly.
    ///
    /// A set of squats and a dead bug do not leave you in the same state, and a
    /// programme that rests the same after each is only nominally adaptive. The
    /// total stays fixed, so the session still lands on its target duration —
    /// what changes is where the seconds go.
    private func weightedRecovery(_ steps: [WorkoutStep]) -> [WorkoutStep] {
        let recoveryIndices = steps.indices.filter { steps[$0].kind == .recovery }
        guard !recoveryIndices.isEmpty else { return steps }

        let budget = recoveryIndices.reduce(0) { $0 + steps[$1].duration }
        let demands = recoveryIndices.map { index -> Double in
            // The exercise just finished is the one being recovered from.
            let previous = steps[..<index].last { $0.kind == .exercise }?.exercise
            return max(0.5, previous?.intensity ?? 1)
        }
        let totalDemand = demands.reduce(0, +)
        guard totalDemand > 0 else { return steps }

        var adjusted = steps
        var spent = 0
        for (position, index) in recoveryIndices.enumerated() {
            let share = Double(budget) * demands[position] / totalDemand
            // The last one absorbs the rounding so the total is exact.
            let seconds = position == recoveryIndices.count - 1
                ? budget - spent
                : max(6, Int(share.rounded()))
            spent += seconds
            adjusted[index] = WorkoutStep(
                id: steps[index].id,
                kind: .recovery,
                exercise: nil,
                duration: seconds
            )
        }
        return adjusted
    }

    private func recoveryDuration(for preferences: WorkoutPreferences) -> Int {
        preferences.difficulty.rest + (preferences.extraRecovery ? 5 : 0)
    }

    private func makeWorkDurations<R: RandomNumberGenerator>(
        target: Int,
        difficulty: WorkoutDifficulty,
        recovery: Int,
        random: inout R
    ) -> [Int] {
        let preferredMinimum = difficulty.interval.lowerBound
        let maximum = difficulty.interval.upperBound
        let midpoint = Double(preferredMinimum + maximum) / 2

        func viableCounts(minimum: Int) -> [(count: Int, workTotal: Int, distance: Double)] {
            (1...80).compactMap { count in
                let recoveryCount = (count - 1) / 2
                let workTotal = target - recoveryCount * recovery
                guard workTotal >= count * minimum, workTotal <= count * maximum else { return nil }
                let average = Double(workTotal) / Double(count)
                return (count, workTotal, abs(average - midpoint))
            }
        }

        let options = viableCounts(minimum: preferredMinimum)
        let relaxedOptions = options.isEmpty ? viableCounts(minimum: 20) : options
        guard let selected = relaxedOptions.min(by: { $0.distance < $1.distance }) else {
            return [target]
        }

        let minimum = options.isEmpty ? 20 : preferredMinimum
        var durations = Array(repeating: minimum, count: selected.count)
        var extra = selected.workTotal - minimum * selected.count
        var indexes = Array(durations.indices)
        while extra > 0 {
            indexes.shuffle(using: &random)
            for index in indexes where extra > 0 {
                let room = maximum - durations[index]
                guard room > 0 else { continue }
                let addition = min(room, Int.random(in: 1...min(3, extra), using: &random))
                durations[index] += addition
                extra -= addition
            }
        }
        return durations
    }

    private func chooseExercise<R: RandomNumberGenerator>(
        from candidates: [Exercise],
        preferences: WorkoutPreferences,
        selectedIDs: Set<String>,
        recentFamilies: [MovementFamily],
        recentAreas: [BodyRegion],
        coveredZones: Set<MuscleZone>,
        focusMatches: Int,
        random: inout R
    ) -> Exercise {
        let explicitFocus = preferences.programme == .core
            ? preferences.focusZones.subtracting([.fullCore])
            : []
        let unselected = candidates.filter { !selectedIDs.contains($0.id) }
        let basePool = unselected.isEmpty ? candidates : unselected
        var pool = basePool

        if explicitFocus.isEmpty {
            // Coverage first: a programme owes the athlete every group it
            // promises, so anything still untouched outranks everything else.
            let missing = Set(preferences.programme.essentialZones).subtracting(coveredZones)
            let covering = pool.filter { !$0.zones.intersection(missing).isEmpty }
            if !covering.isEmpty { pool = covering }
        } else if focusMatches < 2 {
            let focused = pool.filter { !$0.zones.intersection(explicitFocus).isEmpty }
            if !focused.isEmpty { pool = focused }
        }

        if let lastFamily = recentFamilies.last {
            let differentFamily = pool.filter { $0.family != lastFamily }
            if !differentFamily.isEmpty {
                pool = differentFamily
            } else {
                let broaderDifferentFamily = basePool.filter { $0.family != lastFamily }
                if !broaderDifferentFamily.isEmpty { pool = broaderDifferentFamily }
            }
        }

        let scored = pool.map { exercise -> (Exercise, Double) in
            let matches = explicitFocus.isEmpty ? 1 : exercise.zones.intersection(explicitFocus).count
            let focusScore = explicitFocus.isEmpty ? Double(exercise.zones.count) * 0.35 : Double(matches) * 4.5
            let levelDistance = abs(exercise.minimumDifficulty.rawValue - preferences.difficulty.rawValue)
            let levelScore = 2.2 - Double(levelDistance) * 0.65
            let novelty = selectedIDs.contains(exercise.id) ? -9.0 : 2.0
            let familyPenalty = recentFamilies.last == exercise.family ? -5.0 :
                (recentFamilies.contains(exercise.family) ? -1.7 : 1.2)
            let fullCoreBonus = exercise.zones.contains(.fullCore) ? 0.8 : 0

            // A short session cannot afford to spend a slot on one muscle, so
            // movements that pay several at once are worth more the tighter the
            // clock. A long one has room for the specific work.
            let breadth = Double(exercise.zones.count)
            // Steer away from the area just trained. Doing this only when
            // reordering was too late: by then the session was already three
            // quarters legs.
            let areaPenalty = preferences.programme.alternatesRegions
                ? (recentAreas.last == WorkoutEngine.area(of: exercise) ? -4.5 : 0)
                    + (recentAreas.contains(WorkoutEngine.area(of: exercise)) ? -1.6 : 1.4)
                : 0

            let compoundBonus = preferences.durationMinutes <= 8
                ? breadth * 1.1
                : breadth * 0.2

            let jitter = Double.random(in: 0...1.6, using: &random)
            return (
                exercise,
                focusScore + levelScore + novelty + familyPenalty + fullCoreBonus
                    + compoundBonus + areaPenalty + jitter
            )
        }
        return scored.max { $0.1 < $1.1 }?.0 ?? pool[0]
    }

    private func reorderedForFamilyDiversity(
        _ steps: [WorkoutStep],
        programme: TrainingProgramme
    ) -> [WorkoutStep] {
        var remaining = steps.compactMap(\.exercise)
        var ordered: [Exercise] = []

        func area(_ exercise: Exercise) -> BodyRegion { WorkoutEngine.area(of: exercise) }

        while !remaining.isEmpty {
            let lastFamily = ordered.last?.family
            // Away from the same area first, then away from the same family:
            // in a full-body session that is what stops three leg movements
            // landing back to back while the arms sit idle.
            if programme.alternatesRegions, !ordered.isEmpty {
                let recentAreas = Set(ordered.suffix(2).map(area))
                let elsewhere = remaining.indices.filter { !recentAreas.contains(area(remaining[$0])) }
                    .isEmpty
                    ? remaining.indices.filter { area(remaining[$0]) != area(ordered[ordered.count - 1]) }
                    : remaining.indices.filter { !recentAreas.contains(area(remaining[$0])) }
                if !elsewhere.isEmpty {
                    let familyCounts = Dictionary(grouping: remaining, by: \.family).mapValues(\.count)
                    let pick = elsewhere.max { lhs, rhs in
                        familyCounts[remaining[lhs].family, default: 0]
                            < familyCounts[remaining[rhs].family, default: 0]
                    } ?? elsewhere[0]
                    ordered.append(remaining.remove(at: pick))
                    continue
                }
            }

            let allowedIndices = remaining.indices.filter { remaining[$0].family != lastFamily }
            let candidateIndices = allowedIndices.isEmpty ? Array(remaining.indices) : allowedIndices
            let familyCounts = Dictionary(grouping: remaining, by: \.family).mapValues(\.count)
            let selectedIndex = candidateIndices.max { lhs, rhs in
                let leftCount = familyCounts[remaining[lhs].family, default: 0]
                let rightCount = familyCounts[remaining[rhs].family, default: 0]
                if leftCount == rightCount { return lhs > rhs }
                return leftCount < rightCount
            } ?? remaining.startIndex
            ordered.append(remaining.remove(at: selectedIndex))
        }

        var iterator = ordered.makeIterator()
        return steps.map { step in
            guard step.kind == .exercise, let exercise = iterator.next() else { return step }
            return WorkoutStep(id: step.id, kind: .exercise, exercise: exercise, duration: step.duration)
        }
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

private extension Array where Element == Double {
    var average: Double? {
        isEmpty ? nil : reduce(0, +) / Double(count)
    }
}
