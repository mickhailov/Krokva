import SwiftUI

// Cards for the open-data feature modules added on top of the original report:
// waste collection, demographics, local government, local business, aquatics,
// traffic, neighbourhood risk, water quality, capital works, facility closures.

private func cadCurrency(_ value: Double) -> String {
    value.formatted(.currency(code: "CAD").precision(.fractionLength(0)))
}

private func percent(_ value: Double?) -> String? {
    guard let value else { return nil }
    return "\(Int(value.rounded()))%"
}

// MARK: - Waste collection & winter operations

struct WasteCollectionCard: View {
    let summary: WasteCollectionSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Collection & Winter", systemImage: "trash", iconColor: .cleanGreen,
                                          message: "Database error loading the waste & winter schedule."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Collection & Winter", systemImage: "trash", iconColor: .cleanGreen,
                       subtitle: summary.matchedAddress) {
                VStack(alignment: .leading, spacing: 10) {
                    if let day = summary.garbageDay { KeyValueRow(key: "Garbage day", value: day) }
                    if let day = summary.recycleDay { KeyValueRow(key: "Recycling day", value: day) }
                    if let day = summary.yardWasteDay { KeyValueRow(key: "Yard waste day", value: day) }
                    if let zone = summary.plowZone { KeyValueRow(key: "Plow zone", value: zone) }
                    if let window = summary.nextPlowWindow { KeyValueRow(key: "Next plow window", value: window) }
                    if let ban = summary.activeSnowBan {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTIVE SNOW PARKING BAN").eyebrow(color: .cleanRed)
                            Text(ban.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.cleanLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cleanRed.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        )
    }
}

// MARK: - Demographics

struct DemographicsCard: View {
    let summary: DemographicsSummary?
    let sourceFailed: Bool
    @State private var isExpanded = false
    private let modeColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x10B981), .cleanAmber, Color(hex: 0x38BDF8)]

    var body: some View {
        guard summary != nil else {
            return AnyView(
                ReportCard(title: "Who lives here", systemImage: "person.3", iconColor: .cleanIndigo) {
                    EmptyCardState(message: sourceFailed ? "Database error loading census profile." : "No census profile was returned for this address.")
                }
            )
        }
        return AnyView(
            CleanCard(padding: 0) {
                VStack(spacing: 0) {
                    headerButton
                    if isExpanded {
                        Divider()
                        fullContent
                            .padding(18)
                    }
                }
            }
        )
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Who lives here")
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
        guard let summary else { return "Tap to view" }
        var parts: [String] = []
        if let pop = summary.totalPopulation { parts.append("\(pop.formatted()) people") }
        if let income = summary.medianHouseholdIncome { parts.append(cadCurrency(income) + " median") }
        return parts.isEmpty ? summary.boundaryName : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
                VStack(alignment: .leading, spacing: 14) {
                    Text(summary.boundaryName).eyebrow(color: .cleanLabel3)
                    if hasTopStats(summary) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            if let pop = summary.totalPopulation {
                                StatTile(label: "Population", value: pop.formatted())
                            }
                            if let income = summary.medianHouseholdIncome {
                                StatTile(label: "Median income", value: cadCurrency(income))
                            }
                            if let kids = percent(summary.childrenPercent) {
                                StatTile(label: "Children (0–14)", value: kids)
                            }
                            if let seniors = percent(summary.seniorsPercent) {
                                StatTile(label: "Seniors (65+)", value: seniors)
                            }
                            if let size = summary.averageHouseholdSize {
                                StatTile(label: "Avg. household", value: size.formatted(.number.precision(.fractionLength(1))))
                            }
                            if let imm = percent(summary.immigrantPercent) {
                                StatTile(label: "Immigrants", value: imm)
                            }
                        }
                    }

                    if !summary.commuteModes.isEmpty {
                        Divider().foregroundStyle(Color.cleanSep)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How people commute").eyebrow(color: .cleanLabel3)
                            let maxVal = summary.commuteModes.map(\.count).max() ?? 1
                            ForEach(Array(summary.commuteModes.enumerated()), id: \.offset) { i, mode in
                                PillBar(label: mode.incidentType, value: mode.count, maxValue: maxVal,
                                        color: modeColors[i % modeColors.count], animationDelay: Double(i) * 0.07)
                            }
                        }
                    }

                    if summary.topNonOfficialLanguage != nil || summary.isHighPovertyArea != nil || summary.giniIndex != nil {
                        Divider().foregroundStyle(Color.cleanSep)
                        VStack(alignment: .leading, spacing: 8) {
                            if let lang = summary.topNonOfficialLanguage {
                                KeyValueRow(key: "Top mother tongue", value: lang)
                            }
                            if let gini = summary.giniIndex {
                                KeyValueRow(key: "Income inequality (Gini)", value: gini.formatted(.number.precision(.fractionLength(3))))
                            }
                            if summary.isHighPovertyArea == true {
                                Text("Designated higher-poverty area (2021 census).")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.cleanAmber)
                            }
                        }
                    }

                    Text("Census-based neighbourhood profile — context only, not address-specific.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                }
        }
    }

    private func hasTopStats(_ s: DemographicsSummary) -> Bool {
        s.totalPopulation != nil || s.medianHouseholdIncome != nil || s.childrenPercent != nil ||
        s.seniorsPercent != nil || s.averageHouseholdSize != nil || s.immigrantPercent != nil
    }
}

