import Foundation
import SwiftData
import SwiftUI

/// A part of the body the athlete has decided to train, or not to.
///
/// The coarse axis, and deliberately coarse: three switches someone can hold in
/// their head, not fourteen. `MuscleZone` stays the fine one — it says which
/// tissue a movement loads, which is the right grain for a statistic and much
/// too fine for a decision. Every zone belongs to exactly one area, so the two
/// can never disagree about what a movement trains.
enum BodyArea: String, CaseIterable, Codable, Identifiable, Sendable {
    case core, upperBody, lowerBody

    var id: String { rawValue }

    var title: String {
        switch self {
        case .core: "Abdos et gainage"
        case .upperBody: "Haut du corps"
        case .lowerBody: "Bas du corps"
        }
    }

    var shortTitle: String {
        switch self {
        case .core: "Abdos"
        case .upperBody: "Haut"
        case .lowerBody: "Bas"
        }
    }

    var detail: String {
        switch self {
        case .core: "Sangle abdominale, obliques, lombaires."
        case .upperBody: "Pectoraux, épaules, bras, haut du dos."
        case .lowerBody: "Fessiers, cuisses, ischios, mollets."
        }
    }

    var symbol: String {
        switch self {
        case .core: "figure.core.training"
        case .upperBody: "figure.arms.open"
        case .lowerBody: "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .core: .haraCoral
        case .upperBody: .haraBlue
        case .lowerBody: .haraMint
        }
    }

    /// The fine-grained groups that live in this area.
    var zones: Set<MuscleZone> {
        Set(MuscleZone.allCases.filter { $0.area == self })
    }

    /// The groups a complete session in this area owes the athlete. Narrower
    /// than `zones`: `fullCore` is a summary of the others rather than a group
    /// of its own, and no session is expected to hunt down the calves.
    var essentialZones: Set<MuscleZone> {
        switch self {
        case .core: [.upperAbs, .lowerAbs, .obliques, .deepCore]
        case .upperBody: [.chest, .shoulders, .upperBack]
        case .lowerBody: [.glutes, .quadriceps, .hamstrings]
        }
    }

    /// What the athlete may never end up with none of. Training nothing is not
    /// a training preference, it is a broken screen.
    static let fallback: Set<BodyArea> = [.core]

    /// Areas kept in a stable, human order wherever a set has to be shown.
    static func ordered(_ areas: Set<BodyArea>) -> [BodyArea] {
        allCases.filter(areas.contains)
    }

    static func describe(_ areas: Set<BodyArea>) -> String {
        let ordered = ordered(areas)
        if ordered.count == allCases.count { return "Corps entier" }
        return ordered.map(\.shortTitle).joined(separator: " · ")
    }
}

enum MuscleZone: String, CaseIterable, Codable, Identifiable, Sendable {
    // Core first, then the rest of the body. The order is read directly by
    // `Exercise.primaryZone`, so a movement that spans two areas takes its
    // identity from the more specific end of this list rather than from set
    // iteration order, which changes between launches.
    case fullCore, upperAbs, lowerAbs, obliques, deepCore, lowerBack
    case glutes, quadriceps, hamstrings, calves
    case chest, shoulders, arms, upperBack

    var id: String { rawValue }

    /// Zones the catalog can currently build a workout from. The picker reads
    /// this, so it grows on its own as movements are added rather than offering
    /// a focus with no exercises behind it.
    /// Worked out once: it scans the whole catalog per zone, and the picker
    /// asked for it on every redraw.
    static let available: [MuscleZone] = allCases.filter { zone in
        ExerciseCatalog.all.contains { $0.zones.contains(zone) }
    }

    var title: String {
        switch self {
        case .fullCore: "Sangle abdominale"
        case .upperAbs: "Abdos supérieurs"
        case .lowerAbs: "Abdos inférieurs"
        case .obliques: "Obliques"
        case .deepCore: "Transverse"
        case .lowerBack: "Lombaires"
        case .glutes: "Fessiers"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Ischio-jambiers"
        case .calves: "Mollets"
        case .chest: "Pectoraux"
        case .shoulders: "Épaules"
        case .arms: "Bras"
        case .upperBack: "Haut du dos"
        }
    }

