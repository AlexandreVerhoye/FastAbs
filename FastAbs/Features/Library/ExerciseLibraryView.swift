import SwiftUI

/// Every movement in the catalog, browsable on its own.
///
/// Useful to look up a movement before a session, and the only place the
/// animations can be checked one by one rather than whenever a workout happens
/// to schedule them.
struct ExerciseLibraryView: View {
    @State private var search = ""
    @State private var pattern: CorePattern?

    private var results: [Exercise] {
        ExerciseCatalog.all.filter { exercise in
            let matchesPattern = pattern.map { exercise.pattern == $0 } ?? true
            let query = search.trimmingCharacters(in: .whitespaces).lowercased()
            let matchesSearch = query.isEmpty
                || exercise.name.lowercased().contains(query)
                || exercise.zones.contains { $0.title.lowercased().contains(query) }
                || exercise.pattern.title.lowercased().contains(query)
            return matchesPattern && matchesSearch
        }
    }

    /// Grouped by what the trunk is asked to do rather than by muscle: it is
    /// the axis a session is balanced on, and browsing it that way makes the
    /// shape of the catalog legible.
    private var groups: [(pattern: CorePattern, exercises: [Exercise])] {
        CorePattern.allCases.compactMap { pattern in
            let matching = results
                .filter { $0.pattern == pattern }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            return matching.isEmpty ? nil : (pattern, matching)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22, pinnedViews: .sectionHeaders) {
                    regionPicker

                    ForEach(groups, id: \.pattern) { group in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(group.exercises) { exercise in
                                    NavigationLink {
                                        ExerciseDetailView(exercise: exercise)
                                    } label: {
                                        ExerciseRow(exercise: exercise)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.pattern.title)
                                    .font(.headline)
                                Text(group.pattern.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .background(Color(.systemGroupedBackground))
                        }
                    }

                    if groups.isEmpty {
                        ContentUnavailableView.search(text: search)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $search, prompt: "Rechercher un mouvement")
            .navigationTitle("Mouvements")
        }
    }

    private var regionPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                FilterChip(title: "Tout", isSelected: pattern == nil) { pattern = nil }
                ForEach(CorePattern.allCases) { candidate in
                    FilterChip(
                        title: candidate.shortTitle,
                        tint: candidate.color,
                        isSelected: pattern == candidate
                    ) {
                        pattern = pattern == candidate ? nil : candidate
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMotionView(exercise: exercise, isPlaying: false)
                .frame(width: 76, height: 66)
                .background(Color.fastNavy.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(12)
        .glassCard()
    }
}

/// One movement, animating, with everything the coach would say about it.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @State private var isPlaying = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .bottomTrailing) {
                    ExerciseMotionView(exercise: exercise, isPlaying: isPlaying)
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient.fastNight,
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                        )

                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .padding(14)
                    .accessibilityLabel(isPlaying ? "Mettre en pause" : "Lire l’animation")
                }

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

                detail("figure.stand", "Position de départ", exercise.setup, .primary)
                detail("arrow.triangle.turn.up.right.diamond.fill", "Exécution", exercise.instruction, .primary)
                detail("wind", "Respiration", exercise.breathing, .secondary)
                detail("exclamationmark.triangle.fill", "À éviter", exercise.mistake, Color.fastOrange)

                HStack(spacing: 0) {
                    MetricPill(
                        icon: "gauge.with.dots.needle.50percent",
                        value: exercise.minimumDifficulty.title,
                        label: "à partir de"
                    )
                    Divider().frame(height: 44)
                    MetricPill(
                        icon: exercise.impact == .quiet ? "speaker.slash.fill" : "figure.run",
                        value: exercise.impact == .quiet ? "Silencieux" : "Dynamique",
                        label: "impact"
                    )
                    Divider().frame(height: 44)
                    MetricPill(
                        icon: "flame.fill",
                        value: String(format: "%.1f", exercise.intensity),
                        label: "intensité"
                    )
                }
                .padding(.vertical, 16)
                .glassCard()
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ symbol: String, _ title: String, _ body: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
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
                    .foregroundStyle(tint == .secondary ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
