import SwiftUI

/// Setting the app up, as three questions rather than three claims.
///
/// What this replaced was a carousel: three pages of copy about how good the
/// app was, a page control, and a button that led to a screen the athlete had
/// told nothing to. Everything it asked for later — what you train, for how
/// long, how hard — it guessed, and the athlete found out by disagreeing with a
/// session. Now the app asks, and the last screen shows the session those
/// answers built.
///
/// The shape is the one iOS uses for setting something up: one decision per
/// screen, a large title, a progress bar counting only the questions, a back
/// chevron, and a single action pinned at the bottom.
struct OnboardingView: View {
    /// The session a set of answers would produce today.
    ///
    /// Asked for rather than built here, so the session on the last screen is
    /// the one the home screen will show a second later — same seed, same
    /// coach, same engine. Building it locally drew a different one, and the
    /// two disagreed about how many movements the athlete had just agreed to.
    let preview: (WorkoutPreferences) -> WorkoutPlan
    /// Handed the settings the athlete described.
    let completion: (WorkoutPreferences) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = OnboardingFlow()

    var body: some View {
        ZStack {
            LinearGradient.haraNight.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // One screen at a time, sliding in from the side it came from.
                ZStack {
                    switch flow.step {
                    case .intro: intro
                    case .areas: areaQuestion
                    case .duration: durationQuestion
                    case .difficulty: difficultyQuestion
                    case .ready: summary
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(slide)
                .id(flow.step)
            }
            .safeAreaInset(edge: .bottom) { actions }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .animation(Motion.honouring(reduceMotion, Motion.content), value: flow.step)
    }

    private var slide: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = flow.isMovingForward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: Metric.row) {
            Button {
                Haptics.tap()
                flow.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.card)
            .opacity(flow.isFirst ? 0 : 1)
            .disabled(flow.isFirst)
            .accessibilityLabel("Revenir en arrière")

            Spacer(minLength: 0)

            if let index = flow.step.questionIndex {
                HStack(spacing: 5) {
                    ForEach(0..<OnboardingFlow.questionCount, id: \.self) { position in
                        Capsule()
                            .fill(.white.opacity(position <= index ? 0.95 : 0.22))
                            .frame(width: position == index ? 22 : 8, height: 5)
                    }
                }
                .accessibilityLabel("Étape \(index + 1) sur \(OnboardingFlow.questionCount)")
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button("Passer") {
                Haptics.tap()
                completion(flow.preferences)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .opacity(flow.isLast ? 0 : 1)
            .disabled(flow.isLast)
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 8)
        .frame(height: 44)
        .animation(Motion.honouring(reduceMotion, Motion.tap), value: flow.step)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if flow.step == .areas, !flow.canAdvance {
                Label("Choisissez au moins une zone.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .transition(.opacity)
            }

            Button {
                if flow.isLast {
                    Haptics.begin()
                    completion(flow.preferences)
                } else {
                    Haptics.tap()
                    flow.advance()
                }
            } label: {
                Text(actionTitle)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.haraPrimary(tint: Color.white, foreground: .haraNavy))
            .disabled(!flow.canAdvance)
            .opacity(flow.canAdvance ? 1 : 0.45)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 10)
        .animation(Motion.honouring(reduceMotion, Motion.tap), value: flow.canAdvance)
    }

    private var actionTitle: String {
        switch flow.step {
        case .intro: "Commencer"
        case .ready: "C’est parti"
        default: "Continuer"
        }
    }

    // MARK: - Screens

    private var intro: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(LinearGradient.haraHero)
                    .frame(width: 168, height: 168)
                    .shadow(color: Color.haraCoral.opacity(0.45), radius: 42)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 68, weight: .semibold))
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
            }

            VStack(spacing: 12) {
                Text("Bienvenue dans Hara")
                    .font(.haraHeroTitle)
                    .multilineTextAlignment(.center)
                Text("Une séance courte, différente chaque jour, sans rien d’autre qu’un tapis.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Label("Trois questions, et votre programme est prêt.", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(.white.opacity(0.12), in: Capsule())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
    }

    private var areaQuestion: some View {
        question(
            title: "Que voulez-vous travailler ?",
            subtitle: "Plusieurs réponses possibles. Modifiable à tout moment dans les réglages."
        ) {
            VStack(spacing: Metric.row) {
                ForEach(BodyArea.allCases) { area in
                    ChoiceRow(
                        symbol: area.symbol,
                        tint: area.color,
                        title: area.title,
                        detail: area.detail,
                        footnote: "\(flow.movementCount(for: area)) mouvements",
                        isSelected: flow.areas.contains(area)
                    ) {
                        Haptics.selection()
                        flow.toggle(area)
                    }
                }
            }
        }
    }

    private var durationQuestion: some View {
        question(
            title: "Combien de temps ?",
            subtitle: "La séance occupera exactement ce temps, échauffement et récupérations comprises."
        ) {
            VStack(spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(flow.draft.durationMinutes)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("min")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Metric.row), count: 3),
                    spacing: Metric.row
                ) {
                    ForEach(OnboardingFlow.durations, id: \.self) { minutes in
                        DurationTile(
                            minutes: minutes,
                            isSelected: flow.draft.durationMinutes == minutes
                        ) {
                            Haptics.selection()
                            flow.select(minutes: minutes)
                        }
                    }
                }
            }
        }
    }

    private var difficultyQuestion: some View {
        question(
            title: "À quel rythme ?",
            subtitle: "Le niveau change les mouvements, la longueur des intervalles et la fréquence des pauses."
        ) {
            VStack(spacing: Metric.row) {
                ForEach(WorkoutDifficulty.allCases) { difficulty in
                    ChoiceRow(
                        badge: "\(difficulty.rawValue)",
                        tint: .haraCoral,
                        title: difficulty.title,
                        detail: difficulty.detail,
                        footnote: cadence(of: difficulty),
                        isSelected: flow.draft.difficulty == difficulty
                    ) {
                        Haptics.selection()
                        flow.select(difficulty: difficulty)
                    }
                }
            }
        }
    }

    private func cadence(of difficulty: WorkoutDifficulty) -> String {
        let block = difficulty.movementsPerRecovery == 1
            ? "1 pause après chaque mouvement"
            : "1 pause tous les \(difficulty.movementsPerRecovery) mouvements"
        return "\(difficulty.cadenceDescription) · \(block)"
    }

    private var summary: some View {
        let plan = preview(flow.preferences)

        return question(
            title: "Votre première séance",
            subtitle: "Construite à partir de vos réponses. Le coach l’ajustera ensuite selon vos séances."
        ) {
            VStack(spacing: Metric.row) {
                VStack(spacing: 16) {
                    Text(plan.focusDescription)
                        .font(.haraCardTitle)

                    HStack(spacing: 0) {
                        SummaryStat(value: plan.duration.clockText, label: "au total")
                        Divider().frame(height: 34).overlay(.white.opacity(0.18))
                        SummaryStat(value: "\(plan.exerciseCount)", label: "mouvements")
                        Divider().frame(height: 34).overlay(.white.opacity(0.18))
                        SummaryStat(value: plan.workDuration.clockText, label: "de travail")
                    }

                    HStack(spacing: 4) {
                        ForEach(plan.steps.filter { $0.kind == .exercise }.prefix(12)) { step in
                            Capsule()
                                .fill(step.exercise?.accent ?? .white)
                                .frame(height: 7)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(plan.movements.prefix(4).enumerated()), id: \.offset) { index, movement in
                        HStack(spacing: Metric.row) {
                            Image(systemName: CatalogSection.of(movement).symbol)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(movement.accent)
                                .frame(width: 30, height: 30)
                                .background(movement.accent.opacity(0.18), in: Circle())
                            Text(movement.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            Text(movement.zones.map(\.shortTitle).sorted().joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .padding(.vertical, 9)
                        if index < min(4, plan.movements.count) - 1 {
                            Divider().overlay(.white.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous))
            }
        }
    }

    /// The shared shape of a question: title, one line of context, and the
    /// answer below, scrollable so that Dynamic Type has somewhere to go.
    private func question(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.haraHeroTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
            .padding(.bottom, Metric.section)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Parts

/// One answer on a list of them.
///
/// Shared by the areas and the levels so the two questions read as the same
/// kind of question — which they are — rather than as two screens designed a
/// week apart.
private struct ChoiceRow: View {
    var symbol: String?
    var badge: String?
    let tint: Color
    let title: String
    let detail: String
    let footnote: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.14)))
                        .frame(width: 42, height: 42)
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.headline)
                    } else if let badge {
                        Text(badge).font(.headline.weight(.bold))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(footnote)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.07))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.9) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.card)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(footnote)
    }
}

private struct DurationTile: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("min")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.haraHero) : AnyShapeStyle(Color.white.opacity(0.08)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                    .stroke(.white.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.card)
        .accessibilityLabel("\(minutes) minutes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
