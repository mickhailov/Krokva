import SwiftUI

// MARK: - PermitsCard

struct PermitsCard: View {
    let permits: [BuildingPermit]
    var sourceFailed = false
    @State private var isExpanded = false
    @State private var selectedPermit: BuildingPermit?

    var body: some View {
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
        .sheet(item: $selectedPermit) { permit in
            BuildingPermitDetailSheet(permit: permit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hammer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanAmber, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Building permits")
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
        if sourceFailed, permits.isEmpty { return "Database error" }
        guard !permits.isEmpty else { return "No permits in 500m" }
        return "\(permits.count) \(permits.count == 1 ? "permit" : "permits") in 500m"
    }

    @ViewBuilder
    private var fullContent: some View {
        if permits.isEmpty {
            Text(sourceFailed ? "Database error loading nearby building permits." : "No recent street-level permits were returned.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(permits.enumerated()), id: \.offset) { index, permit in
                    Button {
                        selectedPermit = permit
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(Color.cleanLabel3)
                                .frame(width: 50)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(permit.address)
                                    .font(.system(size: 12.5, weight: permit.isAdjacentStructural ? .semibold : .regular))
                                    .foregroundStyle(permit.isAdjacentStructural ? Color.cleanAmber : Color.cleanLabel)
                                Text([permit.type, permit.subType, permit.workType].compactMap { $0 }.joined(separator: " · "))
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.cleanLabel3)
                            }

                            Spacer(minLength: 0)

                            if let status = permit.status {
                                let color = permitStatusColor(status)
                                Text(status)
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(color.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel3.opacity(0.5))
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < permits.count - 1 {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                }
            }
        }
    }

    private func permitStatusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower == "issued" || lower == "active" || lower == "open" { return .cleanAmber }
        if lower.contains("complet") || lower.contains("closed") || lower.contains("final") { return .cleanGreen }
        if lower.contains("cancel") || lower.contains("void") || lower.contains("expir") || lower.contains("refus") { return .cleanRed }
        return .cleanLabel3
    }
}

// MARK: - VacantOrdersCard

struct VacantOrdersCard: View {
    let orders: [VacantOrder]
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanRed, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vacant building orders")
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
        if sourceFailed, orders.isEmpty { return "Database error" }
        guard !orders.isEmpty else { return "No vacant building orders" }
        let base = "\(orders.count) vacant \(orders.count == 1 ? "building" : "buildings") within 500 m"
        guard let nearest = orders.first?.distanceDescription else { return base }
        return "\(base) - nearest \(nearest)"
    }

    @ViewBuilder
    private var fullContent: some View {
        if orders.isEmpty {
            Text(sourceFailed ? "Database error loading vacant building orders." : "No active vacant building orders were returned on this street.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(orders.enumerated()), id: \.offset) { index, order in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(order.address)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(order.distanceDescription ?? "Distance unavailable")
                                .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                                .foregroundStyle(Color.cleanRed)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cleanRed.opacity(0.1), in: Capsule())
                        }
                        Text(order.orderType)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.cleanLabel3)
                        HStack(spacing: 6) {
                            Text(order.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                        }
                        .font(KrokvaTypography.monoSmall)
                        .foregroundStyle(Color.cleanLabel3)
                    }
                    .padding(.vertical, 9)

                    if index < orders.count - 1 {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                }
            }
        }
    }
}

// MARK: - TransitAccessCard