// MARK: - Local government

struct LocalGovernmentCard: View {
    let summary: LocalGovernmentSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Local government", systemImage: "building.columns", iconColor: .cleanSky,
                                          message: "Database error loading ward and councillor info."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Local government", systemImage: "building.columns", iconColor: .cleanSky) {
                VStack(alignment: .leading, spacing: 10) {
                    if let ward = summary.wardName { KeyValueRow(key: "Ward", value: ward) }
                    if let councillor = summary.councillor { KeyValueRow(key: "Councillor", value: councillor) }
                    if let phone = summary.councillorPhone { KeyValueRow(key: "Phone", value: phone) }
                    if let committee = summary.communityCommittee {
                        KeyValueRow(key: "Community committee", value: committee)
                    }
                    if let email = councillorContactURL(summary) {
                        Link(destination: email) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope")
                                Text("Email councillor")
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.cleanSky)
                        }
                    }
                    if let website = summary.councillorWebsite,
                       let url = URL(string: website) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                Text("Councillor page")
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.cleanSky)
                        }
                    }
                }
            }
        )
    }

    /// Winnipeg councillors have no published email — their pages route to a pre-filled
    /// contact form. Build that form URL from the councillor name + ward node id.
    private func councillorContactURL(_ summary: LocalGovernmentSummary) -> URL? {
        guard let councillor = summary.councillor else { return nil }
        let recipient = "Councillor \(councillor)"
        var components = URLComponents(string: "https://winnipeg.ca/city-governance/mayor-council/contact")
        var items = [
            URLQueryItem(name: "recipient", value: recipient),
            URLQueryItem(name: "heading", value: recipient)
        ]
        if let website = summary.councillorWebsite,
           let nodeID = website.split(separator: "/").last.map(String.init),
           Int(nodeID) != nil {
            items.append(URLQueryItem(name: "id", value: nodeID))
        }
        components?.queryItems = items
        return components?.url
    }
}

// MARK: - Local businesses

struct LocalBusinessCard: View {
    let summary: LocalBusinessSummary?
    var sourceFailed = false
    private let colors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x10B981), .cleanAmber, Color(hex: 0x38BDF8), Color(hex: 0x818CF8)]

    var body: some View {
        guard let summary, summary.totalNearby > 0 || !summary.patios.isEmpty else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Local businesses", systemImage: "storefront", iconColor: .cleanIndigo,
                                          message: "Database error loading nearby businesses."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Local businesses", systemImage: "storefront", iconColor: .cleanIndigo,
                       subtitle: "\(summary.totalNearby) licensed within 500 m") {
                VStack(alignment: .leading, spacing: 14) {
                    if !summary.topCategories.isEmpty {
                        let maxVal = summary.topCategories.map(\.count).max() ?? 1
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Most common types").eyebrow(color: .cleanLabel3)
                            ForEach(Array(summary.topCategories.enumerated()), id: \.offset) { i, cat in
                                PillBar(label: cat.incidentType, value: cat.count, maxValue: maxVal,
                                        color: colors[i % colors.count], animationDelay: Double(i) * 0.06)
                            }
                        }
                    }
                    if !summary.recent.isEmpty {
                        Divider().foregroundStyle(Color.cleanSep)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Closest").eyebrow(color: .cleanLabel3)
                            ForEach(summary.recent.prefix(6)) { biz in
                                rowView(title: biz.name, subtitle: biz.category, trailing: biz.distanceDescription)
                            }
                        }
                    }
                    if !summary.patios.isEmpty {
                        Divider().foregroundStyle(Color.cleanSep)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Seasonal patios nearby").eyebrow(color: .cleanLabel3)
                            ForEach(summary.patios.prefix(5)) { patio in
                                rowView(title: patio.name, subtitle: patio.category, trailing: patio.distanceDescription)
                            }
                        }
                    }
                }
            }
        )
    }

    private func rowView(title: String, subtitle: String?, trailing: String?) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
    }
}

