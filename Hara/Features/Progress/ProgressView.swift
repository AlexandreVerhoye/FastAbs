import Charts
import SwiftData
import SwiftUI

/// Everything the tab shows, worked out once.
///
/// These passes used to sit inside the body, wrapped in a `TimelineView`.
/// That meant the whole set was recomputed on every redraw — including every
/// frame of a finger dragging across the chart, and on any tab change, since
/// the shell builds this screen whether or not you open it.
struct ProgressSnapshot {
    var overview = WorkoutHistoryOverview(
        totalSessions: 0, totalActiveSeconds: 0, totalCalories: 0, activeDays: 0,
        currentStreak: 0, longestStreak: 0, currentWeekSeconds: 0,
        previousWeekSeconds: 0, currentMonthSessions: 0
    )
    var chartDays: [WorkoutHistoryDay] = []
    var activityDays: [WorkoutHistoryDay] = []
    var focus: [WorkoutFocusBreakdown] = []
    var patterns: [PatternLoad] = []
    var areas: [AreaLoad] = []
    var bests = PersonalRecords(
        longestStreak: 0, bestWeekMinutes: 0, longestSessionSeconds: 0,
        busiestDaySessions: 0, totalSessions: 0
    )
    /// The last few sessions, already reduced to what a row draws.
    var recent: [RecentWorkout] = []
    /// Calendar days from the first session that counted to today.
    var historySpanDays = 0
    /// Chart periods the history can actually fill. A ninety-day chart holding
    /// one bar is not a chart, it is an accusation.
    var availableRanges: [ProgressRange] = [.week]

    /// True when nothing in the store clears `WorkoutHistoryAnalytics`'
    /// qualifying bar — including the case where sessions exist but were all
    /// abandoned in the first minute, which is the same screen to the athlete.
    var hasHistory: Bool { overview.totalSessions > 0 }

    static func make(
        records: [WorkoutRecord],
        range: Int,
        calendar: Calendar,
        now: Date
    ) -> ProgressSnapshot {
        let analytics = WorkoutHistoryAnalytics(calendar: calendar)
        let qualifying = analytics.qualifyingRecords(from: records)
        let historySpan = span(of: qualifying, calendar: calendar, now: now)
        return ProgressSnapshot(
            overview: analytics.overview(records: records, now: now),
            chartDays: analytics.days(records: records, endingAt: now, count: range),
            activityDays: analytics.days(records: records, endingAt: now, count: 35),
            focus: analytics.focusBreakdown(records: records),
            patterns: analytics.patternLoad(records: records),
            areas: analytics.areaLoad(records: records),
            bests: analytics.personalRecords(records: records),
            recent: qualifying.prefix(5).map(RecentWorkout.init),
            historySpanDays: historySpan,
            availableRanges: ProgressRange.available(historySpanDays: historySpan)
        )
    }

    /// How many calendar days the history covers, first session included.
    static func span(of qualifying: [WorkoutRecord], calendar: Calendar, now: Date) -> Int {
        guard let first = qualifying.map(\.completedAt).min() else { return 0 }
        let start = calendar.startOfDay(for: first)
        let today = calendar.startOfDay(for: now)
        return (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
    }
}

/// One finished session, reduced to the handful of facts a row shows.
///
/// Built with the rest of the snapshot rather than read off the model in the
/// row: the recent list used to take `records` straight from the query, so it
/// listed sessions the chart, the streak and the badges had all thrown out —
/// the one place in the app where an abandoned thirty-second session still
/// counted as training.
struct RecentWorkout: Identifiable, Hashable {
    let id: UUID
    let completedAt: Date
    let activeSeconds: Int
    let calories: Int
    let movementCount: Int
    let difficulty: WorkoutDifficulty
    let section: CatalogSection
    let wasCompleted: Bool

