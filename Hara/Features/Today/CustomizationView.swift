import SwiftUI

/// The session the athlete asks for, as opposed to the one the coach proposes.
///
/// Two things here are deliberate and worth defending.
///
/// The first: there is no "Annuler" and no "Utiliser". Every control writes
/// straight through to the stored preferences, the way a settings screen does,
/// so the sheet has nothing left to commit and nothing left to throw away. The
/// pair of toolbar buttons it replaces asked a question nobody could answer —
/// whether "Utiliser" meant *save these* or *start this now* — and the athlete
/// paid for the ambiguity by losing a set of exclusions every time they swiped
/// the sheet away.
///
/// The second: the one button at the bottom starts the workout, and the workout
/// it starts is exactly what these settings say. No history, no adaptation, no
/// coach. That is the whole point of the screen: the home hero is the adapted
/// session, and this is where you go when you want the other one.
struct CustomizationView: View {
    /// Handed the finished plan. The home screen presents it once this sheet is
    /// out of the way — a full-screen cover raised in the same turn as a sheet
    /// dismissal is a coin toss.
    let onStart: (WorkoutPlan) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: WorkoutPreferences = .recommended
    @State private var showsMovementPicker = false

    /// Fixed while the sheet is open so the preview below and the session that
    /// starts are the same session. Drawing the preview from one seed and the
    /// workout from another is how an app promises eight movements and delivers
    /// eight different ones.
    @State private var seed = UInt64(Date().timeIntervalSince1970)

    /// Recomputed when the draft changes, not on every redraw.
    ///
    /// It used to be a computed property read twice per render, so every
    /// keystroke and every toggle built two complete workouts before drawing
    /// a single frame.
    @State private var preview: WorkoutPlan = WorkoutEngine().makePlan(
        preferences: .recommended,
        seed: 42
    )

