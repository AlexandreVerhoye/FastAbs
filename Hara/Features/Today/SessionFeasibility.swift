import SwiftUI

/// Whether the athlete's own settings still leave a session to build.
///
/// The engine filters the catalog by level, impact, neck safety and the
/// exclusion list, then falls back to a single generic hold when nothing
/// survives. That fallback is a safety net, not a session — so the screen where
/// movements get banished has to see the cliff before someone walks off it,
/// which means reproducing the filter here rather than discovering the result
/// once the workout has already started.
enum SessionFeasibility: Equatable {
    /// More movements available than the session needs.
    case comfortable
    /// A session can still be built, but it will have to repeat itself.
    case thin(available: Int, needed: Int)
    /// Nothing survives the filters at all.
    case impossible

    var blocksStart: Bool { self == .impossible }

    var title: String? {
        switch self {
        case .comfortable: nil
        case .thin: "La séance va tourner en rond"
        case .impossible: "Aucun mouvement ne passe vos réglages"
        }
    }

    var detail: String? {
        switch self {
        case .comfortable:
            nil
        case let .thin(available, needed):
            "Il reste \(available) mouvements pour en programmer \(needed) : certains reviendront deux fois. Réintégrez-en quelques-uns."
        case .impossible:
            "Vos exclusions et vos contraintes ne laissent rien à programmer. Réintégrez des mouvements ou levez une contrainte."
        }
    }

    var symbol: String {
        self == .impossible ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    var tint: Color {
        self == .impossible ? .haraCoral : .haraOrange
    }
}

extension WorkoutPreferences {
    /// The movements the engine would actually have to choose from. Kept in
    /// step with `WorkoutEngine.eligibleExercises` by hand: the engine's copy is
    /// private, and duplicating four predicates is cheaper than opening the
    /// engine up so a picker can ask it a question.
    var eligibleExercises: [Exercise] {
        ExerciseCatalog.all.filter { exercise in
            exercise.areas.isSubset(of: trainedAreas) &&
            exercise.minimumDifficulty <= difficulty &&
            (!apartmentFriendly || exercise.impact == .quiet) &&
            (!neckFriendly || exercise.neckFriendly) &&
            !excludedExerciseIDs.contains(exercise.id)
        }
    }

    /// `movementsNeeded` is what a plan built from these settings actually asks
    /// for, so the warning is measured against this session rather than against
    /// a round number that would be wrong at both ends of the duration slider.
    func feasibility(movementsNeeded: Int) -> SessionFeasibility {
        let available = eligibleExercises.count
        if available == 0 { return .impossible }
        guard available < movementsNeeded else { return .comfortable }
        return .thin(available: available, needed: movementsNeeded)
    }
}
