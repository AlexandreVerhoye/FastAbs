import Foundation
import Testing
@testable import Hara

/// Whether the athlete's own settings still leave a session to build.
///
/// The customisation screen lets movements be banished permanently, which means
/// it is now possible to ask for a session the catalog cannot supply. The engine
/// answers that with a single generic hold — a safety net, not a session — so
/// the warning has to arrive before the workout does.
@Suite("Session feasibility")
struct SessionFeasibilityTests {
    @Test("The warning counts the same pool the engine draws from")
    func eligibilityMatchesTheEngine() {
        // `eligibleExercises` duplicates four predicates that live privately
        // inside the engine. This is the test that keeps the copy honest: every
        // movement the engine actually programmes must be one the screen said
        // was available.
        var excluded = TestSupport.preferences()
        excluded.excludedExerciseIDs = ["forearm-plank", "classic-crunch", "side-plank"]

        for preferences in [
            TestSupport.preferences(),
            TestSupport.preferences(difficulty: .beginner, neckFriendly: true),
            TestSupport.preferences(difficulty: .athlete, apartmentFriendly: false),
            excluded
        ] {
            let eligible = Set(preferences.eligibleExercises.map(\.id))
            #expect(!eligible.isEmpty)

            for seed in TestSupport.seeds {
                let plan = WorkoutEngine().makePlan(preferences: preferences, seed: seed)
                for movement in plan.movements {
                    #expect(
                        eligible.contains(movement.id),
                        "\(movement.id) was programmed but counted as unavailable"
                    )
                }
            }
        }
    }

    @Test("A banished movement never comes back")
    func exclusionsAreHonoured() {
        var preferences = TestSupport.preferences(durationMinutes: 20)
        preferences.excludedExerciseIDs = Set(ExerciseCatalog.all.prefix(6).map(\.id))

        for seed in TestSupport.seeds {
            let plan = WorkoutEngine().makePlan(preferences: preferences, seed: seed)
            for movement in plan.movements {
                #expect(!preferences.excludedExerciseIDs.contains(movement.id))
            }
        }
    }

    @Test("Excluding the whole catalog is caught, not discovered mid-session")
    func anEmptyPoolIsImpossible() {
        var preferences = TestSupport.preferences()
        preferences.excludedExerciseIDs = Set(ExerciseCatalog.all.map(\.id))

        let verdict = preferences.feasibility(movementsNeeded: 8)
        #expect(verdict == .impossible)
        #expect(verdict.blocksStart)
        #expect(verdict.detail != nil)
    }

    @Test("A pool too thin for the session says so with both numbers")
    func aThinPoolReportsWhatIsMissing() {
        var preferences = TestSupport.preferences()
        let keep = Set(ExerciseCatalog.all.prefix(3).map(\.id))
        preferences.excludedExerciseIDs = Set(
            ExerciseCatalog.all.map(\.id).filter { !keep.contains($0) }
        )

        let available = preferences.eligibleExercises.count
        let verdict = preferences.feasibility(movementsNeeded: available + 4)

        #expect(verdict == .thin(available: available, needed: available + 4))
        #expect(!verdict.blocksStart, "a repetitive session is still a session")
        #expect(verdict.detail?.contains("\(available)") == true)
    }

    @Test("A pool wider than the session says nothing at all")
    func aHealthyPoolIsSilent() {
        let verdict = TestSupport.preferences().feasibility(movementsNeeded: 8)

        #expect(verdict == .comfortable)
        #expect(verdict.title == nil)
        #expect(verdict.detail == nil)
    }
}
