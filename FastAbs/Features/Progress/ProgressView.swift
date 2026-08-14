import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.calendar) private var environmentCalendar
    @State private var selectedRange = ProgressRange.month
    @State private var selectedDate: Date?

    private var localCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let analytics = WorkoutHistoryAnalytics(calendar: localCalendar)
            let overview = analytics.overview(records: records, now: context.date)
            let chartDays = analytics.days(
                records: records,
                endingAt: context.date,
                count: selectedRange.dayCount
            )
            let activityDays = analytics.days(records: records, endingAt: context.date, count: 35)
            let focus = analytics.focusBreakdown(records: records)
            let regions = analytics.regionLoad(records: records)
            let bests = analytics.personalRecords(records: records)

            ScrollView {
                LazyVStack(spacing: 24) {
                    ProgressHero(overview: overview)

                    ActivityChartCard(
                        days: chartDays,
                        range: $selectedRange,
                        selectedDate: $selectedDate,
                        calendar: localCalendar
                    )

                    WeeklyComparisonCard(overview: overview)

                    ActivityGridCard(days: activityDays, calendar: localCalendar)

                    if !regions.isEmpty {
                        RegionBalanceCard(items: regions)
                    }

                    if bests.hasAny {
                        PersonalRecordsCard(records: bests)
                    }

                    if !focus.isEmpty {
                        FocusDistributionCard(items: focus)
                    }

                    RecentWorkoutsCard(records: Array(records.prefix(5)))
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }
}

private enum ProgressRange: Int, CaseIterable, Identifiable {
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
}

/// How the work has been split across the body, so a run of leg sessions is
/// visible rather than something you have to remember.
struct RegionBalanceCard: View {
    let items: [RegionLoad]

    private var total: Int { max(1, items.reduce(0) { $0 + $1.activeSeconds }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Équilibre du corps", subtitle: "Temps actif par zone")

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(items) { item in
                        Capsule()
                            .fill(tint(for: item.region))
                            .frame(width: max(6, proxy.size.width * CGFloat(item.activeSeconds) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 14)

            VStack(spacing: 9) {
                ForEach(items) { item in
                    HStack(spacing: 9) {
                        Circle().fill(tint(for: item.region)).frame(width: 9, height: 9)
                        Text(item.region.title).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(item.activeMinutes) min")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private func tint(for region: BodyRegion) -> Color {
        switch region {
        case .core: .fastCoral
        case .upperBody: .fastBlue
        case .lowerBody: .fastMint
        }
    }
}

/// The bests, which is the part of a history worth coming back for.
struct PersonalRecordsCard: View {
    let records: PersonalRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Vos records", subtitle: "Le meilleur que vous ayez fait")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                record("flame.fill", "\(records.longestStreak)", "jours d’affilée")
                record("calendar", "\(records.bestWeekMinutes)", "min sur 7 jours")
                record("timer", "\(records.longestSessionMinutes)", "min en une séance")
                record("bolt.fill", "\(records.busiestDaySessions)", "séances en un jour")
            }
        }
        .padding(18)
        .glassCard()
    }

    private func record(_ symbol: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.fastCoral)
                .frame(width: 34, height: 34)
                .background(Color.fastCoral.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.weight(.bold).monospacedDigit())
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// Presentation components below are internal rather than file-private so
/// `BadgeVisualTests` and `ProgressVisualTests` can rasterise them directly.
struct ProgressHero: View {
    let overview: WorkoutHistoryOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Votre constance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("\(overview.currentStreak) jour\(overview.currentStreak == 1 ? "" : "s")")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                ZStack {
                    Circle().fill(.white.opacity(0.12))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.fastOrange)
                        .symbolEffect(.pulse, options: .repeating.speed(0.35))
                }
                .frame(width: 66, height: 66)
                .accessibilityHidden(true)
            }

            HStack(spacing: 0) {
                HeroMetric(value: "\(overview.totalActiveMinutes)", label: "minutes")
                Divider().overlay(.white.opacity(0.22)).frame(height: 36)
                HeroMetric(value: "\(overview.currentMonthSessions)", label: "ce mois")
                Divider().overlay(.white.opacity(0.22)).frame(height: 36)
                HeroMetric(value: "\(overview.averageMinutesPerActiveDay)", label: "min / jour")
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.fastNight)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.fastCoral.opacity(0.24))
                        .frame(width: 170, height: 170)
                        .blur(radius: 35)
                        .offset(x: 48, y: -72)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .fastIndigo.opacity(0.25), radius: 22, y: 10)
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
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

private struct ActivityChartCard: View {
    let days: [WorkoutHistoryDay]
    @Binding var range: ProgressRange
    @Binding var selectedDate: Date?
    let calendar: Calendar

