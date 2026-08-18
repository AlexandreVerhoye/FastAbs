import Testing
@testable import Hara

@Suite("Exercise catalog")
struct ExerciseCatalogTests {
    @Test("The catalog has unique, stable identifiers")
    func identifiersAreUniqueAndStable() {
        let exercises = ExerciseCatalog.all
        let identifiers = exercises.map(\.id)

        #expect(exercises.count == 64)
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
            .lowerBack: 4,
            .glutes: 5,
            .quadriceps: 5,
            .hamstrings: 3,
            .calves: 2,
            .chest: 5,
            .shoulders: 5,
            .arms: 4,
            .upperBack: 1
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
            .hipFlexion, .posterior, .locomotion,
            .squat, .hinge, .press, .pull
        ]

        #expect(Set(ExerciseCatalog.all.map(\.family)) == expected)
    }

    @Test("Each part of the body can fill a session on its own")
    func everyAreaCanStandAlone() {
        // Someone who switches one area on and the others off has to get a real
        // session out of it, not a warning. The floor is what a twelve-minute
        // session asks for before it starts having to repeat itself.
        for area in BodyArea.allCases {
            let alone = ExerciseCatalog.all.filter { $0.areas.isSubset(of: [area]) }
            #expect(alone.count >= 6, "\(area.rawValue) alone offers \(alone.count) movements")

            let beginner = alone.filter { $0.minimumDifficulty == .beginner && $0.impact == .quiet }
            #expect(
                beginner.count >= 3,
                "\(area.rawValue) offers \(beginner.count) beginner movements"
            )
        }
    }

    @Test("Whole-body movements exist and are honest about it")
    func wholeBodyMovementsExist() {
        let compound = ExerciseCatalog.all.filter(\.isFullBody)
        #expect(compound.count >= 2, "no whole-body movement in the catalog")
        for exercise in compound {
            #expect(exercise.areas == Set(BodyArea.allCases))
            // These are the hardest things in the catalog; none of them belongs
            // at the level someone starts on.
            #expect(exercise.minimumDifficulty >= .balanced, "\(exercise.id) is offered to beginners")
        }
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
