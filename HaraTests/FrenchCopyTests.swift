import Foundation
import Testing
@testable import Hara

/// Guards the French copy the app ships.
///
/// The catalogue was first written by translating English coaching terms word
/// for word, which produced things like "centre" for *core* — a word that in
/// French means the middle of something, not the abdominal wall. These tests
/// pin the vocabulary so the same drift cannot come back.
@Suite("French copy")
struct FrenchCopyTests {
    /// Terms that read as machine translation rather than coaching French.
    static let bannedTerms = [
        "centre complet",
        "votre centre",
        "le centre",
        "du centre",
        "insecte mort",
        "chien-oiseau",
        "haut des abdos",
        "bas des abdos"
    ]

    static var allCopy: [(source: String, text: String)] {
        var copy: [(String, String)] = []

        for zone in MuscleZone.allCases {
            copy.append(("MuscleZone.\(zone.rawValue).title", zone.title))
            copy.append(("MuscleZone.\(zone.rawValue).shortTitle", zone.shortTitle))
        }
        for area in BodyArea.allCases {
            copy.append(("BodyArea.\(area.rawValue).title", area.title))
            copy.append(("BodyArea.\(area.rawValue).shortTitle", area.shortTitle))
            copy.append(("BodyArea.\(area.rawValue).detail", area.detail))
        }
        for section in CatalogSection.all {
            copy.append(("CatalogSection.\(section.id).title", section.title))
            copy.append(("CatalogSection.\(section.id).shortTitle", section.shortTitle))
            copy.append(("CatalogSection.\(section.id).detail", section.detail))
        }
        for pattern in CorePattern.allCases {
            copy.append(("CorePattern.\(pattern.rawValue).title", pattern.title))
            copy.append(("CorePattern.\(pattern.rawValue).shortTitle", pattern.shortTitle))
            copy.append(("CorePattern.\(pattern.rawValue).detail", pattern.detail))
        }
        for difficulty in WorkoutDifficulty.allCases {
            copy.append(("WorkoutDifficulty.\(difficulty.rawValue).title", difficulty.title))
            copy.append(("WorkoutDifficulty.\(difficulty.rawValue).detail", difficulty.detail))
        }
        for exercise in ExerciseCatalog.all {
            copy.append(("\(exercise.id).name", exercise.name))
            copy.append(("\(exercise.id).setup", exercise.setup))
            copy.append(("\(exercise.id).instruction", exercise.instruction))
            copy.append(("\(exercise.id).breathing", exercise.breathing))
            copy.append(("\(exercise.id).mistake", exercise.mistake))
            for (index, tip) in exercise.tips.enumerated() {
                copy.append(("\(exercise.id).tip\(index)", tip))
            }
        }
        for motion in MotionSystemTests.allMotions {
            let metadata = MotionLibrary.metadata(for: motion)
            copy.append(("\(motion.rawValue).title", metadata.title))
            copy.append(("\(motion.rawValue).description", metadata.accessibilityDescription))
        }
        for tier in DailyBadgeTier.allCases {
            copy.append(("DailyBadgeTier.\(tier).title", tier.title))
        }
        for rank in RewardRank.allCases {
            copy.append(("RewardRank.\(rank).title", rank.title))
            copy.append(("RewardRank.\(rank).detail", rank.detail))
        }
        for family in AchievementFamily.allCases {
            copy.append(("AchievementFamily.\(family.rawValue).title", family.title))
            copy.append(("AchievementFamily.\(family.rawValue).detail", family.detail))
        }
        for period in [ChallengePeriod.day, .week, .month, .year] {
            copy.append(("ChallengePeriod.\(period.rawValue).title", period.title))
        }
        // Read back off the engine rather than duplicated here, so an award
        // added without French copy fails this suite instead of shipping.
        for achievement in RewardsEngine().achievements(records: []) {
            copy.append(("Achievement.\(achievement.id).title", achievement.title))
            copy.append(("Achievement.\(achievement.id).detail", achievement.detail))
        }
        // The warnings the customisation screen shows when the athlete has
        // excluded so much that no session can be built. Written in the same
        // voice as the rest, and just as capable of drifting.
        for feasibility: SessionFeasibility in [.thin(available: 3, needed: 8), .impossible] {
            if let title = feasibility.title { copy.append(("SessionFeasibility.title", title)) }
            if let detail = feasibility.detail { copy.append(("SessionFeasibility.detail", detail)) }
        }
        return copy
    }

    @Test("No user-facing string calls the abdominal wall a 'centre'")
    func coreIsNotTranslatedAsCentre() {
        for (source, text) in Self.allCopy {
            let lowered = text.lowercased()
            for term in Self.bannedTerms {
                #expect(!lowered.contains(term), "\(source) still says “\(term)”: \(text)")
            }
        }
    }