    init(record: WorkoutRecord) {
        id = record.id
        completedAt = record.completedAt
        activeSeconds = max(0, record.activeDuration)
        calories = max(0, record.estimatedCalories)
        movementCount = record.exerciseIDs.count
        difficulty = record.difficulty
        // The work the session did most of, so the list has the same colour
        // vocabulary as the balance card rather than a row of identical tiles.
        let sections = record.exerciseIDs
            .compactMap { ExerciseCatalog.byID[$0] }
            .map(CatalogSection.of)
        let counts = sections.reduce(into: [CatalogSection: Int]()) { $0[$1, default: 0] += 1 }
        section = counts.max { left, right in
            left.value == right.value
                ? left.key.id > right.key.id
                : left.value < right.value
        }?.key ?? .pattern(.antiExtension)
        wasCompleted = record.wasCompleted
    }
}

struct ProgressDashboardView: View {
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(AppModel.self) private var appModel
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRange = ProgressRange.month
    @State private var selectedDate: Date?
    @State private var snapshot = ProgressSnapshot()
    @State private var presentedPlan: WorkoutPlan?

    private var localCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Metric.section) {
                if snapshot.hasHistory {
                    history
                } else {
                    ProgressFirstRunView(start: start)
                        .appears(reduceMotion)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, Metric.row)
            .padding(.bottom, Metric.section)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(item: $presentedPlan) { plan in
            WorkoutView(plan: plan)
        }
        .onAppear {
            Haptics.warmUp()
            refresh()
        }
        .onChange(of: records.count) { _, _ in refresh() }
        .onChange(of: selectedRange) { _, _ in refresh() }
        // Only the day boundary needs watching, and once a minute is plenty for
        // that. It used to redraw the entire tab on the same schedule.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                refresh()
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        ProgressHero(overview: snapshot.overview)

        ActivityChartCard(
            days: snapshot.chartDays,
            range: $selectedRange,
            selectedDate: $selectedDate,
            calendar: localCalendar,
            availableRanges: snapshot.availableRanges
        )

        WeeklyComparisonCard(overview: snapshot.overview)

        ActivityGridCard(
            days: snapshot.activityDays,
            calendar: localCalendar,
            allRecords: records
        )

        // The coarse split first, and only once there is more than one part of
        // the body in the history: to an athlete training their core alone this
        // card would be a single full-width bar saying "abdomen, 100%".
        if snapshot.areas.count > 1 {
            AreaBalanceCard(items: snapshot.areas, trained: appModel.preferences.trainedAreas)
                .appears(reduceMotion)
        }

        // A single-colour bar and a one-line legend say nothing about balance,
        // so the card waits until there are two jobs to compare.
        if snapshot.patterns.count > 1 {
            PatternBalanceCard(items: snapshot.patterns)
                .appears(reduceMotion)
        }

        if snapshot.bests.totalSessions >= PersonalRecordsCard.minimumSessions {
            PersonalRecordsCard(records: snapshot.bests)
                .appears(reduceMotion)
        } else {
            // Stated where the card will be, so the gap reads as a screen still
            // filling up rather than a section that failed to load.
            Text("Vos records apparaissent à partir de trois séances.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }

        if snapshot.focus.count > 1 {
            FocusDistributionCard(items: snapshot.focus)
                .appears(reduceMotion)
        }

        RecentWorkoutsCard(workouts: snapshot.recent, calendar: localCalendar)
    }

    /// The one action the tab has, and only while there is nothing to look at.
    private func start() {
        Haptics.begin()
        presentedPlan = appModel.makeTodayWorkout(records: records)
    }

    private func refresh() {
        let calendar = localCalendar
        let now = Date.now
        let qualifying = WorkoutHistoryAnalytics(calendar: calendar).qualifyingRecords(from: records)
        let ranges = ProgressRange.available(
            historySpanDays: ProgressSnapshot.span(of: qualifying, calendar: calendar, now: now)
        )
        // Picked before the passes run, so a range the history cannot fill is
        // never the one the chart is built from — assigning it afterwards would
        // show the sparse chart for a frame and then replace it.
        let range = ranges.contains(selectedRange) ? selectedRange : (ranges.last ?? .week)
        let fresh = ProgressSnapshot.make(
            records: records,
            range: range.dayCount,
            calendar: calendar,
            now: now
        )
        // Animated at the assignment. Every number on this screen already
        // carried `.contentTransition(.numericText())`, but the snapshot was
        // swapped outside any animation — so the modifiers were there and none
        // of them ever played.
        withAnimation(Motion.honouring(reduceMotion, Motion.value)) {
            selectedRange = range
            snapshot = fresh
        }
    }
}

enum ProgressRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }
    var dayCount: Int { rawValue }