    private var selectedDay: WorkoutHistoryDay? {
        guard let selectedDate else { return nil }
        return days.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
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
        VStack(alignment: .leading, spacing: 17) {
            SectionHeader(title: "Temps actif", subtitle: "Minutes par jour")

            Picker("Période", selection: $range) {
                ForEach(ProgressRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: range) { _, _ in selectedDate = nil }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Jour", day.date, unit: .day),
                        y: .value("Minutes", day.activeMinutes)
                    )
                    .foregroundStyle(
                        day.isActive
                            ? Color.fastCoral.gradient
                            : Color.secondary.opacity(0.12).gradient
                    )
                    .cornerRadius(5)
                }

                if let selectedDay {
                    RuleMark(x: .value("Sélection", selectedDay.date, unit: .day))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, spacing: 4) {
                            ChartSelectionLabel(day: selectedDay)
                        }
                }
            }
            .frame(height: 220)
            .chartYScale(domain: 0...yMaximum)
            .chartYAxis {
                AxisMarks(position: .leading) {
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
        .padding(18)
        .glassCard()
    }
}

private struct ChartSelectionLabel: View {
    let day: WorkoutHistoryDay

    var body: some View {
        VStack(spacing: 1) {
            Text(day.date, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(day.activeMinutes.rounded())) min")
                .font(.caption.bold().monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct WeeklyComparisonCard: View {
    let overview: WorkoutHistoryOverview

    private var currentMinutes: Int { overview.currentWeekSeconds / 60 }
    private var previousMinutes: Int { overview.previousWeekSeconds / 60 }

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: comparisonSymbol)
                .font(.title2.bold())
                .foregroundStyle(comparisonTint)
                .frame(width: 54, height: 54)
                .background(comparisonTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Cette semaine")
                    .font(.headline)
                Text(comparisonDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(currentMinutes) min")
                .font(.title3.bold().monospacedDigit())
        }
        .padding(18)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cette semaine, \(currentMinutes) minutes. \(comparisonDescription)")
    }

    private var comparisonDescription: String {
        guard let change = overview.weeklyChange else {
            return currentMinutes > 0 ? "Votre première semaine active" : "Une séance suffit pour démarrer"
        }
        let percent = Int((abs(change) * 100).rounded())
        if percent == 0 { return "Même rythme que la semaine passée" }
        return change > 0 ? "+\(percent) % sur la semaine passée" : "\(percent) % sous la semaine passée"
    }

    private var comparisonSymbol: String {
        guard let change = overview.weeklyChange else { return "sparkles" }
        return change >= 0 ? "arrow.up.right" : "arrow.right"
    }

    private var comparisonTint: Color {
        guard let change = overview.weeklyChange else { return .fastBlue }
        return change >= 0 ? .fastMint : .fastOrange
    }
}

struct ActivityGridCard: View {
    let days: [WorkoutHistoryDay]
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Régularité", subtitle: "Vos cinq dernières semaines")

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(activityColor(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if calendar.isDateInToday(day.date) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.fastCoral, lineWidth: 2)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dayLabel(day))
                }
            }

            HStack(spacing: 6) {
                Text("Repos")
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level == 0 ? Color.secondary.opacity(0.1) : Color.fastCoral.opacity(0.2 + Double(level) * 0.2))
                        .frame(width: 14, height: 14)
                }
                Text("Actif")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .glassCard()
    }

    private func activityColor(for day: WorkoutHistoryDay) -> Color {
        guard day.activeSeconds > 0 else { return .secondary.opacity(0.1) }
        switch day.activeSeconds {
        case ..<300: return .fastCoral.opacity(0.35)
        case ..<480: return .fastCoral.opacity(0.58)
        case ..<720: return .fastCoral.opacity(0.78)
        default: return .fastCoral
        }
    }

    private func dayLabel(_ day: WorkoutHistoryDay) -> String {
        let date = day.date.formatted(date: .long, time: .omitted)
        guard day.activeSeconds > 0 else { return "\(date), repos" }
        return "\(date), \(day.activeSeconds / 60) minutes actives"
    }
}

struct FocusDistributionCard: View {
    let items: [WorkoutFocusBreakdown]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Vos priorités", subtitle: "Répartition des séances terminées")

            HStack(spacing: 20) {
                Chart(items) { item in
                    SectorMark(
                        angle: .value("Séances", item.sessionCount),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(item.zone.color)
                    .cornerRadius(4)
                }
                .frame(width: 142, height: 142)
                .chartLegend(.hidden)
                .accessibilityLabel("Répartition des priorités musculaires")

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(items.prefix(4)) { item in
                        HStack(spacing: 8) {
                            Circle().fill(item.zone.color).frame(width: 8, height: 8)
                            Text(item.zone.shortTitle)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(item.sessionCount)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct RecentWorkoutsCard: View {
    let records: [WorkoutRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Séances récentes")

            if records.isEmpty {
                ContentUnavailableView(
                    "Aucune séance",
                    systemImage: "figure.core.training",
                    description: Text("Votre historique se construira ici.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    RecentWorkoutRow(record: record)
                    if index < records.count - 1 { Divider().padding(.leading, 54) }
                }
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct RecentWorkoutRow: View {
    let record: WorkoutRecord

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "figure.core.training")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.fastHero, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.difficulty.title)
                    .font(.headline)
                Text(record.completedAt, format: .dateTime.day().month(.wide).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(durationDescription(record.activeDuration))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Séance \(record.difficulty.title), \(durationDescription(record.activeDuration)), le \(record.completedAt.formatted(date: .long, time: .shortened))")
    }

    private func durationDescription(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", remainder))"
    }
}