// Pools & amenities are now rendered inside CivicAmenitiesCard (merged in ListCards.swift).

// MARK: - Traffic

struct TrafficCard: View {
    let summary: TrafficSummary?
    var risk: NeighbourhoodRiskSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    private var hasTrafficCounts: Bool {
        guard let summary else { return false }
        return summary.streetStudy != nil
    }
    private var hasParkingSignals: Bool {
        guard let risk else { return false }
        return risk.towingNearby > 0 || risk.paidParkingNearby > 0
    }

    var body: some View {
        guard hasTrafficCounts || hasParkingSignals else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Traffic & parking", systemImage: "car", iconColor: .cleanAmber,
                                          message: "Database error loading traffic & parking."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            CleanCard(padding: 0) {
                VStack(spacing: 0) {
                    headerButton
                    if isExpanded {
                        Divider()
                        fullContent
                            .padding(18)
                    }
                }
            }
        )
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "car")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanAmber, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Traffic & parking")
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
        var parts: [String] = []
        if let study = summary?.streetStudy, let count = study.vehiclesCounted {
            parts.append("\(count.formatted()) \(study.countSummaryUnit ?? "vehicles")")
        }
        if let date = summary?.streetStudy?.countDate {
            parts.append(countedDateFormatter.string(from: date))
        }
        if let tows = risk?.towingNearby, tows > 0 {
            parts.append("\(tows) rush-hour tows")
        }
        return parts.isEmpty ? "Tap to view" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let study = summary?.streetStudy {
                studySection(eyebrow: "ON THIS STREET", study: study)
            }

            if hasTrafficCounts {
                Text(summary?.streetStudy?.countNote ?? "Traffic counts reflect the latest available observation from the source dataset.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
            }

            if hasParkingSignals, let risk {
                if hasTrafficCounts { Divider().foregroundStyle(Color.cleanSep) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("PARKING & ENFORCEMENT NEARBY").eyebrow(color: .cleanLabel3)
                    if risk.towingNearby > 0 {
                        KeyValueRow(key: "Rush-hour tows within 500 m", value: "\(risk.towingNearby)")
                        Text("Vehicles towed for parking in a rush-hour no-stopping zone, recorded within 500 m of this address. A higher number flags streets with peak-hour parking bans — be careful where you leave a car at rush hour.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cleanLabel2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if risk.paidParkingNearby > 0 {
                        KeyValueRow(key: "Paid-parking blocks within 400 m", value: "\(risk.paidParkingNearby)")
                    }
                    if let nearest = risk.nearestPaidParking {
                        Text(nearest)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }
            }
        }
    }

    private func studySection(eyebrow: String, study: TrafficStudy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow).eyebrow(color: .cleanLabel3)
            Text(study.locationDescription)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
                .fixedSize(horizontal: false, vertical: true)
            if let count = study.vehiclesCounted {
                KeyValueRow(key: study.countMetricLabel ?? "Vehicles counted", value: count.formatted())
            }
            if let direction = study.direction {
                KeyValueRow(key: "Direction", value: direction)
            }
            if let date = study.countDate {
                KeyValueRow(key: "Last street measurement", value: countedDateFormatter.string(from: date))
            }
            if let distance = study.distanceDescription {
                KeyValueRow(key: "Distance", value: distance)
            }
        }
    }

    private var countedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d yyyy")
        return formatter
    }
}

// MARK: - Neighbourhood risk

