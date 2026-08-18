import SwiftUI

/// Every movement in the catalog, browsable on its own.
///
/// Useful to look up a movement before a session, and the only place the
/// animations can be checked one by one rather than whenever a workout happens
/// to schedule them.
struct ExerciseLibraryView: View {
    @State private var search = ""
    @State private var section: CatalogSection?
    /// Ties a row to the page it opens: the movement grows out of the row
    /// rather than the page arriving from the right over it.
    @Namespace private var movements
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var query: String {
        search.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var results: [Exercise] {
        let query = query
        return ExerciseCatalog.all.filter { exercise in
            let matchesSection = section.map { $0.contains(exercise) } ?? true
            let matchesSearch = query.isEmpty
                || exercise.name.lowercased().contains(query)
                || exercise.zones.contains { $0.title.lowercased().contains(query) }
                || CatalogSection.of(exercise).title.lowercased().contains(query)
            return matchesSection && matchesSearch
        }
    }

    /// Grouped the way `CatalogSection` decides: trunk work by the job it
    /// asks of the trunk, the rest of the body by the part it trains.
    private var groups: [(section: CatalogSection, exercises: [Exercise])] {
        CatalogSection.grouping(results)
    }

    private var isFiltering: Bool { section != nil || !query.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metric.section, pinnedViews: .sectionHeaders) {
                    sectionPicker

                    if isFiltering {
                        Text("\(results.count) mouvement\(results.count == 1 ? "" : "s") sur \(ExerciseCatalog.all.count)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }

                    ForEach(groups, id: \.section) { group in
                        Section {
                            VStack(spacing: Metric.row) {
                                ForEach(group.exercises) { exercise in
                                    NavigationLink {
                                        ExerciseDetailView(exercise: exercise)
                                            .navigationTransition(.zoom(sourceID: exercise.id, in: movements))
                                    } label: {
                                        ExerciseRow(exercise: exercise)
                                    }
                                    .buttonStyle(.card)
                                    .matchedTransitionSource(id: exercise.id, in: movements)
                                    // A NavigationLink has no action to hang a
                                    // haptic on, and every other control in the
                                    // app answers a touch.
                                    .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                                }
                            }
                        } header: {
                            GroupHeader(section: group.section, count: group.exercises.count)
                        }
                    }

                    if groups.isEmpty {
                        noResults
                            .appears(reduceMotion)
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, Metric.section)
                // Animated on the filter and the query rather than on the
                // groups themselves: keying it to the results would restage
                // every row each time a character is typed.
                .animation(Motion.honouring(reduceMotion, Motion.rearrange), value: section)
                .animation(Motion.honouring(reduceMotion, Motion.rearrange), value: search)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $search, prompt: "Rechercher un mouvement")
            .autocorrectionDisabled()
            .navigationTitle("Mouvements")
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                FilterChip(title: "Tout", isSelected: section == nil) { section = nil }
                ForEach(CatalogSection.all) { candidate in
                    FilterChip(
                        title: candidate.shortTitle,
                        tint: candidate.color,
                        isSelected: section == candidate
                    ) {
                        section = section == candidate ? nil : candidate
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// A search that found nothing, with the way back out of it.
    ///
    /// `ContentUnavailableView.search` states the problem and stops there; on a
    /// screen with a filter chip still active, the athlete cannot always see
    /// why the catalog looks empty.
    private var noResults: some View {
        VStack(spacing: Metric.row) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.haraCoral)
                .frame(width: 62, height: 62)
                .background(Color.haraCoral.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text("Aucun mouvement")
                .font(.headline)

            Text(noResultsReason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Afficher tout le catalogue") {
                Haptics.tap()
                search = ""
                section = nil
            }
            .buttonStyle(.haraSecondary)
            .padding(.top, Metric.row)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Metric.section)
    }

    private var noResultsReason: String {
        let term = search.trimmingCharacters(in: .whitespaces)
        switch (term.isEmpty, section) {
        case let (false, .some(section)):
            return "Rien pour « \(term) » parmi les mouvements de \(section.shortTitle.lowercased())."
        case (false, nil):
            return "Rien pour « \(term) » dans le catalogue."
        case let (true, .some(section)):
            return "Aucun mouvement de \(section.shortTitle.lowercased()) au catalogue."
        case (true, nil):
            return "Le catalogue est vide."
        }
    }
}

/// The pinned title of one group.
private struct GroupHeader: View {
    let section: CatalogSection
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.headline)
                Text(section.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(section.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        // The header's own frame stops at the page gutter, so rows used to
        // slide visibly past it on both sides while it stayed pinned.
        .background {
            Color(.systemGroupedBackground)
                .padding(.horizontal, -Metric.gutter)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Metric.row + 2) {
            // The figure runs here rather than holding its first frame. A
            // still shows the movement's starting position, and the starting
            // position of a crunch, a dead bug and a leg raise is the same
            // person lying on their back — which made half the catalog look
            // like the same row. `ExerciseMotionView` freezes itself on the
            // peak contraction when Reduce Motion is on, which is the one
            // still worth showing.
            ExerciseMotionView(exercise: exercise, isPlaying: true)
                .frame(width: 88, height: 74)
                .background(
                    LinearGradient.haraNight,
                    in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(exercise.zones.map(\.shortTitle).sorted().joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(Metric.row)
        .glassCard()
    }
}

/// One movement, animating, with everything the coach would say about it.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @State private var isPlaying = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var siblings: [Exercise] {
        ExerciseCatalog.all
            .filter { CatalogSection.of($0) == CatalogSection.of(exercise) && $0.id != exercise.id }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.section) {
                figure
                identity
                zoneChips
                coaching
                coachingTips
                related
            }
            .padding(Metric.gutter)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var figure: some View {
        ZStack(alignment: .bottomTrailing) {
            ExerciseMotionView(exercise: exercise, isPlaying: isPlaying)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background {
                    LinearGradient.haraNight
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(exercise.accent.opacity(0.28))
                                .frame(width: 190, height: 190)
                                .blur(radius: 45)
                                .offset(x: 60, y: -70)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous))

            Button {
                Haptics.selection()
                withAnimation(Motion.honouring(reduceMotion, Motion.tap)) { isPlaying.toggle() }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }
            .padding(Metric.row + 2)
            .accessibilityLabel(isPlaying ? "Mettre en pause" : "Lire l’animation")
        }
    }

    /// What kind of movement this is, then the three facts that decide whether
    /// it suits the athlete right now.
    ///
    /// These used to be a strip of three `MetricPill`s at the foot of the page,
    /// one of which read "Intensité 1,4" — an internal weighting on a scale the
    /// screen never showed. A page about a movement is carried by the coaching
    /// text; this line only qualifies it.
    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(
                CatalogSection.of(exercise).title,
                systemImage: CatalogSection.of(exercise).symbol
            )
            .font(.haraEyebrow)
            .textCase(.uppercase)
            .foregroundStyle(exercise.accent)

            Text(metadata)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadata: String {
        // "Dès le niveau" rather than "à partir de": two of the four level
        // names open on a vowel, and "à partir de intense" needs an elision
        // this sentence would have to special-case.
        var parts = [
            "Dès le niveau \(exercise.minimumDifficulty.title.lowercased())",
            exercise.impact == .quiet ? "Silencieux" : "Dynamique"
        ]
        switch exercise.sideMode {
        case .bilateral: break
        case .alternating: parts.append("En alternance")
        case .heldPerSide: parts.append("Un côté puis l’autre")
        }
        return parts.joined(separator: " · ")
    }

    private var zoneChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(exercise.zones).sorted { $0.rawValue < $1.rawValue }) { zone in
                    Label(zone.shortTitle, systemImage: zone.symbol)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(zone.color.opacity(0.16), in: Capsule())
                        .foregroundStyle(zone.color)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    /// The four things the coach says, in the order they matter: get into
    /// position, do the thing, keep breathing, and here is what goes wrong.
    private var coaching: some View {
        VStack(spacing: 0) {
            detail("figure.stand", "Position de départ", exercise.setup, .haraBlue)
            row()
            detail("arrow.triangle.turn.up.right.diamond.fill", "Exécution", exercise.instruction, .haraCoral)
            row()
            detail("wind", "Respiration", exercise.breathing, .haraMint)
            row()
            detail("exclamationmark.triangle.fill", "À éviter", exercise.mistake, .haraOrange)
        }
        .padding(Metric.cardPadding)
        .glassCard()
    }

    private func row() -> some View {
        Divider().padding(.leading, 34).padding(.vertical, Metric.row)
    }

    /// The cues the coach gives while the movement is running.
    ///
    /// They were written for every exercise in the catalog and then shown
    /// nowhere outside a live session, which is the one moment an athlete has
    /// no attention to spare for reading them.
    @ViewBuilder
    private var coachingTips: some View {
        if !exercise.tips.isEmpty {
            VStack(alignment: .leading, spacing: Metric.row) {
                Text("Conseils du coach")
                    .font(.haraEyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.haraCoral)

                ForEach(Array(exercise.tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 11) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.black).monospacedDigit())
                            .foregroundStyle(Color.haraCoral)
                            .frame(width: 20, height: 20)
                            .background(Color.haraCoral.opacity(0.14), in: Circle())
                        Text(tip)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metric.cardPadding)
            .glassCard()
        }
    }

    /// Where to go next without walking back to the list. Same pattern, so the
    /// suggestion is "another way to train this", not "another exercise".
    @ViewBuilder
    private var related: some View {
        if !siblings.isEmpty {
            VStack(alignment: .leading, spacing: Metric.row) {
                SectionHeader(title: "Même travail")

                VStack(spacing: 0) {
                    ForEach(Array(siblings.enumerated()), id: \.element.id) { index, sibling in
                        NavigationLink {
                            ExerciseDetailView(exercise: sibling)
                        } label: {
                            HStack(spacing: Metric.row) {
                                Circle()
                                    .fill(sibling.accent.opacity(0.16))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: CatalogSection.of(sibling).symbol)
                                            .font(.caption)
                                            .foregroundStyle(sibling.accent)
                                    }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sibling.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(sibling.zones.map(\.shortTitle).sorted().joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, Metric.row - 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.card)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })

                        if index < siblings.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
                .padding(.horizontal, Metric.cardPadding)
                .glassCard()
            }
        }
    }

    private func detail(_ symbol: String, _ title: String, _ body: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: Metric.row) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