    /// The area this group belongs to. One area per group, always: the athlete's
    /// switches and the movement's own anatomy have to be the same fact.
    var area: BodyArea {
        switch self {
        case .fullCore, .upperAbs, .lowerAbs, .obliques, .deepCore, .lowerBack: .core
        case .glutes, .quadriceps, .hamstrings, .calves: .lowerBody
        case .chest, .shoulders, .arms, .upperBack: .upperBody
        }
    }

    var shortTitle: String {
        switch self {
        case .fullCore: "Complet"
        case .upperAbs: "Haut"
        case .lowerAbs: "Bas"
        case .obliques: "Obliques"
        case .deepCore: "Profond"
        case .lowerBack: "Lombaires"
        case .glutes: "Fessiers"
        case .quadriceps: "Cuisses"
        case .hamstrings: "Ischios"
        case .calves: "Mollets"
        case .chest: "Pectoraux"
        case .shoulders: "Épaules"
        case .arms: "Bras"
        case .upperBack: "Dos"
        }
    }

    var symbol: String {
        switch self {
        case .fullCore: "figure.core.training"
        case .upperAbs: "arrow.up.to.line.compact"
        case .lowerAbs: "arrow.down.to.line.compact"
        case .obliques: "arrow.left.and.right"
        case .deepCore: "circle.hexagongrid.fill"
        case .lowerBack: "figure.strengthtraining.traditional"
        case .glutes: "figure.stair.stepper"
        case .quadriceps: "figure.walk"
        case .hamstrings: "figure.run"
        case .calves: "shoeprints.fill"
        case .chest: "figure.arms.open"
        case .shoulders: "figure.boxing"
        case .arms: "dumbbell.fill"
        case .upperBack: "figure.strengthtraining.functional"
        }
    }

    var color: Color {
        switch self {
        case .fullCore: .haraCoral
        case .upperAbs: .haraOrange
        case .lowerAbs: .haraBlue
        case .obliques: .purple
        case .deepCore: .haraMint
        case .lowerBack: .cyan
        case .glutes: .pink
        case .quadriceps: .green
        case .hamstrings: .teal
        case .calves: .brown
        case .chest: .haraBlue
        case .shoulders: .indigo
        case .arms: .yellow
        case .upperBack: .mint
        }
    }
}

/// What a movement asks the trunk to do.
///
/// Core work only, and named so on purpose. A squat is not an anti-rotation
/// exercise, it is not a weak one either — it simply does not answer this
/// question, so it answers `nil` instead of being filed under whichever case
/// fits worst. Coverage of these patterns is what a *core* session is measured
/// on; a session that also trains the legs is measured on its areas as well.
///
/// Muscle zones say which tissue is loaded; this says what job it is doing, and
/// the two are not the same question. A session made only of crunches covers
/// every abdominal zone on paper while training exactly one skill. Coverage is
/// measured on patterns for that reason.
enum CorePattern: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Resisting the spine being pulled into an arch — planks, hollow holds,
    /// anything where the load tries to drop the hips.
    case antiExtension
    /// Resisting the trunk being twisted while a limb moves.
    case antiRotation
    /// Resisting the trunk being bent sideways.
    case antiLateralFlexion
    /// Actively shortening the abdominal wall — crunches, leg raises, twists.
    case dynamicFlexion
    /// Driving the hips open against the mat.
    case hipExtension

    var id: String { rawValue }

    var title: String {
        switch self {
        case .antiExtension: "Anti-extension"
        case .antiRotation: "Anti-rotation"
        case .antiLateralFlexion: "Anti-inclinaison"
        case .dynamicFlexion: "Flexion dynamique"
        case .hipExtension: "Extension de hanche"
        }
    }

    var shortTitle: String {
        switch self {
        case .antiExtension: "Gainage"
        case .antiRotation: "Stabilité"
        case .antiLateralFlexion: "Latéral"
        case .dynamicFlexion: "Flexion"
        case .hipExtension: "Extension"
        }
    }

    var detail: String {
        switch self {
        case .antiExtension: "Empêcher le bas du dos de se creuser."
        case .antiRotation: "Empêcher le buste de tourner pendant qu’un membre bouge."
        case .antiLateralFlexion: "Empêcher le buste de pencher sur le côté."
        case .dynamicFlexion: "Raccourcir la sangle contre une résistance."
        case .hipExtension: "Ouvrir la hanche en poussant le bassin."
        }
    }

    var symbol: String {
        switch self {
        case .antiExtension: "figure.core.training"
        case .antiRotation: "arrow.triangle.2.circlepath"
        case .antiLateralFlexion: "arrow.left.and.right"
        case .dynamicFlexion: "arrow.down.to.line.compact"
        case .hipExtension: "arrow.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .antiExtension: .haraMint
        case .antiRotation: .purple
        case .antiLateralFlexion: .haraBlue
        case .dynamicFlexion: .haraCoral
        case .hipExtension: .cyan
        }
    }
}

