import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @State private var plan: WorkoutPlan?
    @State private var presentedPlan: WorkoutPlan?
    @State private var showsCustomization = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 26) {
                    greeting
                    weekStrip
                    if let plan {
                        hero(plan)
                        todayMetrics(plan)
                        playlists
                        programPreview(plan)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Hara")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsSettings = true } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .sheet(isPresented: $showsCustomization) {
                CustomizationView { preferences in
                    appModel.preferences = preferences
                    plan = appModel.makeTodayWorkout()
                }
            }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .fullScreenCover(item: $presentedPlan) { plan in
                WorkoutView(plan: plan)
            }
            .onAppear { refreshPlan() }
            .onChange(of: appModel.preferences) { _, _ in refreshPlan() }
        }
    }

    /// Sessions someone already decided on, for the days you have no opinion.
    private var playlists: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Séances prêtes", subtitle: "Choisissez un angle et lancez-vous")

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(WorkoutPlaylist.all) { playlist in
                        PlaylistCard(playlist: playlist) {
                            Haptics.begin()
                            presentedPlan = WorkoutEngine().makePlan(
                                preferences: playlist.preferences,
                                seed: appModel.seed(for: playlist)
                            )
                        }
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(.horizontal, -Metric.gutter)
        }
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayTitle)
                    .textCase(.uppercase)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fastCoral)
                Text(records.containsCompletedWorkoutToday ? "Objectif du jour atteint" : "Prêt à renforcer vos abdos ?")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if records.currentStreak > 0 {
                StreakBadge(days: records.currentStreak)
            }
        }
    }

    /// The week at a glance, so the home screen shows where you stand and not
    /// only what is next.
    private var weekStrip: some View {
        let calendar = Calendar.current
        let days = WorkoutHistoryAnalytics(calendar: calendar).days(records: records, count: 7)

        return HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(day.isActive ? Color.fastCoral : Color.secondary.opacity(0.13))
                            .frame(width: 30, height: 30)
                        if day.isActive {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white)
                        }
                        if calendar.isDateInToday(day.date) {
                            Circle()
                                .stroke(Color.fastCoral, lineWidth: 2)
                                .frame(width: 38, height: 38)
                        }
                    }
                    .frame(height: 40)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(day.date.formatted(date: .complete, time: .omitted)), \(day.isActive ? "séance faite" : "repos")"
                )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .glassCard()
    }

    private var todayTitle: String {
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        let dayAndMonth = Date.now.formatted(.dateTime.day().month(.wide))
        return "\(weekday) \(dayAndMonth)"
    }

    private func hero(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient.fastNight
                Circle()
                    .fill(Color.fastCoral.opacity(0.32))
                    .frame(width: 220)
                    .blur(radius: 45)
                    .offset(x: 185, y: -90)

                VStack(alignment: .leading, spacing: 18) {
                    Label("PROGRAMME DU JOUR", systemImage: "sparkles")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("Des abdos solides.\nEn quelques minutes.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 18) {
                        Label(plan.duration.clockText, systemImage: "clock.fill")
                        Label(plan.preferences.difficulty.title, systemImage: "gauge.with.dots.needle.50percent")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                    Button {
                        presentedPlan = plan
                    } label: {
                        Label(records.containsCompletedWorkoutToday ? "Refaire la séance" : "Commencer", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Color.fastNavy)

                    Button("Personnaliser") { showsCustomization = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .fastIndigo.opacity(0.34), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func todayMetrics(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: 0) {
            MetricPill(icon: "figure.run", value: "\(plan.exerciseCount)", label: "exercices")
            Divider().frame(height: 46)
            MetricPill(icon: "flame.fill", value: "≈\(plan.estimatedCalories)", label: "kcal")
            Divider().frame(height: 46)
            MetricPill(icon: "scope", value: plan.focusDescription, label: "priorité")
        }
        .padding(.vertical, 18)
        .glassCard()
    }

    private func programPreview(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 14) {
            SectionHeader(title: "Votre programme", subtitle: "Une sélection différente et équilibrée")
            VStack(spacing: 0) {
                ForEach(Array(plan.steps.filter { $0.kind == .exercise }.prefix(5).enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill((step.exercise?.zones.first?.color ?? .fastCoral).opacity(0.14))
                            Image(systemName: step.exercise?.zones.first?.symbol ?? "figure.core.training")
                                .foregroundStyle(step.exercise?.zones.first?.color ?? .fastCoral)
                        }
                        .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(.subheadline.weight(.semibold))
                            Text(step.exercise?.zones.map(\.shortTitle).sorted().joined(separator: " · ") ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(step.duration) s")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 11)
                    if index < min(4, plan.exerciseCount - 1) { Divider().padding(.leading, 56) }
                }
                if plan.exerciseCount > 5 {
                    Text("+ \(plan.exerciseCount - 5) autres mouvements")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard()
        }
    }

    private var dailyProgress: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "Élan du jour")
            HStack(spacing: 16) {
                Image(systemName: records.containsCompletedWorkoutToday ? "checkmark.seal.fill" : "circle.dotted")
                    .font(.system(size: 42))
                    .foregroundStyle(records.containsCompletedWorkoutToday ? Color.fastMint : Color.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(records.containsCompletedWorkoutToday ? "Badge quotidien remporté" : "Votre badge vous attend")
                        .font(.headline)
                    Text(records.containsCompletedWorkoutToday ? "Revenez demain pour prolonger votre série." : "Terminez le programme pour le débloquer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            .glassCard()
        }
    }

    private func refreshPlan() {
        plan = appModel.makeTodayWorkout()
    }
}

/// The current streak, sized to read at a glance without shouting.
private struct StreakBadge: View {
    let days: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.caption)
                Text("\(days)").font(.title3.weight(.bold).monospacedDigit())
            }
            Text(days == 1 ? "jour" : "jours")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.fastCoral)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color.fastCoral.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Série de \(days) jour\(days == 1 ? "" : "s")")
    }
}

extension Int {
    var clockText: String {
        let minutes = self / 60
        let seconds = self % 60
        return seconds == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", seconds))"
    }
}

extension Array where Element == WorkoutRecord {
    var containsCompletedWorkoutToday: Bool {
        contains { Calendar.current.isDateInToday($0.completedAt) }
    }

    var currentStreak: Int {
        WorkoutHistoryAnalytics().currentStreak(records: self)
    }
}

/// One ready-made session in the home carousel.
struct PlaylistCard: View {
    let playlist: WorkoutPlaylist
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [playlist.tint.opacity(0.95), playlist.tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: playlist.symbol)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(14)
                }
                .frame(height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(playlist.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Label(playlist.durationText, systemImage: "clock.fill")
                        Text("·")
                        Text(playlist.preferences.difficulty.title)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(playlist.tint)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 208)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(playlist.title), \(playlist.durationText), \(playlist.preferences.difficulty.title). \(playlist.detail)"
        )
        .accessibilityAddTraits(.isButton)
    }
}