struct TransitAccessCard: View {
    let summary: TransitAccessSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanSky, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Transit access")
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
        guard let s = summary else { return sourceFailed ? "Database error" : "Unavailable" }
        var parts: [String] = []
        if let stop = s.nearestStop { parts.append("\(stop.distanceDescription) to bus stop") }
        if !s.routes.isEmpty {
            let nums = s.routes.prefix(3).map { $0.routeNumber }
            let extra = s.routes.count > 3 ? " +\(s.routes.count - 3)" : ""
            parts.append("Routes \(nums.joined(separator: ", "))\(extra)")
        }
        return parts.isEmpty ? "Transit data unavailable" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        infoTile("Nearest stop", summary.nearestStop?.distanceDescription ?? "—")
                        infoTile("Routes", "\(summary.routes.count)")
                    }
                    GridRow {
                        infoTile("On time", percent(summary.onTimePercentage))
                        infoTile("Pass-ups", "\(summary.passUpsLastYear)")
                    }
                    if let boardings = summary.averageDailyBoardings {
                        GridRow {
                            infoTile("Avg. daily riders", Int(boardings.rounded()).formatted())
                            infoTile("", "")
                        }
                    }
                }

                if !summary.routes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.routes.prefix(5)) { route in
                            HStack {
                                Text(route.routeNumber)
                                    .font(KrokvaTypography.monoBold)
                                    .foregroundStyle(Color.cleanAmber)
                                    .frame(width: 42, alignment: .leading)
                                Text(route.routeName)
                                    .font(KrokvaTypography.bodySecondary)
                                    .foregroundStyle(Color.cleanLabel2)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                if let boardings = summary.averageDailyBoardings {
                    Text("\(Int(boardings.rounded()).formatted()) estimated weekday boardings across nearby sampled stops.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
        } else {
            Text(sourceFailed ? "Database error loading nearby transit data." : "Nearby transit performance data is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

// MARK: - DevelopmentContextCard

struct DevelopmentContextCard: View {
    let summary: DevelopmentContextSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Development context")
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
        guard let intake = summary?.intake.first else { return sourceFailed ? "Database error" : "Unavailable" }
        return "\(intake.approved) approved · \(intake.notApproved) not approved"
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                if !summary.recentPermits.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(summary.recentPermits.prefix(3)) { permit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(permit.address)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Color.cleanLabel)
                                Text([permit.type, permit.subType, permit.workType].compactMap { $0 }.joined(separator: " · "))
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.cleanLabel3)
                                Text(permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.cleanLabel3)
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
            }
        } else {
            Text(sourceFailed ? "Database error loading development permit context." : "Development permit context is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

// MARK: - BylawInvestigationsCard

struct BylawInvestigationsCard: View {
    let summary: BylawInvestigationSummary?
    var sourceFailed = false

    var body: some View {
        ReportCard(title: "By-law investigations", systemImage: "doc.text.magnifyingglass", badge: "NEIGHBOURHOOD") {
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
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer()
                            Text(item.count.formatted())
                                .font(KrokvaTypography.monoBold)
                                .foregroundStyle(Color.cleanLabel)
                        }
                    }
                }
                Text("Shown as neighbourhood activity for \(summary.neighbourhood), not an address-level score.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
            } else {
                Text(sourceFailed ? "Database error loading by-law investigation data." : "Neighbourhood by-law investigation data is unavailable.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            }
        }
    }
}

// MARK: - CivicAmenitiesCard

struct CivicAmenitiesCard: View {
    let parks: ParksSummary?
    let river: RiverGaugeSummary?
    let library: LibraryAmenity?
    var aquatics: AquaticsAmenitiesSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    private var hasAquatics: Bool {
        guard let aquatics else { return false }
        return !aquatics.pools.isEmpty || aquatics.walkwaysNearby > 0 || aquatics.nearestWifi != nil
    }

    var body: some View {
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
    }

    // MARK: Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanGreen, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Civic amenities")
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
        if let count = parks?.nearbyParks.count, count > 0 {
            parts.append("\(count) \(count == 1 ? "park" : "parks")")
        }
        if let dogPark = parks?.nearestDogPark {
            parts.append("\(dogPark.distanceDescription) to dog park")
        }
        if let pools = aquatics?.pools.count, pools > 0 {
            parts.append("\(pools) \(pools == 1 ? "pool" : "pools")")
        }
        if library != nil { parts.append("1 library") }
        return parts.isEmpty ? "Tap to view" : parts.joined(separator: " · ")
    }

    // MARK: Full content

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let parks, !parks.nearbyParks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Parks nearby").eyebrow(color: .cleanLabel3)
                    ForEach(parks.nearbyParks) { park in
                        amenityRow(tag: "PARK", tagColor: .cleanGreen, name: park.name,
                                   distance: park.distanceDescription, detail: parkDetail(park))
                    }
                    if let dogPark = parks.nearestDogPark {
                        amenityRow(tag: "DOG", tagColor: .cleanAmber, name: dogPark.name,
                                   distance: dogPark.distanceDescription, detail: dogPark.classification.map { "\($0) off-leash area" } ?? "Off-leash area")
                    }
                }
            } else if let dogPark = parks?.nearestDogPark {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Off-leash dog park").eyebrow(color: .cleanLabel3)
                    amenityRow(tag: "DOG", tagColor: .cleanAmber, name: dogPark.name,
                               distance: dogPark.distanceDescription, detail: dogPark.classification.map { "\($0) off-leash area" } ?? "Off-leash area")
                }
            }

            if let library {
                let hasPrior = parks?.nearbyParks.isEmpty == false
                if hasPrior { Divider().foregroundStyle(Color.cleanSep) }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Library").eyebrow(color: .cleanLabel3)
                    amenityRow(tag: "LIBRARY", tagColor: .cleanIndigo, name: library.name,
                               distance: library.distanceDescription, detail: libraryDetail(library))
                }
            }

            if let river {
                let hasPrior = (parks?.nearbyParks.isEmpty == false) || parks?.nearestDogPark != nil || library != nil
                if hasPrior { Divider().foregroundStyle(Color.cleanSep) }
                VStack(alignment: .leading, spacing: 10) {
                    Text("River gauge").eyebrow(color: .cleanLabel3)
                    amenityRow(tag: "RIVER", tagColor: .cleanSky,
                               name: "\(river.riverName) River · \(river.location)",
                               distance: river.distanceDescription, detail: riverDetail(river))
                }
            }

            if let aquatics, hasAquatics {
                let hasPrior = (parks?.nearbyParks.isEmpty == false) || parks?.nearestDogPark != nil || library != nil || river != nil
                if hasPrior { Divider().foregroundStyle(Color.cleanSep) }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pools & amenities").eyebrow(color: .cleanLabel3)
                    ForEach(aquatics.pools) { pool in
                        amenityRow(tag: pool.kind, tagColor: .cleanSky, name: pool.name,
                                   distance: pool.distanceDescription,
                                   detail: pool.features.isEmpty ? nil : pool.features.joined(separator: " · "))
                    }
                    if aquatics.walkwaysNearby > 0 {
                        KeyValueRow(key: "Walkways within 600 m", value: "\(aquatics.walkwaysNearby)")
                    }
                    if let wifi = aquatics.nearestWifi {
                        KeyValueRow(key: "Public Wi-Fi", value: [wifi.name, wifi.distanceDescription].compactMap { $0 }.joined(separator: " · "))
                    }
                }
            }

            if parks == nil && library == nil && river == nil && !hasAquatics {
                Text(sourceFailed ? "Database error loading civic amenities." : "Civic amenity data is unavailable.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            }
        }
    }

    // MARK: Unified amenity row (tag pill + name + distance + detail line)

    private func amenityRow(tag: String, tagColor: Color, name: String,
                            distance: String?, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(tag.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tagColor.opacity(0.12), in: Capsule())
                Text(name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let distance {
                    Text(distance)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel2)
            }
        }
    }

    private func parkDetail(_ park: ParkAmenity) -> String? {
        let pieces: [String?] = [
            park.playgrounds > 0 ? "\(park.playgrounds) playground\(park.playgrounds == 1 ? "" : "s")" : nil,
            park.benches > 0 ? "\(park.benches) bench\(park.benches == 1 ? "" : "es")" : nil,
            park.courts > 0 ? "\(park.courts) court\(park.courts == 1 ? "" : "s")" : nil,
            park.fields > 0 ? "\(park.fields) field\(park.fields == 1 ? "" : "s")" : nil,
            park.washrooms > 0 ? "Washrooms" : nil
        ]
        let detail = pieces.compactMap { $0 }.joined(separator: " · ")
        return detail.isEmpty ? nil : detail
    }

    private func libraryDetail(_ library: LibraryAmenity) -> String? {
        let features = [
            library.wifi ? "Wi-Fi" : nil,
            library.accessibility ? "Accessible" : nil,
            library.parkingLot ? "Parking" : nil,
            library.roomRentals ? "Rooms" : nil
        ].compactMap { $0 }
        return ([library.address] + features).joined(separator: " · ")
    }

    private func riverDetail(_ river: RiverGaugeSummary) -> String? {
        let pieces: [String?] = [
            river.jamesFeet.map { String(format: "James %.2f ft", $0) },
            river.geodeticMetric.map { String(format: "Geodetic %.2f m", $0) }
        ]
        let detail = pieces.compactMap { $0 }.joined(separator: " · ")
        return detail.isEmpty ? nil : detail
    }
}