struct NeighbourhoodRiskCard: View {
    let summary: NeighbourhoodRiskSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary, summary.roomingHouse != nil || !summary.vacantFireTrend.isEmpty || (summary.graffitiReports ?? 0) > 0 else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Neighbourhood risk signals", systemImage: "exclamationmark.shield", iconColor: .cleanAmber,
                                          message: "Database error loading neighbourhood risk signals."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Neighbourhood risk signals", systemImage: "exclamationmark.shield", iconColor: .cleanAmber) {
                VStack(alignment: .leading, spacing: 14) {
                    if let rooming = summary.roomingHouse {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ROOMING HOUSE ENFORCEMENT · \(String(rooming.year))").eyebrow(color: .cleanLabel3)
                            if let c = rooming.complaintDriven { KeyValueRow(key: "Complaint-driven", value: "\(c)") }
                            if let p = rooming.proactive { KeyValueRow(key: "Proactive", value: "\(p)") }
                            if let prog = rooming.inProgress { KeyValueRow(key: "In progress", value: "\(prog)") }
                            if let done = rooming.completed { KeyValueRow(key: "Completed", value: "\(done)") }
                        }
                    }
                    if !summary.vacantFireTrend.isEmpty {
                        if summary.roomingHouse != nil { Divider().foregroundStyle(Color.cleanSep) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("VACANT-PROPERTY FIRES (CITYWIDE)").eyebrow(color: .cleanLabel3)
                            MiniBarChart(
                                bars: summary.vacantFireTrend.map { yc in
                                    MiniBarChart.Bar(id: String(yc.year), value: yc.count, label: String(String(yc.year).suffix(2)), highlighted: false)
                                },
                                accentColor: .cleanRed,
                                baseColor: Color.cleanRed.opacity(0.6)
                            )
                            .frame(height: 70)
                        }
                    }
                    if let graffiti = summary.graffitiReports, graffiti > 0 {
                        if summary.roomingHouse != nil || !summary.vacantFireTrend.isEmpty {
                            Divider().foregroundStyle(Color.cleanSep)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GRAFFITI REPORTS · NEIGHBOURHOOD").eyebrow(color: .cleanLabel3)
                            KeyValueRow(key: "Total reports on record", value: graffiti.formatted())
                        }
                    }
                    // Rush-hour tows + paid-parking signals now surface in the Traffic & parking card.
                }
            }
        )
    }
}

// MARK: - Water quality

struct WaterQualityCard: View {
    let summary: WaterQualitySummary?
    var sourceFailed = false
    @State private var isExpanded = false

    // Health Canada Guidelines for Canadian Drinking Water Quality (MAC / aesthetic objectives).
    // Matched by a substring of the parameter name; `within` tests the measured average.
    private struct Guideline {
        let limitText: String
        /// Upper threshold used to scale the progress bar (0 for "non-detectable" parameters).
        let limit: Double
        let within: (Double) -> Bool
    }

    private func guideline(for parameter: String) -> Guideline? {
        let p = parameter.lowercased().trimmingCharacters(in: .whitespaces)
        if p == "ph" || p.hasPrefix("ph ") || p.hasPrefix("ph(") {
            return Guideline(limitText: "7.0–10.5", limit: 10.5) { $0 >= 7.0 && $0 <= 10.5 }
        }
        // Order matters: `p.contains(key)` returns the first match, so place more
        // specific keys (e.g. "total dissolved") before broader ones.
        let table: [(String, String, Double, (Double) -> Bool)] = [
            ("turbidity", "≤ 1.0 NTU", 1.0, { $0 <= 1.0 }),
            ("trihalomethane", "≤ 0.100 mg/L", 0.100, { $0 <= 0.100 }),
            ("thm", "≤ 0.100 mg/L", 0.100, { $0 <= 0.100 }),
            ("haloacetic", "≤ 0.080 mg/L", 0.080, { $0 <= 0.080 }),
            ("haa", "≤ 0.080 mg/L", 0.080, { $0 <= 0.080 }),
            ("fluoride", "≤ 1.5 mg/L", 1.5, { $0 <= 1.5 }),
            ("lead", "≤ 0.005 mg/L", 0.005, { $0 <= 0.005 }),
            ("sodium", "≤ 200 mg/L", 200, { $0 <= 200 }),
            ("nitrate", "≤ 45 mg/L", 45, { $0 <= 45 }),
            // Aesthetic objectives & MACs that apply to common source-water parameters.
            ("total dissolved", "≤ 500 mg/L", 500, { $0 <= 500 }),
            ("dissolved solids", "≤ 500 mg/L", 500, { $0 <= 500 }),
            ("chloride", "≤ 250 mg/L", 250, { $0 <= 250 }),
            ("sulphate", "≤ 500 mg/L", 500, { $0 <= 500 }),
            ("sulfate", "≤ 500 mg/L", 500, { $0 <= 500 }),
            ("iron", "≤ 0.3 mg/L", 0.3, { $0 <= 0.3 }),
            ("manganese", "≤ 0.12 mg/L", 0.12, { $0 <= 0.12 }),
            ("copper", "≤ 1.0 mg/L", 1.0, { $0 <= 1.0 }),
            ("aluminum", "≤ 2.9 mg/L", 2.9, { $0 <= 2.9 }),
            ("aluminium", "≤ 2.9 mg/L", 2.9, { $0 <= 2.9 }),
            ("arsenic", "≤ 0.010 mg/L", 0.010, { $0 <= 0.010 }),
            ("uranium", "≤ 0.02 mg/L", 0.02, { $0 <= 0.02 }),
            ("e. coli", "0 detectable", 0, { $0 <= 0 }),
            ("e.coli", "0 detectable", 0, { $0 <= 0 }),
            ("coliform", "0 detectable", 0, { $0 <= 0 }),
        ]
        for (key, text, limit, test) in table where p.contains(key) {
            return Guideline(limitText: text, limit: limit, within: test)
        }
        return nil
    }

