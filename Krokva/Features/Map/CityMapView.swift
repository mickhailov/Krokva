import MapKit
import SwiftUI

struct CityMapView: View {
    let dossier: AddressDossier?

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
    )
    @State private var showProperty = true
    @State private var showPermits = true
    @State private var showVacantOrders = true
    @State private var selectedMarker: CivicMapMarker?

    private var permitMarkers: [BuildingPermit] {
        (dossier?.permits ?? []).filter { $0.coordinate != nil }
    }

    private var vacantMarkers: [VacantOrder] {
        (dossier?.vacantOrders ?? []).filter { $0.coordinate != nil }
    }

    private var visibleMarkers: [CivicMapMarker] {
        guard let dossier else { return [] }
        return CivicMapMarker.markers(
            for: dossier,
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
        .onChange(of: dossier?.id) {
            if let coordinate = dossier?.property?.coordinate {
                position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
            }
        }
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            if let dossier {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(Color.krokvaAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dossier.address.displayAddress)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.krokvaInk)
                            .lineLimit(1)
                        Text(dossier.property?.neighbourhood ?? dossier.cityName)
                            .font(.caption)
                            .foregroundStyle(Color.krokvaInk3)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(Color.krokvaInk3)
                    Text("Open a dossier from Search to drop a pin")
                        .font(.subheadline)
                        .foregroundStyle(Color.krokvaInk2)
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                MapToggleChip(title: "Address", systemImage: "house.fill", tint: .krokvaAccent, isOn: $showProperty)
                MapToggleChip(title: "Permits \(permitMarkers.count)", systemImage: "hammer.fill", tint: .krokvaGold, isOn: $showPermits)
                    .disabled(permitMarkers.isEmpty)
                MapToggleChip(title: "Vacant \(vacantMarkers.count)", systemImage: "exclamationmark.triangle.fill", tint: .orange, isOn: $showVacantOrders)
                    .disabled(vacantMarkers.isEmpty)
            }
        }
        .padding(14)
        .background(Color.krokvaSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLine, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
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
            .foregroundStyle(isOn ? .white : tint)
            .background(
                Capsule().fill(isOn ? tint : tint.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
