import SwiftUI

// MARK: - PermitsCard (Civic Modernist)

struct PermitsCard: View {
    let permits: [BuildingPermit]

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hammer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Building permits")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("WITHIN 200M")
                        .eyebrow(color: .krokvaInk3)
                }

                if permits.isEmpty {
                    Text("No recent street-level permits were returned.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(permits.prefix(6).enumerated(), id: \.offset) { index, permit in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.krokvaInk3)
                                }
                                .frame(width: 50)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(permit.address)
                                        .font(.system(size: 12.5, weight: permit.isAdjacentStructural ? .semibold : .regular))
                                        .foregroundStyle(permit.isAdjacentStructural ? Color.krokvaGold : Color.krokvaInk)
                                    Text([permit.type, permit.subType, permit.workType].compactMap { $0 }.joined(separator: " · "))
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                }

                                Spacer(minLength: 0)

                                if let status = permit.status {
                                    Text(status)
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(status == "Active" ? Color.krokvaGold : Color.krokvaInk3)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().strokeBorder(
                                                status == "Active" ? Color.krokvaGold : Color.krokvaLine,
                                                lineWidth: 0.5
                                            )
                                        )
                                }
                            }
                            .padding(.vertical, 9)

                            if index < permits.prefix(6).count - 1 {
                                Divider().foregroundStyle(Color.krokvaLineSoft)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - VacantOrdersCard

struct VacantOrdersCard: View {
    let orders: [VacantOrder]

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaAccent)
                    Text("Vacant building orders")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if orders.isEmpty {
                    Text("No active vacant building orders were returned on this street.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(orders.prefix(4).enumerated(), id: \.offset) { index, order in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(order.address)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Color.krokvaInk)
                                Text(order.orderType)
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.krokvaInk3)
                                HStack(spacing: 6) {
                                    Text(order.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                    Text("·")
                                    Text(order.distanceDescription ?? "—")
                                }
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(Color.krokvaInk3)
                            }
                            .padding(.vertical, 9)

                            if index < orders.prefix(4).count - 1 {
                                Divider().foregroundStyle(Color.krokvaLineSoft)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - InfrastructureCard

struct InfrastructureCard: View {
    let summary: InfrastructureSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Infrastructure")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary {
                    Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                        GridRow {
                            infraTile("Posted speed", summary.speedLimit ?? "—")
                            infraTile("Potholes repaired", "\(summary.potholes)")
                        }
                        GridRow {
                            infraTile("Public trees", "\(summary.publicTrees)")
                            infraTile("DED-tagged", "\(summary.taggedTrees)")
                        }
                    }
                } else {
                    Text("Infrastructure data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

    @ViewBuilder
    private func infraTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).eyebrow()
            Text(value)
                .font(KrokvaTypography.monoBold)
                .foregroundStyle(Color.krokvaInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - ParksAmenitiesCard

struct ParksAmenitiesCard: View {
    let summary: ParksSummary?

    private var displayParks: [ParkAmenity] {
        guard let summary else { return [] }
        if !summary.nearbyParks.isEmpty { return summary.nearbyParks }
        return summary.nearestPark.map { [$0] } ?? []
    }

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tree")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Parks nearby")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("500M")
                        .eyebrow(color: .krokvaInk3)
                }

                if let summary {
                    let parks = displayParks
                    if !parks.isEmpty {
                        HStack(spacing: 10) {
                            StatTile(label: "Parks within 500m", value: parks.count.formatted())
                            StatTile(label: "Neighbourhood parks", value: summary.neighbourhoodParkCount.formatted())
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(parks.enumerated()), id: \.element.id) { index, park in
                                parkOpenRow(park, index: index)

                                if index < parks.count - 1 {
                                    Divider().foregroundStyle(Color.krokvaLineSoft)
                                }
                            }
                        }
                    } else {
                        Text("No mapped park assets were returned within 500m.")
                            .font(KrokvaTypography.bodySecondary)
                            .foregroundStyle(Color.krokvaInk3)
                    }

                    if let hectares = summary.neighbourhoodHectares {
                        Text("\(hectares.formatted(.number.precision(.fractionLength(1)))) ha of mapped parks and open space in this neighbourhood.")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk3)
                    }
                } else {
                    Text("Park and open-space data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

    @ViewBuilder
    private func amenityTile(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).eyebrow()
            Text(value.formatted())
                .font(KrokvaTypography.monoBold)
                .foregroundStyle(Color.krokvaInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func parkOpenRow(_ park: ParkAmenity, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: index == 0 ? "location.fill" : "tree.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(index == 0 ? Color.krokvaGold : Color.green)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(park.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                        .lineLimit(2)
                    Text((index == 0 ? "Nearest · " : "") + "Park ID \(park.parkID) · \(park.distanceDescription)")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                }
                Spacer(minLength: 0)
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    amenityTile("Playgrounds", park.playgrounds)
                    amenityTile("Fields", park.fields)
                    amenityTile("Courts", park.courts)
                }
                GridRow {
                    amenityTile("Washrooms", park.washrooms)
                    amenityTile("Benches", park.benches)
                    amenityTile("Mapped assets", mappedAssetCount(park))
                }
            }

            if let coordinate = park.coordinate {
                HStack(spacing: 6) {
                    Text("Lat \(coordinate.latitude.formatted(.number.precision(.fractionLength(5))))")
                    Text("·")
                    Text("Lon \(coordinate.longitude.formatted(.number.precision(.fractionLength(5))))")
                }
                .font(KrokvaTypography.monoSmall)
                .foregroundStyle(Color.krokvaInk3)
            }
        }
        .padding(.vertical, 10)
    }

    private func mappedAssetCount(_ park: ParkAmenity) -> Int {
        park.playgrounds + park.fields + park.courts + park.washrooms + park.benches
    }
}

