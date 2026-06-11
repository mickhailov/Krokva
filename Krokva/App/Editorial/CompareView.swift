// MARK: - Compare view
//
// 2–3 properties side-by-side with metric rows and a blue-glow recommendation.

import SwiftUI

struct KrokvaEdCompareProperty: Identifiable {
    let id: String                // "A" / "B" / "C"
    let address: String
    let area: String
    let label: String             // "Pinned" / "Watching" / "New"
    let assessed: Double          // in thousands, for bar
    let assessedLabel: String     // "$1.247M"
    let delta: String             // "+5.4%"
    let sf: Int
    let lot: Int
    let year: Int
    let era: String
    let permits: Int
    let rooms: String
    let tint: Color
    let foreground: Color
}

struct KrokvaEdCompareView: View {
    let properties: [KrokvaEdCompareProperty]
    let recommendationTitle: String
    let recommendationBody: String

    private func bestIdx<T: Comparable>(_ key: KeyPath<KrokvaEdCompareProperty, T>, ascending: Bool = true) -> Int {
        let pairs = properties.enumerated().map { ($0.offset, $0.element[keyPath: key]) }
        let sorted = ascending ? pairs.sorted { $0.1 < $1.1 } : pairs.sorted { $0.1 > $1.1 }
        return sorted.first?.0 ?? 0
    }

    var body: some View {
        ZStack {
            Color.krokvaEdPaper.ignoresSafeArea()
            KrokvaEdAmbient()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compare.").krokvaEdTitle(42)
                        Text("Side by side on assessment, size, age, and permit pressure.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.krokvaEdInk.opacity(0.62))
                    }
                    .padding(.top, 4)

                    // Property header cards
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(properties) { p in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    LetterBadge(letter: p.id, foreground: p.foreground)
                                    Spacer()
                                    Text(p.label).krokvaEdEyebrow(color: p.foreground.opacity(0.66))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.address)
                                        .font(KrokvaEdTypography.display(16))
                                        .tracking(-0.3)
                                        .textCase(.uppercase)
                                    Text(p.area)
                                        .font(.system(size: 10, weight: .semibold))
                                        .opacity(0.72)
                                }
                                Spacer(minLength: 0)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.assessedLabel)
                                        .font(KrokvaEdTypography.display(18))
                                        .tracking(-0.4)
                                        .textCase(.uppercase)
                                    Text("\(p.delta) YoY")
                                        .font(.system(size: 10, weight: .bold))
                                        .opacity(0.7)
                                }
                            }
                            .foregroundStyle(p.foreground)
                            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
                            .padding(12)
                            .background(p.tint.opacity(0.78))
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
                            )
                            .shadow(color: Color.krokvaEdInk.opacity(0.10), radius: 14, x: 0, y: 12)
                        }
                    }

                    // Metric rows
                    VStack(spacing: 10) {
                        CompareRow(
                            label: "Assessed value", eyebrow: "LOWER IS CHEAPER",
                            values: properties.map(\.assessedLabel),
                            bars: properties.map { $0.assessed / 1500 },
                            bestIdx: bestIdx(\.assessed, ascending: true),
                            bestLabel: "BEST"
                        )
                        CompareRow(
                            label: "Living area", eyebrow: "SQ FT",
                            values: properties.map { "\($0.sf.formatted())" },
                            bars: properties.map { Double($0.sf) / 4000 },
                            bestIdx: bestIdx(\.sf, ascending: false),
                            bestLabel: "LARGEST"
                        )
                        CompareRow(
                            label: "Year built", eyebrow: "ERA",
                            values: properties.map { String($0.year) },
                            subs: properties.map(\.era),
                            bars: properties.map { Double($0.year - 1900) / 130 },
                            bestIdx: bestIdx(\.year, ascending: false),
                            bestLabel: "NEWEST"
                        )
                        CompareRow(
                            label: "Lot size", eyebrow: "SQ FT",
                            values: properties.map { "\($0.lot.formatted())" },
                            bars: properties.map { Double($0.lot) / 10000 },
                            bestIdx: bestIdx(\.lot, ascending: false),
                            bestLabel: "LARGEST"
                        )
                        CompareRow(
                            label: "Permits (5y, 200m)", eyebrow: "LOWER = QUIETER",
                            values: properties.map { String($0.permits) },
                            bars: properties.map { Double($0.permits) / 6 },
                            bestIdx: bestIdx(\.permits, ascending: true),
                            bestLabel: "BEST"
                        )
                        CompareRow(
                            label: "Rooms", eyebrow: "BD / BA",
                            values: properties.map(\.rooms),
                            bestIdx: bestIdx(\.sf, ascending: false),
                            bestLabel: "MOST"
                        )
                    }

                    // Recommendation
                    RecommendationCard(
                        title: recommendationTitle,
                        bodyText: recommendationBody
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Pieces

private struct LetterBadge: View {
    let letter: String
    let foreground: Color
    var body: some View {
        Text(letter)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(foreground)
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(foreground == .white ? Color.white.opacity(0.22) : Color.krokvaEdInk.opacity(0.14))
            )
    }
}

