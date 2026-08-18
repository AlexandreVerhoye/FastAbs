import SwiftData
import SwiftUI

/// The home screen, answering three questions in order.
///
/// *What am I about to do* is the hero. *Why this one* is the section under it.
/// *What else could I do* comes last, and only last. The screen this replaced
/// put a row of metrics, a carousel of ready-made sessions and a preview of the
/// day's programme at the same visual weight, so the eye had no reason to start
/// anywhere in particular — and the carousel, being the most colourful thing on
/// the page, usually won against the session the coach had just built.
struct TodayView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @State private var plan: WorkoutPlan?
    @State private var presentedPlan: WorkoutPlan?
    /// Built inside the customisation sheet, presented once it has closed. A
    /// full-screen cover raised in the same turn as a sheet dismissal is a coin
    /// toss over which one survives.
    @State private var pendingPlan: WorkoutPlan?
    @State private var showsCustomization = false
    @State private var showsSettings = false
    @State private var showsAllMovements = false
    @State private var guidance = CoachGuidance.none

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Metric.section) {
                    greeting
                    if let note = guidance.note {
                        CoachNoteCard(note: note) { difficulty in
                            Haptics.begin()
                            var updated = appModel.preferences
                            updated.difficulty = difficulty
                            appModel.preferences = updated
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    weekStrip
                    if let plan {
                        hero(plan)
                        todaySection(plan)
                        alternatives
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Aujourd’hui")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showsSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .sheet(isPresented: $showsCustomization, onDismiss: sheetDismissed) {
                CustomizationView { plan in pendingPlan = plan }
            }
            .sheet(isPresented: $showsSettings, onDismiss: refresh) { SettingsView() }
            .fullScreenCover(item: $presentedPlan) { plan in
                WorkoutView(plan: plan)
            }
            .onAppear {
                Haptics.warmUp()
                refresh()
            }
            .onChange(of: appModel.preferences) { _, _ in
                // The sheet keeps its own live preview while it is open, so
                // rebuilding the day's plan behind it is work nobody can see.
                guard !showsCustomization else { return }
                refresh()
            }
            .onChange(of: records.count) { _, _ in refresh() }
        }
    }

    // MARK: - Greeting and week

    /// The date, the streak, and — only once it is true — the fact that today
    /// is done.
    ///
    /// This used to open with "Prêt à renforcer vos abdos ?" in title weight,
    /// under the app's own name, above the date. Three lines of chrome before
    /// anything the athlete came for, two of which said nothing that changes.
    /// The hero already states what today is; a headline whose only job is to
    /// ask a rhetorical question is the first thing to cut.
    private var greeting: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayTitle)
                    .textCase(.uppercase)
                    .font(.haraEyebrow)
                    .foregroundStyle(Color.haraCoral)
                if records.containsCompletedWorkoutToday {
                    Label("Séance faite", systemImage: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.haraMint)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
            Spacer(minLength: 0)
            if records.currentStreak > 0 {
                StreakBadge(days: records.currentStreak)
            }
        }
        .animation(
            Motion.honouring(reduceMotion, Motion.content),
            value: records.containsCompletedWorkoutToday
        )
    }

    private var todayTitle: String {
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        let dayAndMonth = Date.now.formatted(.dateTime.day().month(.wide))
        return "\(weekday) \(dayAndMonth)"
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
                            .fill(day.isActive ? Color.haraCoral : Color.secondary.opacity(0.13))
                            .frame(width: 28, height: 28)
                            .scaleEffect(day.isActive ? 1 : 0.92)
                        if day.isActive {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                        if calendar.isDateInToday(day.date) {
                            Circle()
                                .stroke(Color.haraCoral, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .frame(height: 36)
                    // A day filling in is the smallest reward the app gives.
                    // It used to appear between two frames.
                    .animation(Motion.honouring(reduceMotion, Motion.reveal), value: day.isActive)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(day.date.formatted(date: .complete, time: .omitted)), \(day.isActive ? "séance faite" : "repos")"
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .glassCard()
    }

    // MARK: - The hero: what am I about to do

    private func hero(_ plan: WorkoutPlan) -> some View {
        let isAdapted = appModel.todayRecipe?.isAdapted ?? false

        return ZStack(alignment: .topLeading) {
            LinearGradient.haraNight
            Circle()
                .fill(Color.haraCoral.opacity(0.32))
                .frame(width: 220)
                .blur(radius: 45)
                .offset(x: 185, y: -90)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Label("PROGRAMME DU JOUR", systemImage: "sparkles")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.72))
                    if isAdapted {
                        Text("ADAPTÉ")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.6)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Color.haraCoral, in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // The session, not a slogan. This line used to read "Des abdos
                // solides. En quelques minutes." every single day, which is an
                // advert on a screen the athlete opens to find out what they
                // are doing. The focus is the thing that actually changes —
                // and when the coach reaches for a neglected group, this is
                // where you see it happen.
                Text(plan.focusDescription)
                    .font(.haraHeroTitle)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)

                HStack(spacing: 10) {
                    Text(plan.duration.clockText)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text(plan.preferences.difficulty.title)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text("\(plan.exerciseCount) mouvements")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .contentTransition(.numericText())

                Button {
                    Haptics.begin()
                    presentedPlan = plan
                } label: {
                    Label(
                        records.containsCompletedWorkoutToday ? "Refaire la séance" : "Commencer",
                        systemImage: "play.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.haraNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    // Inside the label, so the pill and its text answer the
                    // touch as one object. Left outside the button style, the
                    // text shrank inside a capsule that stayed put.
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.card)

                // One quiet line. It carried a caption explaining that it runs
                // your settings without adaptation — but a hero is not where an
                // app teaches, and the sheet it opens already says exactly that
                // above its own start button. A second line here only made the
                // card look like it had two primary actions.
                Button {
                    Haptics.tap()
                    showsCustomization = true
                } label: {
                    Label("Personnaliser", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.card)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.hero + 2, style: .continuous))
        .shadow(color: .haraIndigo.opacity(0.34), radius: 24, y: 12)
        .animation(reduceMotion ? nil : .snappy, value: isAdapted)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Under the hero: what exactly, and why

    private func todaySection(_ plan: WorkoutPlan) -> some View {
        VStack(spacing: 14) {
            // The detail line the metric strip used to be. Three columns of
            // icons and numbers sat directly under three more in the hero, so
            // six figures had to be read before anything could be started —
            // and the strip repeated the movement count that was already there.
            SectionHeader(
                title: "Au programme",
                subtitle: "\(plan.workDuration.clockText) de travail · \(cadenceText(plan)) · ≈\(plan.estimatedCalories) kcal"
            )
            sessionShape(plan)
            if let recipe = appModel.todayRecipe, recipe.hasRationale {
                SessionRationaleCard(recipe: recipe)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// The shape of the session, then the movements themselves.
    ///
    /// One card rather than the two it replaced: the metric row and the
    /// movement list are answers to the same question, and splitting them left
    /// a strip of numbers floating above a carousel with nothing to attach to.
    private func sessionShape(_ plan: WorkoutPlan) -> some View {
        let rows = movementRows(plan)
        let visible = showsAllMovements ? rows : Array(rows.prefix(4))

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                movementRow(row)
                if index < visible.count - 1 { Divider().padding(.leading, 56) }
            }

            if rows.count > 4 {
                Button {
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                        showsAllMovements.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showsAllMovements ? "Réduire" : "Voir les \(rows.count) mouvements")
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(showsAllMovements ? 180 : 0))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.haraCoral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.card)
            }
        }
        .padding(.horizontal, Metric.cardPadding)
        .glassCard()
    }

    private func movementRow(_ row: MovementRow) -> some View {
        // The pattern, not the zone. The line underneath already names the
        // groups, so the icon is free to say what job the movement is doing —
        // and a zone drawn from a `Set` was picking a different one between
        // launches, which is how two neighbouring rows ended up wearing the
        // same icon for no reason a reader could see.
        let pattern = row.exercise.pattern

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(pattern.color.opacity(0.14))
                Image(systemName: pattern.symbol).foregroundStyle(pattern.color)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.exercise.name).font(.subheadline.weight(.semibold))
                Text(row.exercise.zones.map(\.shortTitle).sorted().joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(row.durationText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.exercise.name), \(row.durationText)")
    }

    /// A movement as the athlete counts it: a side plank is one movement done
    /// twice, not two movements.
    private struct MovementRow: Identifiable {
        let exercise: Exercise
        let seconds: Int
        let perSide: Bool
        /// Position included: the same movement can legitimately come round
        /// twice in a long session, and two rows sharing an id collapses them.
        let id: String

        var durationText: String {
            perSide ? "2 × \(seconds / 2) s" : "\(seconds) s"
        }
    }

    private func movementRows(_ plan: WorkoutPlan) -> [MovementRow] {
        var rows: [MovementRow] = []
        for step in plan.steps {
            guard step.kind == .exercise, let exercise = step.exercise else { continue }
            if step.side == .right, let last = rows.last, last.exercise.id == exercise.id {
                rows[rows.count - 1] = MovementRow(
                    exercise: exercise,
                    seconds: last.seconds + step.duration,
                    perSide: true,
                    id: last.id
                )
            } else {
                rows.append(
                    MovementRow(
                        exercise: exercise,
                        seconds: step.duration,
                        perSide: false,
                        id: "\(rows.count)-\(exercise.id)"
                    )
                )
            }
        }
        return rows
    }

    /// The work/rest pair as this plan actually runs it, not as the level
    /// advertises it — the solver trades seconds around to land on the exact
    /// duration asked for, and quoting the nominal figure would be the one
    /// number on the screen that the session does not honour.
    private func cadenceText(_ plan: WorkoutPlan) -> String {
        let work = plan.steps.filter { $0.kind == .exercise }.map(\.duration).sorted()
        let rest = plan.steps.filter { $0.kind == .recovery }.map(\.duration).sorted()
        guard !work.isEmpty else { return "—" }
        let typicalWork = work[work.count / 2]
        guard !rest.isEmpty else { return "\(typicalWork) s" }
        return "\(typicalWork)/\(rest[rest.count / 2]) s"
    }

    // MARK: - What else could I do

    /// Sessions someone already decided on, for the days you have no opinion.
    /// Last on the screen on purpose: they are the alternative to the day's
    /// programme, and a carousel placed above it reads as the main event.
    private var alternatives: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Envie d’autre chose", subtitle: "Des séances toutes prêtes, hors programme")

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
                // Cards come to rest aligned rather than wherever the finger
                // let go, which is the difference between a row of cards and a
                // carousel.
                .scrollTargetLayout()
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .padding(.horizontal, -Metric.gutter)
        }
    }

    // MARK: - Plumbing

    private func sheetDismissed() {
        refresh()
        if let pendingPlan {
            presentedPlan = pendingPlan
            self.pendingPlan = nil
        }
    }

    private func refresh() {
        guidance = CoachAdvisor().guidance(records: records, preferences: appModel.preferences)
        plan = appModel.makeTodayWorkout(records: records)
        showsAllMovements = false
    }
}

