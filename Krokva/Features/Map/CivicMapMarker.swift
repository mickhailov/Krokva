import MapKit
import SwiftUI

enum CivicMapMarkerKind: String {
    case address
    case permit
    case vacantOrder
    case park
    case development
    case library
    case river
    case planningNotice
    case disruption
    case laneClosure

    var systemImage: String {
        switch self {
        case .address: "house.fill"
        case .permit: "hammer.fill"
        case .vacantOrder: "exclamationmark.triangle.fill"
        case .park: "tree.fill"
        case .development: "building.2.fill"
        case .library: "books.vertical.fill"
        case .river: "water.waves"
        case .planningNotice: "building.columns.fill"
        case .disruption: "figure.walk.motion"
        case .laneClosure: "road.lanes.curved.right"
        }
    }

    var tint: Color {
        switch self {
        case .address: .cleanRed
        case .permit: .cleanAmber
        case .vacantOrder: .orange
        case .park: .green
        case .development: .cleanSky
        case .library: .purple
        case .river: .blue
        case .planningNotice: .cleanAmber
        case .disruption: .orange
        case .laneClosure: .red
        }
    }

    var label: String {
        switch self {
        case .address: "Address"
        case .permit: "Permit"
        case .vacantOrder: "Vacant order"
        case .park: "Park"
        case .development: "Development"
        case .library: "Library"
        case .river: "River gauge"
        case .planningNotice: "Planning notice"
        case .disruption: "Accessibility disruption"
        case .laneClosure: "Lane closure"
        }
    }
}

struct CivicMapDetailRow: Identifiable {
    var id: String { "\(key)-\(value)" }
    let key: String
    let value: String
}

struct CivicMapMarker: Identifiable {
    let id: String
    let kind: CivicMapMarkerKind
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let details: [CivicMapDetailRow]

    static func markers(
        for report: AddressReport,
        includeProperty: Bool = true,
        includePermits: Bool = true,
        includeVacantOrders: Bool = true,
        includeParks: Bool = true,
        includeDevelopment: Bool = true,
        includeCivicAmenities: Bool = true,
        includePlanning: Bool = true,
        includeStreetAccess: Bool = true
    ) -> [CivicMapMarker] {
        var markers: [CivicMapMarker] = []

        if includeProperty, let coordinate = report.property?.coordinate {
            markers.append(
                CivicMapMarker(
                    id: "address-\(report.id)",
                    kind: .address,
                    title: report.address.displayAddress,
                    subtitle: report.property?.neighbourhood ?? report.cityName,
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Neighbourhood", value: report.property?.neighbourhood ?? "-"),
                        CivicMapDetailRow(key: "Assessed value", value: money(report.property?.totalAssessedValue)),
                        CivicMapDetailRow(key: "Year built", value: report.property?.yearBuilt.map(String.init) ?? "-")
                    ]
                )
            )
        }

