import MapKit
import SwiftUI

struct DossierMapCard: View {
    let dossier: AddressDossier
    @State private var camera: MapCameraPosition
    @State private var selectedMarker: CivicMapMarker?

    private var markers: [CivicMapMarker] {
        CivicMapMarker.markers(for: dossier)
    }

    init(dossier: AddressDossier) {
        self.dossier = dossier
        let coordinate = dossier.property?.coordinate ?? CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
        _camera = State(initialValue: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))))
    }

    var body: some View {
        DossierCard(title: "Map", systemImage: "map") {
            Map(position: $camera) {
                ForEach(markers) { marker in
                    Annotation(marker.title, coordinate: marker.coordinate) {
                        CivicMapMarkerButton(marker: marker) {
                            selectedMarker = marker
                        }
                    }
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .sheet(item: $selectedMarker) { marker in
                CivicMapMarkerDetailView(marker: marker)
                    .presentationDetents([.medium])
            }
            .accessibilityLabel("Map showing tappable civic records for the selected address area.")
            Text("Tap a pin to see permits, parks, development context, or civic amenity details. No heatmaps or safety ratings are used.")
                .font(.caption)
                .foregroundStyle(Color.krokvaInk3)
        }
    }
}
