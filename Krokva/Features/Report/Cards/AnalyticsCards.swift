import SwiftUI
import Charts

// Three cards that surface `ReportAnalytics`: composite indices, year-over-year
// trends, and comparative percentiles. Each hides itself entirely when its
// slice of the analytics has no data, so thin/rural addresses degrade quietly.

// MARK: - Composite indices

struct CompositeIndicesCard: View {
    let analytics: ReportAnalytics
    @State private var expanded: Set<String> = []

    var body: some View {
        if analytics.indices.isEmpty {
            EmptyView()
        } else {
            ReportCard(
                title: "Analytics indices",
                systemImage: "gauge.with.dots.needle.bottom.50percent",
                iconColor: .cleanIndigo,
                subtitle: "Derived from city data · informational"
            ) {
                VStack(spacing: 14) {
                    ForEach(analytics.indices) { index in
                        indexRow(index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indexRow(_ index: ReportAnalytics.CompositeIndex) -> some View {
        let isOpen = expanded.contains(index.id)
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if isOpen { expanded.remove(index.id) } else { expanded.insert(index.id) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: index.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index.accent)
                        .frame(width: 20)
                    PillBar(
                        label: index.name,
                        value: Int(index.score.rounded()),
                        maxValue: 100,
                        color: scoreColor(index.score)
                    )
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel3)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                Text(index.blurb)
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) {
                    ForEach(index.section.signals) { signal in
                        signalRow(signal)
                    }
                }
                if index.section.isPartial {
                    Text("\(index.section.signals.count) of \(index.section.capacity) possible signals available here.")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }
            }
        }
    }

    private func signalRow(_ signal: ReportRating.Signal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(signal.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer(minLength: 12)
                Text("\(Int(signal.score.rounded()))")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(scoreColor(signal.score))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule().fill(scoreColor(signal.score))
                        .frame(width: geo.size.width * CGFloat(min(signal.score, 100) / 100))
                }
            }
            .frame(height: 5)
            Text(signal.detail)
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return .cleanGreen }
        if score >= 50 { return .cleanAmber }
        return .cleanRed
    }
}

// MARK: - Temporal trends

struct TrendsCard: View {
    let analytics: ReportAnalytics

    var body: some View {
        if analytics.trends.isEmpty {
            EmptyView()
        } else {
            ReportCard(
                title: "Year-over-year trends",
                systemImage: "chart.xyaxis.line",
                iconColor: .cleanSky,
                subtitle: "Neighbourhood movement over recent years"
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(analytics.trends.enumerated()), id: \.element.id) { i, trend in
                        if i > 0 { Divider().padding(.vertical, 10) }
                        trendRow(trend)
                    }
                }
            }
        }
    }

    private func trendRow(_ trend: ReportAnalytics.TrendSeries) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label(trend.label, systemImage: trend.systemImage)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Text("\(trend.latest.formatted()) latest")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel3)
            }
            Spacer(minLength: 8)
            Sparkline(points: trend.points, color: lineColor(trend))
                .frame(width: 84, height: 34)
            Text(trend.chip)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(chipColor(trend))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chipColor(trend).opacity(0.12), in: Capsule())
                .fixedSize()
        }
    }

    private func lineColor(_ trend: ReportAnalytics.TrendSeries) -> Color {
        chipColor(trend)
    }

    private func chipColor(_ trend: ReportAnalytics.TrendSeries) -> Color {
        switch trend.isFavourable {
        case .some(true):  return .cleanGreen
        case .some(false): return .cleanRed
        case .none:        return .cleanLabel3
        }
    }
}

/// Compact line sparkline over a `[YearCount]` series.
private struct Sparkline: View {
    let points: [YearCount]
    let color: Color

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("Year", p.year), y: .value("Count", p.count))
                .interpolationMethod(.monotone)
                .foregroundStyle(color)
            AreaMark(x: .value("Year", p.year), y: .value("Count", p.count))
                .interpolationMethod(.monotone)
                .foregroundStyle(color.opacity(0.12))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("Trend sparkline")
    }
}

// MARK: - Comparative percentiles

struct ComparativeCard: View {
    let analytics: ReportAnalytics

    var body: some View {
        if analytics.comparisons.isEmpty {
            EmptyView()
        } else {
            ReportCard(
                title: "How this area compares",
                systemImage: "chart.bar.xaxis",
                iconColor: .cleanGreen,
                subtitle: "Relative position vs other areas · estimated"
            ) {
                VStack(spacing: 14) {
                    ForEach(analytics.comparisons) { metric in
                        metricRow(metric)
                    }
                }
            }
        }
    }

    private func metricRow(_ metric: ReportAnalytics.ComparativeMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(metric.label, systemImage: metric.systemImage)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer(minLength: 12)
                Text("\(Int(metric.percentile.rounded()))th pct")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(barColor(metric))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule().fill(barColor(metric))
                        .frame(width: geo.size.width * CGFloat(min(max(metric.percentile, 0), 100) / 100))
                }
            }
            .frame(height: 6)
            Text(metric.framing)
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Green when the position is desirable for this metric, red when not.
    private func barColor(_ metric: ReportAnalytics.ComparativeMetric) -> Color {
        let good = metric.higherIsBetter ? metric.percentile >= 50 : metric.percentile <= 50
        if abs(metric.percentile - 50) < 8 { return .cleanAmber }
        return good ? .cleanGreen : .cleanRed
    }
}