    @Test("Muscle zone names use real anatomical vocabulary")
    func zoneNamesAreAnatomical() {
        #expect(MuscleZone.glutes.title == "Fessiers")
        #expect(MuscleZone.hamstrings.title == "Ischio-jambiers")
        #expect(MuscleZone.chest.title == "Pectoraux")
        #expect(MuscleZone.fullCore.title == "Sangle abdominale")
        #expect(MuscleZone.upperAbs.title == "Abdos supérieurs")
        #expect(MuscleZone.lowerAbs.title == "Abdos inférieurs")
        #expect(MuscleZone.obliques.title == "Obliques")
        #expect(MuscleZone.deepCore.title == "Transverse")
        #expect(MuscleZone.lowerBack.title == "Lombaires")
    }

    @Test("Zone names are distinct so a picker is never ambiguous")
    func zoneNamesAreUnique() {
        let titles = MuscleZone.allCases.map(\.title)
        let shortTitles = MuscleZone.allCases.map(\.shortTitle)

        #expect(Set(titles).count == titles.count, "duplicate zone titles: \(titles)")
        #expect(Set(shortTitles).count == shortTitles.count, "duplicate short titles: \(shortTitles)")
    }

    @Test("Short titles stay short enough for a pill")
    func shortTitlesFitTheirPills() {
        for zone in MuscleZone.allCases {
            #expect(
                zone.shortTitle.count <= 10,
                "\(zone.rawValue) short title is \(zone.shortTitle.count) characters"
            )
            #expect(zone.shortTitle.count < zone.title.count || zone.shortTitle == zone.title)
        }
    }

    @Test("Every string is present and tidy")
    func copyIsWellFormed() {
        for (source, text) in Self.allCopy {
            #expect(!text.isEmpty, "\(source) is empty")
            #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines), "\(source) has stray whitespace")
            #expect(!text.contains("  "), "\(source) has a double space")
            #expect(text.first?.isUppercase == true, "\(source) does not start with a capital: \(text)")
        }
    }

    @Test("French copy uses typographic apostrophes")
    func apostrophesAreTypographic() {
        // A straight quote in the middle of a French word is the classic sign of
        // copy pasted from a plain-text source.
        for (source, text) in Self.allCopy {
            #expect(!text.contains("'"), "\(source) uses a straight apostrophe: \(text)")
        }
    }

    @Test("Every exercise explains itself fully")
    func everyExerciseIsBriefed() {
        // The recovery screen reads all four of these out before the movement
        // starts, so a thin one leaves a gap in the coaching.
        for exercise in ExerciseCatalog.all {
            #expect(exercise.setup.count > 30, "\(exercise.id) has no real starting position")
            #expect(exercise.mistake.count > 20, "\(exercise.id) names no common mistake")
            #expect(exercise.setup != exercise.instruction, "\(exercise.id) repeats itself")
            #expect(
                exercise.mistake.first?.isUppercase == true,
                "\(exercise.id) mistake does not start with a capital"
            )
        }
    }

    @Test("Coaching sentences are punctuated")
    func sentencesAreComplete() {
        for exercise in ExerciseCatalog.all {
            #expect(exercise.setup.hasSuffix("."), "\(exercise.id) setup is unpunctuated")
            #expect(exercise.mistake.hasSuffix("."), "\(exercise.id) mistake is unpunctuated")
            #expect(
                exercise.instruction.hasSuffix("."),
                "\(exercise.id) instruction is unpunctuated: \(exercise.instruction)"
            )
            #expect(
                exercise.breathing.hasSuffix("."),
                "\(exercise.id) breathing cue is unpunctuated: \(exercise.breathing)"
            )
            #expect(
                exercise.instruction.count > 25,
                "\(exercise.id) instruction is too terse to coach with"
            )
        }
    }

    @Test("Exercise names are unique and readable")
    func exerciseNamesAreDistinct() {
        let names = ExerciseCatalog.all.map(\.name)
        #expect(Set(names).count == names.count, "duplicate exercise names")

        for name in names {
            #expect(name.count <= 26, "“\(name)” is too long for a single line")
            #expect(!name.hasSuffix("."), "“\(name)” is a title, not a sentence")
        }
    }

    @Test("Exercise identifiers stay stable and machine-readable")
    func identifiersAreSlugs() {
        // These end up in stored workout records, so they must not drift with
        // the display copy.
        let identifiers = ExerciseCatalog.all.map(\.id)
        #expect(Set(identifiers).count == identifiers.count, "duplicate exercise ids")

        for id in identifiers {
            #expect(
                id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" },
                "\(id) is not a lowercase slug"
            )
        }
    }

    @Test("Every motion title is French, not a raw case name")
    func motionTitlesAreTranslated() {
        for motion in MotionSystemTests.allMotions {
            let title = MotionLibrary.metadata(for: motion).title
            #expect(title != motion.rawValue, "\(motion.rawValue) is showing its identifier")
            #expect(title.first?.isUppercase == true)
        }
    }

    @Test("Accessibility descriptions describe the movement")
    func accessibilityCopyIsUseful() {
        for motion in MotionSystemTests.allMotions {
            let description = MotionLibrary.metadata(for: motion).accessibilityDescription
            #expect(description.count > 40, "\(motion.rawValue) description is too thin")
            #expect(description.hasSuffix("."), "\(motion.rawValue) description is unpunctuated")
        }
    }

    @Test("No user-facing copy still carries the old app name")
    func appNameIsConsistent() {
        // The app is Hara; strings naming the old one would surface in
        // notifications, badges and the safety notice.
        for (source, text) in Self.allCopy {
            #expect(!text.contains("FastAbs"), "\(source) still says FastAbs")
        }
    }

    @Test("Challenge units read correctly in French")
    func challengeUnitsAreFormatted() {
        #expect(ChallengeUnit.activeDays.formatted(3) == "3 j")
        #expect(ChallengeUnit.activeMinutes.formatted(45) == "45 min")
        #expect(ChallengeUnit.sessions.formatted(2) == "2 séances")
        #expect(ChallengeUnit.corePatterns.formatted(0) == "0 type", "zéro prend le singulier")
        #expect(ChallengeUnit.corePatterns.formatted(1) == "1 type")
        #expect(ChallengeUnit.corePatterns.formatted(3) == "3 types")
        #expect(ChallengeUnit.muscleZones.formatted(1) == "1 zone")
        #expect(ChallengeUnit.muscleZones.formatted(6) == "6 zones")
        #expect(ChallengeUnit.times.formatted(1) == "1 fois", "« fois » est invariable")
        #expect(ChallengeUnit.times.formatted(4) == "4 fois")
    }

    @Test("Rank names are distinct and fit the hero card")
    func rankNamesAreDistinct() {
        let titles = RewardRank.allCases.map(\.title)
        #expect(Set(titles).count == titles.count, "duplicate rank names: \(titles)")

        for title in titles {
            #expect(title.count <= 12, "“\(title)” is too long for the rank line")
            #expect(!title.hasSuffix("."), "“\(title)” is a name, not a sentence")
        }
        for rank in RewardRank.allCases {
            #expect(rank.detail.hasSuffix("."), "\(rank) detail is unpunctuated")
        }
    }

    @Test("Award names are distinct and fit a tile")
    func achievementNamesAreDistinct() {
        let shelf = RewardsEngine().achievements(records: [])
        let titles = shelf.map(\.title)
        #expect(Set(titles).count == titles.count, "duplicate award names")

        for achievement in shelf {
            // Two lines of caption text under a 58-point disc.
            #expect(achievement.title.count <= 26, "“\(achievement.title)” is too long for a tile")
            #expect(!achievement.title.hasSuffix("."), "“\(achievement.title)” is a name, not a sentence")
            #expect(achievement.detail.hasSuffix("."), "\(achievement.id) detail is unpunctuated")
            #expect(achievement.detail.count > 20, "\(achievement.id) does not say what it takes")
        }
    }

    @Test("A streak always has something to say about itself")
    func streakCopyIsAlwaysWritten() {
        let states = [
            StreakStatus.idle,
            StreakStatus(current: 1, longest: 4, restDaysUsed: 0, restDaysEarned: 0, isSecuredToday: true),
            StreakStatus(current: 9, longest: 12, restDaysUsed: 1, restDaysEarned: 1, isSecuredToday: false),
            StreakStatus(current: 400, longest: 400, restDaysUsed: 0, restDaysEarned: 2, isSecuredToday: true)
        ]

        for status in states {
            for text in [status.headline, status.detail, status.protectionDescription] {
                #expect(!text.isEmpty)
                // A streak line often opens on its own figure, which is the one
                // place a lowercase-looking first character is correct.
                #expect(
                    text.first?.isUppercase == true || text.first?.isNumber == true,
                    "“\(text)” starts with neither a capital nor a figure"
                )
                #expect(!text.contains("'"), "“\(text)” uses a straight apostrophe")
                #expect(!text.contains("  "), "“\(text)” has a double space")
            }
        }
        // French takes the singular for one, and the plural from two.
        #expect(states[1].headline == "1 jour d’affilée")
        #expect(states[2].headline == "9 jours d’affilée")
    }

    @Test("A focus description never falls back to a placeholder")
    func focusDescriptionAlwaysReads() {
        for zones in [
            Set<MuscleZone>([.fullCore]),
            [.upperAbs],
            [.obliques, .lowerAbs],
            [.fullCore, .deepCore]
        ] {
            let plan = WorkoutEngine().makePlan(
                preferences: TestSupport.preferences(focusZones: zones),
                seed: 7
            )
            #expect(!plan.focusDescription.isEmpty)
            #expect(!plan.focusDescription.lowercased().contains("centre"))
        }
    }
}
