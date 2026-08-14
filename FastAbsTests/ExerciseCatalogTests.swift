import Testing
@testable import FastAbs

@Suite("Exercise catalog")
struct ExerciseCatalogTests {
    @Test("The catalog has unique, stable identifiers")
    func identifiersAreUniqueAndStable() {
        let exercises = ExerciseCatalog.all
        let identifiers = exercises.map(\.id)

        #expect(exercises.count == 37)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.allSatisfy { id in
            !id.isEmpty && id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
        })
    }

    @Test("Every exercise contains the data needed by the player")
    func entriesAreComplete() {
        for exercise in ExerciseCatalog.all {
            #expect(!exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Missing name for \(exercise.id)")
            #expect(!exercise.zones.isEmpty, "Missing zone for \(exercise.id)")
            #expect(!exercise.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Missing instruction for \(exercise.id)")
            #expect(!exercise.breathing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Missing breathing cue for \(exercise.id)")
            #expect(exercise.intensity > 0, "Non-positive intensity for \(exercise.id)")
            #expect(exercise.motion != .rest, "Recovery must not be modeled as an exercise")
        }
    }

    @Test("The original SevenAbs movements remain available")
    func legacyMovementsRemainAvailable() {
        let expectedLegacyIDs: Set<String> = [
            "hip-raise", "leg-raise", "bent-knee-raise", "lower-ab-jumps",
            "scissors", "oblique-crunch", "russian-twist", "bicycle",
            "toe-reach", "classic-crunch", "shoulder-hold", "explosive-crunch"
        ]
        let actualIDs = Set(ExerciseCatalog.all.map(\.id))

        #expect(expectedLegacyIDs.isSubset(of: actualIDs))
    }

    @Test("Every focus zone has enough exercise variety")
    func zonesHaveVariety() {
        let minimumByZone: [MuscleZone: Int] = [
            .fullCore: 6,
            .upperAbs: 5,
            .lowerAbs: 8,
            .obliques: 6,
            .deepCore: 12,
            .lowerBack: 4
        ]

        for (zone, minimum) in minimumByZone {
            let count = ExerciseCatalog.all.count { $0.zones.contains(zone) }
            #expect(count >= minimum, "Only \(count) exercises cover \(zone.rawValue)")
        }
    }

    @Test("The catalog spans every movement family")
    func movementFamiliesAreCovered() {
        let expected: Set<MovementFamily> = [
            .flexion, .antiExtension, .rotation, .lateral,
            .hipFlexion, .posterior, .locomotion
        ]

        #expect(Set(ExerciseCatalog.all.map(\.family)) == expected)
    }

    @Test("Every difficulty has a viable quiet and neck-friendly selection")
    func safetySelectionsRemainViable() {
        for difficulty in WorkoutDifficulty.allCases {
            let eligible = ExerciseCatalog.all.filter {
                $0.minimumDifficulty <= difficulty &&
                $0.impact == .quiet &&
                $0.neckFriendly
            }

            #expect(eligible.count >= 6,
                    "Only \(eligible.count) safe exercises at \(difficulty.title)")
        }
    }
}