// MARK: - TransitAccessCard

struct TransitAccessCard: View {
    let summary: TransitAccessSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Transit access")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary {
                    Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                        GridRow {
                            infoTile("Nearest stop", summary.nearestStop?.distanceDescription ?? "—")
                            infoTile("Routes", "\(summary.routes.count)")
                        }
                        GridRow {
                            infoTile("On time", percent(summary.onTimePercentage))
                            infoTile("Pass-ups", "\(summary.passUpsLastYear)")
                        }
                    }

                    if !summary.routes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(summary.routes.prefix(5)) { route in
                                HStack {
                                    Text(route.routeNumber)
                                        .font(KrokvaTypography.monoBold)
                                        .foregroundStyle(Color.krokvaGold)
                                        .frame(width: 42, alignment: .leading)
                                    Text(route.routeName)
                                        .font(KrokvaTypography.bodySecondary)
                                        .foregroundStyle(Color.krokvaInk2)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }

                    if let boardings = summary.averageDailyBoardings {
                        Text("\(Int(boardings.rounded()).formatted()) estimated weekday boardings across nearby sampled stops.")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk3)
                    }
                } else {
                    Text("Nearby transit performance data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - DevelopmentContextCard

struct DevelopmentContextCard: View {
    let summary: DevelopmentContextSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaGold)
                    Text("Development context")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary {
                    if !summary.recentPermits.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(summary.recentPermits.prefix(3)) { permit in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(permit.address)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color.krokvaInk)
                                    Text([permit.type, permit.subType, permit.workType].compactMap { $0 }.joined(separator: " · "))
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                    Text(permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.krokvaInk3)
                                }
                                .padding(.vertical, 7)
                            }
                        }
                    }

                    if let metric = summary.reviewProcessing.first {
                        KeyValueRow(key: "Review processing", value: "\(days(metric.averageBusinessDays)) avg")
                    }
                    if let intake = summary.intake.first {
                        KeyValueRow(key: "Latest intake", value: "\(intake.approved) approved / \(intake.notApproved) not approved")
                    }
                } else {
                    Text("Development permit context is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - BylawInvestigationsCard

struct BylawInvestigationsCard: View {
    let summary: BylawInvestigationSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("By-law investigations")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("NEIGHBOURHOOD")
                        .eyebrow(color: .krokvaInk3)
                }

                if let summary {
                    if !summary.yearly.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(summary.yearly.suffix(4)) { item in
                                StatTile(label: "\(item.year)", value: item.count.formatted())
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.complaintTypes.prefix(5)) { item in
                            HStack {
                                Text(item.incidentType)
                                    .font(KrokvaTypography.bodySecondary)
                                    .foregroundStyle(Color.krokvaInk2)
                                Spacer()
                                Text(item.count.formatted())
                                    .font(KrokvaTypography.monoBold)
                                    .foregroundStyle(Color.krokvaInk)
                            }
                        }
                    }
                    Text("Shown as neighbourhood activity for \(summary.neighbourhood), not an address-level score.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    Text("Neighbourhood by-law investigation data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - RiverAndLibraryCard

struct RiverAndLibraryCard: View {
    let river: RiverGaugeSummary?
    let library: LibraryAmenity?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Civic amenities")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let library {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(library.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.krokvaInk)
                        Text("\(library.address) · \(library.distanceDescription)")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk3)
                        Text([
                            library.wifi ? "Wi-Fi" : nil,
                            library.accessibility ? "Accessible" : nil,
                            library.parkingLot ? "Parking" : nil,
                            library.roomRentals ? "Rooms" : nil
                        ].compactMap { $0 }.joined(separator: " · "))
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk2)
                    }
                }

                if let river {
                    Divider().foregroundStyle(Color.krokvaLineSoft)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(river.riverName) River · \(river.location)")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.krokvaInk)
                        Text("Nearest gauge · \(river.distanceDescription)")
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk3)
                        HStack {
                            infoTile("James", river.jamesFeet.map { String(format: "%.2f ft", $0) } ?? "—")
                            infoTile("Geodetic", river.geodeticMetric.map { String(format: "%.2f m", $0) } ?? "—")
                        }
                    }
                }

                if library == nil && river == nil {
                    Text("Library and river gauge context is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - ServiceRequestsCard

struct ServiceRequestsCard: View {
    let summary: ServiceRequestSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "phone.connection")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("311 service activity")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("NEIGHBOURHOOD")
                        .eyebrow(color: .krokvaInk3)
                }

                if let summary {
                    HStack(spacing: 10) {
                        StatTile(label: "Last 12 months", value: summary.totalLastYear.formatted())
                        StatTile(label: "Open", value: summary.openLastYear.formatted())
                        StatTile(label: "Closed", value: summary.closedLastYear.formatted())
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
                                            .frame(height: barHeight(item.count, in: summary.monthlyTrend))
                                        Text(item.label)
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Color.krokvaInk3)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("\(item.label): \(item.count) 311 requests")
                                }
                            }
                        }
                    }

                    Grid(horizontalSpacing: 14, verticalSpacing: 10) {
                        GridRow {
                            breakdownColumn("Status", summary.statusBreakdown)
                            breakdownColumn("Channel", summary.channelBreakdown)
                        }
                    }

                    breakdownSection("Subjects", summary.topSubjects)
                    breakdownSection("Reasons", summary.topReasons)
                    breakdownSection("Request types", summary.topTypes)

                    if !summary.recentRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Recent public rows")
                                .eyebrow()
                                .padding(.bottom, 6)
                            ForEach(Array(summary.recentRequests.prefix(6).enumerated()), id: \.element.id) { index, request in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(request.subject ?? request.reason ?? request.type ?? "311 request")
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(Color.krokvaInk)
                                            .lineLimit(2)
                                        Spacer(minLength: 8)
                                        Text(request.status ?? "—")
                                            .font(KrokvaTypography.monoSmall)
                                            .foregroundStyle(statusColor(request.status))
                                    }
                                    Text([request.reason, request.type, request.channel].compactMap { $0 }.joined(separator: " · "))
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                        .lineLimit(2)
                                    HStack(spacing: 6) {
                                        Text(request.openDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable")
                                        if let ward = request.ward {
                                            Text("·")
                                            Text(ward)
                                        }
                                    }
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.krokvaInk3)
                                }
                                .padding(.vertical, 8)

                                if index < min(summary.recentRequests.count, 6) - 1 {
                                    Divider().foregroundStyle(Color.krokvaLineSoft)
                                }
                            }
                        }
                    }

                    Text("311 locations are privacy-adjusted by the City, so this is shown as \(summary.neighbourhood) context only.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    Text("Neighbourhood 311 service request data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownSection(_ title: String, _ items: [IncidentBreakdown]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).eyebrow()
                ForEach(items.prefix(6)) { item in
                    HStack {
                        Text(item.incidentType)
                            .font(KrokvaTypography.bodySecondary)
                            .foregroundStyle(Color.krokvaInk2)
                            .lineLimit(2)
                        Spacer()
                        Text(item.count.formatted())
                            .font(KrokvaTypography.monoBold)
                            .foregroundStyle(Color.krokvaInk)
                    }
                }
            }
        }
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

    private func barHeight(_ value: Int, in values: [ServiceRequestMonth]) -> CGFloat {
        let maxValue = max(values.map(\.count).max() ?? 1, 1)
        return max(CGFloat(value) / CGFloat(maxValue) * 56, 4)
    }

    private func statusColor(_ status: String?) -> Color {
        guard let status else { return .krokvaInk3 }
        return status.localizedCaseInsensitiveContains("open") ? .krokvaGoldDeep : .krokvaInk3
    }
}