// MARK: - PlanningContextCard

struct PlanningContextCard: View {
    let summary: PlanningContextSummary?
    var sourceFailed = false
    @State private var isExpanded = false
    @State private var selectedNotice: PublicNotice?

    var body: some View {
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
        .sheet(item: $selectedNotice) { notice in
            PublicNoticeDetailSheet(notice: notice)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "building.columns")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Planning notices")
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
        guard let summary else { return sourceFailed ? "Database error" : "Unavailable" }
        var parts: [String] = []
        if let code = summary.zoningCode { parts.append(code) }
        let count = summary.publicNotices.count
        if count > 0 {
            parts.append("\(count) \(count == 1 ? "notice" : "notices")")
        } else if parts.isEmpty {
            return "No notices"
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                if summary.zoningCode != nil || summary.zoningDescription != nil {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.zoningCode ?? "Zoning")
                            .font(KrokvaTypography.monoBold)
                            .foregroundStyle(Color.cleanLabel)
                        if let description = summary.zoningDescription {
                            Text(description)
                                .font(KrokvaTypography.caption)
                                .foregroundStyle(Color.cleanLabel3)
                        }
                        if let intent = summary.zoningIntent, !intent.isEmpty {
                            Text(intent)
                                .font(KrokvaTypography.bodySecondary)
                                .foregroundStyle(Color.cleanLabel2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }

                if !summary.publicNotices.isEmpty {
                    if summary.zoningCode != nil || summary.zoningDescription != nil {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(summary.publicNotices.prefix(4).enumerated()), id: \.element.id) { index, notice in
                            Button {
                                selectedNotice = notice
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(notice.noticeType.capitalized)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(Color.cleanLabel)
                                        Spacer(minLength: 8)
                                        Text(notice.distanceDescription ?? "Nearby")
                                            .font(KrokvaTypography.monoSmall)
                                            .foregroundStyle(Color.cleanLabel3)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.cleanLabel3.opacity(0.5))
                                    }
                                    Text(notice.address.capitalized)
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.cleanLabel3)
                                    if let description = notice.description, !description.isEmpty {
                                        Text(description)
                                            .font(KrokvaTypography.bodySecondary)
                                            .foregroundStyle(Color.cleanLabel2)
                                            .lineLimit(2)
                                    }
                                    HStack(spacing: 8) {
                                        if let date = notice.meetingDate {
                                            Text("Meeting \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(KrokvaTypography.monoSmall)
                                                .foregroundStyle(Color.cleanLabel3)
                                        }
                                        if let decision = notice.decision, !decision.isEmpty {
                                            let dcolor = planningDecisionColor(decision)
                                            Text(decision.capitalized)
                                                .font(KrokvaTypography.monoSmall)
                                                .foregroundStyle(dcolor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(dcolor.opacity(0.10), in: Capsule())
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < min(summary.publicNotices.count, 4) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                } else if summary.zoningCode == nil && summary.zoningDescription == nil {
                    Text("No nearby planning notices or zoning context were returned.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
        } else {
            Text(sourceFailed ? "Database error loading planning notices." : "Planning notice data is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }

    private func planningDecisionColor(_ decision: String) -> Color {
        let lower = decision.lowercased()
        if lower.contains("approv") || lower.contains("grant") { return .cleanGreen }
        if lower.contains("refus") || lower.contains("deni") || lower.contains("reject") { return .cleanRed }
        return .cleanLabel3
    }
}

// MARK: - StreetAccessCard (merged with Infrastructure)

struct StreetAccessCard: View {
    let street: StreetAccessSummary?
    let infrastructure: InfrastructureSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    // MARK: Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanGreen, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Street access")
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
        if let roadType = street?.roadType { parts.append(roadType) }
        else if let surface = street?.pavementSurface { parts.append(surface) }
        if let trees = infrastructure?.publicTrees { parts.append("\(trees) trees") }
        if parts.isEmpty { return "Tap to view" }
        return parts.joined(separator: " · ")
    }

    // MARK: Full content

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Street access section
            if let street {
                Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        infoTile("Pavement", street.pavementCondition ?? "—")
                        infoTile("Surface", street.pavementSurface ?? "—")
                    }
                    GridRow {
                        infoTile("Bike links", street.cyclingRoutesNearby.formatted())
                        infoTile("School zone", street.schoolSpeedLimit?.speedLimit ?? "—")
                    }
                }

                if street.pavementCondition == nil && street.pavementSurface == nil {
                    Text("No pavement survey on record — Winnipeg surveys pavement condition on major and collector roads, not most residential streets.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }

                if let schoolZone = street.schoolSpeedLimit {
                    Text([schoolZone.school, schoolZone.effectiveDays, schoolZone.effectiveTime].compactMap { $0 }.joined(separator: " · "))
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }

                let items = street.activeDisruptions + street.activeLaneClosures
                if !items.isEmpty {
                    Divider().foregroundStyle(Color.cleanSep)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color.cleanLabel)
                                    Spacer(minLength: 8)
                                    Text(item.status ?? item.distanceDescription ?? "Active")
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                                if let detail = item.detail {
                                    Text(detail)
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.cleanLabel3)
                                        .lineLimit(2)
                                }
                                Text([item.startDate?.formatted(date: .abbreviated, time: .omitted), item.endDate?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.joined(separator: " to "))
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.cleanLabel3)
                            }
                            .padding(.vertical, 8)

                            if index < min(items.count, 5) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                }
            } else if sourceFailed {
                Text("Database error loading street access data.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            } else {
                Text("No pavement survey, bike route, or active disruption on record for this street. Winnipeg surveys pavement condition on major and collector roads, so quieter residential streets are often not included.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            }

            // Infrastructure section
            if let infra = infrastructure {
                Divider().foregroundStyle(Color.cleanSep)
                Text("Infrastructure").eyebrow(color: .cleanLabel3)
                Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        infoTile("Posted speed", infra.speedLimit ?? "—")
                        infoTile("Potholes repaired", "\(infra.potholes)")
                    }
                    GridRow {
                        infoTile("Public trees", "\(infra.publicTrees)")
                        infoTile("Top species", infra.topTreeSpecies ?? "—")
                    }
                }
                if infra.potholes == 0 {
                    Text("No pothole repairs logged on this street — common for newer neighbourhoods.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
        }
    }
}

// MARK: - CivicContextCard

struct CivicContextCard: View {
    let summary: AddressCivicContext?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanSky, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Civic boundaries")
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
        guard let summary else { return sourceFailed ? "Database error" : "Unavailable" }
        var parts: [String] = []
        if let ward = summary.ward { parts.append(ward) }
        if let neighbourhood = summary.neighbourhood { parts.append(neighbourhood) }
        if let plow = summary.plowZone { parts.append("Plow \(plow)") }
        return parts.isEmpty ? "Tap to view" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        infoTile("Ward", summary.ward ?? "—")
                        infoTile("Plow zone", summary.plowZone ?? "—")
                    }
                    GridRow {
                        infoTile("Neighbourhood", summary.neighbourhood ?? "—")
                        infoTile("Postal code", summary.postalCode ?? "—")
                    }
                }

                if let addressID = summary.addressID {
                    Text("Address ID \(addressID)")
                        .font(KrokvaTypography.monoSmall)
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
        } else {
            Text(sourceFailed ? "Database error loading civic boundary data." : "Address-level civic boundary data is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

// MARK: - RecreationCard

struct RecreationCard: View {
    let summary: RecreationSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanGreen, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recreation nearby")
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
        guard let summary else { return sourceFailed ? "Database error" : "Unavailable" }
        var parts: [String] = []
        if let nearest = summary.nearestComplex {
            parts.append(nearest.distanceDescription.map { "\($0) to \(nearest.name)" } ?? nearest.name)
        }
        if !summary.activities.isEmpty {
            parts.append("\(summary.activities.count) activities")
        }
        if !summary.communityCentres.isEmpty {
            parts.append("\(summary.communityCentres.count) community centres")
        }
        return parts.isEmpty ? "No nearby recreation data" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                if !summary.complexes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Complexes").eyebrow(color: .cleanLabel3).padding(.bottom, 6)
                        ForEach(Array(summary.complexes.prefix(4).enumerated()), id: \.element.id) { index, complex in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(complex.name)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color.cleanLabel)
                                    Spacer(minLength: 8)
                                    Text(complex.distanceDescription ?? "Nearby")
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                                Text([complex.address, complex.amenities.prefix(4).joined(separator: " · ")].compactMap { value in
                                    value?.isEmpty == false ? value : nil
                                }.joined(separator: " · "))
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.cleanLabel3)
                            }
                            .padding(.vertical, 8)

                            if index < min(summary.complexes.count, 4) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                }

                if !summary.communityCentres.isEmpty {
                    if !summary.complexes.isEmpty { Divider().foregroundStyle(Color.cleanSep) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Community centres").eyebrow(color: .cleanLabel3).padding(.bottom, 6)
                        ForEach(Array(summary.communityCentres.prefix(4).enumerated()), id: \.element.id) { index, centre in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(centre.name)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color.cleanLabel)
                                    Spacer(minLength: 8)
                                    Text(centre.distanceDescription ?? "Nearby")
                                        .font(KrokvaTypography.monoSmall)
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                                if let address = centre.address {
                                    Text(address)
                                        .font(KrokvaTypography.caption)
                                        .foregroundStyle(Color.cleanLabel3)
                                }
                            }
                            .padding(.vertical, 8)

                            if index < min(summary.communityCentres.count, 4) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                }

                if !summary.activities.isEmpty {
                    if !summary.complexes.isEmpty || !summary.communityCentres.isEmpty { Divider().foregroundStyle(Color.cleanSep) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Programs").eyebrow(color: .cleanLabel3).padding(.bottom, 6)
                        ForEach(Array(summary.activities.prefix(5).enumerated()), id: \.element.id) { index, activity in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(activity.name)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Color.cleanLabel)
                                Text([activity.placeName, activity.category, activity.activityType].compactMap { $0 }.joined(separator: " · "))
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.cleanLabel3)
                                HStack(spacing: 6) {
                                    Text(activity.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date TBD")
                                    if let openSpaces = activity.openSpaces {
                                        Text("·")
                                        Text("\(openSpaces) open")
                                    }
                                    if let status = activity.status {
                                        Text("·")
                                        Text(status)
                                    }
                                }
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(Color.cleanLabel3)
                            }
                            .padding(.vertical, 8)

                            if index < min(summary.activities.count, 5) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                }
            }
        } else {
            Text(sourceFailed ? "Database error loading nearby recreation data." : "Nearby recreation complex and program data is unavailable.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

// MARK: - ShortTermRentalsCard

struct ShortTermRentalsCard: View {
    let summary: ShortTermRentalSummary?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
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
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bed.double")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanAmber, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Short-term rentals")
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
        guard let summary else { return sourceFailed ? "Database error" : "No matched rental records" }
        return "\(summary.total) matched · \(summary.nonPrimaryCount) non-primary"
    }

    @ViewBuilder
    private var fullContent: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                    GridRow {
                        infoTile("Total matched", summary.total.formatted())
                        infoTile("Primary", summary.primaryCount.formatted())
                    }
                    GridRow {
                        infoTile("Non-primary", summary.nonPrimaryCount.formatted())
                        infoTile("Recent rows", summary.recent.count.formatted())
                    }
                }

                if !summary.recent.isEmpty {
                    Divider().foregroundStyle(Color.cleanSep)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(summary.recent.prefix(5).enumerated()), id: \.element.id) { index, rental in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rental.address)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Color.cleanLabel)
                                Text([rental.primaryStatus, rental.ward].compactMap { $0 }.joined(separator: " · "))
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.cleanLabel3)
                                Text(rental.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Issue date unavailable")
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.cleanLabel3)
                            }
                            .padding(.vertical, 8)

