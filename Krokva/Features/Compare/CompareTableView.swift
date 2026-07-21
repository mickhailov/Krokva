import SwiftUI

// MARK: - Row / section model

struct CompareRow {
    let label: String
    let values: [String?]
    let bestIndex: Int?

    var hasValues: Bool {
        values.contains { ($0?.nilIfEmpty) != nil }
    }
}

struct CompareSection {
    let title: String
    let rows: [CompareRow]
}

// MARK: - Comparison table

/// The side-by-side comparison grid. Extracted from `PropertyCompareView` so the
/// exact same view renders both on screen and offscreen into the compare PDF.
/// `currentIndex` marks the column that is the user's current/home address.
struct CompareTableView: View {
    let props: [SavedReport]
    let reports: [AddressReport?]
    var currentIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeaders
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
            taxDisclaimer
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 96)
            ForEach(Array(props.enumerated()), id: \.offset) { i, prop in
                VStack(spacing: 3) {
                    Text(shortAddress(prop.address))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)
                    Text(i == currentIndex ? "CURRENT" : "CANDIDATE")
                        .font(.system(size: 7, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(i == currentIndex ? Color.cleanSky : Color.cleanLabel3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Section rendering

    private func sectionView(_ section: CompareSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .eyebrow()
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 6)
            CleanCard(padding: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.offset) { idx, row in
                    rowView(row)
                    if idx < section.rows.count - 1 {
                        Divider().padding(.leading, 96)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func rowView(_ row: CompareRow) -> some View {
        HStack(spacing: 0) {
            Text(row.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cleanLabel2)
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)
            ForEach(Array(props.indices), id: \.self) { i in
                let val = i < row.values.count ? (row.values[i] ?? "—") : "—"
                let isBest = i == row.bestIndex
                Text(val)
                    .font(.system(size: 12, weight: isBest ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isBest ? Color.cleanSky : Color.cleanLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(cellBackground(column: i, isBest: isBest))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func cellBackground(column: Int, isBest: Bool) -> Color {
        if isBest { return Color.cleanSkyWash }
        if column == currentIndex { return Color.cleanSky.opacity(0.05) }
        return Color.clear
    }

    // MARK: Tax disclaimer

    @ViewBuilder
    private var taxDisclaimer: some View {
        if props.contains(where: { $0.propertyTaxIsEstimated && $0.propertyTax != nil }) {
            Text("* 2026 tax estimate based on assessment")
                .font(.system(size: 10))
                .foregroundStyle(Color.cleanLabel3)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Sections data

    private var sections: [CompareSection] {
        [
            CompareSection(title: "VALUE",        rows: valueRows),
            CompareSection(title: "SIZE",          rows: sizeRows),
            CompareSection(title: "PROPERTY",      rows: propertyRows),
            CompareSection(title: "FEATURES",      rows: featureRows),
            CompareSection(title: "CIVIC",         rows: civicRows),
            CompareSection(title: "COLLECTION",    rows: collectionRows),
            CompareSection(title: "SCHOOLS",       rows: schoolRows),
            CompareSection(title: "SAFETY",        rows: safetyRows),
            CompareSection(title: "ACCESS",        rows: accessRows),
            CompareSection(title: "PLANNING",      rows: planningRows),
            CompareSection(title: "LOCAL AREA",    rows: localAreaRows),
            CompareSection(title: "RISK & WORKS",  rows: riskAndWorksRows),
        ].compactMap { section in
            let rows = section.rows.filter(\.hasValues)
            return rows.isEmpty ? nil : CompareSection(title: section.title, rows: rows)
        }
    }

    private var valueRows: [CompareRow] {
        [
            CompareRow(
                label: "Assessed",
                values: props.map { $0.assessedValue.map(currencyLabel) },
                bestIndex: nil
            ),
            CompareRow(
                label: "Tax",
                values: props.map {
                    guard let v = $0.propertyTax else { return nil }
                    return $0.propertyTaxIsEstimated ? currencyLabel(v) + "*" : currencyLabel(v)
                },
                bestIndex: bestDouble(props.map(\.propertyTax), higher: false)
            ),
        ]
    }

    private var sizeRows: [CompareRow] {
        [
            CompareRow(
                label: "Living",
                values: props.map { $0.livingArea.map { "\(Int($0).formatted()) sf" } },
                bestIndex: bestDouble(props.map(\.livingArea), higher: true)
            ),
            CompareRow(
                label: "Lot",
                values: props.map { $0.landArea.map { "\(Int($0).formatted()) sf" } },
                bestIndex: bestDouble(props.map(\.landArea), higher: true)
            ),
        ]
    }

    private var propertyRows: [CompareRow] {
        [
            CompareRow(
                label: "Year Built",
                values: props.map { $0.yearBuilt.map { "\($0)" } },
                bestIndex: bestInt(props.map(\.yearBuilt), higher: true)
            ),
            CompareRow(label: "Style",   values: props.map { $0.houseStyle?.nilIfEmpty },   bestIndex: nil),
            CompareRow(label: "Storeys", values: props.map { $0.storeys?.nilIfEmpty },       bestIndex: nil),
            CompareRow(label: "Zoning",  values: props.map { $0.zoning?.nilIfEmpty },        bestIndex: nil),
        ]
    }

    private var featureRows: [CompareRow] {
        [
            featureRow("Basement",  \.basement),
            featureRow("Garage",    \.garage),
            featureRow("A/C",       \.airConditioning),
            featureRow("Fireplace", \.fireplace),
            featureRow("Pool",      \.swimmingPool),
        ]
    }

    private func featureRow(_ label: String, _ kp: KeyPath<SavedReport, String?>) -> CompareRow {
        CompareRow(
            label: label,
            values: props.map {
                guard let v = $0[keyPath: kp], !v.isEmpty else { return nil }
                let low = v.lowercased()
                guard low != "none", low != "no" else { return nil }
                return v
            },
            bestIndex: nil
        )
    }

    private var civicRows: [CompareRow] {
        [
            CompareRow(
                label: "District",
                values: props.map { $0.neighbourhood.nilIfEmpty },
                bestIndex: nil
            ),
            CompareRow(label: "Ward", values: reports.map { $0?.civicContext?.ward?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Postal", values: reports.map { $0?.civicContext?.postalCode?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Plow Zone", values: reports.map { $0?.civicContext?.plowZone?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "School Div.", values: reports.map { $0?.civicContext?.schoolDivision?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "School Ward", values: reports.map { $0?.civicContext?.schoolDivisionWard?.nilIfEmpty }, bestIndex: nil),
        ]
    }

    private var collectionRows: [CompareRow] {
        [
            CompareRow(label: "Garbage", values: reports.map { $0?.waste?.garbageDay?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Recycling", values: reports.map { $0?.waste?.recycleDay?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Yard Waste", values: reports.map { $0?.waste?.yardWasteDay?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Next Plow", values: reports.map { $0?.waste?.nextPlowWindow?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Snow Ban", values: reports.map { $0?.waste?.activeSnowBan == nil ? nil : "Active" }, bestIndex: nil),
        ]
    }

    private var schoolRows: [CompareRow] {
        [
            CompareRow(label: "Assigned", values: reports.map { report in
                report?.nearbySchools.first(where: \.isAssigned)?.name.nilIfEmpty
            }, bestIndex: nil),
            CompareRow(label: "Nearest", values: reports.map { $0?.nearbySchools.first?.name.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Distance", values: reports.map { $0?.nearbySchools.first?.distanceDescription.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Walk", values: reports.map { $0?.nearbySchools.first?.walkingTimeDescription?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Grades", values: reports.map { $0?.nearbySchools.first?.grades?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Programs", values: reports.map { report in
                guard let programs = report?.nearbySchools.first?.programs, !programs.isEmpty else { return nil }
                return programs.prefix(2).joined(separator: ", ")
            }, bestIndex: nil),
            CompareRow(
                label: "Nearby",
                values: reports.map { report in
                    guard let count = report?.nearbySchools.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.nearbySchools.count }, higher: true)
            ),
        ]
    }

    private var safetyRows: [CompareRow] {
        [
            CompareRow(
                label: "Permits",
                values: props.map { Optional("\($0.permitCount)") },
                bestIndex: nil
            ),
            CompareRow(
                label: "Vacant Orders",
                values: props.map { Optional("\($0.vacantOrderCount)") },
                bestIndex: bestInts(props.map(\.vacantOrderCount), higher: false)
            ),
            CompareRow(
                label: "311 Calls",
                values: props.map { $0.serviceRequestTotal.map { "\($0.formatted())" } },
                bestIndex: bestInt(props.map(\.serviceRequestTotal), higher: false)
            ),
            CompareRow(
                label: "311 Open",
                values: reports.map { $0?.serviceRequests.map { "\($0.openLastYear.formatted())" } },
                bestIndex: bestInt(reports.map { $0?.serviceRequests?.openLastYear }, higher: false)
            ),
            CompareRow(
                label: "Fire/Med",
                values: reports.map { $0?.emergency.map { "\($0.totalLastYear.formatted())" } },
                bestIndex: bestInt(reports.map { $0?.emergency?.totalLastYear }, higher: false)
            ),
            CompareRow(
                label: "Avg Call",
                values: reports.map { $0?.emergency?.averageDurationMinutes.map { "\(Int($0.rounded())) min" } },
                bestIndex: bestDouble(reports.map { $0?.emergency?.averageDurationMinutes }, higher: false)
            ),
            CompareRow(
                label: "Vehicle",
                values: reports.map { $0?.emergency.map { "\($0.motorVehicleLastYear.formatted())" } },
                bestIndex: bestInt(reports.map { $0?.emergency?.motorVehicleLastYear }, higher: false)
            ),
            CompareRow(
                label: "Crime/Year",
                values: props.map { $0.crimeLastYear.map { "\($0.formatted())" } },
                bestIndex: bestInt(props.map(\.crimeLastYear), higher: false)
            ),
            CompareRow(
                label: "Bylaw",
                values: reports.map { $0?.bylaw?.yearly.last.map { "\($0.count.formatted())" } },
                bestIndex: bestInt(reports.map { $0?.bylaw?.yearly.last?.count }, higher: false)
            ),
            CompareRow(label: "ER", values: reports.map { $0?.publicHealth?.nearestER?.name.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Walk-ins",
                values: reports.map { $0?.publicHealth?.walkInClinicsNearby.map { "\($0)" } },
                bestIndex: bestInt(reports.map { $0?.publicHealth?.walkInClinicsNearby }, higher: true)
            ),
        ]
    }

    private var accessRows: [CompareRow] {
        [
            CompareRow(
                label: "Parks Nearby",
                values: props.map { $0.parkCount.map { "\($0)" } },
                bestIndex: bestInt(props.map(\.parkCount), higher: true)
            ),
            CompareRow(label: "Nearest Park", values: reports.map { $0?.parks?.nearestPark?.name.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Park Ha",
                values: reports.map { $0?.parks?.neighbourhoodHectares.map { String(format: "%.1f", $0) } },
                bestIndex: bestDouble(reports.map { $0?.parks?.neighbourhoodHectares }, higher: true)
            ),
            CompareRow(
                label: "Transit",
                values: props.map { $0.transitOnTimePct.map { String(format: "%.0f%%", $0) } },
                bestIndex: bestDouble(props.map(\.transitOnTimePct), higher: true)
            ),
            CompareRow(
                label: "Routes",
                values: reports.map { report in
                    guard let count = report?.transit?.routes.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.transit?.routes.count }, higher: true)
            ),
            CompareRow(label: "Stop", values: reports.map { $0?.transit?.nearestStop?.distanceDescription.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Road", values: reports.map { $0?.streetAccess?.pavementCondition?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Speed", values: reports.map { $0?.infrastructure?.speedLimit?.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Bike Routes",
                values: reports.map { $0?.streetAccess.map { "\($0.cyclingRoutesNearby)" } },
                bestIndex: bestInt(reports.map { $0?.streetAccess?.cyclingRoutesNearby }, higher: true)
            ),
            CompareRow(
                label: "Disruptions",
                values: reports.map { report in
                    guard let street = report?.streetAccess else { return nil }
                    return "\(street.activeDisruptions.count + street.activeLaneClosures.count)"
                },
                bestIndex: bestInt(reports.map { report in
                    guard let street = report?.streetAccess else { return nil }
                    return street.activeDisruptions.count + street.activeLaneClosures.count
                }, higher: false)
            ),
            CompareRow(label: "Library", values: reports.map { $0?.library?.name.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Rec Centre", values: reports.map { $0?.recreation?.nearestComplex?.name.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Activities",
                values: reports.map { report in
                    guard let count = report?.recreation?.activities.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.recreation?.activities.count }, higher: true)
            ),
            CompareRow(
                label: "Pools",
                values: reports.map { report in
                    guard let count = report?.aquatics?.pools.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.aquatics?.pools.count }, higher: true)
            ),
            CompareRow(
                label: "Walkways",
                values: reports.map { $0?.aquatics.map { "\($0.walkwaysNearby)" } },
                bestIndex: bestInt(reports.map { $0?.aquatics?.walkwaysNearby }, higher: true)
            ),
            CompareRow(label: "Wi-Fi", values: reports.map { $0?.aquatics?.nearestWifi?.name.nilIfEmpty }, bestIndex: nil),
        ]
    }

    private var planningRows: [CompareRow] {
        [
            CompareRow(label: "Zoning Use", values: reports.map { $0?.planning?.zoningDescription?.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Notices",
                values: reports.map { report in
                    guard let count = report?.planning?.publicNotices.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.planning?.publicNotices.count }, higher: false)
            ),
            CompareRow(
                label: "Dev Permits",
                values: reports.map { report in
                    guard let count = report?.development?.recentPermits.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.development?.recentPermits.count }, higher: false)
            ),
            CompareRow(
                label: "Review Days",
                values: reports.map { $0?.development?.reviewProcessing.first?.averageBusinessDays.formatted(.number.precision(.fractionLength(0))) },
                bestIndex: bestDouble(reports.map { $0?.development?.reviewProcessing.first?.averageBusinessDays }, higher: false)
            ),
            CompareRow(
                label: "STRs",
                values: reports.map { $0?.shortTermRentals.map { "\($0.total)" } },
                bestIndex: bestInt(reports.map { $0?.shortTermRentals?.total }, higher: false)
            ),
        ]
    }

    private var localAreaRows: [CompareRow] {
        [
            CompareRow(label: "Population", values: reports.map { $0?.demographics?.totalPopulation.map { "\($0.formatted())" } }, bestIndex: nil),
            CompareRow(
                label: "Income",
                values: reports.map { $0?.demographics?.medianHouseholdIncome.map(currencyLabel) },
                bestIndex: bestDouble(reports.map { $0?.demographics?.medianHouseholdIncome }, higher: true)
            ),
            CompareRow(label: "Household", values: reports.map { $0?.demographics?.averageHouseholdSize.map { String(format: "%.1f", $0) } }, bestIndex: nil),
            CompareRow(label: "Children", values: reports.map { $0?.demographics?.childrenPercent.map(percentLabel) }, bestIndex: nil),
            CompareRow(label: "Seniors", values: reports.map { $0?.demographics?.seniorsPercent.map(percentLabel) }, bestIndex: nil),
            CompareRow(label: "Councillor", values: reports.map { $0?.localGovernment?.councillor?.nilIfEmpty }, bestIndex: nil),
            CompareRow(label: "Committee", values: reports.map { $0?.localGovernment?.communityCommittee?.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Businesses",
                values: reports.map { $0?.localBusiness.map { "\($0.totalNearby)" } },
                bestIndex: bestInt(reports.map { $0?.localBusiness?.totalNearby }, higher: true)
            ),
            CompareRow(label: "Top Biz", values: reports.map { $0?.localBusiness?.topCategories.first?.incidentType.nilIfEmpty }, bestIndex: nil),
        ]
    }

    private var riskAndWorksRows: [CompareRow] {
        [
            CompareRow(
                label: "Traffic",
                values: reports.map { report in
                    guard let study = report?.traffic?.streetStudy,
                          let count = study.vehiclesCounted else { return nil }
                    return "\(count.formatted()) \(study.countSummaryUnit ?? "")".trimmingCharacters(in: .whitespaces)
                },
                bestIndex: bestInt(reports.map { $0?.traffic?.streetStudy?.vehiclesCounted }, higher: false)
            ),
            CompareRow(
                label: "Tows",
                values: reports.map { $0?.neighbourhoodRisk.map { "\($0.towingNearby)" } },
                bestIndex: bestInt(reports.map { $0?.neighbourhoodRisk?.towingNearby }, higher: false)
            ),
            CompareRow(
                label: "Paid Pkg",
                values: reports.map { $0?.neighbourhoodRisk.map { "\($0.paidParkingNearby)" } },
                bestIndex: bestInt(reports.map { $0?.neighbourhoodRisk?.paidParkingNearby }, higher: false)
            ),
            CompareRow(
                label: "Rooming",
                values: reports.map { $0?.neighbourhoodRisk?.roomingHouse?.complaintDriven.map { "\($0)" } },
                bestIndex: bestInt(reports.map { $0?.neighbourhoodRisk?.roomingHouse?.complaintDriven }, higher: false)
            ),
            CompareRow(label: "Water Area", values: reports.map { $0?.waterQuality?.area?.nilIfEmpty }, bestIndex: nil),
            CompareRow(
                label: "Water Tests",
                values: reports.map { report in
                    guard let count = report?.waterQuality?.parameters.filter({ !$0.parameter.lowercased().contains("temperature") }).count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.waterQuality?.parameters.filter { !$0.parameter.lowercased().contains("temperature") }.count }, higher: true)
            ),
            CompareRow(
                label: "Capital",
                values: reports.map { report in
                    guard let count = report?.capitalWorks?.projects.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.capitalWorks?.projects.count }, higher: true)
            ),
            CompareRow(
                label: "Closures",
                values: reports.map { report in
                    guard let count = report?.facilityClosures?.closures.count, count > 0 else { return nil }
                    return "\(count)"
                },
                bestIndex: bestInt(reports.map { $0?.facilityClosures?.closures.count }, higher: false)
            ),
        ]
    }
}

// MARK: - Shared helpers (used by table + verdict)

func currencyLabel(_ value: Double) -> String {
    if value >= 1_000_000 { return String(format: "$%.2fM", value / 1_000_000) }
    if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
    return String(format: "$%.0f", value)
}

func percentLabel(_ value: Double) -> String {
    String(format: "%.0f%%", value)
}

func shortAddress(_ address: String) -> String {
    String(address.split(separator: ",").first ?? Substring(address))
}

func bestDouble(_ values: [Double?], higher: Bool) -> Int? {
    let pairs = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
    guard pairs.count > 1, !pairs.allSatisfy({ $0.1 == pairs[0].1 }) else { return nil }
    return higher
        ? pairs.max(by: { $0.1 < $1.1 })?.0
        : pairs.min(by: { $0.1 < $1.1 })?.0
}

func bestInt(_ values: [Int?], higher: Bool) -> Int? {
    bestDouble(values.map { $0.map(Double.init) }, higher: higher)
}

func bestInts(_ values: [Int], higher: Bool) -> Int? {
    bestDouble(values.map { Optional(Double($0)) }, higher: higher)
}

fileprivate extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
