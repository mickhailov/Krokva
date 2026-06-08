import Charts
import SwiftUI

// MARK: - NeighbourhoodValueCard (Civic Modernist)

struct NeighbourhoodValueCard: View {
    let dossier: AddressDossier

    private var subjectBinID: UUID? {
        guard let assessed = dossier.property?.totalAssessedValue else { return nil }
        return dossier.neighbourhoodValues.min(by: { abs($0.midpoint - assessed) < abs($1.midpoint - assessed) })?.id
    }

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Where it sits in the neighbourhood")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.krokvaInk)
                        Text("\(dossier.property?.neighbourhood ?? dossier.cityName) · \(dossier.neighbourhoodValues.count) homes")
                            .eyebrow(color: .krokvaInk3)
                    }
                }

                if dossier.neighbourhoodValues.isEmpty {
                    Text("Neighbourhood assessment distribution is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    let sid = subjectBinID
                    Chart(dossier.neighbourhoodValues) { bin in
                        BarMark(x: .value("Bucket", bin.bucket), y: .value("Count", bin.count))
                            .foregroundStyle(bin.id == sid ? Color.krokvaGold : Color.krokvaNavy.opacity(0.85))
                    }
                    .frame(height: 180)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                .foregroundStyle(Color.krokvaLine.opacity(0.5))
                        }
                    }
                    .accessibilityLabel("Histogram of assessed values in this neighbourhood.")

                    Text("This chart compares municipal assessed values in the neighbourhood. It is not a market-price estimate.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - ComparablesCard

struct ComparablesCard: View {
    let dossier: AddressDossier

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Direct comparables")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("\(dossier.comparables.count) PICKS")
                        .eyebrow(color: .krokvaInk3)
                }

                if dossier.comparables.isEmpty {
                    Text("Comparable assessment records were not returned.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    Chart(dossier.comparables) { item in
                        PointMark(x: .value("Living area", item.livingArea), y: .value("Value", item.value))
                            .foregroundStyle(
                                item.address == dossier.property?.fullAddress
                                    ? Color.krokvaGold
                                    : Color.krokvaNavy.opacity(0.7)
                            )
                            .symbolSize(item.address == dossier.property?.fullAddress ? 180 : 120)
                    }
                    .frame(height: 200)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                    .accessibilityLabel("Scatter plot of comparable homes by living area and assessed value.")

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(dossier.comparables.prefix(3)) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.address)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color.krokvaInk)
                                    Text("\(area(item.livingArea)) · built \(item.yearBuilt.map(String.init) ?? "—")")
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                }
                                Spacer()
                                Text(money(item.value))
                                    .font(KrokvaTypography.monoBold)
                                    .foregroundStyle(Color.krokvaInk)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - PermitActivityCard

struct PermitActivityCard: View {
    let activity: [YearCount]

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaGold)
                    Text("Neighbourhood permit activity")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }

                if activity.isEmpty {
                    Text("Permit trend data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    Chart(activity) { item in
                        LineMark(x: .value("Year", String(item.year)), y: .value("Permits", item.count))
                            .foregroundStyle(Color.krokvaGold)
                        PointMark(x: .value("Year", String(item.year)), y: .value("Permits", item.count))
                            .foregroundStyle(Color.krokvaGold)
                    }
                    .frame(height: 180)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: activity.map { String($0.year) }) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                .foregroundStyle(Color.krokvaLine.opacity(0.5))
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .accessibilityLabel("Line chart of permits issued per year.")
                }
            }
        }
    }
}

// MARK: - EmergencyActivityCard

struct EmergencyActivityCard: View {
    let summary: EmergencySummary?
    @State private var selectedYear: Int?

