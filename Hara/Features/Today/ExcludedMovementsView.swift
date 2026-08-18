import SwiftUI

/// The movements the athlete never wants to see again.
///
/// Every catalog has three or four movements someone simply cannot do — an old
/// shoulder, a floor too hard for the hips, a hatred of mountain climbers that
/// no amount of coaching will argue away. Without a way to say so the only
/// remaining move is to skip them mid-session, every session, which teaches the
/// app nothing and costs the athlete the same ten seconds forever.
///
/// The list never reorders as things are excluded. Watching a row you just
/// tapped fly to another part of the screen is how a picker loses your place.
struct ExcludedMovementsView: View {
    @Binding var draft: WorkoutPreferences
    /// What a session built from these settings actually asks for, so the
    /// warning is about this session rather than about a round number.
    let movementsNeeded: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""

    private var query: String {
        search.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Only the movements this athlete's session can contain.
    ///
    /// Banishing a movement that is already unreachable — a push-up when the
    /// upper body is switched off — is a decision with no effect, and a list full
    /// of them makes the ones that matter harder to find.
    private var programmable: [Exercise] {
        ExerciseCatalog.all.filter { $0.areas.isSubset(of: draft.trainedAreas) }
    }

    private var results: [Exercise] {
        guard !query.isEmpty else { return programmable }
        return programmable.filter { exercise in
            exercise.name.lowercased().contains(query)
                || CatalogSection.of(exercise).title.lowercased().contains(query)
                || exercise.zones.contains { $0.title.lowercased().contains(query) }
        }
    }

    /// Grouped exactly like the movement library, so the two screens read the
    /// same way round.
    private var groups: [(section: CatalogSection, exercises: [Exercise])] {
        CatalogSection.grouping(results)
    }

    private var excludedExercises: [Exercise] {
        draft.excludedExerciseIDs
            .compactMap { ExerciseCatalog.byID[$0] }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var feasibility: SessionFeasibility {
        draft.feasibility(movementsNeeded: movementsNeeded)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metric.section, pinnedViews: .sectionHeaders) {
                if !excludedExercises.isEmpty { excludedSummary }
                if feasibility.title != nil { warning }

                ForEach(groups, id: \.section) { group in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, exercise in
                                row(exercise)
                                if index < group.exercises.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .padding(.horizontal, Metric.cardPadding)
                        .padding(.vertical, 4)
                        .glassCard()
                    } header: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.section.title)
                                .font(.headline)
                            Text(group.section.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .systemGroupedBackground))
                    }
                }

                if groups.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $search, prompt: "Rechercher un mouvement")
        .navigationTitle("Mouvements écartés")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Excluding is one tap; undoing it has to be one tap too, from a place the
    /// athlete can find without remembering which of forty-seven rows they hit.
    private var excludedSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(excludedExercises.count)")
                    .font(.haraDisplay)
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.haraCoral)
                Text(excludedExercises.count == 1 ? "mouvement écarté" : "mouvements écartés")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Tout réintégrer") {
                    Haptics.success()
                    withAnimation(reduceMotion ? nil : .snappy) {
                        draft.excludedExerciseIDs = []
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.haraCoral)
            }

            FlowChips(exercises: excludedExercises) { exercise in
                toggle(exercise)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metric.cardPadding + 2)
        .glassCard()
        .animation(reduceMotion ? nil : .snappy, value: draft.excludedExerciseIDs)
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feasibility.symbol)
                .font(.headline)
                .foregroundStyle(feasibility.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(feasibility.title ?? "")
                    .font(.subheadline.weight(.bold))
                Text(feasibility.detail ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Metric.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous)
                .fill(feasibility.tint.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }

    private func row(_ exercise: Exercise) -> some View {
        let isExcluded = draft.excludedExerciseIDs.contains(exercise.id)
        let zone = exercise.primaryZone

        return Button {
            toggle(exercise)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(zone.color.opacity(isExcluded ? 0.08 : 0.14))
                    Image(systemName: isExcluded ? "slash.circle.fill" : zone.symbol)
                        .foregroundStyle(isExcluded ? Color.secondary : zone.color)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(isExcluded, color: .secondary)
                    Text(exercise.zones.map(\.shortTitle).sorted().joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: isExcluded ? "arrow.uturn.backward.circle.fill" : "minus.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isExcluded ? Color.haraMint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .opacity(isExcluded ? 0.62 : 1)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.card)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isExcluded)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name), \(exercise.zones.map(\.shortTitle).sorted().joined(separator: ", "))")
        .accessibilityValue(isExcluded ? "Écarté" : "Au programme")
        .accessibilityHint(isExcluded ? "Réintégrer ce mouvement" : "Écarter ce mouvement")
        .accessibilityAddTraits(.isButton)
    }

    private func toggle(_ exercise: Exercise) {
        var updated = draft.excludedExerciseIDs
        if updated.contains(exercise.id) {
            updated.remove(exercise.id)
            Haptics.selection()
        } else {
            updated.insert(exercise.id)
            // The last movement out of the pool is the one that breaks the
            // session, so that is the one that gets a different vibration.
            var probe = draft
            probe.excludedExerciseIDs = updated
            if probe.feasibility(movementsNeeded: movementsNeeded) == .comfortable {
                Haptics.selection()
            } else {
                Haptics.warning()
            }
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            draft.excludedExerciseIDs = updated
        }
    }
}

/// The excluded movements as chips that wrap, each one its own undo button.
///
/// Written by hand rather than with a `LazyVGrid`: the chips are all different
/// widths, and a grid would leave a ragged column of air on every row.
private struct FlowChips: View {
    let exercises: [Exercise]
    let onTap: (Exercise) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(exercises) { exercise in
                Button {
                    onTap(exercise)
                } label: {
                    HStack(spacing: 5) {
                        Text(exercise.name)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .background(Color.haraCoral.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.haraCoral)
                }
                .buttonStyle(.card)
                .accessibilityLabel("Réintégrer \(exercise.name)")
            }
        }
    }
}

/// A left-to-right wrapping row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var height: CGFloat = 0
        var width: CGFloat = 0
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty, x + size.width > width {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
                x = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            x += size.width + spacing
            current.width = x - spacing
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