    var title: String {
        switch self {
        case .week: "7 j"
        case .month: "30 j"
        case .quarter: "90 j"
        }
    }

    var axisStep: Int {
        switch self {
        case .week: 1
        case .month: 5
        case .quarter: 15
        }
    }

    /// A period is offered once the history reaches into it. Before that the
    /// chart would spend most of its width drawing days that predate the app.
    static func available(historySpanDays: Int) -> [ProgressRange] {
        allCases.filter { $0 == .week || historySpanDays > $0.previous }
    }

    private var previous: Int {
        switch self {
        case .week: 0
        case .month: ProgressRange.week.dayCount
        case .quarter: ProgressRange.month.dayCount
        }
    }
}

// MARK: - First run

/// What the tab is before there is anything to look back on.
///
/// It used to render the whole screen against an empty store: a hero reading
/// "0 jours" over three more zeros, then a chart five hundred points tall with
/// axis labels and no bars, then cards of dashes. It is the first thing a new
/// athlete sees, and it read as a report card on work they had not yet had the
/// chance to do. What replaced it names the three sections that will appear and
/// the one action that fills them.
struct ProgressFirstRunView: View {
    var start: () -> Void

    private static let sections: [(symbol: String, title: String, detail: String)] = [
        ("chart.bar.fill", "Temps actif", "Vos minutes, jour par jour."),
        ("square.grid.3x3.fill", "Régularité", "Cinq semaines, un carré par jour."),
        ("trophy.fill", "Vos records", "La plus longue série, la meilleure semaine.")
    ]

    var body: some View {
        VStack(spacing: Metric.section) {
            VStack(spacing: Metric.row) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.haraHero, in: Circle())
                    .shadow(color: .haraCoral.opacity(0.3), radius: 16, y: 8)
                    .accessibilityHidden(true)

                Text("Aucune séance terminée")
                    .font(.haraCardTitle)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Metric.section)

            VStack(alignment: .leading, spacing: Metric.cardPadding) {
                SectionHeader(title: "Ce que vous verrez ici")

                ForEach(Self.sections, id: \.title) { section in
                    HStack(alignment: .top, spacing: Metric.row) {
                        Image(systemName: section.symbol)
                            .font(.subheadline)
                            .foregroundStyle(Color.haraCoral)
                            .frame(width: 30, height: 30)
                            .background(
                                Color.haraCoral.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title).font(.subheadline.weight(.semibold))
                            Text(section.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(Metric.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()

            Button("Commencer une séance", action: start)
                .buttonStyle(.haraPrimary)
        }
    }
}

// MARK: - Hero

/// Presentation components below are internal rather than file-private so
/// `ProgressVisualTests` can rasterise them directly.
struct ProgressHero: View {
    let overview: WorkoutHistoryOverview

    private var streakUnit: String { overview.currentStreak == 1 ? "jour" : "jours" }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.section) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Série en cours")
                        .textCase(.uppercase)
                        .font(.haraEyebrow)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(alignment: .lastTextBaseline, spacing: 7) {
                        Text("\(overview.currentStreak)")
                            .font(.haraDisplay)
                            .contentTransition(.numericText())
                        Text(streakUnit)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                    // Only when it is true, and phrased as the thing to do
                    // rather than as a comment on the zero above it.
                    if overview.currentStreak == 0 {
                        Text("Une séance aujourd’hui la relance.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: Metric.row)

                ZStack {
                    Circle().fill(.white.opacity(0.12))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(overview.currentStreak > 0 ? Color.haraOrange : .white.opacity(0.3))
                        // Only alight when there is a streak behind it. It used
                        // to pulse on day zero too, which promises something the
                        // number underneath immediately takes back.
                        .symbolEffect(
                            .pulse,
                            options: .repeating.speed(0.35),
                            isActive: overview.currentStreak > 0
                        )
                }
                .frame(width: 66, height: 66)
                .accessibilityHidden(true)
            }

            // Three different quantities rather than three ways of saying the
            // same one: the strip used to put total minutes next to minutes per
            // day, which is one figure and its own average.
            HStack(spacing: 0) {
                HeroMetric(value: "\(overview.totalSessions)", label: "séances")
                Divider().overlay(.white.opacity(0.22)).frame(height: 36)
                HeroMetric(value: overview.totalActiveMinutes.formatted(), label: "minutes")
                Divider().overlay(.white.opacity(0.22)).frame(height: 36)
                HeroMetric(value: "\(overview.activeDays)", label: "jours actifs")
            }
        }
        .padding(Metric.section)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous)
                .fill(.haraNight)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.haraCoral.opacity(0.24))
                        .frame(width: 170, height: 170)
                        .blur(radius: 35)
                        .offset(x: 48, y: -72)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous))
        .shadow(color: .haraIndigo.opacity(0.25), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
    }
}