                            if index < min(summary.recent.count, 5) - 1 {
                                Divider().foregroundStyle(Color.cleanSep)
                            }
                        }
                    }
                }

                Text("Matched by street text from the public registry; this is context, not a zoning or compliance determination.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
            }
        } else {
            Text(sourceFailed ? "Database error loading short-term rental records." : "No short-term rental records matched nearby street names.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

// MARK: - SourcesCard

struct SourcesCard: View {
    let report: AddressReport

    var body: some View {
        ReportCard(title: "Sources & licence", systemImage: "link") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Records shown here come from public City of Winnipeg Open Data datasets and Winnipeg Police Service public crime map data.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)

                if !report.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.sources.prefix(4), id: \.id) { source in
                            HStack(spacing: 8) {
                                Text(source.name)
                                    .font(KrokvaTypography.bodySecondary)
                                    .foregroundStyle(Color.cleanLabel2)
                                Spacer(minLength: 0)
                                Text(source.datasetID)
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.cleanAmber)
                            }
                        }
                    }
                }

                Text("City datasets are licensed under the Open Government Licence - Winnipeg. WPS crime map data is public, aggregated by neighbourhood/month, and shown as context, not as an address-level safety score.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.cleanLabel3)

                HStack(spacing: 6) {
                    BrandMarkView(lineWidth: 1.5).frame(width: 12, height: 12)
                        .foregroundStyle(Color.cleanSky)
                    Text("Krokva. Civic data for Canadian addresses.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.cleanLabel3)
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
        Text(label).eyebrow(color: .cleanLabel3)
        Text(value)
            .font(KrokvaTypography.monoBold)
            .foregroundStyle(Color.cleanLabel)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
}

// MARK: - PublicNoticeDetailSheet

struct PublicNoticeDetailSheet: View {
    let notice: PublicNotice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(notice.noticeType.uppercased())
                        .eyebrow(color: .cleanLabel3)
                    Text(notice.address.capitalized)
                        .font(KrokvaTypography.h1)
                        .foregroundStyle(Color.cleanLabel)
                    if let dist = notice.distanceDescription {
                        Text(dist)
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.cleanLabel3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    if let description = notice.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .eyebrow(color: .cleanLabel3)
                            Text(description)
                                .font(KrokvaTypography.body)
                                .foregroundStyle(Color.cleanLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let date = notice.meetingDate {
                        KeyValueRow(key: "Meeting date", value: date.formatted(date: .long, time: .omitted))
                    }

                    if let decision = notice.decision, !decision.isEmpty {
                        let dcolor = noticeDecisionColor(decision)
                        HStack(alignment: .firstTextBaseline) {
                            Text("Decision")
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer(minLength: 16)
                            Text(decision.capitalized)
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(dcolor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dcolor.opacity(0.10), in: Capsule())
                        }
                        .font(.subheadline)
                    }
                }
                .padding(20)
            }
        }
    }

    private func noticeDecisionColor(_ decision: String) -> Color {
        let lower = decision.lowercased()
        if lower.contains("approv") || lower.contains("grant") { return .cleanGreen }
        if lower.contains("refus") || lower.contains("deni") || lower.contains("reject") { return .cleanRed }
        return .cleanLabel3
    }
}