/// How a movement treats the two sides of the body.
///
/// A boolean cannot say this: "involves sides" and "needs splitting in two" are
/// different facts, and conflating them is why the side plank trained one side
/// for as long as it did.
enum SideMode: String, Codable, Sendable {
    /// No sides — a plank, a crunch.
    case bilateral
    /// Both sides trained inside a single interval, taking turns — a bicycle
    /// crunch, a dead bug. Splitting these would change what they are.
    case alternating
    /// One side held for a whole interval. The only kind that has to be
    /// performed twice to train the athlete symmetrically.
    case heldPerSide
}

enum BodySide: String, Codable, Hashable, Sendable {
    case left, right

    var title: String {
        switch self {
        case .left: "Gauche"
        case .right: "Droite"
        }
    }
}

enum WorkoutDifficulty: Int, CaseIterable, Codable, Identifiable, Comparable, Sendable {
    case beginner = 1, balanced, advanced, athlete

    var id: Int { rawValue }

    static func < (lhs: WorkoutDifficulty, rhs: WorkoutDifficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .beginner: "Débutant"
        case .balanced: "Équilibré"
        case .advanced: "Intense"
        case .athlete: "Athlète"
        }
    }

    var detail: String {
        switch self {
        case .beginner: "Contrôle et récupération"
        case .balanced: "Rythme quotidien idéal"
        case .advanced: "Enchaînements exigeants"
        case .athlete: "Puissance et gainage long"
        }
    }

    /// How long one working interval runs at this level.
    ///
    /// Every real interval protocol is quoted as a work/rest pair — 30/30 for a
    /// beginner circuit, 40/20 for general conditioning, 45/15 for hard work,
    /// Tabata's 20/10 at the top. So the session is built from that pair rather
    /// than from a budget that rests are carved out of afterwards. The previous
    /// model derived rest length from whatever seconds were left over, which is
    /// how a session labelled "Intense" ended up handing out five recoveries of
    /// up to thirty-one seconds: nothing in it had the authority to say that a
    /// hard session simply does not rest for that long.
    var work: ClosedRange<Int> {
        switch self {
        case .beginner: 25...35
        case .balanced: 32...42
        case .advanced: 38...48
        case .athlete: 45...55
        }
    }

    /// How long a single recovery runs at this level.
    ///
    /// A promise, not a target: the upper bound is what the athlete is
    /// guaranteed never to exceed. Standing still for forty-five seconds in a
    /// session you asked to be intense is the loudest way an interval app can
    /// say it was not listening.
    var recovery: ClosedRange<Int> {
        switch self {
        case .beginner: 28...40
        case .balanced: 18...26
        case .advanced: 15...20
        case .athlete: 12...18
        }
    }

    /// How many movements run back to back before a recovery is earned.
    ///
    /// This is what actually separates the levels. At the bottom every movement
    /// is followed by a rest; at the top you work through four of them and get
    /// one short break. Between movements inside a block there is only the few
    /// seconds it takes to change position — which is a doorway, not a rest.
    var movementsPerRecovery: Int {
        switch self {
        case .beginner: 1
        case .balanced: 2
        case .advanced: 3
        case .athlete: 4
        }
    }

    /// The nominal pair this level is quoted as, for the athlete to read.
    var cadenceDescription: String {
        let work = (work.lowerBound + work.upperBound) / 2
        let rest = (recovery.lowerBound + recovery.upperBound) / 2
        return "\(work) s / \(rest) s"
    }
}

