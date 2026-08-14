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
                    if let plan {
                        hero(plan)
                        todayMetrics(plan)
                        programPreview(plan)
                        dailyProgress
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("FastAbs")
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

    private var greeting: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayTitle)
                    .textCase(.uppercase)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fastCoral)
                Text(records.containsCompletedWorkoutToday ? "Objectif du jour atteint" : "Prêt à renforcer votre centre ?")
                    .font(.title2.bold())
            }
            Spacer()
            if records.currentStreak > 0 {
                Label("\(records.currentStreak)", systemImage: "flame.fill")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Série de \(records.currentStreak) jours")
            }
        }
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
                    Text("Un centre fort.\nEn quelques minutes.")
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
