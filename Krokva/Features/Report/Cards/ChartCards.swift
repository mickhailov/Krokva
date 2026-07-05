import Charts
import SwiftUI

private let comparisonCityAveragePosition: CGFloat = 0.50

// MARK: - PermitActivityCard

struct PermitActivityCard: View {
    let activity: [YearCount]
    var sourceFailed = false

    var body: some View {
        ReportCard(title: "Neighbourhood permit activity", systemImage: "chart.xyaxis.line", iconColor: .cleanAmber) {
            if activity.isEmpty {
                Text(sourceFailed ? "Database error loading neighbourhood permit activity." : "Permit trend data is unavailable.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            } else {
                Chart(activity) { item in
                    LineMark(x: .value("Year", String(item.year)), y: .value("Permits", item.count))
                        .foregroundStyle(Color.cleanAmber)
                    PointMark(x: .value("Year", String(item.year)), y: .value("Permits", item.count))
                        .foregroundStyle(Color.cleanAmber)
                }
                .frame(height: 180)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: activity.map { String($0.year) }) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(Color.cleanSep.opacity(0.6))
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel("Line chart of permits issued per year.")
            }
        }
    }
}

// MARK: - EmergencyActivityCard

struct EmergencyActivityCard: View {
    let summary: EmergencySummary?
    var substances: [IncidentBreakdown] = []
    var sourceFailed = false
    @State private var isExpanded = false
    @Environment(\.reportPDFRender) private var pdfRender
    @State private var selectedYear: Int?