/// The shape of a movement, used to keep neighbours from feeling alike.
///
/// Deliberately kept alongside `CorePattern` rather than replaced by it: this
/// is a taxonomy of shape and drives adjacency, the other is a taxonomy of
/// stimulus and drives coverage. Six of these seven families split across
/// several patterns, so neither can stand in for the other.
enum MovementFamily: String, Codable, Sendable {
    case flexion, antiExtension, rotation, lateral, hipFlexion, posterior, locomotion
    // Off the mat. Added rather than folded into the seven above: a squat and a
    // glute bridge are both hip extension and they are not remotely the same
    // shape, and adjacency is decided on shape.
    case squat, hinge, press, pull
}

enum MotionKind: String, CaseIterable, Codable, Sendable {
    case crunch, reverseCrunch, toeReach, legRaise, hipRaise, flutter, scissors
    case bicycle, twist, obliqueCrunch, heelTap
    case plank, sidePlank, plankReach, mountainClimber, hollowHold
    case deadBug, birdDog, bearHold, vSit, vSitExtension, seatedTuck, longLeverCrunch
    case superman, bridge, bridgeMarch
    case sidePlankKnees, sideCrunch, hollowRock, vUp
    case singleLegBridge, swimmer, heelSlide, reversePlank
    // Off the mat: the lower body, the pressing patterns, and the compound
    // movements that visit several stances inside one repetition.
    case squat, squatHold, lunge, lateralLunge, wallSit, calfRaise, goodMorning, donkeyKick
    case pushUp, kneePushUp, wallPushUp, pikePushUp, floorDip, proneRow
    case plankUpDown, squatThrust, burpee, jumpingJack
    case rest
}

enum ExerciseImpact: String, Codable, Sendable {
    case quiet, dynamic
}

struct Exercise: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let zones: Set<MuscleZone>
    let family: MovementFamily
    /// What the trunk is being asked to do — the axis core coverage is measured
    /// on. Nil for movements that do not train the trunk as their job: a calf
    /// raise has no honest answer here, and inventing one would let a session
    /// claim core coverage it never earned.
    let pattern: CorePattern?
    let minimumDifficulty: WorkoutDifficulty
    let impact: ExerciseImpact
    let motion: MotionKind
    /// How to get into position before the first repetition.
    let setup: String
    let instruction: String
    let breathing: String
    /// The mistake this movement invites, so it can be named before it happens.
    let mistake: String
    /// Short cues shown one at a time while the movement is running.
    let tips: [String]
    let sideMode: SideMode
    let neckFriendly: Bool
    let intensity: Double
}

extension Exercise {
    /// The parts of the body this movement trains, derived from its zones
    /// rather than authored separately — two lists of the same fact drift.
    var areas: Set<BodyArea> { Set(zones.map(\.area)) }

    /// The area that stands for the movement, on the same "specific before
    /// general" principle as `primaryZone`.
    var primaryArea: BodyArea { primaryZone.area }

    /// True when the movement spans the whole body rather than one part of it.
    var isFullBody: Bool { areas.count >= BodyArea.allCases.count }

    /// The colour that stands for this movement on screen.
    ///
    /// Trunk work is coloured by the job it asks of the trunk; everything else
    /// by the part of the body it trains. Each movement is coloured by the
    /// finest fact it actually has, rather than by a case chosen to fill a
    /// non-optional field.
    var accent: Color { pattern?.color ?? primaryArea.color }

    /// The group that stands for this movement wherever one icon has to speak
    /// for it.
    ///
    /// `zones` is a `Set`, and Swift seeds set hashing per process — so
    /// `zones.first` handed back a different group between two launches of the
    /// same build, and a movement could quietly wear another one's icon.
    /// Ordered here so a movement always looks like itself, and specific before
    /// general, since "sangle abdominale" says the least of the six.
    var primaryZone: MuscleZone {
        MuscleZone.allCases.first { $0 != .fullCore && zones.contains($0) }
            ?? .fullCore
    }
}