    private var feasibility: SessionFeasibility {
        draft.feasibility(movementsNeeded: preview.exerciseCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metric.section) {
                    durationCard
                    intensityCard
                    focusCard
                    movementsCard
                    rhythmCard
                    constraintsCard
                    coachCard
                    previewCard
                }
                .padding(Metric.gutter)
                .padding(.bottom, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { startBar }
            .navigationTitle("Personnaliser")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showsMovementPicker) {
                ExcludedMovementsView(draft: $draft, movementsNeeded: preview.exerciseCount)
            }
            .onAppear {
                Haptics.warmUp()
                draft = appModel.preferences
                seed = UInt64(Date().timeIntervalSince1970)
                refreshPreview()
            }
            .onChange(of: draft) { _, updated in
                // Written through immediately: with no Cancel there is nothing
                // to confirm, and an exclusion made here has to survive the
                // athlete simply putting the phone down.
                if appModel.preferences != updated { appModel.preferences = updated }
                refreshPreview()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Duration

    private static let durationPresets = [5, 7, 10, 12, 15, 20]

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Temps disponible", subtitle: "La séance occupe exactement ce temps")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(draft.durationMinutes)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("min").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // The number the athlete actually feels. A seven-minute session
                // is not seven minutes of work, and hiding that made the gentler
                // levels look like they were cheating.
                Text("dont \(preview.workDuration.clockText) de travail")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(draft.durationMinutes) },
                    set: { value in
                        // Fired here rather than from `onChange` so the detents
                        // belong to the drag: the preset chips below already
                        // tick on their own, and both paths firing gave a
                        // double knock for one tap.
                        let minutes = Int(value.rounded())
                        guard minutes != draft.durationMinutes else { return }
                        Haptics.selection()
                        draft.durationMinutes = minutes
                    }
                ),
                in: 5...20,
                step: 1
            )
            .tint(Color.haraCoral)
            .accessibilityValue("\(draft.durationMinutes) minutes")

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(Self.durationPresets, id: \.self) { minutes in
                        FilterChip(title: "\(minutes) min", isSelected: draft.durationMinutes == minutes) {
                            withAnimation(reduceMotion ? nil : .snappy) {
                                draft.durationMinutes = minutes
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Intensity

    private var intensityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Intensité", subtitle: "Le rythme change autant que les mouvements")

            ForEach(WorkoutDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy) { draft.difficulty = difficulty }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(
                                draft.difficulty == difficulty
                                    ? AnyShapeStyle(LinearGradient.haraHero)
                                    : AnyShapeStyle(Color.secondary.opacity(0.12))
                            )
                            Text("\(difficulty.rawValue)")
                                .font(.subheadline.bold())
                                .foregroundStyle(draft.difficulty == difficulty ? .white : .secondary)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(difficulty.title).font(.headline)
                            Text(difficulty.detail).font(.caption).foregroundStyle(.secondary)
                            // The cadence is what actually separates the levels
                            // now, so the picker says it out loud rather than
                            // leaving the athlete to infer it from four
                            // adjectives.
                            Text(cadenceSummary(difficulty))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        if draft.difficulty == difficulty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.haraCoral)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)
                .accessibilityAddTraits(draft.difficulty == difficulty ? .isSelected : [])
                .accessibilityHint(cadenceSummary(difficulty))
            }
        }
        .padding(20)
        .glassCard()
    }

    private func cadenceSummary(_ difficulty: WorkoutDifficulty) -> String {
        let movements = difficulty.movementsPerRecovery
        let block = movements == 1 ? "1 pause après chaque mouvement" : "1 pause tous les \(movements) mouvements"
        return "\(difficulty.cadenceDescription) · \(block)"
    }

    // MARK: - Focus

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Zones prioritaires", subtitle: "Trois au maximum, le reste reste sollicité")

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 11) {
                ForEach(MuscleZone.available.filter { $0 != .lowerBack }) { zone in
                    let isSelected = draft.focusZones.contains(zone)
                    Button {
                        Haptics.selection()
                        withAnimation(reduceMotion ? nil : .snappy) { toggle(zone) }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: zone.symbol)
                            Text(zone.shortTitle).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(
                            isSelected ? AnyShapeStyle(zone.color) : AnyShapeStyle(Color.secondary.opacity(0.1)),
                            in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                        )
                    }
                    .buttonStyle(.card)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Excluded movements

    private var movementsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Mouvements", subtitle: "Écartez ceux que votre corps refuse")

            Button {
                Haptics.tap()
                showsMovementPicker = true
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "slash.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.haraCoral)
                        .frame(width: 38, height: 38)
                        .background(Color.haraCoral.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exclusionSummary)
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.numericText())
                        Text("\(draft.eligibleExercises.count) mouvements disponibles à ce niveau")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.card)

            if !draft.excludedExerciseIDs.isEmpty {
                Button("Tout réintégrer") {
                    Haptics.success()
                    withAnimation(reduceMotion ? nil : .snappy) { draft.excludedExerciseIDs = [] }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.haraCoral)
            }

            if let title = feasibility.title, let detail = feasibility.detail {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: feasibility.symbol)
                        .font(.subheadline)
                        .foregroundStyle(feasibility.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.footnote.weight(.bold))
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                        .fill(feasibility.tint.opacity(0.14))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .glassCard()
        .animation(reduceMotion ? nil : .snappy, value: draft.excludedExerciseIDs)
    }

    private var exclusionSummary: String {
        switch draft.excludedExerciseIDs.count {
        case 0: "Aucun mouvement écarté"
        case 1: "1 mouvement écarté"
        default: "\(draft.excludedExerciseIDs.count) mouvements écartés"
        }
    }

    // MARK: - Rhythm and constraints

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Rythme", subtitle: "Ce qui se passe entre deux mouvements")

            OptionRow(
                symbol: "heart.text.clipboard",
                tint: .haraMint,
                title: "Récupération renforcée",
                detail: "Une pause plus tôt et plus longue, dans les limites du niveau.",
                isOn: $draft.extraRecovery
            )
            Divider()
            OptionRow(
                symbol: "figure.stand",
                tint: .haraBlue,
                title: "Temps de mise en place",
                detail: "Cinq secondes pour changer de position, sans les prendre sur la récupération.",
                isOn: $draft.positionTransitions
            )
        }
        .padding(20)
        .glassCard()
    }

    private var constraintsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Contraintes", subtitle: "Ce que la séance doit éviter")

            OptionRow(
                symbol: "speaker.slash.fill",
                tint: .haraIndigo,
                title: "Sans sauts",
                detail: "Rien qui résonne chez le voisin du dessous.",
                isOn: $draft.apartmentFriendly
            )
            Divider()
            OptionRow(
                symbol: "figure.mind.and.body",
                tint: .purple,
                title: "Préserver la nuque",
                detail: "Écarte les mouvements où la tête porte le travail.",
                isOn: $draft.neckFriendly
            )
        }
        .padding(20)
        .glassCard()
    }

    /// Where the two paths through the app get named.
    ///
    /// Without this the athlete has no way to know that the home button and the
    /// button below do different things — and a session that quietly differs
    /// from the settings that produced it looks exactly like a bug.
    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Coach", subtitle: "Qui décide de la séance du jour")

            OptionRow(
                symbol: "wand.and.stars",
                tint: .haraCoral,
                title: "Adapter le programme du jour",
                detail: "Durée, niveau et zones ajustés selon vos dernières séances.",
                isOn: $draft.adaptiveCoaching
            )

            Label(
                "Le bouton ci-dessous lance toujours vos réglages à la lettre, adaptation ou non.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Cette séance", subtitle: preview.focusDescription)

            HStack(spacing: 0) {
                MetricPill(icon: "figure.core.training", value: "\(preview.exerciseCount)", label: "mouvements")
                Divider().frame(height: 40)
                MetricPill(icon: "timer", value: preview.workDuration.clockText, label: "de travail")
                Divider().frame(height: 40)
                MetricPill(icon: "pause.circle", value: "\(recoveryCount)", label: "récupérations")
            }

            HStack(spacing: 4) {
                ForEach(Array(preview.steps.filter { $0.kind == .exercise }.prefix(12))) { step in
                    Capsule()
                        .fill(step.exercise?.primaryZone.color ?? .secondary)
                        .frame(height: 8)
                }
            }

            Text(preview.movements.prefix(4).map(\.name).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private var recoveryCount: Int {
        preview.steps.count { $0.kind == .recovery }
    }

    // MARK: - Start

    private var startBar: some View {
        VStack(spacing: 8) {
            Text("\(preview.duration.clockText) · \(preview.exerciseCount) mouvements · sans adaptation")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Button {
                Haptics.begin()
                onStart(appModel.makeCustomWorkout(preferences: draft, seed: seed))
                dismiss()
            } label: {
                Label("C’est parti", systemImage: "play.fill")
            }
            .buttonStyle(.haraPrimary)
            .disabled(feasibility.blocksStart)
            .opacity(feasibility.blocksStart ? 0.5 : 1)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Plumbing

    private func refreshPreview() {
        preview = WorkoutEngine().makePlan(preferences: draft, seed: seed, guidance: .none)
    }

    private func toggle(_ zone: MuscleZone) {
        if zone == .fullCore {
            draft.focusZones = [.fullCore]
        } else {
            draft.focusZones.remove(.fullCore)
            if draft.focusZones.contains(zone) {
                draft.focusZones.remove(zone)
            } else if draft.focusZones.count < 3 {
                draft.focusZones.insert(zone)
            }
            if draft.focusZones.isEmpty { draft.focusZones = [.fullCore] }
        }
    }
}

/// One setting, explained.
///
/// The screen this replaced stacked five bare toggles under the word "Confort",
/// which told the athlete what each switch was called and nothing about what it
/// would do to their session.
private struct OptionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(tint)
        .onChange(of: isOn) { _, _ in Haptics.selection() }
    }
}