/// The current streak, sized to read at a glance without shouting.
private struct StreakBadge: View {
    let days: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.caption)
                Text("\(days)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(days == 1 ? "jour" : "jours")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.haraCoral)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color.haraCoral.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .buttonStyle(.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(playlist.title), \(playlist.durationText), \(playlist.preferences.difficulty.title). \(playlist.detail)"
        )
        .accessibilityAddTraits(.isButton)
    }
}

/// The one thing a coach would say before you start.
///
/// Deliberately at most one, and only when there is something to say: an app
/// that comments on every session is noise, and noise is what people learn to
/// scroll past.
struct CoachNoteCard: View {
    let note: CoachNote
    let onAccept: (WorkoutDifficulty) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: note.symbol)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(LinearGradient.haraHero, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(note.title)
                    .font(.subheadline.weight(.bold))
                Text(note.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggested = note.suggestedDifficulty {
                    Button("Passer en \(suggested.title.lowercased())") {
                        onAccept(suggested)
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

/// Why today's session is not exactly what the settings say.
///
/// An adaptation the athlete cannot see is indistinguishable from a bug: they
/// asked for twelve minutes at balanced and got nine at beginner, and without a
/// reason attached that reads as the app being broken rather than as coaching.
/// It sits directly under the session it explains — floating above the hero, as
/// it used to, it explained something the reader had not seen yet.
struct SessionRationaleCard: View {
    let recipe: SessionRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("POURQUOI CETTE SÉANCE", systemImage: "wand.and.stars")
                .font(.caption2.weight(.heavy))
                .tracking(0.7)
                .foregroundStyle(Color.haraCoral)

            ForEach(recipe.rationale, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.haraCoral.opacity(0.55))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pourquoi cette séance. " + recipe.rationale.joined(separator: " "))
    }
}