        if includePermits {
            markers.append(contentsOf: report.permits.compactMap { permit in
                guard let coordinate = permit.coordinate else { return nil }
                return CivicMapMarker(
                    id: "permit-\(permit.id)",
                    kind: .permit,
                    title: permit.address,
                    subtitle: permit.type,
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Issued", value: permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
                        CivicMapDetailRow(key: "Type", value: permit.type),
                        CivicMapDetailRow(key: "Sub type", value: permit.subType ?? "-"),
                        CivicMapDetailRow(key: "Work", value: permit.workType ?? "-"),
                        CivicMapDetailRow(key: "Status", value: permit.status ?? "-")
                    ]
                )
            })
        }

        if includeVacantOrders {
            markers.append(contentsOf: report.vacantOrders.compactMap { order in
                guard let coordinate = order.coordinate else { return nil }
                return CivicMapMarker(
                    id: "vacant-\(order.id)",
                    kind: .vacantOrder,
                    title: order.address,
                    subtitle: order.orderType,
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Issued", value: order.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
                        CivicMapDetailRow(key: "Order type", value: order.orderType),
                        CivicMapDetailRow(key: "Distance", value: order.distanceDescription ?? "-")
                    ]
                )
            })
        }

        if includeParks, let parks = report.parks {
            let nearbyParks = parks.nearbyParks.isEmpty ? parks.nearestPark.map { [$0] } ?? [] : parks.nearbyParks
            markers.append(contentsOf: nearbyParks.enumerated().compactMap { index, park in
                guard let coordinate = park.coordinate else { return nil }
                return CivicMapMarker(
                    id: "park-\(park.id)",
                    kind: .park,
                    title: park.name,
                    subtitle: index == 0 ? "Nearest park · \(park.distanceDescription)" : "Nearby park · \(park.distanceDescription)",
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Distance", value: park.distanceDescription),
                        CivicMapDetailRow(key: "Playgrounds", value: park.playgrounds.formatted()),
                        CivicMapDetailRow(key: "Fields", value: park.fields.formatted()),
                        CivicMapDetailRow(key: "Courts", value: park.courts.formatted()),
                        CivicMapDetailRow(key: "Washrooms", value: park.washrooms.formatted()),
                        CivicMapDetailRow(key: "Benches", value: park.benches.formatted())
                    ]
                )
            })
        }

        if includeDevelopment {
            markers.append(contentsOf: report.development?.recentPermits.compactMap { permit in
                guard let coordinate = permit.coordinate else { return nil }
                return CivicMapMarker(
                    id: "development-\(permit.id)",
                    kind: .development,
                    title: permit.address,
                    subtitle: permit.type,
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Issued", value: permit.issuedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
                        CivicMapDetailRow(key: "Permit", value: permit.permitNumber ?? "-"),
                        CivicMapDetailRow(key: "Type", value: permit.type),
                        CivicMapDetailRow(key: "Sub type", value: permit.subType ?? "-"),
                        CivicMapDetailRow(key: "Work", value: permit.workType ?? "-"),
                        CivicMapDetailRow(key: "Status", value: permit.status ?? "-")
                    ]
                )
            } ?? [])
        }

        if includeCivicAmenities {
            if let library = report.library,
               let coordinate = library.coordinate {
                markers.append(
                    CivicMapMarker(
                        id: "library-\(library.id)",
                        kind: .library,
                        title: library.name,
                        subtitle: "\(library.address) · \(library.distanceDescription)",
                        coordinate: coordinate,
                        details: [
                            CivicMapDetailRow(key: "Address", value: library.address),
                            CivicMapDetailRow(key: "Distance", value: library.distanceDescription),
                            CivicMapDetailRow(key: "Wi-Fi", value: yesNo(library.wifi)),
                            CivicMapDetailRow(key: "Accessible", value: yesNo(library.accessibility)),
                            CivicMapDetailRow(key: "Parking", value: yesNo(library.parkingLot)),
                            CivicMapDetailRow(key: "Room rentals", value: yesNo(library.roomRentals))
                        ]
                    )
                )
            }

            if let river = report.river,
               let coordinate = river.coordinate {
                markers.append(
                    CivicMapMarker(
                        id: "river-\(river.riverName)-\(river.location)",
                        kind: .river,
                        title: "\(river.riverName) River",
                        subtitle: "\(river.location) · \(river.distanceDescription)",
                        coordinate: coordinate,
                        details: [
                            CivicMapDetailRow(key: "Gauge", value: river.location),
                            CivicMapDetailRow(key: "Distance", value: river.distanceDescription),
                            CivicMapDetailRow(key: "James", value: river.jamesFeet.map { String(format: "%.2f ft", $0) } ?? "-"),
                            CivicMapDetailRow(key: "Geodetic", value: river.geodeticMetric.map { String(format: "%.2f m", $0) } ?? "-"),
                            CivicMapDetailRow(key: "Reading", value: river.readingDate?.formatted(date: .abbreviated, time: .shortened) ?? "Date unavailable")
                        ]
                    )
                )
            }
        }

        if includePlanning {
            markers.append(contentsOf: report.planning?.publicNotices.compactMap { notice in
                guard let coordinate = notice.coordinate else { return nil }
                return CivicMapMarker(
                    id: "notice-\(notice.id)",
                    kind: .planningNotice,
                    title: notice.noticeType,
                    subtitle: "\(notice.address) · \(notice.distanceDescription ?? "Nearby")",
                    coordinate: coordinate,
                    details: notice.mapDetails
                )
            } ?? [])
        }

        if includeStreetAccess {
            markers.append(contentsOf: report.streetAccess?.activeDisruptions.compactMap { item in
                guard let coordinate = item.coordinate else { return nil }
                return CivicMapMarker(
                    id: "disruption-\(item.id)",
                    kind: .disruption,
                    title: item.title,
                    subtitle: item.distanceDescription ?? item.status ?? "Active",
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Status", value: item.status ?? "-"),
                        CivicMapDetailRow(key: "Detail", value: item.detail ?? "-"),
                        CivicMapDetailRow(key: "Start", value: item.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
                        CivicMapDetailRow(key: "End", value: item.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable")
                    ]
                )
            } ?? [])

            markers.append(contentsOf: report.streetAccess?.activeLaneClosures.compactMap { item in
                guard let coordinate = item.coordinate else { return nil }
                return CivicMapMarker(
                    id: "closure-\(item.id)",
                    kind: .laneClosure,
                    title: item.title,
                    subtitle: item.status ?? "Lane closure",
                    coordinate: coordinate,
                    details: [
                        CivicMapDetailRow(key: "Status", value: item.status ?? "-"),
                        CivicMapDetailRow(key: "Detail", value: item.detail ?? "-"),
                        CivicMapDetailRow(key: "Start", value: item.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
                        CivicMapDetailRow(key: "End", value: item.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable")
                    ]
                )
            } ?? [])
        }

        return markers
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

private extension PublicNotice {
    var mapDetails: [CivicMapDetailRow] {
        [
            CivicMapDetailRow(key: "Address", value: address),
            CivicMapDetailRow(key: "Distance", value: distanceDescription ?? "-"),
            noticeID.map { CivicMapDetailRow(key: "Notice ID", value: $0) },
            approvalType.map { CivicMapDetailRow(key: "Approval", value: $0) },
            CivicMapDetailRow(key: "Meeting", value: meetingDate?.formatted(date: .abbreviated, time: .omitted) ?? "Date unavailable"),
            appealDate.map { CivicMapDetailRow(key: "Appeal", value: $0.formatted(date: .abbreviated, time: .omitted)) },
            decision.map { CivicMapDetailRow(key: "Decision", value: $0) },
            ward.map { CivicMapDetailRow(key: "Ward", value: $0) },
            neighbourhood.map { CivicMapDetailRow(key: "Neighbourhood", value: $0) }
        ].compactMap { $0 }
    }
}

struct CivicMapMarkerButton: View {
    let marker: CivicMapMarker
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: marker.kind.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(marker.kind.tint, in: Circle())
                .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(marker.kind.label): \(marker.title)")
    }
}

struct CivicMapMarkerDetailView: View {
    let marker: CivicMapMarker

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: marker.kind.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(marker.kind.tint, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(marker.title)
                                .font(.headline)
                                .foregroundStyle(Color.cleanLabel)
                            Text(marker.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.cleanLabel3)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    ForEach(marker.details) { detail in
                        KeyValueRow(key: detail.key, value: detail.value)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.krokvaPaper)
            .navigationTitle(marker.kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.krokvaSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
