// MARK: - Stacked category rows (Home)
//
// The pill-shaped stacked rows from the Editorial Home screen.
// Use for: Pinned addresses · Streetwatch · Recent searches · etc.

import SwiftUI

struct KrokvaEdStackRow: View {
    let label: String
    let meta: String
    let icon: String                    // SF Symbol
    var tint: Color = .krokvaEdSlate
    var tintOpacity: Double = 0.82
    var foreground: Color = .white

    var body: some View {
        HStack(spacing: 12) {
            // White circle glyph
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.2)
                Text(meta)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.72)
            }

            Spacer(minLength: 8)

            // Arrow circle button
            ZStack {
                Circle()
                    .fill(foreground == .white ? Color.white : Color.krokvaEdInk)
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(foreground == .white ? Color.krokvaEdInk : Color.white)
            }
        }
        .foregroundStyle(foreground)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(tint.opacity(tintOpacity))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay(
            Capsule().stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdInk.opacity(0.10), radius: 14, x: 0, y: 12)
    }
}

// MARK: - Featured property row
//
// The larger sage tile that sits below the stacked rows on Home.

struct KrokvaEdFeaturedRow: View {
    let eyebrow: String
    let title: String
    let location: String
    let value: String
    let delta: String
    var tint: Color = .krokvaEdSage
    var tintOpacity: Double = 0.72
    var foreground: Color = .krokvaEdOnSage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(eyebrow).krokvaEdEyebrow(color: foreground.opacity(0.7))
                Spacer()
                KrokvaEdBluePill(label: delta)
            }
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KrokvaEdTypography.display(28))
                        .tracking(-0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(foreground)
                    Text(location)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(foreground.opacity(0.7))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 8) {
                    Text(value)
                        .font(KrokvaEdTypography.display(22))
                        .tracking(-0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(foreground)
                    ZStack {
                        Circle().fill(Color.krokvaEdInk).frame(width: 34, height: 34)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(18)
        .background(tint.opacity(tintOpacity))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdInk.opacity(0.12), radius: 18, x: 0, y: 14)
    }
}
