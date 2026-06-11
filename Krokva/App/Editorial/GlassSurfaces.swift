// MARK: - Liquid glass surfaces
//
// Three building blocks:
//   1. KrokvaEdAmbient — full-screen blurred blob wash behind a screen.
//                        Must sit BELOW the content stack.
//   2. KrokvaGlassCard — translucent tile with backdrop blur, hairline border,
//                        inset highlight, and soft drop shadow.
//   3. .krokvaEdGlass(tint:) — modifier form for inline use.
//
// Usage:
//   ZStack {
//       Color.krokvaEdPaper.ignoresSafeArea()
//       KrokvaEdAmbient()
//       ScrollView { ... }
//   }

import SwiftUI

// MARK: - Ambient

struct KrokvaEdAmbient: View {
    var body: some View {
        ZStack {
            Blob(color: .krokvaEdClay,  opacity: 0.30,
                 size: 380, blur: 60)
                .offset(x: 180, y: -260)
            Blob(color: .krokvaEdBlue,  opacity: 0.22,
                 size: 420, blur: 70)
                .offset(x: -200, y: 60)
            Blob(color: .krokvaEdSage,  opacity: 0.26,
                 size: 360, blur: 64)
                .offset(x: 160, y: 380)
            Blob(color: .krokvaEdOchre, opacity: 0.22,
                 size: 260, blur: 60)
                .offset(x: -60, y: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Blob: View {
        let color: Color
        let opacity: Double
        let size: CGFloat
        let blur: CGFloat
        var body: some View {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(opacity), color.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: blur)
        }
    }
}

// MARK: - Glass card

struct KrokvaGlassCard<Content: View>: View {
    /// Solid tint to apply over the blurred background. Pass nil for clear glass.
    var tint: Color? = nil
    var tintOpacity: Double = 0.0       // ignored if tint is nil; default for a solid Color
    var cornerRadius: CGFloat = 26
    var padding: CGFloat = 18
    var contentColor: Color = .krokvaEdInk
    @ViewBuilder var content: Content

    var body: some View {
        content
            .foregroundStyle(contentColor)
            .padding(padding)
            .background {
                ZStack {
                    // Translucent base
                    if let tint {
                        tint.opacity(tintOpacity > 0 ? tintOpacity : 0.78)
                    } else {
                        Color.white.opacity(0.55)
                    }
                    // Material blur picks up ambient color underneath
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            // Hairline outer border
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            }
            // Inset top highlight
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.46), Color.white.opacity(0)],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            // Depth shadow
            .shadow(color: Color.krokvaEdInk.opacity(0.10), radius: 18, x: 0, y: 14)
    }
}

// MARK: - Modifier form

extension View {
    /// Wraps content in a liquid-glass tile. Use the `tint` argument for the
    /// colored variants (slate / ochre / sage / clay / ink).
    func krokvaEdGlass(
        tint: Color? = nil,
        tintOpacity: Double = 0.78,
        cornerRadius: CGFloat = 26,
        padding: CGFloat = 18,
        contentColor: Color = .krokvaEdInk
    ) -> some View {
        KrokvaGlassCard(
            tint: tint,
            tintOpacity: tintOpacity,
            cornerRadius: cornerRadius,
            padding: padding,
            contentColor: contentColor
        ) { self }
    }
}

// MARK: - Blue glow accents

extension View {
    /// Apple-blue halo glow — for CTAs and selected/best states.
    func krokvaEdBlueGlow(strong: Bool = false) -> some View {
        self
            .shadow(color: Color.krokvaEdBlue.opacity(strong ? 0.32 : 0.18),
                    radius: strong ? 16 : 10, x: 0, y: strong ? 12 : 8)
    }
}

// MARK: - Blue pill tag
//
// Use for: "Live", "+5.4% YoY", "PRO", "BEST".

struct KrokvaEdBluePill: View {
    let label: String
    var withDot: Bool = false
    var glow: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if withDot {
                Circle()
                    .fill(Color.krokvaEdBlue)
                    .frame(width: 6, height: 6)
                    .shadow(color: .krokvaEdBlue, radius: 4)
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .textCase(.uppercase)
        }
        .foregroundStyle(Color.krokvaEdBlue)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.krokvaEdBlueWash)
        )
        .overlay(
            Capsule().stroke(Color.krokvaEdBlueEdge, lineWidth: 1)
        )
        .if(glow) { v in v.krokvaEdBlueGlow() }
    }
}

// Tiny conditional modifier helper
private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
