// MARK: - Krokva · Editorial
// SwiftUI port of the Editorial direction:
//   - Cream "paper" base with dusty muted accents (slate / ochre / sage / clay)
//   - iOS-style liquid glass tiles (translucent, blurred, hairline highlight)
//   - Apple-blue accent + halo glow for interaction & "best" states
//
// Drop this file in alongside the existing Branding.swift OR replace it.
// All new tokens are namespaced `krokvaEd*` so nothing else in the app breaks.

import SwiftUI

extension Color {
    // ===== Editorial palette =====

    // Paper base
    static let krokvaEdPaper      = Color(edHex: 0xEDE7D6)
    static let krokvaEdPaper2     = Color(edHex: 0xE2DBC6)
    static let krokvaEdPaper3     = Color(edHex: 0xD6CFB9)

    // Ink (slate, not pure black)
    static let krokvaEdInk        = Color(edHex: 0x1B1E25)
    static let krokvaEdInk2       = Color(edHex: 0x2A2E37)

    // Dusty muted accents
    static let krokvaEdSlate      = Color(edHex: 0x4E5874)
    static let krokvaEdSlateDeep  = Color(edHex: 0x39415A)
    static let krokvaEdOchre      = Color(edHex: 0xB89455)
    static let krokvaEdOchreDeep  = Color(edHex: 0x937539)
    static let krokvaEdSage       = Color(edHex: 0x8AA083)
    static let krokvaEdSageDeep   = Color(edHex: 0x6B8166)
    static let krokvaEdClay       = Color(edHex: 0xB07262)
    static let krokvaEdClayDeep   = Color(edHex: 0x8C5749)
    static let krokvaEdCream      = Color(edHex: 0xF4ECD5)

    // Apple blue · interaction + glow
    static let krokvaEdBlue       = Color(edHex: 0x2F7BFF)
    static let krokvaEdBlueDeep   = Color(edHex: 0x1A5FE0)
    static let krokvaEdBlueWash   = Color(edHex: 0x2F7BFF, opacity: 0.10)
    static let krokvaEdBlueEdge   = Color(edHex: 0x2F7BFF, opacity: 0.32)

    // Text on tinted surfaces
    static let krokvaEdOnOchre    = Color(edHex: 0x1A1408)
    static let krokvaEdOnSage     = Color(edHex: 0x11180F)
    static let krokvaEdOnSlate    = Color.white
    static let krokvaEdOnClay     = Color.white

    // Hairlines & translucent layers
    static let krokvaEdHairline   = Color(edHex: 0x1B1E25, opacity: 0.08)
    static let krokvaEdGlassEdge  = Color.white.opacity(0.7)
    static let krokvaEdGlassEdgeI = Color.white.opacity(0.42)

    // Convenience hex init (named `edHex` to avoid colliding with the existing `hex` init)
    fileprivate init(edHex: UInt32, opacity: Double = 1.0) {
        let r = Double((edHex >> 16) & 0xFF) / 255.0
        let g = Double((edHex >>  8) & 0xFF) / 255.0
        let b = Double( edHex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Typography
//
// Editorial uses two faces:
//   • UI text  — SF Pro (system default)
//   • Display  — heavy condensed sans for big address headlines.
//                If "Archivo Black" isn't bundled, falls back to system .heavy.

enum KrokvaEdTypography {
    // Display — the big editorial caps
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        if let _ = UIFont(name: "ArchivoBlack-Regular", size: size) {
            return Font.custom("ArchivoBlack-Regular", size: size)
        }
        return Font.system(size: size, weight: weight).width(.condensed)
    }

    static let title        = display(42)
    static let title2       = display(36)
    static let title3       = display(28)
    static let chunkySmall  = display(20)

    // UI
    static let h1           = Font.system(size: 22, weight: .semibold)
    static let h2           = Font.system(size: 17, weight: .semibold)
    static let body         = Font.system(size: 15)
    static let bodySmall    = Font.system(size: 13)
    static let caption      = Font.system(size: 11, weight: .medium)

    // Eyebrow (small caps tag)
    static let eyebrow      = Font.system(size: 10, weight: .heavy)
}

extension View {
    /// All-caps, tracked, 10pt eyebrow label — the small section/category tag.
    func krokvaEdEyebrow(color: Color = Color.krokvaEdInk.opacity(0.62)) -> some View {
        self
            .font(KrokvaEdTypography.eyebrow)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Editorial display title — chunky condensed caps.
    func krokvaEdTitle(_ size: CGFloat = 42, color: Color = .krokvaEdInk) -> some View {
        self
            .font(KrokvaEdTypography.display(size))
            .tracking(-0.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineSpacing(-2)
    }
}
