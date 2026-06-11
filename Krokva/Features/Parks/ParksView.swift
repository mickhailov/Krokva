import SwiftUI

struct ParksView: View {
    let summary: ParksSummary

    private let cardGradients: [(Color, Color)] = [
        (Color(hex: 0xE0F2FE), Color(hex: 0xBAE6FD)),
        (Color(hex: 0xEDE9FE), Color(hex: 0xDDD6FE)),
        (Color(hex: 0xD1FAE5), Color(hex: 0xA7F3D0)),
    ]

    private let dotColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x10B981)]

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    radarCard
                    ForEach(Array(summary.nearbyParks.prefix(3).enumerated()), id: \.offset) { i, park in
                        parkCard(park: park, index: i)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .cleanNavBar(title: "Parks Nearby")
    }

    // MARK: Radar map card

    private var radarCard: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0xE0F2FE), Color(hex: 0xEEF2FF)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    Canvas { ctx, size in
                        let cx = size.width / 2
                        let cy = size.height * 0.52
                        let rings: [(r: CGFloat, label: String)] = [(90, "300m"), (125, "400m"), (160, "500m")]

                        for ring in rings {
                            let rect = CGRect(x: cx - ring.r, y: cy - ring.r, width: ring.r * 2, height: ring.r * 2)
                            ctx.stroke(
                                Path(ellipseIn: rect),
                                with: .color(Color(hex: 0x0284C7, opacity: 0.15)),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                        }

                        // Center dot (property)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)),
                            with: .color(Color.cleanSky)
                        )
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)),
                            with: .color(.white)
                        )

                        // Park dots
                        let angles: [CGFloat] = [-0.9, 0.4, 1.8]
                        let radii: [CGFloat] = [100, 135, 115]
                        let parkDotColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x10B981)]
                        let labels = Array(summary.nearbyParks.prefix(3).enumerated())

                        for (i, (_, park)) in labels.enumerated() {
                            let angle = angles[i % angles.count]
                            let r = radii[i % radii.count]
                            let px = cx + r * cos(angle)
                            let py = cy + r * sin(angle)

                            // Glow
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: px - 16, y: py - 16, width: 32, height: 32)),
                                with: .color(parkDotColors[i % 3].opacity(0.12))
                            )
                            // Dot
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: px - 8, y: py - 8, width: 16, height: 16)),
                                with: .color(parkDotColors[i % 3])
                            )
                            // Connector
                            var connPath = Path()
                            connPath.move(to: CGPoint(x: cx, y: cy))
                            connPath.addLine(to: CGPoint(x: px, y: py))
                            ctx.stroke(connPath, with: .color(parkDotColors[i % 3].opacity(0.3)),
                                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            let _ = park
                        }
                    }
                }
                .frame(height: 220)

                // Legend
                HStack(spacing: 16) {
                    ForEach(Array(summary.nearbyParks.prefix(3).enumerated()), id: \.offset) { i, park in
                        HStack(spacing: 6) {
                            ZStack {
                                Circle().fill(dotColors[i % 3]).frame(width: 18, height: 18)
                                Text("\(i + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text(park.name.components(separatedBy: " ").prefix(2).joined(separator: " "))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.cleanLabel2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Per-park card

    private func parkCard(park: ParkAmenity, index: Int) -> some View {
        let (gradStart, gradEnd) = cardGradients[index % cardGradients.count]
        let cardColor = dotColors[index % dotColors.count]
        let totalAssets = park.playgrounds + park.benches + park.courts + park.fields + park.washrooms

        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [gradStart, gradEnd],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.68))
                            .frame(width: 36, height: 36)
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(cardColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(park.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.cleanLabel)
                        HStack(spacing: 8) {
                            Text(park.distanceDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cleanLabel2)
                        }
                    }
                }

                HStack(spacing: 8) {
                    statTile("Playgrounds", value: "\(park.playgrounds)", color: cardColor)
                    statTile("Benches", value: "\(park.benches)", color: cardColor)
                    statTile("Assets", value: "\(totalAssets)", color: cardColor)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.5)).frame(height: 5)
                        Capsule()
                            .fill(cardColor)
                            .frame(width: geo.size.width * min(CGFloat(totalAssets) / 51, 1), height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(16)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4)
    }

    private func statTile(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