    private func selectedYear(for summary: EmergencySummary) -> Int? {
        if let selectedYear, summary.yearlyCalls.contains(where: { $0.year == selectedYear }) {
            return selectedYear
        }
        return summary.yearlyCalls.last?.year
    }

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cross.case")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Emergency response activity")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }

                if let summary, (!summary.yearlyCalls.isEmpty || !summary.last12Months.isEmpty || !summary.recentIncidents.isEmpty) {
                    HStack(spacing: 10) {
                        StatTile(label: "Last 12 months", value: summary.totalLastYear.formatted())
                        StatTile(label: "Vehicle involved", value: summary.motorVehicleLastYear.formatted())
                        StatTile(label: "Avg duration", value: duration(summary.averageDurationMinutes))
                    }

                    if !summary.yearlyCalls.isEmpty {
                        let activeYear = selectedYear(for: summary)
                        let years = summary.yearlyCalls.map(\.year)
                        let yearLabels = years.map(String.init)
                        Chart(summary.yearlyCalls) { item in
                            BarMark(x: .value("Year", String(item.year)), y: .value("Calls", item.count))
                                .foregroundStyle(item.year == activeYear ? Color.krokvaGold : Color.krokvaNavy.opacity(0.85))
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
                                    .foregroundStyle(Color.krokvaLine.opacity(0.5))
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                        .accessibilityLabel("Selectable bar chart of fire and medical calls by year.")
                    }

                    if !summary.monthlyTrend.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent monthly volume")
                                .eyebrow()
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(summary.monthlyTrend.suffix(12)) { item in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.krokvaNavy.opacity(0.84))
                                            .frame(height: monthlyBarHeight(item.count, in: summary.monthlyTrend))
                                        Text(item.label)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Color.krokvaInk3)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("\(item.label): \(item.count) emergency responses")
                                }
                            }
                        }
                    }

                    let activeYear = selectedYear(for: summary)
                    let selectedBreakdown = activeYear.flatMap { summary.breakdownByYear[$0] } ?? summary.last12Months
                    if !selectedBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if let activeYear {
                                Text("Incident types in \(activeYear)")
                                    .eyebrow()
                            }
                            ForEach(selectedBreakdown.prefix(5)) { item in
                                HStack {
                                    Text(item.incidentType)
                                        .font(KrokvaTypography.bodySecondary)
                                        .foregroundStyle(Color.krokvaInk2)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(KrokvaTypography.monoBold)
                                        .foregroundStyle(Color.krokvaInk)
                                }
                            }
                        }
                    }

                    Grid(horizontalSpacing: 14, verticalSpacing: 10) {
                        GridRow {
                            breakdownColumn("Ward", summary.wardBreakdown)
                            breakdownColumn("Motor vehicle", summary.motorVehicleBreakdown)
                        }
                        GridRow {
                            breakdownColumn("Units dispatched", summary.unitBreakdown)
                            breakdownColumn("Last 12 months", summary.last12Months)
                        }
                    }

                    if !summary.recentIncidents.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Recent public rows")
                                .eyebrow()
                                .padding(.bottom, 6)
                            ForEach(Array(summary.recentIncidents.prefix(6).enumerated()), id: \.element.id) { index, incident in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(incident.incidentType)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(Color.krokvaInk)
                                            .lineLimit(2)
                                        Spacer(minLength: 8)
                                        Text(incident.motorVehicleIncident ?? "—")
                                            .font(KrokvaTypography.monoSmall)
                                            .foregroundStyle(Color.krokvaInk3)
                                    }
                                    Text([incident.units, incident.ward].compactMap { $0 }.joined(separator: " · "))
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                        .lineLimit(2)
                                    HStack(spacing: 6) {
                                        Text(incident.callTime?.formatted(date: .abbreviated, time: .shortened) ?? "Time unavailable")
                                        if let minutes = incident.durationMinutes {
                                            Text("·")
                                            Text("\(minutes) min")
                                        }
                                    }
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.krokvaInk3)
                                }
                                .padding(.vertical, 8)

                                if index < min(summary.recentIncidents.count, 6) - 1 {
                                    Divider().foregroundStyle(Color.krokvaLineSoft)
                                }
                            }
                        }
                    }

                    Text("WFPS calls are shown as \(summary.neighbourhood) municipal activity records, not as an address-level safety score.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    Text("Emergency response activity is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

    private func chartMaxValue(for summary: EmergencySummary) -> Double {
        let values = summary.yearlyCalls.map { Double($0.count) }
        return max((values.max() ?? 1) * 1.18, 1)
    }

    private func year(at xLocation: CGFloat, in plotFrame: CGRect, years: [Int]) -> Int? {
        guard !years.isEmpty, plotFrame.width > 0 else { return nil }
        guard years.count > 1 else { return years.first }
        let clampedX = min(max(xLocation, plotFrame.minX), plotFrame.maxX)
        let ratio = (clampedX - plotFrame.minX) / plotFrame.width
        let index = min(max(Int((ratio * CGFloat(years.count)).rounded(.down)), 0), years.count - 1)
        return years[index]
    }

    @ViewBuilder
    private func breakdownColumn(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrow()
            if items.isEmpty {
                Text("—")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.krokvaInk3)
            } else {
                ForEach(items.prefix(4)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.incidentType)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk2)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(item.count.formatted())
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.krokvaInk)
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

    private func duration(_ minutes: Double?) -> String {
        guard let minutes else { return "—" }
        return "\(Int(minutes.rounded())) min"
    }
}

