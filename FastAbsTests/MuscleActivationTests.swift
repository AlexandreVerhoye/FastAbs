import Foundation
import Testing
@testable import FastAbs

@Suite("Muscle activation")
struct MuscleActivationTests {
    static let allMotions = MotionSystemTests.allMotions
    static let phases: [Float] = (0..<64).map { Float($0) / 64 }

    @Test("Every intensity stays within 0 and 1")
    func intensitiesAreBounded() {
        for motion in Self.allMotions {
            for phase in Self.phases {
                let activation = MuscleActivation.make(for: motion, phase: phase)
                #expect(activation.isValid, "\(motion.rawValue) at phase \(phase): \(activation)")
            }
        }
    }

    @Test("Invalid phases cannot produce invalid intensities")
    func degeneratePhasesStaySafe() {
        for phase in [Float.nan, .infinity, -.infinity, -12, 900] {
            let activation = MuscleActivation.make(for: .crunch, phase: phase)
            #expect(activation.isValid, "phase \(phase) produced \(activation)")
        }
    }

    @Test("Each movement peaks on the muscle it is named for")
    func movementsHighlightTheirOwnMuscle() {
        // The intensity ramp is the whole point of the visual: if a leg raise
        // lit the upper abs, it would be teaching the wrong thing.
        let expectations: [(MotionKind, KeyPath<MuscleActivation, Float>)] = [
            (.crunch, \.upperAbs),
            (.toeReach, \.upperAbs),
            (.legRaise, \.lowerAbs),
            (.reverseCrunch, \.lowerAbs),
            (.hipRaise, \.lowerAbs),
            (.flutter, \.lowerAbs),
            (.plank, \.deepCore),
            (.hollowHold, \.deepCore),
            (.bearHold, \.deepCore),
            (.superman, \.lowerBack),
            (.birdDog, \.lowerBack)
        ]

        for (motion, dominant) in expectations {
            let peak = Self.phases
                .map { MuscleActivation.make(for: motion, phase: $0) }
                .max { $0[keyPath: dominant] < $1[keyPath: dominant] }

            guard let peak else {
                Issue.record("\(motion.rawValue) produced no activation")
                continue
            }
            let value = peak[keyPath: dominant]
            #expect(value > 0.85, "\(motion.rawValue) only reaches \(value) on its target muscle")
        }
    }

    @Test("Rotational movements load the obliques hardest")
    func rotationLoadsTheObliques() {
        for motion in [MotionKind.bicycle, .twist, .obliqueCrunch, .heelTap, .sidePlank] {
            let peak = Self.phases
                .map { MuscleActivation.make(for: motion, phase: $0) }
                .map { max($0.leftOblique, $0.rightOblique) }
                .max() ?? 0
            #expect(peak > 0.85, "\(motion.rawValue) only reaches \(peak) on the obliques")
        }
    }

    @Test("Alternating movements light one oblique at a time")
    func obliquesTakeTurns() {
        for motion in [MotionKind.bicycle, .twist, .obliqueCrunch, .heelTap] {
            let samples = Self.phases.map { MuscleActivation.make(for: motion, phase: $0) }
            let leftLeads = samples.contains { $0.leftOblique > $0.rightOblique + 0.15 }
            let rightLeads = samples.contains { $0.rightOblique > $0.leftOblique + 0.15 }

            #expect(leftLeads && rightLeads, "\(motion.rawValue) never swaps working side")
        }
    }