    private func activeYear(for summary: EmergencySummary) -> Int? {
        if let selectedYear, summary.yearlyCalls.contains(where: { $0.year == selectedYear }) {
            return selectedYear
        }
        return summary.yearlyCalls.last?.year
    }

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded || pdfRender {
                    Divider()
                    fullContent
                        .padding(18)
                }
            }
        }
    }

    // MARK: Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cross.case")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanRed, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency response")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(smallSummary)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var smallSummary: String {
        guard let s = summary else { return sourceFailed ? "Database error" : "Unavailable" }
        guard hasEmergencyData(s) else { return sourceFailed ? "Database error" : "Unavailable" }
        let medical = s.last12Months.first { $0.incidentType.localizedCaseInsensitiveContains("medical") }
        let fire = s.last12Months.first { $0.incidentType.localizedCaseInsensitiveContains("fire") }
        var parts: [String] = []
        if let medical { parts.append("\(medical.count.formatted()) medical") }
        if let fire { parts.append("\(fire.count.formatted()) fire") }
        if parts.isEmpty { return "\(s.totalLastYear.formatted()) calls" }
        return parts.joined(separator: " · ") + " · \(s.totalLastYear.formatted()) total"
    }

    // MARK: Full content

    @ViewBuilder
    private var fullContent: some View {
        if let summary, hasEmergencyData(summary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(label: "Last 12 months", value: summary.totalLastYear.formatted())
                    StatTile(label: "Vehicle involved", value: summary.motorVehicleLastYear.formatted())
                }
                yearlyChartSection(for: summary)
                monthlyTrendSection(for: summary)
                incidentTypesSection(for: summary)
                breakdownGridSection(for: summary)
                substanceSection
                Text("WFPS calls are shown as \(summary.neighbourhood) municipal activity records, not as an address-level safety score.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
            }
        } else if sourceFailed {
            Text("Database error loading emergency response activity.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        } else {
            Text("Emergency response activity is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }

    private func hasEmergencyData(_ summary: EmergencySummary) -> Bool {
        !summary.yearlyCalls.isEmpty || !summary.last12Months.isEmpty || !summary.recentIncidents.isEmpty
    }

    @ViewBuilder
    private func yearlyChartSection(for summary: EmergencySummary) -> some View {
        if !summary.yearlyCalls.isEmpty {
            let active = activeYear(for: summary)
            let years = summary.yearlyCalls.map(\.year)
            let yearLabels = years.map(String.init)
            let hasCityAverage = summary.yearlyCalls.contains { $0.citywideAverage > 0 }
            Chart(summary.yearlyCalls) { item in
                BarMark(x: .value("Year", String(item.year)), y: .value("Calls", item.count))
                    .foregroundStyle(item.year == active ? Color.cleanAmber : Color.cleanSky.opacity(0.7))

                if hasCityAverage {
                    LineMark(
                        x: .value("Year", String(item.year)),
                        y: .value("City neighbourhood average", item.citywideAverage)
                    )
                    .foregroundStyle(Color.cleanIndigo)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                    PointMark(
                        x: .value("Year", String(item.year)),
                        y: .value("City neighbourhood average", item.citywideAverage)
                    )
                    .foregroundStyle(item.year == active ? Color.cleanIndigo : Color.cleanLabel3)
                    .symbolSize(item.year == active ? 120 : 55)
                }
            }
            .frame(height: 180)
            .chartXScale(domain: yearLabels)
            .chartYScale(domain: 0...chartMaxValue(for: summary))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard let plotFrameAnchor = proxy.plotFrame else { return }
                                    let plotFrame = geometry[plotFrameAnchor]
                                    selectedYear = year(at: value.location.x, in: plotFrame, years: years)
                                }
                        )
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: yearLabels) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.cleanSep.opacity(0.6))
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .accessibilityLabel("Selectable bar chart of fire and medical calls by year, compared with the city neighbourhood average.")

            if hasCityAverage, let item = active.flatMap(yearCall(for: summary)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(item.year) \(summary.neighbourhood)").eyebrow(color: .cleanLabel3)
                        Spacer()
                        Text("\(item.count.formatted()) calls")
                            .font(KrokvaTypography.monoBold)
                            .foregroundStyle(Color.cleanLabel)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("City neighbourhood avg").eyebrow(color: .cleanLabel3)
                        Spacer()
                        Text(item.citywideAverage.formatted(.number.precision(.fractionLength(0))) + " calls")
                            .font(KrokvaTypography.monoBold)
                            .foregroundStyle(Color.cleanIndigo)
                    }
                }
            }
        }
    }

    private func yearCall(for summary: EmergencySummary) -> (Int) -> YearCount? {
        { year in summary.yearlyCalls.first { $0.year == year } }
    }

    @ViewBuilder
    private func monthlyTrendSection(for summary: EmergencySummary) -> some View {
        if !summary.monthlyTrend.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent monthly volume").eyebrow(color: .cleanLabel3)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(summary.monthlyTrend.suffix(12)) { item in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.cleanSky.opacity(0.7))
                                .frame(height: monthlyBarHeight(item.count, in: summary.monthlyTrend))
                            Text(item.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.cleanLabel3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(item.label): \(item.count) emergency responses")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func incidentTypesSection(for summary: EmergencySummary) -> some View {
        let active = activeYear(for: summary)
        let selectedBreakdown = active.flatMap { summary.breakdownByYear[$0] } ?? summary.last12Months
        if !selectedBreakdown.isEmpty {
            let hasCityAverage = selectedBreakdown.contains { $0.citywideAverage > 0 }
            VStack(alignment: .leading, spacing: 10) {
                Text(active.map { "Incident types in \($0)" } ?? "Incident types").eyebrow(color: .cleanLabel3)
                if hasCityAverage {
                    ForEach(selectedBreakdown.prefix(8)) { item in
                        comparisonRow(item)
                    }
                    comparisonLegend
                } else {
                    // No city-average context available — fall back to a plain count list.
                    ForEach(selectedBreakdown.prefix(8)) { item in
                        HStack {
                            Text(item.incidentType)
                                .font(KrokvaTypography.bodySecondary)
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer()
                            Text("\(item.count)")
                                .font(KrokvaTypography.monoBold)
                                .foregroundStyle(Color.cleanLabel)
                        }
                    }
                }
            }
        }
    }

    // MARK: Comparison bars (neighbourhood vs city average)

    private func comparisonRow(_ item: IncidentBreakdown) -> some View {
        let aboveAverage = Double(item.count) > item.citywideAverage
        let barColor: Color = aboveAverage ? .cleanRed : .cleanGreen
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.incidentType)
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel2)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(item.count.formatted())
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.cleanLabel)
                Text("avg \(item.citywideAverage.formatted(.number.precision(.fractionLength(0))))")
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.cleanLabel3)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let average = max(item.citywideAverage, 0.0001)
                let fillRatio = min((Double(item.count) / average) * Double(comparisonCityAveragePosition), 1)
                let fillWidth = width * CGFloat(fillRatio)
                let avgX = width * comparisonCityAveragePosition
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule().fill(barColor).frame(width: fillWidth)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.cleanIndigo)
                        .frame(width: 2, height: 12)
                        .offset(x: max(avgX - 1, 0))
                }
            }
            .frame(height: 8)
        }
    }

    private var comparisonLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Capsule().fill(Color.cleanRed).frame(width: 14, height: 6)
                Text("Above city avg").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.cleanGreen).frame(width: 14, height: 6)
                Text("At or below").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1).fill(Color.cleanIndigo).frame(width: 2, height: 12)
                Text("City avg").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
        }
    }

    @ViewBuilder
    private func breakdownGridSection(for summary: EmergencySummary) -> some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                breakdownColumn("Motor vehicle", summary.motorVehicleBreakdown)
                breakdownColumn("Units dispatched", summary.unitBreakdown)
            }
        }
    }

    @ViewBuilder
    private var substanceSection: some View {
        if !substances.isEmpty {
            let sortedSubstances = substances.sorted { $0.count > $1.count }
            let hasCityAverage = sortedSubstances.contains { $0.citywideAverage > 0 }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Substance-related calls").eyebrow(color: .cleanLabel3)
                    Spacer()
                    Text("\(substances.map(\.count).reduce(0, +).formatted()) total")
                        .font(KrokvaTypography.monoSmall)
                        .foregroundStyle(Color.cleanLabel2)
                }
                if hasCityAverage {
                    ForEach(sortedSubstances) { item in
                        comparisonRow(item)
                    }
                    comparisonLegend
                } else {
                    ForEach(sortedSubstances) { item in
                        HStack {
                            Text(item.incidentType)
                                .font(KrokvaTypography.bodySecondary)
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer()
                            Text(item.count.formatted())
                                .font(KrokvaTypography.monoBold)
                                .foregroundStyle(Color.cleanLabel)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func chartMaxValue(for summary: EmergencySummary) -> Double {
        let values = summary.yearlyCalls.flatMap { [Double($0.count), $0.citywideAverage] }
        return max((values.max() ?? 1) * 1.18, 1)
    }

    private func year(at xLocation: CGFloat, in plotFrame: CGRect, years: [Int]) -> Int? {
        guard !years.isEmpty, plotFrame.width > 0 else { return nil }
        guard years.count > 1 else { return years.first }
        let ratio = (min(max(xLocation, plotFrame.minX), plotFrame.maxX) - plotFrame.minX) / plotFrame.width
        return years[min(max(Int((ratio * CGFloat(years.count)).rounded(.down)), 0), years.count - 1)]
    }

    @ViewBuilder
    private func breakdownColumn(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrow(color: .cleanLabel3)
            if items.isEmpty {
                Text("—").font(KrokvaTypography.bodySecondary).foregroundStyle(Color.cleanLabel3)
            } else {
                ForEach(items.prefix(4)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.incidentType)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.cleanLabel2)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(item.count.formatted())
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.cleanLabel)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func monthlyBarHeight(_ value: Int, in values: [EmergencyMonth]) -> CGFloat {
        let maxValue = max(values.map(\.count).max() ?? 1, 1)
        return max(CGFloat(value) / CGFloat(maxValue) * 56, 4)
    }

}

// MARK: - PoliceCrimeCard

struct PoliceCrimeCard: View {
    let summary: PoliceCrimeSummary?
    var sourceFailed = false
    @State private var isExpanded = false
    @Environment(\.reportPDFRender) private var pdfRender
    @State private var selectedYearValue: Int?

    private var activeYear: Int? {
        guard let summary else { return nil }
        if let selectedYearValue, summary.yearlyCounts.contains(where: { $0.year == selectedYearValue }) {
            return selectedYearValue
        }
        return summary.yearlyCounts.last?.year
    }

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded || pdfRender {
                    Divider()
                    fullContent
                        .padding(18)
                }
            }
        }
    }

    // MARK: Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Police crime context")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(smallSummary)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var smallSummary: String {
        if sourceFailed, summary == nil { return "Database error" }
        guard let latest = summary?.yearlyCounts.last, latest.citywideAverage > 0 else {
            return "Unavailable"
        }
        let diff = (Double(latest.neighbourhood) - latest.citywideAverage) / latest.citywideAverage * 100
        let absVal = Int(abs(diff).rounded())
        if absVal < 5 { return "At city average (\(latest.year))" }
        return "\(absVal)% \(diff > 0 ? "above" : "below") city average (\(latest.year))"
    }

    // MARK: Full content

    @ViewBuilder
    private var fullContent: some View {
        if let summary, !summary.yearlyCounts.isEmpty || !summary.crimeTypes.isEmpty || !summary.offenceTypes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Aggregated by neighbourhood and month; not address-level incident data.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel)
                    .padding(10)
                    .background(Color.cleanAmber.opacity(0.12))
                    .cornerRadius(8)

                if !summary.yearlyCounts.isEmpty {
                    let selected = activeYear
                    let years = summary.yearlyCounts.map(\.year)
                    let yearLabels = years.map(String.init)
                    Chart(summary.yearlyCounts) { item in
                        BarMark(
                            x: .value("Year", String(item.year)),
                            y: .value("Neighbourhood crime count", item.neighbourhood)
                        )
                        .foregroundStyle(item.year == selected ? Color.cleanAmber : Color.cleanSky.opacity(0.7))

                        LineMark(
                            x: .value("Year", String(item.year)),
                            y: .value("City neighbourhood average", item.citywideAverage)
                        )
                        .foregroundStyle(Color.cleanIndigo)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                        PointMark(
                            x: .value("Year", String(item.year)),
                            y: .value("City neighbourhood average", item.citywideAverage)
                        )
                        .foregroundStyle(item.year == selected ? Color.cleanIndigo : Color.cleanLabel3)
                        .symbolSize(item.year == selected ? 120 : 55)
                    }
                    .chartXScale(domain: yearLabels)
                    .chartYScale(domain: 0...chartMaxValue)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: yearLabels) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                .foregroundStyle(Color.cleanSep.opacity(0.6))
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            guard let plotFrameAnchor = proxy.plotFrame else { return }
                                            let plotFrame = geometry[plotFrameAnchor]
                                            selectedYearValue = year(at: value.location.x, in: plotFrame, years: years)
                                        }
                                )
                        }
                    }
                    .frame(height: 180)
                    .accessibilityLabel("Selectable chart comparing neighbourhood police crime counts with the city neighbourhood average.")

                    if let selectedItem = activeYear.flatMap(eventForYear) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(selectedItem.year) \(summary.neighbourhood)").eyebrow(color: .cleanLabel3)
                                Spacer()
                                Text("\(selectedItem.neighbourhood.formatted()) records")
                                    .font(KrokvaTypography.monoBold)
                                    .foregroundStyle(Color.cleanLabel)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text("City neighbourhood avg").eyebrow(color: .cleanLabel3)
                                Spacer()
                                Text(selectedItem.citywideAverage.formatted(.number.precision(.fractionLength(0))) + " records")
                                    .font(KrokvaTypography.monoBold)
                                    .foregroundStyle(Color.cleanIndigo)
                            }
                        }
                    }
                }

                let selectedTypes = activeYear.flatMap { summary.crimeTypesByYear[$0] } ?? summary.crimeTypes
                let selectedOffences = activeYear.flatMap { summary.offenceTypesByYear[$0] } ?? summary.offenceTypes

                VStack(alignment: .leading, spacing: 16) {
                    comparisonColumn(activeYear.map { "Crime types in \($0)" } ?? "Crime types", selectedTypes)
                    comparisonColumn(activeYear.map { "Top offences in \($0)" } ?? "Top offences", selectedOffences)
                    comparisonLegend
                }
            }
        } else {
            Text(sourceFailed ? "Database error loading police crime context." : "Police crime map context is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }

    // MARK: Helpers

    private func eventForYear(_ year: Int) -> PoliceCrimeYear? {
        summary?.yearlyCounts.first { $0.year == year }
    }

    private var chartMaxValue: Double {
        let values = summary?.yearlyCounts.flatMap { [Double($0.neighbourhood), $0.citywideAverage] } ?? []
        return max((values.max() ?? 1) * 1.18, 1)
    }

    private func year(at xLocation: CGFloat, in plotFrame: CGRect, years: [Int]) -> Int? {
        guard !years.isEmpty, plotFrame.width > 0 else { return nil }
        guard years.count > 1 else { return years.first }
        let ratio = (min(max(xLocation, plotFrame.minX), plotFrame.maxX) - plotFrame.minX) / plotFrame.width
        return years[min(max(Int((ratio * CGFloat(years.count)).rounded(.down)), 0), years.count - 1)]
    }

    private func breakdownColumn(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrow(color: .cleanLabel3)
            if items.isEmpty {
                Text("—").font(KrokvaTypography.bodySecondary).foregroundStyle(Color.cleanLabel3)
            } else {
                ForEach(items.prefix(6)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.incidentType)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.cleanLabel2)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        Text(item.count.formatted())
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.cleanLabel)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Comparison list (neighbourhood vs city average)

    private func comparisonColumn(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow(color: .cleanLabel3)
            if items.isEmpty {
                Text("—").font(KrokvaTypography.bodySecondary).foregroundStyle(Color.cleanLabel3)
            } else {
                ForEach(items.prefix(8)) { item in
                    comparisonRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func comparisonRow(_ item: IncidentBreakdown) -> some View {
        let aboveAverage = Double(item.count) > item.citywideAverage
        let barColor: Color = aboveAverage ? .cleanRed : .cleanGreen
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.incidentType)
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel2)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(item.count.formatted())
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.cleanLabel)
                Text("avg \(item.citywideAverage.formatted(.number.precision(.fractionLength(0))))")
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.cleanLabel3)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let average = max(item.citywideAverage, 0.0001)
                let fillRatio = min((Double(item.count) / average) * Double(comparisonCityAveragePosition), 1)
                let fillWidth = width * CGFloat(fillRatio)
                let avgX = width * comparisonCityAveragePosition
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule().fill(barColor).frame(width: fillWidth)
                    // City-average marker
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.cleanIndigo)
                        .frame(width: 2, height: 12)
                        .offset(x: max(avgX - 1, 0))
                }
            }
            .frame(height: 8)
        }
    }

    private var comparisonLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Capsule().fill(Color.cleanRed).frame(width: 14, height: 6)
                Text("Above city avg").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.cleanGreen).frame(width: 14, height: 6)
                Text("At or below").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1).fill(Color.cleanIndigo).frame(width: 2, height: 12)
                Text("City avg").font(KrokvaTypography.caption).foregroundStyle(Color.cleanLabel3)
            }
        }
    }
}
