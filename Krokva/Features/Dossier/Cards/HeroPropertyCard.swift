import CoreLocation
import MapKit
import SwiftUI

// MARK: - HeroPropertyCard (Civic Modernist · map hero)
//
// Top-of-dossier card. The visual signature of the locked design:
//
//   ┌────────────────────────┐
//   │  ▒▒▒ dark muted map ▒▒ │  220pt — MapKit, forced dark, gold pin
//   │  ▒▒▒ visible map ▒▒▒▒ │
//   ├────────────────────────┤  hairline
//   │  ADDRESS               │  white card body
//   │  412 Wellington Cres   │
//   │  Winnipeg, MB · roll…  │
//   └────────────────────────┘
//
// Pieces:
//   • Gold rule across the top-left (KrokvaCard accent)
//   • MapKit Map, dark color scheme, muted standard style, non-interactive
//   • Gold property pin (annotation) at the property coordinate
//   • Below: address and compact public-record context

struct HeroPropertyCard: View {
    let dossier: AddressDossier
    private let mapHeaderHeight: CGFloat = 250

    private var coordinate: CLLocationCoordinate2D {
        dossier.property?.coordinate
            ?? CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
    }

    private var camera: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        ))
    }

    var body: some View {
        KrokvaCard(accent: true) {
            VStack(spacing: 0) {
                mapHeader
                bodySection
            }
        }
    }

    // MARK: Map header

    private var mapHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // The map
            Map(
                initialPosition: camera,
                interactionModes: []           // static; tappable via the card itself
            ) {
                Annotation("", coordinate: coordinate) {
                    GoldPropertyPin()
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(height: mapHeaderHeight)
            .clipped()

            // Corner ticks (subtle blueprint nod)
            cornerTick.padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: 0) {
                Spacer()
                cornerTick.rotationEffect(.degrees(90)).padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Coordinates badge
            Text(coordinateString)
                .font(KrokvaTypography.monoSmall)
                .tracking(0.6)
                .foregroundStyle(Color.krokvaGoldSoft.opacity(0.65))
                .padding(.top, 12)
                .padding(.trailing, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: mapHeaderHeight)
        .clipShape(
            // round only the top corners — KrokvaCard's outer radius is 14
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 14,
                style: .continuous
            )
        )
    }

    private var cornerTick: some View {
        ZStack {
            Rectangle().frame(width: 10, height: 1.2)
            Rectangle().frame(width: 1.2, height: 10)
        }
        .frame(width: 10, height: 10, alignment: .topLeading)
        .foregroundStyle(Color.krokvaGold.opacity(0.7))
    }

    // MARK: Card body (white)

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Address").eyebrow()
            Text(dossier.property?.fullAddress ?? dossier.address.displayAddress)
                .font(.system(size: 32, weight: .bold, design: .default))
                .tracking(0)
                .foregroundStyle(Color.krokvaInk)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
            Text(addressDescription)
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.krokvaInk3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.krokvaInk3)
                Text("Public assessment record from municipal open data.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.krokvaInk3)
            }
            .padding(.top, 2)
        }
        .padding(18)
    }

    // MARK: Computed strings

    private var subLine: String {
        if let prov = dossier.address.provinceCode {
            return "\(dossier.cityName), \(prov)"
        }
        return dossier.cityName
    }

    private var coordinateString: String {
        String(
            format: "%.4f°N · %.4f°W",
            coordinate.latitude,
            abs(coordinate.longitude)
        )
    }

    private var rollLine: String {
        if let roll = dossier.property?.rollNumber {
            return "2024 ROLL · #\(roll)"
        }
        return "2024 ROLL · MUNICIPAL RECORD"
    }

    private var addressDescription: String {
        var parts = [subLine]
        if let neighbourhood = dossier.property?.neighbourhood, !neighbourhood.isEmpty {
            parts.append(neighbourhood)
        }
        parts.append(rollLine)
        return parts.joined(separator: " · ")
    }
}

// MARK: - Gold pin annotation

private struct GoldPropertyPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.krokvaGold)
                .opacity(0.10)
                .frame(width: 56, height: 56)
            Circle()
                .fill(Color.krokvaGold)
                .opacity(0.22)
                .frame(width: 32, height: 32)
            Circle()
                .fill(Color.krokvaGold)
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color.krokvaPaper)
                .frame(width: 5, height: 5)
        }
    }
}