struct WorkoutPreferences: Codable, Hashable, Sendable {
    var durationMinutes: Int
    var difficulty: WorkoutDifficulty
    /// The parts of the body the athlete trains at all. Guaranteed non-empty:
    /// see `reconcile()`.
    var trainedAreas: Set<BodyArea>
    /// The groups to lean on inside those areas, or `[.fullCore]` for "no
    /// priority, spread it".
    var focusZones: Set<MuscleZone>
    var apartmentFriendly: Bool
    var neckFriendly: Bool
    var extraRecovery: Bool
    /// Five seconds between movements to change position.
    var positionTransitions: Bool
    /// Whether the day's session may adapt itself to what the history shows.
    /// Off, the settings below are followed to the letter.
    var adaptiveCoaching: Bool
    /// Movements the athlete never wants to see again. Survives relaunches, so
    /// banishing an exercise is a decision made once rather than every session.
    var excludedExerciseIDs: Set<String>

    init(
        durationMinutes: Int,
        difficulty: WorkoutDifficulty,
        focusZones: Set<MuscleZone>,
        apartmentFriendly: Bool,
        neckFriendly: Bool,
        extraRecovery: Bool,
        trainedAreas: Set<BodyArea> = BodyArea.fallback,
        positionTransitions: Bool = true,
        adaptiveCoaching: Bool = true,
        excludedExerciseIDs: Set<String> = []
    ) {
        self.durationMinutes = durationMinutes
        self.difficulty = difficulty
        self.trainedAreas = trainedAreas.isEmpty ? BodyArea.fallback : trainedAreas
        self.focusZones = focusZones
        self.apartmentFriendly = apartmentFriendly
        self.neckFriendly = neckFriendly
        self.extraRecovery = extraRecovery
        self.positionTransitions = positionTransitions
        self.adaptiveCoaching = adaptiveCoaching
        self.excludedExerciseIDs = excludedExerciseIDs
    }

    /// Decoded by hand rather than by the compiler.
    ///
    /// These are read back from `UserDefaults`, and the app falls back to the
    /// recommended defaults whenever decoding throws — so a preference added
    /// after someone installed the app, or a muscle zone removed from it, would
    /// silently wipe every setting they had chosen. Missing keys take their
    /// default and unknown zones are dropped instead.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        difficulty = try container.decodeIfPresent(WorkoutDifficulty.self, forKey: .difficulty) ?? .balanced
        let areaNames = try container.decodeIfPresent([String].self, forKey: .trainedAreas) ?? []
        let areas = Set(areaNames.compactMap(BodyArea.init(rawValue:)))
        // Anyone who installed the app before it could train anything else was
        // training the core, so that is what a missing key means.
        trainedAreas = areas.isEmpty ? BodyArea.fallback : areas
        let zoneNames = try container.decodeIfPresent([String].self, forKey: .focusZones) ?? []
        let zones = Set(zoneNames.compactMap(MuscleZone.init(rawValue:)))
        focusZones = zones.isEmpty ? [.fullCore] : zones
        apartmentFriendly = try container.decodeIfPresent(Bool.self, forKey: .apartmentFriendly) ?? true
        neckFriendly = try container.decodeIfPresent(Bool.self, forKey: .neckFriendly) ?? false
        extraRecovery = try container.decodeIfPresent(Bool.self, forKey: .extraRecovery) ?? false
        positionTransitions = try container.decodeIfPresent(Bool.self, forKey: .positionTransitions) ?? true
        adaptiveCoaching = try container.decodeIfPresent(Bool.self, forKey: .adaptiveCoaching) ?? true
        // Filtered against the catalog on the way in: an exercise removed from
        // a later build must not keep a slot reserved in someone's exclusions.
        let excluded = try container.decodeIfPresent([String].self, forKey: .excludedExerciseIDs) ?? []
        excludedExerciseIDs = Set(excluded.filter { ExerciseCatalog.byID[$0] != nil })
        // A focus stored while an area was on has to be dropped if the area
        // came off in the meantime, or the engine would chase a zone it is no
        // longer allowed to programme.
        reconcile()
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(trainedAreas.map(\.rawValue).sorted(), forKey: .trainedAreas)
        try container.encode(focusZones.map(\.rawValue).sorted(), forKey: .focusZones)
        try container.encode(apartmentFriendly, forKey: .apartmentFriendly)
        try container.encode(neckFriendly, forKey: .neckFriendly)
        try container.encode(extraRecovery, forKey: .extraRecovery)
        try container.encode(positionTransitions, forKey: .positionTransitions)
        try container.encode(adaptiveCoaching, forKey: .adaptiveCoaching)
        try container.encode(excludedExerciseIDs.sorted(), forKey: .excludedExerciseIDs)
    }

    private enum CodingKeys: String, CodingKey {
        case durationMinutes, difficulty, trainedAreas, focusZones
        case apartmentFriendly, neckFriendly, extraRecovery, positionTransitions
        case adaptiveCoaching, excludedExerciseIDs
    }

    /// Brings the rest of the settings back in line with the areas that are on.
    ///
    /// Turning an area off is a small instruction and must not become a large
    /// one. Duration, level, rhythm, constraints and every exclusion survive
    /// untouched; so does every focus zone that is still reachable. Only what
    /// has become unreachable is dropped, and only if that leaves nothing at
    /// all does the neutral focus step in. Rebuilding the whole preference set
    /// from defaults would be the easy fix and the wrong one — it would throw
    /// away a dozen decisions to answer one.
    mutating func reconcile() {
        if trainedAreas.isEmpty { trainedAreas = BodyArea.fallback }
        let reachable = trainedAreas.reduce(into: Set<MuscleZone>()) { $0.formUnion($1.zones) }
        let kept = focusZones.intersection(reachable)
        // `.fullCore` is the neutral marker rather than a priority, so it is
        // never what makes a focus worth keeping.
        focusZones = kept.subtracting([.fullCore]).isEmpty ? [.fullCore] : kept
    }

    func reconciled() -> WorkoutPreferences {
        var copy = self
        copy.reconcile()
        return copy
    }

    /// Whether the athlete named a priority, as opposed to leaving it neutral.
    var explicitFocus: Set<MuscleZone> { focusZones.subtracting([.fullCore]) }

    static let recommended = WorkoutPreferences(
        durationMinutes: 7,
        difficulty: .balanced,
        focusZones: [.fullCore],
        apartmentFriendly: true,
        neckFriendly: false,
        extraRecovery: false,
        trainedAreas: BodyArea.fallback
    )
}

