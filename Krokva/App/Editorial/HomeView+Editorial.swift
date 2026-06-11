// MARK: - Example: Editorial Home screen
//
// Plug this into your existing tab where the search screen lives.
// Uses only the Editorial primitives from the rest of this folder.

import SwiftUI

struct KrokvaEdHomeView: View {
    @State private var query = ""

    var body: some View {
        ZStack {
            Color.krokvaEdPaper.ignoresSafeArea()
            KrokvaEdAmbient()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Top bar — avatar + search button
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.krokvaEdBlue, .krokvaEdBlueDeep],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                Text("AK").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                            }
                            .krokvaEdBlueGlow()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alex Kowalski").font(.system(size: 13, weight: .bold))
                                Text("WPG · Pro").font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.krokvaEdInk.opacity(0.42))
                            }
                        }
                        Spacer()
                        Circle().fill(Color.white).frame(width: 40, height: 40)
                            .overlay(Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.krokvaEdInk))
                    }
                    .padding(.top, 8)

                    // Headline + Filters
                    HStack(alignment: .bottom) {
                        Text("Explore\nWinnipeg.").krokvaEdTitle(42)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 11, weight: .bold))
                            Text("Filters").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color.krokvaEdInk)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.krokvaEdHairline, lineWidth: 1))
                    }
                    .padding(.top, 24)

                    // Search field — liquid glass + blue glow halo
                    ZStack {
                        // Soft blue radial halo behind
                        Circle()
                            .fill(Color.krokvaEdBlue.opacity(0.22))
                            .frame(width: 240, height: 80)
                            .blur(radius: 18)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.krokvaEdBlue)
                            Text("Street address or roll #")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.krokvaEdInk.opacity(0.42))
                            Spacer()
                            ZStack {
                                Circle().fill(Color.krokvaEdBlue).frame(width: 34, height: 34)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .krokvaEdBlueGlow(strong: true)
                        }
                        .padding(.leading, 22).padding(.trailing, 8).padding(.vertical, 8)
                        .background(Color.white.opacity(0.55))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .shadow(color: Color.krokvaEdInk.opacity(0.06), radius: 14, x: 0, y: 8)
                    }
                    .padding(.top, 18)

                    // Stacked categories
                    VStack(spacing: 8) {
                        KrokvaEdStackRow(
                            label: "Pinned", meta: "8 addresses",
                            icon: "house.fill",
                            tint: .krokvaEdSlate, tintOpacity: 0.82,
                            foreground: .white
                        )
                        KrokvaEdStackRow(
                            label: "Streetwatch", meta: "12 permits",
                            icon: "arrow.up.right",
                            tint: .krokvaEdOchre, tintOpacity: 0.78,
                            foreground: .krokvaEdOnOchre
                        )
                        KrokvaEdStackRow(
                            label: "Recent", meta: "24 lookups",
                            icon: "clock.fill",
                            tint: .white, tintOpacity: 0.55,
                            foreground: .krokvaEdInk
                        )

                        KrokvaEdFeaturedRow(
                            eyebrow: "Last viewed · 2 min ago",
                            title: "412 Wellington",
                            location: "Crescentwood",
                            value: "$1.247M",
                            delta: "+5.4% YoY"
                        )
                        .padding(.top, 2)
                    }
                    .padding(.top, 18)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 22)
            }
        }
    }
}

#Preview {
    KrokvaEdHomeView()
}
