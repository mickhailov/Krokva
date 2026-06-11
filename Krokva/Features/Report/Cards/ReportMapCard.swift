import MapKit
import SwiftUI

struct ReportMapCard: View {
    let report: AddressReport
    @State private var camera: MapCameraPosition
    @State private var showFullMap = false

    private var markers: [CivicMapMarker] {
        CivicMapMarker.markers(for: report)
    }

    init(report: AddressReport) {
        self.report = report
        let coordinate = report.property?.coordinate ?? CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )))
    }

    var body: some View {
        Button { showFullMap = true } label: {
            CleanCard(padding: 0) {
                ZStack(alignment: .bottomTrailing) {
                    GeometryReader { geo in
                        Map(position: $camera) {
                            ForEach(markers) { marker in
                                Annotation(marker.title, coordinate: marker.coordinate) {
                                    CivicMapMarkerButton(marker: marker) { }
                                }
                            }
                        }
                        .disabled(true)
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open map")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.cleanLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullMap) {
            FullReportMapView(report: report)
        }
    }
}

// MARK: - Full Map View

private struct FullReportMapView: View {
    let report: AddressReport
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition
    @State private var selectedMarker: CivicMapMarker?

    private var markers: [CivicMapMarker] {
        CivicMapMarker.markers(for: report)
    }

    init(report: AddressReport) {
        self.report = report
        let coordinate = report.property?.coordinate ?? CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        )))
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                ForEach(markers) { marker in
                    Annotation(marker.title, coordinate: marker.coordinate) {
                        CivicMapMarkerButton(marker: marker) {
                            selectedMarker = marker
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedMarker) { marker in
                CivicMapMarkerDetailView(marker: marker)
                    .presentationDetents([.medium])
            }
        }
        .accessibilityLabel("Full map showing tappable civic records for the selected address area.")
    }
}
