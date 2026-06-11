import MapKit
import SwiftUI

struct CityMapView: View {
    let report: AddressReport?

    @State private var position = MapCameraPosition.camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384),
            distance: 2000,
            heading: 0,
            pitch: 60
        )
    )
    @State private var showProperty = true
    @State private var showPermits = true
    @State private var showVacantOrders = true
    @State private var selectedMarker: CivicMapMarker?

    private var permitMarkers: [BuildingPermit] {
        (report?.permits ?? []).filter { $0.coordinate != nil }
    }

    private var vacantMarkers: [VacantOrder] {
        (report?.vacantOrders ?? []).filter { $0.coordinate != nil }
    }

    private var visibleMarkers: [CivicMapMarker] {
        guard let report else { return [] }
        return CivicMapMarker.markers(
            for: report,
            includeProperty: showProperty,
            includePermits: showPermits,
            includeVacantOrders: showVacantOrders
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $position) {
                    ForEach(visibleMarkers) { marker in
                        Annotation(marker.title, coordinate: marker.coordinate) {
                            CivicMapMarkerButton(marker: marker) {
                                selectedMarker = marker
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)
                .sheet(item: $selectedMarker) { marker in
                    CivicMapMarkerDetailView(marker: marker)
                        .presentationDetents([.medium])
                }

                controlBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: report?.id) {
            if let coordinate = report?.property?.coordinate {
                position = .camera(MapCamera(centerCoordinate: coordinate, distance: 2000, heading: 0, pitch: 60))
            }
        }
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            if let report {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(Color.cleanSky)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.address.displayAddress)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.cleanLabel)
                            .lineLimit(1)
                        Text(report.property?.neighbourhood ?? report.cityName)
                            .font(.caption)
                            .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                    Text("Open a report from Search to drop a pin")
                        .font(.subheadline)
                        .foregroundStyle(Color.cleanLabel2)
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                MapToggleChip(title: "Address", systemImage: "house.fill", tint: .cleanSky, isOn: $showProperty)
                MapToggleChip(title: "Permits \(permitMarkers.count)", systemImage: "hammer.fill", tint: .cleanAmber, isOn: $showPermits)
                    .disabled(permitMarkers.isEmpty)
                MapToggleChip(title: "Vacant \(vacantMarkers.count)", systemImage: "exclamationmark.triangle.fill", tint: .cleanRed, isOn: $showVacantOrders)
                    .disabled(vacantMarkers.isEmpty)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
        .shadow(color: Color.cleanLabel.opacity(0.12), radius: 22, y: 10)
    }
}

private struct MapToggleChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isOn ? Color.white : tint)
            .background(Capsule().fill(isOn ? Color.cleanSky : tint.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}
