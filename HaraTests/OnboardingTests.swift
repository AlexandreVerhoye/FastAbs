import Foundation
import Testing
@testable import Hara

/// The setup flow, as decisions rather than as screens.
///
/// What it replaced asked nothing and guessed everything, so the only way to
/// find out the app had picked twelve minutes at "Équilibré" for you was to
/// disagree with a session. These tests hold the three answers, the rule that
/// something must be trained, and the one promise the last screen makes: that
/// the session it shows is the session that starts.
@Suite("Onboarding")
struct OnboardingTests {
    @Test("It opens on the door in, with the recommended programme behind it")
    func startsFromTheRecommendedProgramme() {
        let flow = OnboardingFlow()

        #expect(flow.step == .intro)
        #expect(flow.isFirst)
        #expect(!flow.isLast)
        // Skipping from the very first screen has to leave the app configured,
        // not empty: this is what "Passer" hands back.
        #expect(flow.preferences == WorkoutPreferences.recommended)
    }

    @Test("Each screen leads to the next, and back to the last")
    func stepsMoveBothWays() {
        var flow = OnboardingFlow()

        for expected in [OnboardingFlow.Step.areas, .duration, .difficulty, .ready] {
            flow.advance()
            #expect(flow.step == expected)
            #expect(flow.isMovingForward)
        }

        // And no further: the last screen is the last screen.
        flow.advance()
        #expect(flow.step == .ready)
        #expect(flow.isLast)

        flow.back()
        #expect(flow.step == .difficulty)
        #expect(!flow.isMovingForward)

        while !flow.isFirst { flow.back() }
        #expect(flow.step == .intro)
        flow.back()
        #expect(flow.step == .intro)
    }

    @Test("The progress bar counts the questions, not the screens")
    func progressCountsQuestionsOnly() {
        #expect(OnboardingFlow.Step.intro.questionIndex == nil)
        #expect(OnboardingFlow.Step.ready.questionIndex == nil)
        #expect(OnboardingFlow.Step.areas.questionIndex == 0)
        #expect(OnboardingFlow.Step.duration.questionIndex == 1)
        #expect(OnboardingFlow.Step.difficulty.questionIndex == 2)

        let counted = OnboardingFlow.Step.allCases.compactMap(\.questionIndex)
        #expect(counted.count == OnboardingFlow.questionCount)
    }

    @Test("You cannot leave the first question with nothing chosen")
    func areasMustNotBeEmpty() {
        var flow = OnboardingFlow()
        flow.advance()
        #expect(flow.step == .areas)
        #expect(flow.canAdvance)

        // Clearing the last one is allowed — the screen says why you cannot
        // continue rather than silently putting it back.
        flow.toggle(.core)
        #expect(flow.areas.isEmpty)
        #expect(!flow.canAdvance)
        flow.advance()
        #expect(flow.step == .areas, "an empty answer walked to the next question")

        // And an empty answer still cannot produce empty settings.
        #expect(flow.preferences.trainedAreas == BodyArea.fallback)

        flow.toggle(.lowerBody)
        #expect(flow.canAdvance)
        flow.advance()
        #expect(flow.step == .duration)
    }

    @Test("Every answer reaches the settings")
    func answersAreCarried() {
        var flow = OnboardingFlow()
        flow.toggle(.upperBody)
        flow.toggle(.lowerBody)
        flow.select(minutes: 15)
        flow.select(difficulty: .advanced)

        let preferences = flow.preferences
        #expect(preferences.trainedAreas == [.core, .upperBody, .lowerBody])
        #expect(preferences.durationMinutes == 15)
        #expect(preferences.difficulty == .advanced)
        // Untouched by the flow, and therefore untouched at all.
        #expect(preferences.apartmentFriendly == WorkoutPreferences.recommended.apartmentFriendly)
        #expect(preferences.adaptiveCoaching == WorkoutPreferences.recommended.adaptiveCoaching)
    }

    @Test("Only the offered durations are offered, and the default is one of them")
    func durationsAreCoherent() {
        #expect(OnboardingFlow.durations.contains(WorkoutPreferences.recommended.durationMinutes))
        for minutes in OnboardingFlow.durations {
            #expect(CoachAdvisor.durationBounds.contains(minutes), "\(minutes) min is outside what the coach may prescribe")
        }
    }

    @Test("Whatever is answered, the settings are buildable")
    func everyAnswerProducesASession() {
        let combinations: [Set<BodyArea>] = [
            [.core], [.upperBody], [.lowerBody],
            [.core, .upperBody], [.core, .lowerBody], [.upperBody, .lowerBody],
            [.core, .upperBody, .lowerBody]
        ]

        for areas in combinations {
            for minutes in OnboardingFlow.durations {
                for difficulty in WorkoutDifficulty.allCases {
                    var flow = OnboardingFlow()
                    for area in BodyArea.allCases where !areas.contains(area) == flow.areas.contains(area) {
                        flow.toggle(area)
                    }
                    flow.select(minutes: minutes)
                    flow.select(difficulty: difficulty)

                    #expect(flow.areas == areas)
                    let plan = WorkoutEngine().makePlan(preferences: flow.preferences, seed: 11)
                    #expect(plan.duration == minutes * 60)
                    #expect(plan.areas == areas, "\(areas) at \(minutes) min trained \(plan.areas)")
                }
            }
        }
    }

    @MainActor
    @Test("The session on the last screen is the session that starts")
    func theSummaryIsTheRealSession() {
        // The whole point of ending on a preview: if the home screen then draws
        // a different session, the setup flow has told the athlete something
        // that was not true a second later.
        let model = AppModel(defaults: UserDefaults(suiteName: "hara-tests-onboarding") ?? .standard)
        var flow = OnboardingFlow()
        flow.toggle(.lowerBody)
        flow.select(minutes: 10)

        let shown = model.previewTodayWorkout(for: flow.preferences)

        model.preferences = flow.preferences
        let started = model.makeTodayWorkout()

        #expect(TestSupport.signature(of: shown) == TestSupport.signature(of: started))
    }
}