    @Test("Symmetric movements load both obliques equally")
    func symmetricMovementsStayBalanced() {
        for motion in [MotionKind.crunch, .legRaise, .plank, .hollowHold, .bridge] {
            for phase in Self.phases {
                let activation = MuscleActivation.make(for: motion, phase: phase)
                #expect(
                    abs(activation.leftOblique - activation.rightOblique) < 0.001,
                    "\(motion.rawValue) at phase \(phase) is lopsided"
                )
            }
        }
    }

    @Test("Isometric holds never relax to nothing")
    func holdsKeepTension() {
        // A plank that flickers dark between frames would read as the muscle
        // switching off, which is the opposite of what a hold trains.
        for motion in [MotionKind.plank, .hollowHold, .bearHold, .sidePlank] {
            let lowest = Self.phases
                .map { MuscleActivation.make(for: motion, phase: $0).overall }
                .min() ?? 0
            #expect(lowest > 0.55, "\(motion.rawValue) drops to \(lowest)")
        }
    }

    @Test("Repetition-based movements do relax between reps")
    func repetitionsBreathe() {
        for motion in [MotionKind.crunch, .legRaise, .reverseCrunch, .bridge] {
            let samples = Self.phases.map { MuscleActivation.make(for: motion, phase: $0).overall }
            #expect((samples.min() ?? 1) < 0.4, "\(motion.rawValue) never releases")
            #expect((samples.max() ?? 0) > 0.85, "\(motion.rawValue) never fully contracts")
        }
    }

    @Test("Intensity rises and falls across a repetition")
    func intensityFollowsTheRepetition() {
        let tempo = MotionLibrary.tempo(for: .crunch)
        let relaxed = MuscleActivation.make(for: .crunch, phase: 0)
        let contracted = MuscleActivation.make(for: .crunch, phase: tempo.peakPhase)

        #expect(contracted.upperAbs > relaxed.upperAbs + 0.5)
    }

    @Test("The catalog focus emphasises the coached muscle")
    func focusDimsUnrelatedGroups() {
        let tempo = MotionLibrary.tempo(for: .crunch)
        let unfocused = MuscleActivation.make(for: .crunch, phase: tempo.peakPhase)
        let focused = MuscleActivation.make(for: .crunch, phase: tempo.peakPhase, focus: [.upperAbs])

        #expect(focused.upperAbs == unfocused.upperAbs, "the focused group must not be dimmed")
        #expect(focused.lowerAbs < unfocused.lowerAbs, "unrelated groups should recede")
        #expect(focused.lowerAbs > 0, "assisting groups still show some tension")
    }

    @Test("A full-core focus dims nothing")
    func fullCoreFocusKeepsEverything() {
        let tempo = MotionLibrary.tempo(for: .bicycle)
        let plain = MuscleActivation.make(for: .bicycle, phase: tempo.peakPhase)
        let full = MuscleActivation.make(for: .bicycle, phase: tempo.peakPhase, focus: [.fullCore])

        #expect(full.upperAbs == plain.upperAbs)
        #expect(full.lowerAbs == plain.lowerAbs)
        #expect(full.deepCore == plain.deepCore)
    }

    @Test("Every catalog exercise lights up the zones it claims")
    func catalogZonesAreRepresented() {
        for exercise in ExerciseCatalog.all {
            let peak = Self.phases
                .map { MuscleActivation.make(for: exercise.motion, phase: $0, focus: exercise.zones) }
                .map(\.overall)
                .max() ?? 0
            #expect(peak > 0.7, "\(exercise.id) barely activates anything (\(peak))")

            for zone in exercise.zones where zone != .fullCore {
                let zonePeak = Self.phases
                    .map { MuscleActivation.make(for: exercise.motion, phase: $0, focus: exercise.zones)[zone] }
                    .max() ?? 0
                #expect(zonePeak > 0.2, "\(exercise.id) claims \(zone.rawValue) but shows \(zonePeak)")
            }
        }
    }

    @Test("Recovery keeps the body calm")
    func restIsQuiet() {
        for phase in Self.phases {
            let activation = MuscleActivation.make(for: .rest, phase: phase)
            #expect(activation.overall < 0.2, "recovery should not look like effort")
        }
    }

    @Test("Subscript access agrees with the stored values")
    func zoneSubscriptIsConsistent() {
        let activation = MuscleActivation(
            upperAbs: 0.8, lowerAbs: 0.4, leftOblique: 0.6,
            rightOblique: 0.2, deepCore: 0.5, lowerBack: 0.1
        )

        #expect(activation[.upperAbs] == 0.8)
        #expect(activation[.lowerAbs] == 0.4)
        #expect(activation[.obliques] == 0.6)
        #expect(activation[.deepCore] == 0.5)
        #expect(activation[.lowerBack] == 0.1)
        #expect(activation[.fullCore] == 0.8)
        #expect(activation.overall == 0.8)
    }

    @Test("Idle activation is completely relaxed")
    func idleIsZero() {
        #expect(MuscleActivation.idle.overall == 0)
        #expect(MuscleActivation.idle.isValid)
    }
}