enum WorkoutStepKind: String, Codable, Sendable {
    case exercise, recovery
    /// Five seconds to change position. Not recovery: it is spent moving, it
    /// takes no seconds from the recovery budget, and it never lands before the
    /// first movement or after the last.
    case transition
}

struct WorkoutStep: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let kind: WorkoutStepKind
    let exercise: Exercise?
    /// Set only on the two halves of a movement held per side.
    let side: BodySide?
    let duration: Int

    init(
        id: UUID = UUID(),
        kind: WorkoutStepKind,
        exercise: Exercise?,
        side: BodySide? = nil,
        duration: Int
    ) {
        self.id = id
        self.kind = kind
        self.exercise = exercise
        self.side = side
        self.duration = duration
    }

    var title: String {
        guard let exercise else {
            return kind == .transition ? "En place" : "Récupération"
        }
        guard let side else { return exercise.name }
        return "\(exercise.name) · \(side.title)"
    }

    var motion: MotionKind { exercise?.motion ?? .rest }

    /// The right-side half of a held movement is the same choreography seen
    /// from the other side.
    var isMirrored: Bool { side == .right }
}

struct WorkoutPlan: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let preferences: WorkoutPreferences
    let steps: [WorkoutStep]
    let estimatedCalories: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        preferences: WorkoutPreferences,
        steps: [WorkoutStep],
        estimatedCalories: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.preferences = preferences
        self.steps = steps
        self.estimatedCalories = estimatedCalories
    }

    var duration: Int { steps.reduce(0) { $0 + $1.duration } }

    /// The seconds the plan actually asks the athlete to work, recoveries and
    /// position changes excluded.
    ///
    /// This is what a finished session has to be measured against. Comparing
    /// seconds worked against the wall-clock length of the plan compares two
    /// different quantities: a seven-minute beginner session only ever holds
    /// about three minutes of work, so that ratio could never clear a
    /// completion threshold — every finished session was recorded and then
    /// silently discarded by every screen that read the history back.
    var workDuration: Int {
        steps.reduce(0) { $0 + ($1.kind == .exercise ? $1.duration : 0) }
    }

    /// The exercises as an athlete counts them: a movement held per side is one
    /// movement done twice, not two movements. Everything user-facing — the
    /// count, the preview, the uniqueness rules — reads this rather than the
    /// raw steps.
    var movements: [Exercise] {
        var result: [Exercise] = []
        for step in steps {
            guard let exercise = step.exercise else { continue }
            if step.side == .right, result.last?.id == exercise.id { continue }
            result.append(exercise)
        }
        return result
    }

    var exerciseCount: Int { movements.count }

    /// What the movements in the plan actually train.
    var areas: Set<BodyArea> {
        movements.reduce(into: Set<BodyArea>()) { $0.formUnion($1.areas) }
    }

    /// Named after the priority when there is one, and after the parts of the
    /// body being trained when there is not. Reading "Sangle abdominale" back
    /// from a leg session was the old version's way of saying it only knew
    /// about one kind of session.
    var focusDescription: String {
        let zones = preferences.explicitFocus
        guard zones.isEmpty else {
            return zones.map(\.shortTitle).sorted().joined(separator: " · ")
        }
        return BodyArea.describe(preferences.trainedAreas)
    }
}

