// MARK: - Hero / Value / Mini tiles (Report)
//
// Reusable Editorial tile components — translucent tinted glass with depth.

import SwiftUI

// MARK: - Hero address (top of Report)

struct KrokvaEdHeroAddress: View {
    let street: String              // "412 Wellington"
    let cont: String                // "Crescent."
    let location: String            // "Crescentwood, Winnipeg MB · R3M 0A1"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                KrokvaEdBluePill(label: "Live", withDot: true)
                EdTag(label: "Crescentwood")
                EdTag(label: "R1-N")
            }
            VStack(alignment: .leading, spacing: -2) {
                Text(street).krokvaEdTitle(40)
                Text(cont).krokvaEdTitle(40)
            }
            Text(location)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.krokvaEdInk.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Value tile (ochre tinted glass)

struct KrokvaEdValueTile: View {
    let value: String               // "$1.247M"
    let delta: String               // "+5.4% YoY"
    let history: [Double]           // 9 values, normalized 0–1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("2024 Assessment").krokvaEdEyebrow(color: Color.krokvaEdOnOchre.opacity(0.7))
                Spacer()
                KrokvaEdBluePill(label: delta)
            }
            Text(value).krokvaEdTitle(46, color: .krokvaEdOnOchre)

            // Sparkline
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { p in
                    for (i, v) in history.enumerated() {
                        let x = w * (CGFloat(i) / CGFloat(max(history.count - 1, 1)))
                        let y = h - h * CGFloat(v)
                        i == 0 ? p.move(to: .init(x: x, y: y))
                               : p.addLine(to: .init(x: x, y: y))
                    }
                }
                .stroke(Color.krokvaEdOnOchre, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = history.last {
                    let cx = w
                    let cy = h - h * CGFloat(last)
                    Circle()
                        .fill(Color.krokvaEdOnOchre)
                        .frame(width: 10, height: 10)
                        .position(x: cx, y: cy)
                    Circle()
                        .fill(Color.krokvaEdOchre)
                        .frame(width: 4, height: 4)
                        .position(x: cx, y: cy)
                }
            }
            .frame(height: 56)
        }
        .padding(22)
        .background(Color.krokvaEdOchre.opacity(0.78))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdInk.opacity(0.14), radius: 22, x: 0, y: 16)
    }
}

// MARK: - Mini tile (2-column report facts)

struct KrokvaEdMiniTile: View {
    let label: String               // "Year built"
    let value: String               // "1924"
    let sub: String                 // "Era · Pre-war"
    var tint: Color
    var tintOpacity: Double = 0.78
    var foreground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).krokvaEdEyebrow(color: foreground.opacity(0.72))
            Text(value)
                .font(KrokvaEdTypography.display(26))
                .tracking(-0.4)
                .textCase(.uppercase)
                .foregroundStyle(foreground)
            Text(sub)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(tint.opacity(tintOpacity))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdInk.opacity(0.10), radius: 16, x: 0, y: 12)
    }
}

// MARK: - Small tag (used in hero header)

struct EdTag: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.krokvaEdInk.opacity(0.62))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.55)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
    }
}