// MARK: - PoliceCrimeCard

struct PoliceCrimeCard: View {
    let summary: PoliceCrimeSummary?
    @State private var selectedYearValue: Int?

    private var activeYear: Int? {
        guard let summary else { return nil }
        if let selectedYearValue, summary.yearlyCounts.contains(where: { $0.year == selectedYearValue }) {
            return selectedYearValue
        }
        return summary.yearlyCounts.last?.year
    }

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Police crime context")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.krokvaInk)
                        if let latest = summary?.latestMonth {
                            Text("WPS public crime map · through \(latest.label)")
                                .eyebrow(color: .krokvaInk3)
                        }
                    }
                    Spacer()
                }

                if let summary, !summary.yearlyCounts.isEmpty || !summary.crimeTypes.isEmpty || !summary.offenceTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aggregated by neighbourhood and month; not address-level incident data.")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk)
                            .padding(10)
                            .background(Color.krokvaGold.opacity(0.18))
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
                                .foregroundStyle(item.year == selected ? Color.krokvaGold : Color.krokvaNavy.opacity(0.85))

                                LineMark(
                                    x: .value("Year", String(item.year)),
                                    y: .value("City neighbourhood average", item.citywideAverage)
                                )
                                .foregroundStyle(Color.krokvaNavyLight)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                                PointMark(
                                    x: .value("Year", String(item.year)),
                                    y: .value("City neighbourhood average", item.citywideAverage)
                                )
                                .foregroundStyle(item.year == selected ? Color.krokvaNavyLight : Color.krokvaInk3)
                                .symbolSize(item.year == selected ? 120 : 55)
                            }
                            .chartXScale(domain: yearLabels)
                            .chartYScale(domain: 0...chartMaxValue)
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(values: yearLabels) { _ in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                        .foregroundStyle(Color.krokvaLine.opacity(0.5))
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
                                        Text("\(selectedItem.year) \(summary.neighbourhood)")
                                            .eyebrow()
                                        Spacer()
                                        Text("\(selectedItem.neighbourhood.formatted()) records")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaInk)
                                    }
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("City neighbourhood avg")
                                            .eyebrow(color: .krokvaInk3)
                                        Spacer()
                                        Text(selectedItem.citywideAverage.formatted(.number.precision(.fractionLength(0))) + " records")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaNavyLight)
                                    }
                                }
                            }
                        }

                        let selectedTypes = activeYear.flatMap { summary.crimeTypesByYear[$0] } ?? summary.crimeTypes
                        let selectedOffences = activeYear.flatMap { summary.offenceTypesByYear[$0] } ?? summary.offenceTypes

                        Grid(horizontalSpacing: 14, verticalSpacing: 10) {
                            GridRow {
                                breakdownColumn(activeYear.map { "Crime types in \($0)" } ?? "Crime types", selectedTypes)
                                breakdownColumn(activeYear.map { "Top offences in \($0)" } ?? "Top offences", selectedOffences)
                            }
                        }
                    }
                } else {
                    Text("Police crime map context is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

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
        let clampedX = min(max(xLocation, plotFrame.minX), plotFrame.maxX)
        let ratio = (clampedX - plotFrame.minX) / plotFrame.width
        let index = min(max(Int((ratio * CGFloat(years.count)).rounded(.down)), 0), years.count - 1)
        return years[index]
    }

    private func breakdownColumn(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrow()
            if items.isEmpty {
                Text("—")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.krokvaInk3)
            } else {
                ForEach(items.prefix(6)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.incidentType)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk2)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        Text(item.count.formatted())
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.krokvaInk)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - PublicHealthCard

struct PublicHealthCard: View {
    let summary: PublicHealthSummary?
    @State private var selectedYearValue: Int?

    private var activeYear: Int? {
        guard let summary else { return nil }
        if let selectedYearValue, summary.yearlyEvents.contains(where: { $0.year == selectedYearValue }) {
            return selectedYearValue
        }
        return summary.yearlyEvents.last?.year
    }

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Public-health context")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary, !summary.yearlyEvents.isEmpty || !summary.ageGroups.isEmpty || !summary.substances.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("These are anonymized emergency response events, not a risk score or grade.")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk)
                            .padding(10)
                            .background(Color.krokvaGreen.opacity(0.15))
                            .cornerRadius(8)