private struct CompareRow: View {
    let label: String
    let eyebrow: String
    let values: [String]
    var subs: [String]? = nil
    var bars: [Double]? = nil
    let bestIdx: Int
    let bestLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(label)
                    .font(KrokvaEdTypography.display(16))
                    .tracking(-0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.krokvaEdInk)
                Spacer()
                Text(eyebrow).krokvaEdEyebrow(color: Color.krokvaEdInk.opacity(0.42))
            }
            HStack(spacing: 10) {
                ForEach(values.indices, id: \.self) { i in
                    Cell(
                        letter: ["A","B","C"][i % 3],
                        value: values[i],
                        sub: subs?[i],
                        bar: bars?[i],
                        isBest: i == bestIdx,
                        bestLabel: bestLabel
                    )
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .background(Color.white.opacity(0.50))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdInk.opacity(0.08), radius: 12, x: 0, y: 10)
    }

    private struct Cell: View {
        let letter: String
        let value: String
        let sub: String?
        let bar: Double?
        let isBest: Bool
        let bestLabel: String

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(letter)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(isBest ? Color.white : Color.krokvaEdInk.opacity(0.42))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(isBest ? Color.krokvaEdBlue : Color.krokvaEdInk.opacity(0.10)))
                    Spacer()
                    if isBest {
                        Text(bestLabel)
                            .font(.system(size: 7.5, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color.krokvaEdBlue)
                    }
                }
                Text(value)
                    .font(KrokvaEdTypography.display(17))
                    .tracking(-0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(isBest ? Color.krokvaEdBlue : Color.krokvaEdInk)
                if let sub {
                    Text(sub)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.krokvaEdInk.opacity(0.42))
                }
                if let bar {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.krokvaEdInk.opacity(0.08))
                            Capsule()
                                .fill(isBest ? Color.krokvaEdBlue : Color.krokvaEdInk.opacity(0.42))
                                .frame(width: geo.size.width * min(1.0, CGFloat(bar)))
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isBest ? Color.krokvaEdBlue.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isBest ? Color.krokvaEdBlueEdge : Color.krokvaEdHairline, lineWidth: 1)
            )
            .shadow(color: isBest ? Color.krokvaEdBlue.opacity(0.18) : .clear, radius: 10, x: 0, y: 8)
        }
    }
}

private struct RecommendationCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.krokvaEdBlue).frame(width: 28, height: 28)
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .krokvaEdBlueGlow()
                Text("Krokva suggests").krokvaEdEyebrow(color: .krokvaEdBlue)
            }
            Text(title)
                .font(KrokvaEdTypography.display(22))
                .tracking(-0.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.krokvaEdInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(bodyText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.krokvaEdInk.opacity(0.62))
                .lineSpacing(2)
            HStack(spacing: 8) {
                Text("Open recommendation →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.krokvaEdBlue))
                    .overlay(Capsule().stroke(Color.krokvaEdBlueEdge, lineWidth: 1))
                    .krokvaEdBlueGlow(strong: true)
                Text("Export")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.krokvaEdInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.55)))
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            }
        }
        .padding(20)
        .background(Color.krokvaEdBlue.opacity(0.16))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.krokvaEdBlueEdge, lineWidth: 1)
        )
        .shadow(color: Color.krokvaEdBlue.opacity(0.18), radius: 18, x: 0, y: 16)
    }
}
