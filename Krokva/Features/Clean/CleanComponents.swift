import SwiftUI

// MARK: - Clean palette tokens
// Apple-grouped aesthetic: gray bg, white cards, sky-blue accent.

extension Color {
    static let cleanBg         = Color(hex: 0xF2F2F7)
    static let cleanCard       = Color.white
    static let cleanLabel      = Color(hex: 0x1C1C1E)
    static let cleanLabel2     = Color(hex: 0x636366)
    static let cleanLabel3     = Color(hex: 0x8E8E93)
    static let cleanSep        = Color(hex: 0xC6C6C8)
    static let cleanTrack      = Color(hex: 0xE5E5EA)
    static let cleanSky        = Color(hex: 0x0284C7)
    static let cleanSkyWash    = Color(hex: 0x0284C7, opacity: 0.09)
    static let cleanIndigo     = Color(hex: 0x6366F1)
    static let cleanIndigoWash = Color(hex: 0x6366F1, opacity: 0.09)
    static let cleanGreen      = Color(hex: 0x34C759)
    static let cleanGreenWash  = Color(hex: 0x34C759, opacity: 0.12)
    static let cleanAmber      = Color(hex: 0xFF9500)
    static let cleanAmberWash  = Color(hex: 0xFF9500, opacity: 0.12)
    static let cleanRed        = Color(hex: 0xFF3B30)
}

// MARK: - CleanCard

struct CleanCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4)
    }
}

// MARK: - SectionHeader

struct CleanSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.cleanLabel)
            Spacer()
            if let action {
                Button(action, action: { onAction?() })
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.cleanSky)
            }
        }
    }
}

// MARK: - ScoreRing (0-100, animated on appear)

struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 42
    var strokeWidth: CGFloat = 3.5
    var animationDelay: Double = 0
    var showLabel: Bool = true

    @State private var progress: Double = 0
    // Offscreen PDF rendering never runs onAppear animations, so draw final state.
    @Environment(\.reportPDFRender) private var pdfRender
    private var effectiveProgress: Double { pdfRender ? 1 : progress }

    var ringColor: Color {
        if score >= 80 { return .cleanSky }
        if score >= 60 { return .cleanAmber }
        return .cleanRed
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cleanTrack, lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: effectiveProgress * Double(score) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showLabel {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .bold).monospacedDigit())
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.9).delay(animationDelay)) {
                progress = 1
            }
        }
    }
}

// MARK: - DonutRing (value/max, animated)

struct DonutRing: View {
    let value: Int
    let maxValue: Int
    var size: CGFloat = 90
    var strokeWidth: CGFloat = 8
    let color: Color
    var centerLabel: String? = nil
    var centerSub: String? = nil

    @State private var progress: Double = 0
    @Environment(\.reportPDFRender) private var pdfRender
    private var effectiveProgress: Double { pdfRender ? 1 : progress }

    private var fraction: Double {
        maxValue > 0 ? min(Double(value) / Double(maxValue), 1) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cleanTrack, lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: effectiveProgress * fraction)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(centerLabel ?? "\(value)")
                    .font(.system(size: size * 0.22, weight: .heavy).monospacedDigit())
                    .foregroundStyle(color)
                if let sub = centerSub {
                    Text(sub)
                        .font(.system(size: size * 0.1, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.0)) {
                progress = 1
            }
        }
    }
}

// MARK: - PillBar (label + animated bar + count)

struct PillBar: View {
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color
    var animationDelay: Double = 0.15

    @State private var progress: Double = 0
    @Environment(\.reportPDFRender) private var pdfRender
    private var effectiveProgress: Double { pdfRender ? 1 : progress }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cleanLabel)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule().fill(color)
                        .frame(width: maxValue > 0
                               ? geo.size.width * CGFloat(effectiveProgress) * CGFloat(value) / CGFloat(maxValue)
                               : 0)
                }
            }
            .frame(height: 7)

            Text(value.formatted(.number))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.cleanLabel3)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 30, alignment: .trailing)
        }
        .onAppear {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.9).delay(animationDelay)) {
                progress = 1
            }
        }
    }
}

// MARK: - SegmentedBar (proportional color segments)

struct SegmentedBar: View {
    struct Segment: Identifiable {
        let id: String
        let color: Color
        let fraction: Double
    }

    let segments: [Segment]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments) { seg in
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(seg.color)
                        .frame(width: max(1, geo.size.width * CGFloat(seg.fraction)))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

// MARK: - MiniBarChart

struct MiniBarChart: View {
    struct Bar: Identifiable {
        let id: String
        let value: Int
        var label: String
        var highlighted: Bool = false
    }

    let bars: [Bar]
    var accentColor: Color = .cleanSky
    var baseColor: Color = Color(hex: 0xCBD5E1).opacity(0.65)
    var avgLine: Double? = nil
    var avgLineColor: Color = .cleanGreen

    var body: some View {
        let maxVal = bars.map(\.value).max() ?? 1
        VStack(spacing: 6) {
            GeometryReader { geo in
                let barW = (geo.size.width - CGFloat(bars.count - 1) * 4) / CGFloat(bars.count)
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(bars) { bar in
                            let h = maxVal > 0 ? geo.size.height * CGFloat(bar.value) / CGFloat(maxVal) : 0
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(bar.highlighted ? accentColor : baseColor)
                                .frame(width: barW, height: max(2, h))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    if let avg = avgLine {
                        let lineY = geo.size.height * (1 - CGFloat(avg) / CGFloat(maxVal))
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: lineY))
                            path.addLine(to: CGPoint(x: geo.size.width, y: lineY))
                        }
                        .stroke(avgLineColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
            }

            HStack(alignment: .top, spacing: 4) {
                ForEach(bars) { bar in
                    Text(bar.label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(bar.highlighted ? accentColor : Color.cleanLabel3)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - GradientButton

struct GradientButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [.cleanSky, .cleanIndigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: Color.cleanIndigo.opacity(0.28), radius: 20, x: 0, y: 4)
        }
    }
}

// MARK: - CleanNavBar modifier

extension View {
    func cleanNavBar(title: String = "") -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.cleanBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