                        if !summary.yearlyEvents.isEmpty {
                            let selected = activeYear
                            let years = summary.yearlyEvents.map(\.year)
                            let yearLabels = years.map(String.init)
                            let yMax = chartMaxValue
                            Chart(summary.yearlyEvents) { item in
                                BarMark(
                                    x: .value("Year", String(item.year)),
                                    y: .value("Neighbourhood events", item.neighbourhood)
                                )
                                .foregroundStyle(item.year == selected ? Color.krokvaGold : Color.krokvaNavy.opacity(0.85))

                                LineMark(
                                    x: .value("Year", String(item.year)),
                                    y: .value("City average", item.citywideAverage)
                                )
                                .foregroundStyle(Color.krokvaNavyLight)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                                PointMark(
                                    x: .value("Year", String(item.year)),
                                    y: .value("City average", item.citywideAverage)
                                )
                                .foregroundStyle(item.year == selected ? Color.krokvaNavyLight : Color.krokvaInk3)
                                .symbolSize(item.year == selected ? 120 : 55)
                            }
                            .chartXScale(domain: yearLabels)
                            .chartYScale(domain: 0...yMax)
                            .chartYAxis(.hidden)
                            .chartXAxis {
                                AxisMarks(values: yearLabels) { _ in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                                        .foregroundStyle(Color.krokvaLine.opacity(0.5))
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
                            .accessibilityLabel("Selectable chart comparing neighbourhood public-health responses with citywide average.")

                            if let selectedItem = activeYear.flatMap(eventForYear) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("\(selectedItem.year) neighbourhood")
                                            .eyebrow()
                                        Spacer()
                                        Text("\(selectedItem.neighbourhood.formatted()) events")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaInk)
                                    }
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("City avg")
                                            .eyebrow(color: .krokvaInk3)
                                        Spacer()
                                        Text(selectedItem.citywideAverage.formatted(.number.precision(.fractionLength(0))) + " events")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaNavyLight)
                                    }
                                }
                            }
                        }

                        let selectedAges = activeYear.flatMap { summary.ageGroupsByYear[$0] } ?? summary.ageGroups
                        let selectedSubstances = activeYear.flatMap { summary.substancesByYear[$0] } ?? summary.substances

                        if !selectedAges.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activeYear.map { "Age groups in \($0)" } ?? "Age groups")
                                    .eyebrow()
                                ForEach(selectedAges.prefix(6)) { item in
                                    HStack {
                                        Text(item.incidentType)
                                            .font(KrokvaTypography.caption)
                                            .foregroundStyle(Color.krokvaInk2)
                                        Spacer()
                                        Text("\(item.count)")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaInk)
                                    }
                                }
                            }
                        }

                        if !selectedSubstances.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activeYear.map { "Substance reported in \($0)" } ?? "Substance reported")
                                    .eyebrow()
                                    .padding(.top, 4)
                                ForEach(selectedSubstances.prefix(6)) { item in
                                    HStack {
                                        Text(item.incidentType)
                                            .font(KrokvaTypography.caption)
                                            .foregroundStyle(Color.krokvaInk2)
                                        Spacer()
                                        Text("\(item.count)")
                                            .font(KrokvaTypography.monoBold)
                                            .foregroundStyle(Color.krokvaInk)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Public-health context is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

    private func eventForYear(_ year: Int) -> PublicHealthYear? {
        summary?.yearlyEvents.first { $0.year == year }
    }

    private var chartMaxValue: Double {
        let values = summary?.yearlyEvents.flatMap { [Double($0.neighbourhood), $0.citywideAverage] } ?? []
        return max((values.max() ?? 1) * 1.18, 1)
    }

    private func year(at xLocation: CGFloat, in plotFrame: CGRect, years: [Int]) -> Int? {
        guard !years.isEmpty, plotFrame.width > 0 else { return nil }
        guard years.count > 1 else { return years.first }
        let clampedX = min(max(xLocation, plotFrame.minX), plotFrame.maxX)
        let ratio = (clampedX - plotFrame.minX) / plotFrame.width
        let index = min(max(Int((ratio * CGFloat(years.count)).rounded(.down)), 0), years.count - 1)
        return years[index]
    }
}