/// How the session felt, asked once at the end.
enum PerceivedEffort: Int, CaseIterable, Codable, Sendable {
    case unrated = 0, easy, right, hard

    var title: String {
        switch self {
        case .unrated: "Non noté"
        case .easy: "Facile"
        case .right: "Parfait"
        case .hard: "Difficile"
        }
    }

    var symbol: String {
        switch self {
        case .unrated: "questionmark"
        case .easy: "wind"
        case .right: "checkmark"
        case .hard: "flame.fill"
        }
    }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var plannedDuration: Int
    var activeDuration: Int
    /// The work the plan asked for, which is what `activeDuration` is compared
    /// against. Zero on records written before this was tracked.
    var plannedActiveDuration: Int = 0
    var difficultyRaw: Int
    var exerciseIDs: [String]
    var focusZoneRaws: [String]
    var estimatedCalories: Int
    /// What the athlete said about the session afterwards. Was collected and
    /// thrown away before.
    var perceivedEffortRaw: Int = PerceivedEffort.unrated.rawValue
    /// False when the session was ended early. Kept rather than dropping the
    /// record: an abandoned session that still passed the qualifying threshold
    /// is real training, and losing it made streaks lie.
    var wasCompleted: Bool = true

    init(
        plan: WorkoutPlan,
        completedAt: Date = .now,
        activeDuration: Int? = nil,
        wasCompleted: Bool = true
    ) {
        id = UUID()
        self.completedAt = completedAt
        plannedDuration = plan.duration
        plannedActiveDuration = plan.workDuration
        self.activeDuration = activeDuration ?? plan.workDuration
        difficultyRaw = plan.preferences.difficulty.rawValue
        exerciseIDs = plan.movements.map(\.id)
        focusZoneRaws = plan.preferences.focusZones.map(\.rawValue)
        estimatedCalories = plan.estimatedCalories
        self.wasCompleted = wasCompleted
    }

    var difficulty: WorkoutDifficulty {
        WorkoutDifficulty(rawValue: difficultyRaw) ?? .balanced
    }

    var perceivedEffort: PerceivedEffort {
        PerceivedEffort(rawValue: perceivedEffortRaw) ?? .unrated
    }

    /// The muscle groups actually trained, read back from the exercises rather
    /// than from the focus that was asked for — what you did, not what you
    /// intended.
    var trainedZones: Set<MuscleZone> {
        exerciseIDs.reduce(into: Set<MuscleZone>()) { zones, id in
            if let exercise = ExerciseCatalog.byID[id] { zones.formUnion(exercise.zones) }
        }
    }

    /// The jobs the trunk was asked to do. What a balanced week of core work is
    /// measured on. Movements with no trunk job of their own contribute nothing
    /// here rather than contributing noise.
    var trainedPatterns: Set<CorePattern> {
        exerciseIDs.reduce(into: Set<CorePattern>()) { patterns, id in
            if let pattern = ExerciseCatalog.byID[id]?.pattern { patterns.insert(pattern) }
        }
    }

    /// The parts of the body the session touched, read back from the movements.
    var trainedAreas: Set<BodyArea> {
        exerciseIDs.reduce(into: Set<BodyArea>()) { areas, id in
            if let exercise = ExerciseCatalog.byID[id] { areas.formUnion(exercise.areas) }
        }
    }
}
