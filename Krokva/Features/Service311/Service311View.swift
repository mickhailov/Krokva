import SwiftUI

struct Service311View: View {
    let summary: ServiceRequestSummary

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    if !summary.monthlyTrend.isEmpty { monthlyVolumeCard }
                    if !summary.channelBreakdown.isEmpty { channelCard }
                    if !summary.topReasons.isEmpty { topReasonsCard }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .cleanNavBar(title: "311 Activity")
    }

    // MARK: Hero — 3 donuts

    private var heroCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("311 Service Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    Text("Last 12 months · \(summary.neighbourhood)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cleanLabel2)
                }

                HStack(spacing: 0) {
                    donutCell(value: summary.totalLastYear,
                              maxValue: max(summary.totalLastYear, 400),
                              color: .cleanIndigo, label: "Total Calls")
                    Divider().frame(height: 80)
                    donutCell(value: summary.openLastYear,
                              maxValue: max(summary.totalLastYear, 1),
                              color: .cleanAmber, label: "Open")
                    Divider().frame(height: 80)
                    donutCell(value: summary.closedLastYear,
                              maxValue: max(summary.totalLastYear, 1),
                              color: .cleanGreen, label: "Closed")
                }
            }
        }
    }

    private func donutCell(value: Int, maxValue: Int, color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            DonutRing(value: value, maxValue: maxValue, size: 90, strokeWidth: 8, color: color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Monthly Volume

    private var monthlyVolumeCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Monthly Volume")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)

                let recent = Array(summary.monthlyTrend.suffix(12))
                let maxYear = recent.map(\.year).max() ?? 0
                let maxMonth = recent.filter { $0.year == maxYear }.map(\.month).max() ?? 0

                MiniBarChart(
                    bars: recent.map { m in
                        MiniBarChart.Bar(
                            id: m.id,
                            value: m.count,
                            label: m.label,
                            highlighted: m.year == maxYear && m.month == maxMonth
                        )
                    },
                    accentColor: .cleanIndigo,
                    baseColor: Color(hex: 0x6366F1).opacity(0.65)
                )
                .frame(height: 90)
            }
        }
    }

    // MARK: Channel Breakdown

    private let channelColors: [Color] = [.cleanSky, .cleanIndigo, .cleanAmber,
                                          Color(hex: 0x10B981), .cleanRed]

    private var channelCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("By Channel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)

                let total = summary.channelBreakdown.map(\.count).reduce(0, +)
                if total > 0 {
                    let segs = summary.channelBreakdown.enumerated().map { i, ch in
                        SegmentedBar.Segment(
                            id: ch.incidentType,
                            color: channelColors[i % channelColors.count],
                            fraction: Double(ch.count) / Double(total)
                        )
                    }
                    SegmentedBar(segments: segs, height: 10)
                }

                let maxVal = summary.channelBreakdown.map(\.count).max() ?? 1
                ForEach(Array(summary.channelBreakdown.enumerated()), id: \.offset) { i, ch in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(channelColors[i % channelColors.count])
                            .frame(width: 8, height: 8)
                        Text(ch.incidentType)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.cleanLabel)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.cleanTrack)
                                Capsule()
                                    .fill(channelColors[i % channelColors.count])
                                    .frame(width: maxVal > 0
                                           ? geo.size.width * CGFloat(ch.count) / CGFloat(maxVal)
                                           : 0)
                            }
                        }
                        .frame(width: 100, height: 7)
                        Text("\(ch.count)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel3)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Top Reasons

    private let reasonColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x0EA5E9),
                                         Color(hex: 0x10B981), .cleanAmber]

    private var topReasonsCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Reasons")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)

                let maxVal = summary.topReasons.map(\.count).max() ?? 1
                ForEach(Array(summary.topReasons.prefix(6).enumerated()), id: \.offset) { i, reason in
                    PillBar(
                        label: reason.incidentType,
                        value: reason.count,
                        maxValue: maxVal,
                        color: reasonColors[i % reasonColors.count],
                        animationDelay: Double(i) * 0.08
                    )
                }
            }
        }
    }
}