    /// Parameters shown in the card, excluding non-quality readings like temperature.
    private func visibleParameters(_ summary: WaterQualitySummary) -> [WaterQualityReading] {
        summary.parameters.filter { !$0.parameter.lowercased().contains("temperature") }
    }

    private var matchedCount: Int {
        guard let summary else { return 0 }
        return summary.parameters.filter { reading in
            guard let avg = reading.average else { return false }
            return guideline(for: reading.parameter)?.within(avg) != nil
        }.count
    }

    private var allWithin: Bool {
        guard let summary else { return false }
        var any = false
        for reading in summary.parameters {
            guard let avg = reading.average, let g = guideline(for: reading.parameter) else { continue }
            any = true
            if !g.within(avg) { return false }
        }
        return any
    }

    var body: some View {
        guard let summary, !summary.parameters.isEmpty else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Drinking water quality", systemImage: "drop", iconColor: .cleanSky,
                                          message: "Database error loading drinking water quality."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            CleanCard(padding: 0) {
                VStack(spacing: 0) {
                    headerButton(summary)
                    if isExpanded {
                        Divider()
                        fullContent(summary)
                            .padding(18)
                    }
                }
            }
        )
    }

    private func headerButton(_ summary: WaterQualitySummary) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "drop")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanSky, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Drinking water quality")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(smallSummary(summary))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(allWithin ? Color.cleanGreen : Color.cleanLabel2)
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

    private func smallSummary(_ summary: WaterQualitySummary) -> String {
        if matchedCount > 0 && allWithin {
            return "Meets Health Canada guidelines"
        }
        var parts: [String] = []
        if let area = summary.area { parts.append(area) }
        parts.append("\(visibleParameters(summary).count) parameters")
        return parts.joined(separator: " · ")
    }

    private func sourceLabel(_ summary: WaterQualitySummary) -> String {
        [summary.area, summary.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    private func fullContent(_ summary: WaterQualitySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let source = sourceLabel(summary)
            if !source.isEmpty {
                Text(source).eyebrow(color: .cleanLabel3)
            }

            let visible = visibleParameters(summary)
            ForEach(visible) { reading in
                readingRow(reading)
                if reading.id != visible.last?.id {
                    Divider().foregroundStyle(Color.cleanSep)
                }
            }

            if let year = summary.year {
                Text("Values are annual averages for \(String(year)).")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
            }

            if matchedCount > 0 {
                Text("Limits are Health Canada Guidelines for Canadian Drinking Water Quality (maximum acceptable concentrations / aesthetic objectives).")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
    }

    @ViewBuilder
    private func readingRow(_ reading: WaterQualityReading) -> some View {
        let valueText = [reading.average.map { $0.formatted(.number.precision(.fractionLength(2))) }, reading.units]
            .compactMap { $0 }.joined(separator: " ")
        let g = guideline(for: reading.parameter)
        let within = reading.average.flatMap { avg in g.map { $0.within(avg) } }
        let rangeText: String? = {
            guard let lo = reading.minimum, let hi = reading.maximum, lo < hi else { return nil }
            let fmt: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...2))) }
            return "Range \(fmt(lo))–\(fmt(hi))"
        }()
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(reading.parameter)
                        .font(.subheadline)
                        .foregroundStyle(Color.cleanLabel2)
                    if let rangeText {
                        Text(rangeText)
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel3)
                    }
                }
                Spacer(minLength: 12)
                Text(valueText.isEmpty ? "—" : valueText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel)
            }
            if let g, let avg = reading.average, let within {
                guidelineBar(average: avg, guideline: g, within: within)
                HStack(spacing: 6) {
                    Label(within ? "Within guideline" : "Above guideline",
                          systemImage: within ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(within ? Color.cleanGreen : Color.cleanAmber)
                        .labelStyle(.titleAndIcon)
                    Spacer(minLength: 0)
                    Text("Guideline \(g.limitText)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel3)
                }
            } else if let g {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text("Guideline \(g.limitText)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel3)
                }
            } else {
                Text("No Health Canada drinking-water limit — source-water indicator only.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
        .padding(.vertical, 4)
    }

    /// Progress bar: fill = measured average, indigo marker = Health Canada guideline limit.
    private func guidelineBar(average: Double, guideline g: Guideline, within: Bool) -> some View {
        // "Non-detectable" parameters (limit 0): any reading scales against itself so a clean result reads empty.
        let scale = max(g.limit, average, g.limit > 0 ? g.limit * 0.0001 : 0.0001) * 1.25
        let fill = min(average / scale, 1)
        let markerFraction = g.limit > 0 ? min(g.limit / scale, 1) : 0
        let barColor: Color = within ? .cleanGreen : .cleanAmber
        return GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.cleanTrack)
                Capsule().fill(barColor).frame(width: width * CGFloat(fill))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.cleanIndigo)
                    .frame(width: 2, height: 12)
                    .offset(x: max(width * CGFloat(markerFraction) - 1, 0))
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Capital works

struct CapitalWorksCard: View {
    let summary: CapitalWorksSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary, !summary.projects.isEmpty else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Capital projects nearby", systemImage: "cone", iconColor: .cleanAmber,
                                          message: "Database error loading nearby capital projects."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Capital projects nearby", systemImage: "cone", iconColor: .cleanAmber,
                       subtitle: "Matched to your street") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summary.projects) { project in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                if let status = project.status, !status.isEmpty {
                                    Text(status)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.cleanLabel2)
                                }
                                if let year = project.year, !year.isEmpty {
                                    Text(year)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                                Spacer(minLength: 0)
                                if let budget = project.budget, budget > 0 {
                                    Text(cadCurrency(budget))
                                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(Color.cleanLabel)
                                }
                            }
                            if project.funded == false {
                                Text("Unfunded")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.cleanAmber)
                            }
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Facility closures

