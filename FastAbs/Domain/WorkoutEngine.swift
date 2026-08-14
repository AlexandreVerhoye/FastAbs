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
            steps = reorderedForFamilyDiversity(steps)
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

    private func eligibleExercises(for preferences: WorkoutPreferences) -> [Exercise] {
        catalog.filter { exercise in
            exercise.minimumDifficulty <= preferences.difficulty &&
            (!preferences.apartmentFriendly || exercise.impact == .quiet) &&
            (!preferences.neckFriendly || exercise.neckFriendly)
        }
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
        coveredZones: Set<MuscleZone>,
        focusMatches: Int,
        random: inout R
    ) -> Exercise {
        let explicitFocus = preferences.focusZones.subtracting([.fullCore])
        let unselected = candidates.filter { !selectedIDs.contains($0.id) }
        let basePool = unselected.isEmpty ? candidates : unselected
        var pool = basePool

        if explicitFocus.isEmpty {
            let required: Set<MuscleZone> = [.upperAbs, .lowerAbs, .obliques, .deepCore]
            let missing = required.subtracting(coveredZones)
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
            let jitter = Double.random(in: 0...1.6, using: &random)
            return (exercise, focusScore + levelScore + novelty + familyPenalty + fullCoreBonus + jitter)
        }
        return scored.max { $0.1 < $1.1 }?.0 ?? pool[0]
    }

    private func reorderedForFamilyDiversity(_ steps: [WorkoutStep]) -> [WorkoutStep] {
        var remaining = steps.compactMap(\.exercise)
        var ordered: [Exercise] = []

        while !remaining.isEmpty {
            let lastFamily = ordered.last?.family
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