// MARK: - PlanningContextCard

struct PlanningContextCard: View {
    let summary: PlanningContextSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.columns")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaGold)
                    Text("Planning notices")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary {
                    if summary.zoningCode != nil || summary.zoningDescription != nil {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.zoningCode ?? "Zoning")
                                .font(KrokvaTypography.monoBold)
                                .foregroundStyle(Color.krokvaInk)
                            if let description = summary.zoningDescription {
                                Text(description)
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.krokvaInk3)
                            }
                        }
                    }

                    if !summary.publicNotices.isEmpty {
                        if summary.zoningCode != nil || summary.zoningDescription != nil {
                            Divider().foregroundStyle(Color.krokvaLineSoft)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(summary.publicNotices.prefix(4).enumerated()), id: \.element.id) { index, notice in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(notice.noticeType)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(Color.krokvaInk)
                                        Spacer(minLength: 8)
                                        Text(notice.distanceDescription ?? "Nearby")
                                            .font(KrokvaTypography.monoSmall)
                                            .foregroundStyle(Color.krokvaInk3)
                                    }
                                    Text(notice.address)
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.krokvaInk3)
                                    if let description = notice.description, !description.isEmpty {
                                        Text(description)
                                            .font(KrokvaTypography.bodySecondary)
                                            .foregroundStyle(Color.krokvaInk2)
                                            .lineLimit(2)
                                    }
                                    Text([notice.meetingDate?.formatted(date: .abbreviated, time: .omitted), notice.decision].compactMap { $0 }.joined(separator: " · "))
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.krokvaInk3)
                                }
                                .padding(.vertical, 8)

                                if index < min(summary.publicNotices.count, 4) - 1 {
                                    Divider().foregroundStyle(Color.krokvaLineSoft)
                                }
                            }
                        }
                    } else if summary.zoningCode == nil && summary.zoningDescription == nil {
                        Text("No nearby planning notices or zoning context were returned.")
                            .font(KrokvaTypography.bodySecondary)
                            .foregroundStyle(Color.krokvaInk3)
                    }
                } else {
                    Text("Planning notice data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - StreetAccessCard

struct StreetAccessCard: View {
    let summary: StreetAccessSummary?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Street access")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                if let summary {
                    Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                        GridRow {
                            infoTile("Pavement", summary.pavementCondition ?? "—")
                            infoTile("Surface", summary.pavementSurface ?? "—")
                        }
                        GridRow {
                            infoTile("Bike links", summary.cyclingRoutesNearby.formatted())
                            infoTile("School zone", summary.schoolSpeedLimit?.speedLimit ?? "—")
                        }
                    }

                    if let schoolZone = summary.schoolSpeedLimit {
                        Text([schoolZone.school, schoolZone.effectiveDays, schoolZone.effectiveTime].compactMap { $0 }.joined(separator: " · "))
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.krokvaInk3)
                    }

                    let items = summary.activeDisruptions + summary.activeLaneClosures
                    if !items.isEmpty {
                        Divider().foregroundStyle(Color.krokvaLineSoft)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.title)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(Color.krokvaInk)
                                        Spacer(minLength: 8)
                                        Text(item.status ?? item.distanceDescription ?? "Active")
                                            .font(KrokvaTypography.monoSmall)
                                            .foregroundStyle(Color.krokvaInk3)
                                    }
                                    if let detail = item.detail {
                                        Text(detail)
                                            .font(KrokvaTypography.caption)
                                            .foregroundStyle(Color.krokvaInk3)
                                            .lineLimit(2)
                                    }
                                    Text([item.startDate?.formatted(date: .abbreviated, time: .omitted), item.endDate?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.joined(separator: " to "))
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.krokvaInk3)
                                }
                                .padding(.vertical, 8)

                                if index < min(items.count, 5) - 1 {
                                    Divider().foregroundStyle(Color.krokvaLineSoft)
                                }
                            }
                        }
                    }
                } else {
                    Text("Street access and mobility data is unavailable.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                }
            }
        }
    }
}

