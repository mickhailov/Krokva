import SwiftUI

// MARK: - Color tokens
//
// Civic Modernist palette — locked V1.
// Existing names preserved so the rest of the codebase keeps compiling;
// new semantic tokens added for the locked direction.

extension Color {
    // Brand
    static let krokvaNavy       = Color(hex: 0x0F2540)
    static let krokvaNavyLight  = Color(hex: 0x1E3556)
    static let krokvaGold       = Color(hex: 0xB8860B)
    static let krokvaGoldSoft   = Color(hex: 0xE9D9A8)   // highlight wash, +N% chips, "you" bar
    static let krokvaGoldDeep   = Color(hex: 0x5C4500)   // text on gold-soft

    // Semantic
    static let krokvaGreen      = Color(hex: 0x1E7A45)   // live / synced / ok
    static let krokvaAccent     = Color(hex: 0xA8362A)   // warn / vacant / over
    static let krokvaBlue       = Color(hex: 0x4A87EB)   // info, secondary stats

    // Surfaces (light theme — Civic Modernist)
    static let krokvaPaper      = Color(hex: 0xF6F4EE)   // app background, "paper"
    static let krokvaSurface    = Color(hex: 0xFFFFFF)   // cards
    static let krokvaSurfaceAlt = Color(hex: 0xFAF8F1)   // chart wells, insets

    // Ink
    static let krokvaInk        = Color(hex: 0x0F1B2D)   // primary text
    static let krokvaInk2       = Color(hex: 0x3D4859)   // secondary text
    static let krokvaInk3       = Color(hex: 0x7A8497)   // tertiary / captions

    // Lines
    static let krokvaLine       = Color(hex: 0xE6E0D2)   // hairline border
    static let krokvaLineSoft   = Color(hex: 0xEEEAE0)   // softest divider

    // Convenience hex init
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Typography
//
// Two faces in play: system sans for UI, monospaced for labels & data.
// SF Pro Text / Display ship with iOS; the mono is SF Mono (system .monospaced).
// Eyebrows are the signature: 9.5pt mono, semibold, tracking 0.14em, UPPERCASE.

enum KrokvaTypography {
    // Brand
    static let wordmark      = Font.system(size: 22, weight: .bold).leading(.tight)

    // Display & numbers
    static let displayLarge  = Font.system(size: 32, weight: .bold).leading(.tight)
    static let display       = Font.system(size: 28, weight: .semibold).leading(.tight)
    static let bigNumber     = Font.system(size: 32, weight: .bold).monospacedDigit()

    // Headings & body
    static let h1            = Font.system(size: 22, weight: .semibold)
    static let h2            = Font.system(size: 17, weight: .semibold)
    static let body          = Font.system(size: 15, weight: .regular)
    static let bodySecondary = Font.system(size: 13, weight: .regular)
    static let caption       = Font.system(size: 12, weight: .regular)

    // Data
    static let mono          = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoBold      = Font.system(size: 13, weight: .semibold, design: .monospaced)
    static let monoSmall     = Font.system(size: 10, weight: .medium, design: .monospaced)

    // Eyebrow label — the workhorse of this design
    static let eyebrow       = Font.system(size: 9.5, weight: .medium, design: .monospaced)
}

// MARK: - Eyebrow modifier
//
// Use everywhere a small uppercase mono label is needed:
//     Text("Assessed value").eyebrow()

extension View {
    func eyebrow(color: Color = .krokvaInk3) -> some View {
        self
            .font(KrokvaTypography.eyebrow)
            .tracking(1.3)              // ~0.14em on 9.5pt
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Card container
//
// Single canonical card: white surface, 14pt radius, hairline border,
// optional gold accent rule at the top-left (the "this is a Krokva card" tell).

struct KrokvaCard<Content: View>: View {
    var accent: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.krokvaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLine, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if accent {
                Rectangle()
                    .fill(Color.krokvaGold)
                    .frame(width: 28, height: 2)
                    .offset(x: 14, y: 0)
            }
        }
    }
}

// MARK: - Brand mark
// The rafter — gable + ridge dot.

struct BrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.16
        path.move(to: CGPoint(x: inset, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.midX, y: inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        return path
    }
}

struct BrandMarkView: View {
    var color: Color = .krokvaGold
    var lineWidth: CGFloat = 2.4
    var ridgeDot: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BrandMark()
                    .stroke(color, style: StrokeStyle(
                        lineWidth: lineWidth, lineCap: .round, lineJoin: .round
                    ))
                if ridgeDot {
                    Circle()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * 0.05))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.56)
                }
            }
        }
        .accessibilityLabel("Krokva rafter mark")
    }
}

// MARK: - Splash
// Unchanged behaviorally — just retuned for the new palette.

struct KrokvaSplashView: View {
    @State private var pulse = false
    @State private var drawMark = false
    @State private var revealText = false
    @State private var rotateHalo = false

    var body: some View {
        ZStack {
            Color.krokvaNavy.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Color.krokvaGold.opacity(0.14), lineWidth: 1)
                        .frame(width: 148, height: 148)
                        .scaleEffect(pulse ? 1.06 : 0.92)
                        .opacity(pulse ? 0.25 : 0.9)
                    Circle()
                        .trim(from: 0, to: 0.34)
                        .stroke(Color.krokvaGold.opacity(0.65),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 124, height: 124)
                        .rotationEffect(.degrees(rotateHalo ? 360 : 0))
                    BrandMark()
                        .trim(from: 0, to: drawMark ? 1 : 0)
                        .stroke(Color.krokvaGold,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulse ? 1.03 : 0.96)
                        .shadow(color: Color.krokvaGold.opacity(0.35), radius: pulse ? 16 : 4)
                }
                Text("Krokva")
                    .font(KrokvaTypography.wordmark)
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .opacity(revealText ? 1 : 0)
                    .offset(y: revealText ? 0 : 8)
                Text("The foundation of every address.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .opacity(revealText ? 1 : 0)
                    .offset(y: revealText ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { drawMark = true }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { rotateHalo = true }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.72).repeatCount(2, autoreverses: true)) { pulse = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.38)) { revealText = true }
        }
    }
}