struct HeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Activity chart

struct ActivityChartCard: View {
    let days: [WorkoutHistoryDay]
    @Binding var range: ProgressRange
    @Binding var selectedDate: Date?
    let calendar: Calendar
    var availableRanges: [ProgressRange] = ProgressRange.allCases

    private var selectedDay: WorkoutHistoryDay? {
        guard let selectedDate else { return nil }
        return days.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var activeDays: [WorkoutHistoryDay] { days.filter(\.isActive) }

    private var totalMinutes: Int {
        Int((days.reduce(0.0) { $0 + $1.activeMinutes }).rounded())
    }

    /// The header carries either the period or the day under the finger. Health
    /// reads the same way, and it keeps a floating annotation from colliding
    /// with the top of the plot on a tall bar.
    private var summary: String {
        if let selectedDay {
            let date = selectedDay.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return "\(date) · \(Int(selectedDay.activeMinutes.rounded())) min"
        }
        return "\(totalMinutes) min · \(activeDays.count) jour\(activeDays.count == 1 ? "" : "s") actif\(activeDays.count == 1 ? "" : "s")"
    }

    private var yMaximum: Double {
        max(10, (days.map(\.activeMinutes).max() ?? 0) * 1.25)
    }

    private var axisDates: [Date] {
        days.enumerated().compactMap { index, day in
            index.isMultiple(of: range.axisStep) || index == days.count - 1 ? day.date : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.row) {
            SectionHeader(title: "Temps actif", subtitle: summary)

            if availableRanges.count > 1 {
                Picker("Période", selection: $range) {
                    ForEach(availableRanges) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: range) { _, _ in
                    Haptics.selection()
                    selectedDate = nil
                }
            }

            if activeDays.isEmpty {
                // A plot with axis labels and no bars is the single most
                // discouraging thing this screen could draw, so it does not.
                Text("Aucune séance sur cette période.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
            } else {
                chart
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Jour", day.date, unit: .day),
                    y: .value("Minutes", day.activeMinutes)
                )
                .foregroundStyle(barStyle(for: day))
                .cornerRadius(5)
            }

            if let selectedDay {
                RuleMark(x: .value("Sélection", selectedDay.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        .frame(height: 210)
        .chartYScale(domain: 0...yMaximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(.secondary.opacity(0.14))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        if range == .week {
                            Text(date, format: .dateTime.weekday(.narrow))
                        } else {
                            Text(date, format: .dateTime.day())
                        }
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDay?.id)
        .accessibilityLabel("Graphique du temps actif sur \(range.dayCount) jours")
    }

    /// Everything but the day under the finger steps back, which is what ties
    /// the figure in the header to a bar on the plot.
    private func barStyle(for day: WorkoutHistoryDay) -> AnyShapeStyle {
        guard day.isActive else { return AnyShapeStyle(Color.secondary.opacity(0.12).gradient) }
        guard let selectedDay, selectedDay.id != day.id else {
            return AnyShapeStyle(Color.haraCoral.gradient)
        }
        return AnyShapeStyle(Color.haraCoral.opacity(0.28).gradient)
    }
}

// MARK: - This week

struct WeeklyComparisonCard: View {
    let overview: WorkoutHistoryOverview

    private var currentMinutes: Int { overview.currentWeekSeconds / 60 }
    private var previousMinutes: Int { overview.previousWeekSeconds / 60 }

    var body: some View {
        HStack(spacing: Metric.cardPadding) {
            Image(systemName: comparisonSymbol)
                .font(.title2.bold())
                .foregroundStyle(comparisonTint)
                .frame(width: 54, height: 54)
                .background(
                    comparisonTint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Cette semaine")
                    .font(.headline)
                Text(comparisonDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Metric.row)

            Text("\(currentMinutes) min")
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .padding(Metric.cardPadding)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cette semaine, \(currentMinutes) minutes. \(comparisonDescription)")
    }

    private var comparisonDescription: String {
        guard let change = overview.weeklyChange else {
            // No previous week to compare against. It used to answer that with
            // "Une séance suffit pour démarrer", which is an advertising line
            // on a card whose whole job is to report a figure.
            return currentMinutes > 0 ? "Votre première semaine active" : "Pas encore de séance cette semaine"
        }
        let percent = Int((abs(change) * 100).rounded())
        if percent == 0 { return "Même rythme que la semaine passée" }
        return change > 0
            ? "+\(percent) % sur les \(previousMinutes) min de la semaine passée"
            : "\(percent) % sous les \(previousMinutes) min de la semaine passée"
    }

    private var comparisonSymbol: String {
        guard let change = overview.weeklyChange else { return "sparkles" }
        return change >= 0 ? "arrow.up.right" : "arrow.right"
    }

    private var comparisonTint: Color {
        guard let change = overview.weeklyChange else { return .haraBlue }
        return change >= 0 ? .haraMint : .haraOrange
    }
}

// MARK: - Regularity

struct ActivityGridCard: View {
    let days: [WorkoutHistoryDay]
    let calendar: Calendar
    var allRecords: [WorkoutRecord] = []

    @State private var selected: WorkoutHistoryDay?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    /// The grid is a calendar, so its columns have to be weekdays. Laid out as
    /// a plain run of the last thirty-five days, column four meant nothing —
    /// every square sat under whichever weekday the run happened to start on,
    /// and the shape of a week was invisible.
    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first.date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7 else { return [] }
        let offset = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(offset + $0) % 7] }
    }

    private var activeCount: Int { days.count(where: \.isActive) }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardPadding) {
            SectionHeader(
                title: "Régularité",
                subtitle: "\(activeCount) jour\(activeCount == 1 ? "" : "s") actif\(activeCount == 1 ? "" : "s") sur \(days.count)"
            )

            LazyVGrid(columns: columns, spacing: 7) {
                // Keyed by position, not by the symbol: French very-short
                // weekdays are D L M M J V S, and two identical ids in a
                // `ForEach` drop a column.
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                ForEach(days) { day in
                    Button {
                        guard day.activeSeconds > 0 else { return }
                        Haptics.tap()
                        selected = day
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(activityColor(for: day))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if calendar.isDateInToday(day.date) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.haraCoral, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.card)
                    .disabled(day.activeSeconds == 0)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayLabel(day))
                    .accessibilityAddTraits(day.activeSeconds > 0 ? .isButton : [])
                }
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
        .sheet(item: $selected) { day in
            DayDetailView(day: day, records: records(on: day.date))
        }
    }

    private func records(on date: Date) -> [WorkoutRecord] {
        allRecords.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }

    private func activityColor(for day: WorkoutHistoryDay) -> Color {
        guard day.activeSeconds > 0 else { return .secondary.opacity(0.1) }
        switch day.activeSeconds {
        case ..<300: return .haraCoral.opacity(0.35)
        case ..<480: return .haraCoral.opacity(0.58)
        case ..<720: return .haraCoral.opacity(0.78)
        default: return .haraCoral
        }
    }

    private func dayLabel(_ day: WorkoutHistoryDay) -> String {
        let date = day.date.formatted(date: .long, time: .omitted)
        guard day.activeSeconds > 0 else { return "\(date), repos" }
        return "\(date), \(day.activeSeconds / 60) minutes actives"
    }
}

// MARK: - Balance

/// How the work has been split across the body.
///
/// Reads the athlete's own switches as well as the history, so an area they
/// train and have not touched is named rather than being absent — an empty
/// space looks the same as a bar of zero width, and only one of those is a
/// thing you can act on.
struct AreaBalanceCard: View {
    let items: [AreaLoad]
    let trained: Set<BodyArea>

    private var total: Int { max(1, items.reduce(0) { $0 + $1.activeSeconds }) }

    private var untouched: [BodyArea] {
        let worked = Set(items.map(\.area))
        return BodyArea.ordered(trained.subtracting(worked))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardPadding) {
            SectionHeader(title: "Répartition du corps", subtitle: "Temps actif par zone")

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(items) { item in
                        Capsule()
                            .fill(item.area.color)
                            .frame(width: max(6, proxy.size.width * CGFloat(item.activeSeconds) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 14)

            VStack(spacing: Metric.row) {
                ForEach(items) { item in
                    HStack(spacing: 9) {
                        Image(systemName: item.area.symbol)
                            .font(.caption)
                            .foregroundStyle(item.area.color)
                            .frame(width: 18)
                        Text(item.area.title).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(item.sessions) séance\(item.sessions == 1 ? "" : "s")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Text("\(item.activeMinutes) min")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .contentTransition(.numericText())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !untouched.isEmpty {
                Divider()
                Text("Activé mais jamais travaillé : \(untouched.map(\.title).joined(separator: ", ")).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
        .accessibilityElement(children: .contain)
    }
}

/// How the work has been split across the jobs of the trunk, so a month of
/// nothing but crunches is visible rather than something you have to remember.
struct PatternBalanceCard: View {
    let items: [PatternLoad]

    private var total: Int { max(1, items.reduce(0) { $0 + $1.activeSeconds }) }

    /// The jobs no session has touched. They are the whole point of the card
    /// and they were the one thing it could not show: `patternLoad` only
    /// returns patterns with work behind them, so a gap looked like a shorter
    /// list rather than a gap.
    private var untouched: [CorePattern] {
        let trained = Set(items.map(\.pattern))
        return CorePattern.allCases.filter { !trained.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardPadding) {
            SectionHeader(title: "Équilibre du travail", subtitle: "Temps actif par type d’effort")

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(items) { item in
                        Capsule()
                            .fill(item.pattern.color)
                            .frame(width: max(6, proxy.size.width * CGFloat(item.activeSeconds) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 14)

            VStack(spacing: Metric.row) {
                ForEach(items) { item in
                    HStack(spacing: 9) {
                        Circle().fill(item.pattern.color).frame(width: 9, height: 9)
                        Text(item.pattern.title).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(item.activeMinutes) min")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .contentTransition(.numericText())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !untouched.isEmpty {
                Divider()
                Text("Jamais travaillé : \(untouched.map(\.title).joined(separator: ", ")).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Records

/// The bests, which is the part of a history worth coming back for.
struct PersonalRecordsCard: View {
    let records: PersonalRecords

    /// Below this every tile reads "1", and a record you set by turning up once
    /// is not a record.
    static let minimumSessions = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardPadding) {
            SectionHeader(
                title: "Vos records",
                subtitle: "Sur \(records.totalSessions) séances terminées"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Metric.row) {
                record("flame.fill", "\(records.longestStreak)", "jours d’affilée")
                record("calendar", "\(records.bestWeekMinutes)", "min sur 7 jours")
                record("timer", "\(records.longestSessionMinutes)", "min en une séance")
                record("bolt.fill", "\(records.busiestDaySessions)", "séances en un jour")
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
    }

    private func record(_ symbol: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: Metric.row) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.haraCoral)
                .frame(width: 34, height: 34)
                .background(
                    Color.haraCoral.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Focus

struct FocusDistributionCard: View {
    let items: [WorkoutFocusBreakdown]

    private var total: Int { items.reduce(0) { $0 + $1.sessionCount } }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.cardPadding) {
            SectionHeader(title: "Vos priorités", subtitle: "Répartition des séances terminées")

            HStack(spacing: Metric.cardPadding) {
                ZStack {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Séances", item.sessionCount),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(item.zone.color)
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)

                    // The hole in a donut is the one place a total can sit
                    // without adding a line to the card.
                    VStack(spacing: 0) {
                        Text("\(total)")
                            .font(.title3.bold().monospacedDigit())
                            .contentTransition(.numericText())
                        Text("séances")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 142, height: 142)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Répartition des priorités musculaires, \(total) séances")

                VStack(alignment: .leading, spacing: Metric.row) {
                    ForEach(items.prefix(4)) { item in
                        HStack(spacing: 8) {
                            Circle().fill(item.zone.color).frame(width: 8, height: 8)
                            Text(item.zone.shortTitle)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(item.sessionCount)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .contentTransition(.numericText())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
    }
}

// MARK: - Recent sessions

private struct RecentWorkoutsCard: View {
    let workouts: [RecentWorkout]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.row) {
            SectionHeader(title: "Séances récentes")

            ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                RecentWorkoutRow(workout: workout, calendar: calendar)
                if index < workouts.count - 1 { Divider().padding(.leading, 54) }
            }
        }
        .padding(Metric.cardPadding)
        .glassCard()
    }
}

private struct RecentWorkoutRow: View {
    let workout: RecentWorkout
    let calendar: Calendar

    var body: some View {
        HStack(spacing: Metric.row) {
            Image(systemName: workout.section.symbol)
                .font(.headline)
                .foregroundStyle(workout.section.color)
                .frame(width: 42, height: 42)
                .background(
                    workout.section.color.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Metric.Radius.small, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(dayText)
                        .font(.subheadline.weight(.semibold))
                    if !workout.wasCompleted {
                        Text("Écourtée")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(Color.haraOrange.opacity(0.16), in: Capsule())
                            .foregroundStyle(Color.haraOrange)
                    }
                }
                // Three secondary figures on one line rather than a strip of
                // icons: on this card the session's identity is the row above,
                // and these only qualify it.
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            Text(workout.activeSeconds.clockText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayText), \(metadata), \(workout.activeSeconds / 60) minutes")
    }

    private var dayText: String {
        let time = workout.completedAt.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(workout.completedAt) { return "Aujourd’hui, \(time)" }
        if calendar.isDateInYesterday(workout.completedAt) { return "Hier, \(time)" }
        return workout.completedAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private var metadata: String {
        let movements = "\(workout.movementCount) mouvement\(workout.movementCount == 1 ? "" : "s")"
        return "\(workout.difficulty.title) · \(movements) · ≈\(workout.calories) kcal"
    }
}

// MARK: - One day

/// One day of the activity grid, opened.
///
/// The grid used to be the only thing on this tab with any density and nothing
/// to say when you touched it — a square that is darker than its neighbour
/// raises a question the screen refused to answer.
struct DayDetailView: View {
    let day: WorkoutHistoryDay
    let records: [WorkoutRecord]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metric.section) {
                    // A strip is right here and nowhere else on this tab: these
                    // three figures are the entire content of the sheet.
                    HStack(spacing: 0) {
                        MetricPill(icon: "clock.fill", value: day.activeSeconds.clockText, label: "effort")
                        Divider().frame(height: 44)
                        MetricPill(
                            icon: "figure.core.training",
                            value: "\(day.sessionCount)",
                            label: day.sessionCount > 1 ? "séances" : "séance"
                        )
                        Divider().frame(height: 44)
                        MetricPill(icon: "flame.fill", value: "≈\(day.calories)", label: "kcal")
                    }
                    .padding(.vertical, 14)
                    .glassCard()

                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: Metric.row) {
                            HStack {
                                Text(record.completedAt, format: .dateTime.hour().minute())
                                    .font(.headline)
                                Spacer()
                                if !record.wasCompleted {
                                    Text("Écourtée")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 9)
                                        .frame(height: 22)
                                        .background(Color.haraOrange.opacity(0.16), in: Capsule())
                                        .foregroundStyle(Color.haraOrange)
                                }
                                Text(record.difficulty.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                Label(record.activeDuration.clockText, systemImage: "timer")
                                if record.perceivedEffort != .unrated {
                                    Label(record.perceivedEffort.title, systemImage: record.perceivedEffort.symbol)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            let movements = record.exerciseIDs.compactMap { ExerciseCatalog.byID[$0] }
                            if !movements.isEmpty {
                                Divider()
                                ForEach(Array(movements.enumerated()), id: \.offset) { _, movement in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(movement.accent.opacity(0.16))
                                            .frame(width: 26, height: 26)
                                            .overlay {
                                                Image(systemName: CatalogSection.of(movement).symbol)
                                                    .font(.caption2)
                                                    .foregroundStyle(movement.accent)
                                            }
                                        Text(movement.name).font(.subheadline)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                        .padding(Metric.cardPadding)
                        .glassCard()
                    }
                }
                .padding(Metric.gutter)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
    }
}