struct FacilityClosuresCard: View {
    let summary: FacilityClosureSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary, !summary.closures.isEmpty else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Health inspection closures", systemImage: "fork.knife", iconColor: .cleanRed,
                                          message: "Database error loading health inspection closures."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Health inspection closures", systemImage: "fork.knife", iconColor: .cleanRed,
                       subtitle: "Establishments on your street") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summary.closures) { closure in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(closure.name)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel)
                                .fixedSize(horizontal: false, vertical: true)
                            if let reason = closure.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cleanLabel2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(spacing: 8) {
                                if let type = closure.establishmentType {
                                    Text(type)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                                Spacer(minLength: 0)
                                if let date = closure.closureDate {
                                    Text("Closed \(date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(closure.reopenDate == nil ? Color.cleanRed : Color.cleanLabel3)
                                }
                            }
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Heritage / historical resources

struct HeritageCard: View {
    let summary: HeritageSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary, summary.subjectDesignation != nil || !summary.nearby.isEmpty else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Heritage & historical", systemImage: "building.columns", iconColor: .cleanIndigo,
                                          message: "Database error loading heritage register."))
                : AnyView(EmptyView()))
        }
        return AnyView(
            ReportCard(title: "Heritage & historical", systemImage: "building.columns", iconColor: .cleanIndigo,
                       subtitle: "City of Winnipeg Historical Resources") {
                VStack(alignment: .leading, spacing: 12) {
                    if let subject = summary.subjectDesignation {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THIS ADDRESS IS A LISTED HERITAGE RESOURCE").eyebrow(color: .cleanIndigo)
                            heritageRow(subject, emphasize: true)
                            Text("Listed buildings have rules on alterations and demolition — confirm with the City before renovating.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.cleanLabel2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !summary.nearby.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary.subjectDesignation == nil ? "Heritage buildings nearby" : "Also nearby")
                                .eyebrow(color: .cleanLabel3)
                            ForEach(summary.nearby) { building in
                                heritageRow(building, emphasize: false)
                            }
                        }
                    }
                }
            }
        )
    }

    private func heritageRow(_ building: HeritageBuilding, emphasize: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(building.name)
                    .font(.system(size: emphasize ? 15 : 13.5, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let grade = building.grade {
                    Text("Grade \(grade)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cleanIndigo)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.cleanIndigo.opacity(0.12), in: Capsule())
                }
            }
            HStack(spacing: 8) {
                if let address = building.address {
                    Text(address)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                }
                if let year = building.constructionYear, !year.isEmpty {
                    Text("Built \(year)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                }
                Spacer(minLength: 0)
                if !emphasize, let distance = building.distanceDescription {
                    Text(distance)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
            if let listType = building.listType, !listType.isEmpty {
                Text(listType)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
    }
}

// MARK: - Mosquito control

struct MosquitoCard: View {
    let summary: MosquitoSummary?
    var sourceFailed = false

    var body: some View {
        guard let summary else {
            return AnyView(sourceFailed
                ? AnyView(ModuleErrorCard(title: "Mosquito control", systemImage: "ant", iconColor: .cleanAmber,
                                          message: "Database error loading mosquito trap data."))
                : AnyView(EmptyView()))
        }
        let dateLabel = summary.countDate.map { $0.formatted(date: .abbreviated, time: .omitted) }
        return AnyView(
            ReportCard(title: "Mosquito control", systemImage: "ant", iconColor: .cleanAmber,
                       subtitle: dateLabel.map { "Latest trap count · \($0)" } ?? "Adult mosquito trap counts") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        StatTile(label: "\(summary.quadrant) quadrant", value: summary.quadrantCount.map { "\($0)" } ?? "—")
                        StatTile(label: "City-wide average", value: summary.cityWideAverage.map { "\($0)" } ?? "—")
                    }
                    Text("Average mosquitoes per trap. The City considers nuisance fogging when counts climb to about 100 per trap.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel2)
                        .fixedSize(horizontal: false, vertical: true)
                    if summary.foggingThresholdReached {
                        Label("Counts are near the level where fogging is typically considered.", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.cleanAmber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Residents can register a fogging buffer zone around their home through the City’s Insect Control branch.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        )
    }
}

// MARK: - Radon potential

struct RadonCard: View {
    let summary: RadonSummary?

    var body: some View {
        guard let summary else { return AnyView(EmptyView()) }
        return AnyView(
            ReportCard(title: "Radon potential", systemImage: "aqi.medium", iconColor: .cleanSky,
                       subtitle: "\(summary.region) regional reference") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(summary.percentAboveGuideline)%")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel)
                        Text("of tested homes were at or above Health Canada’s 200 Bq/m³ guideline.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cleanLabel2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("This is a regional figure, not a reading for this address — radon varies house to house. The only way to know is a long-term test.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summary.surveyName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
        )
    }
}

// MARK: - Rental market (CMHC)

struct RentalMarketCard: View {
    let summary: RentalMarketSummary?

    var body: some View {
        guard let summary, !summary.brackets.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            ReportCard(title: "Rental market", systemImage: "key", iconColor: .cleanIndigo,
                       subtitle: "\(summary.area) · CMHC \(String(summary.year))") {
                VStack(alignment: .leading, spacing: 12) {
                    if let vacancy = summary.vacancyRate {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f%%", vacancy))
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel)
                            Text("apartment vacancy rate")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cleanLabel2)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average rent").eyebrow(color: .cleanLabel3)
                        ForEach(summary.brackets) { bracket in
                            HStack {
                                Text(bracket.bedrooms)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.cleanLabel2)
                                Spacer(minLength: 16)
                                Text(bracket.averageRent.map { cadCurrency($0) } ?? "—")
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Color.cleanLabel)
                            }
                        }
                    }
                    Text("Metro-wide averages from CMHC’s annual Rental Market Survey — not specific to this address.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cleanLabel3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        )
    }
}