// MARK: - BuildingPermitDetailSheet

struct BuildingPermitDetailSheet: View {
    let permit: BuildingPermit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Building Permit")
                        .eyebrow(color: .cleanLabel3)
                    Text(permit.address)
                        .font(KrokvaTypography.h1)
                        .foregroundStyle(Color.cleanLabel)
                    if permit.isAdjacentStructural {
                        Text("Adjacent structural work")
                            .font(KrokvaTypography.monoSmall)
                            .foregroundStyle(Color.cleanAmber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    if let date = permit.issuedDate {
                        KeyValueRow(key: "Issued", value: date.formatted(date: .long, time: .omitted))
                    }
                    let typeStr = [permit.type, permit.subType, permit.workType].compactMap { $0 }.joined(separator: " · ")
                    if !typeStr.isEmpty {
                        KeyValueRow(key: "Type", value: typeStr)
                    }
                    if let status = permit.status {
                        let color = permitDetailStatusColor(status)
                        HStack(alignment: .firstTextBaseline) {
                            Text("Status")
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer(minLength: 16)
                            Text(status)
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.10), in: Capsule())
                                .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
                        }
                        .font(.subheadline)
                    }
                }
                .padding(20)
            }
        }
    }

    private func permitDetailStatusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower == "issued" || lower == "active" || lower == "open" { return .cleanAmber }
        if lower.contains("complet") || lower.contains("closed") || lower.contains("final") { return .cleanGreen }
        if lower.contains("cancel") || lower.contains("void") || lower.contains("expir") || lower.contains("refus") { return .cleanRed }
        return .cleanLabel3
    }
}
