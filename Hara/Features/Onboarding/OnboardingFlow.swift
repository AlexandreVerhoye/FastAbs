import Foundation

/// The three questions the app asks before it programmes anything, and the
/// answers as they are being given.
///
/// Kept out of the view on purpose: these are decisions — what the athlete
/// trains, for how long, and how hard — and they decide every session the app
/// will ever build. Testing them through a SwiftUI hierarchy would be testing
/// the hierarchy.
struct OnboardingFlow: Equatable {
    /// Five screens, of which three are questions. The other two are the door
    /// in and the door out.
    enum Step: Int, CaseIterable, Comparable {
        case intro, areas, duration, difficulty, ready

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Position among the questions, for the progress indicator. Nil for
        /// the two screens that ask nothing: a bar that counted them would tell
        /// the athlete they have three steps left when they have one.
        var questionIndex: Int? {
            switch self {
            case .areas: 0
            case .duration: 1
            case .difficulty: 2
            case .intro, .ready: nil
            }
        }
    }

    static let questionCount = 3
    static let durations = [5, 7, 10, 12, 15, 20]

    private(set) var step: Step = .intro
    /// Which way the last move went, so a screen can slide in from the side it
    /// came from. Without it every step slides the same way and going back
    /// feels like going on.
    private(set) var isMovingForward = true

    /// The answers so far, starting from the recommended session — so skipping
    /// the flow and finishing it land on the same defensible programme rather
    /// than on nothing.
    private(set) var draft: WorkoutPreferences = .recommended

    /// The chosen areas, held apart from the draft.
    ///
    /// `WorkoutPreferences` guarantees a non-empty set, and a screen in the
    /// middle of being edited cannot: the athlete has to be able to clear the
    /// last one and be told why they cannot continue, rather than watch the app
    /// silently put it back and wonder what it did.
    private(set) var areas: Set<BodyArea> = BodyArea.fallback

    var isFirst: Bool { step == .intro }
    var isLast: Bool { step == .ready }

    /// Whether the current screen has an answer worth carrying forward.
    var canAdvance: Bool {
        switch step {
        case .areas: !areas.isEmpty
        default: true
        }
    }

    /// What the flow has produced, ready to be stored.
    var preferences: WorkoutPreferences {
        var result = draft
        result.trainedAreas = areas.isEmpty ? BodyArea.fallback : areas
        result.reconcile()
        return result
    }

    // MARK: - Moving

    mutating func advance() {
        guard canAdvance, let next = Step(rawValue: step.rawValue + 1) else { return }
        isMovingForward = true
        step = next
    }

    mutating func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        isMovingForward = false
        step = previous
    }

    // MARK: - Answering

    mutating func toggle(_ area: BodyArea) {
        if areas.contains(area) {
            areas.remove(area)
        } else {
            areas.insert(area)
        }
    }

    mutating func select(minutes: Int) {
        draft.durationMinutes = minutes
    }

    mutating func select(difficulty: WorkoutDifficulty) {
        draft.difficulty = difficulty
    }

    /// How many movements the catalog can offer for the current answers, which
    /// is what the area screen counts.
    func movementCount(for area: BodyArea) -> Int {
        ExerciseCatalog.all.count { $0.areas.contains(area) }
    }
}