// MARK: - SourcesCard

struct SourcesCard: View {
    let dossier: AddressDossier

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Sources & licence")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Records shown here come from public City of Winnipeg Open Data datasets and Winnipeg Police Service public crime map data.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.krokvaInk3)

                    if !dossier.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dossier.sources.prefix(4), id: \.id) { source in
                                HStack(spacing: 8) {
                                    Text(source.name)
                                        .font(KrokvaTypography.bodySecondary)
                                        .foregroundStyle(Color.krokvaInk2)
                                    Spacer(minLength: 0)
                                    Text(source.datasetID)
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.krokvaGold)
                                }
                            }
                        }
                    }

                    Text("City datasets are licensed under the Open Government Licence - Winnipeg. WPS crime map data is public, aggregated by neighbourhood/month, and shown as context, not as an address-level safety score.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.krokvaInk3)

                    HStack(spacing: 6) {
                        BrandMarkView(lineWidth: 1.5).frame(width: 12, height: 12)
                            .foregroundStyle(Color.krokvaGold)
                        Text("Krokva. Civic data for Canadian addresses.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.krokvaInk3)
                    }
                }
            }
        }
    }
}

// MARK: - Formatting helpers

func money(_ value: Double?) -> String {
    guard let value else { return "—" }
    return value.formatted(.currency(code: "CAD").precision(.fractionLength(0)))
}

func area(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value).formatted()) sf"
}

func percent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return "\(Int(value.rounded()))%"
}

func days(_ value: Double) -> String {
    String(format: "%.1f days", value)
}

@ViewBuilder
private func infoTile(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(label).eyebrow()
        Text(value)
            .font(KrokvaTypography.monoBold)
            .foregroundStyle(Color.krokvaInk)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
}
