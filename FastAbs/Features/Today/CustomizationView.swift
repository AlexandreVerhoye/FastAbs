import SwiftUI

struct CustomizationView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let onApply: (WorkoutPreferences) -> Void
    @State private var draft: WorkoutPreferences = .recommended

    /// Recomputed when the draft changes, not on every redraw.
    ///
    /// It used to be a computed property read twice per render, so every
    /// keystroke and every toggle built two complete workouts before drawing
    /// a single frame.
    @State private var preview: WorkoutPlan = WorkoutEngine().makePlan(
        preferences: .recommended,
        seed: 42
    )

    private func refreshPreview() {
        preview = WorkoutEngine().makePlan(preferences: draft, seed: 42)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    programmeCard
                    durationCard
                    difficultyCard
                    focusCard
                    comfortCard
                    previewCard
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Personnaliser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Utiliser") {
                        onApply(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onApply(draft)
                    dismiss()
                } label: {
                    Text("Utiliser ce programme · \(preview.duration.clockText)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(LinearGradient.fastHero, in: Capsule())
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .onAppear {
                draft = appModel.preferences
                refreshPreview()
            }
            .onChange(of: draft) { _, _ in refreshPreview() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var programmeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Programme", subtitle: "Ce que la séance travaille")
            ForEach(TrainingProgramme.allCases) { programme in
                Button {
                    withAnimation(.snappy) {
                        draft.programme = programme
                        if programme != .core { draft.focusZones = [.fullCore] }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(
                                draft.programme == programme
                                    ? Color.fastCoral
                                    : Color.secondary.opacity(0.12)
                            )
                            Image(systemName: programme.symbol)
                                .font(.subheadline)
                                .foregroundStyle(draft.programme == programme ? .white : .secondary)
                        }
                        .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(programme.title).font(.headline)
                            Text(programme.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if draft.programme == programme {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.fastCoral)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(draft.programme == programme ? .isSelected : [])
            }
        }
        .padding(20)
        .glassCard()
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "Temps disponible", subtitle: "Le programme occupe exactement ce temps")
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(draft.durationMinutes)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("min").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            Slider(value: Binding(
                get: { Double(draft.durationMinutes) },
                set: { draft.durationMinutes = Int($0.rounded()) }
            ), in: 5...20, step: 1)
            HStack {
                Text("Express")
                Spacer()
                Text("Complet")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .glassCard()
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Difficulté", subtitle: "Les mouvements changent réellement avec le niveau")
            ForEach(WorkoutDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    withAnimation(.snappy) { draft.difficulty = difficulty }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(draft.difficulty == difficulty ? Color.fastCoral : Color.secondary.opacity(0.12))
                            Text("\(difficulty.rawValue)").font(.subheadline.bold())
                                .foregroundStyle(draft.difficulty == difficulty ? .white : .secondary)
                        }.frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(difficulty.title).font(.headline)
                            Text(difficulty.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if draft.difficulty == difficulty {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.fastCoral)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .glassCard()
    }

    @ViewBuilder
    private var focusCard: some View {
        if draft.programme == .core {
            coreFocusCard
        }
    }

    private var coreFocusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Zones prioritaires", subtitle: "Le reste de la sangle abdominale reste sollicité")
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 11) {
                ForEach(MuscleZone.available.filter { $0 != .lowerBack }) { zone in
                    let isSelected = draft.focusZones.contains(zone)
                    Button {
                        toggle(zone)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: zone.symbol)
                            Text(zone.shortTitle).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(isSelected ? zone.color : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private var comfortCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Confort")
            Toggle(isOn: $draft.apartmentFriendly) {
                Label("Sans sauts", systemImage: "speaker.slash.fill")
            }
            Divider()
            Toggle(isOn: $draft.neckFriendly) {
                Label("Préserver la nuque", systemImage: "figure.mind.and.body")
            }
            Divider()
            Toggle(isOn: $draft.extraRecovery) {
                Label("Récupération renforcée", systemImage: "heart.text.clipboard")
            }
        }
        .padding(20)
        .glassCard()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Aperçu recalculé", subtitle: "\(preview.exerciseCount) mouvements · \(preview.focusDescription)")
            HStack(spacing: 5) {
                ForEach(Array(preview.steps.filter { $0.kind == .exercise }.prefix(10))) { step in
                    Capsule()
                        .fill(step.exercise?.zones.first?.color ?? .secondary)
                        .frame(height: 10)
                }
            }
            Text(preview.steps.filter { $0.kind == .exercise }.prefix(4).map(\.title).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(20)
        .glassCard()
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
