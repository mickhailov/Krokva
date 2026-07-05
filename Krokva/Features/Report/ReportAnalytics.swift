import Foundation
import SwiftUI

/// Second-order analytics derived from an already-assembled `AddressReport`.
///
/// Where `ReportRating` produces the single House Score, `ReportAnalytics`
/// adds three explainable lenses on top of the same data — no new network
/// calls or datasets:
///   1. **Composite indices** — Family-Suitability & Investment-Momentum,
///      each built from the same `ReportRating.Signal`/`SectionScore` pattern
///      so every index stays auditable ("why exactly this number?").
///   2. **Temporal trends** — year-over-year movement across the yearly series
///      the report already carries (crime, emergency, permits, bylaw, fires).
///   3. **Comparative percentiles** — where this address sits versus its
///      neighbourhood / the city for a handful of headline metrics.
///
/// Guardrail (CLAUDE.md): public-health data (naloxone / substance use) is
/// never scored, graded, or ranked — it is intentionally absent from all three
/// lenses below.
struct ReportAnalytics {

    // MARK: - Value types

    /// One named composite index. Reuses `SectionScore` so the UI can expand it
    /// into its individual signals, exactly like a House Score section.
    struct CompositeIndex: Identifiable {
        let name: String
        let systemImage: String
        let accent: Color
        let blurb: String
        let section: ReportRating.SectionScore
        var id: String { name }
        var score: Double { section.score }
        var isAvailable: Bool { !section.isUnavailable }
    }

    enum TrendDirection { case up, down, steady }

    /// A single year-over-year series, ready to render as a sparkline + chip.
    struct TrendSeries: Identifiable {
        let label: String
        let systemImage: String
        let points: [YearCount]
        /// Whether a rising line is a *good* thing (e.g. permit activity) or a
        /// *bad* thing (e.g. crime). Drives the chip colour.
        let higherIsBetter: Bool
        var id: String { label }

        var latest: Int { points.last?.count ?? 0 }
        var previous: Int? { points.count >= 2 ? points[points.count - 2].count : nil }

        /// Percentage change from the prior recorded year. `nil` when there is
        /// no prior year or it was zero (avoids divide-by-zero / infinite %).
        var deltaPercent: Double? {
            guard let previous, previous != 0 else { return nil }
            return (Double(latest) - Double(previous)) / Double(previous) * 100
        }

        var direction: TrendDirection {
            guard let d = deltaPercent else { return .steady }
            if d > 2 { return .up }
            if d < -2 { return .down }
            return .steady
        }

        /// Is the movement favourable for this metric? `nil` when steady.
        var isFavourable: Bool? {
            switch direction {
            case .steady: return nil
            case .up:     return higherIsBetter
            case .down:   return !higherIsBetter
            }
        }

        var chip: String {
            guard let d = deltaPercent else { return "New" }
            let arrow = direction == .up ? "▲" : direction == .down ? "▼" : "→"
            return "\(arrow) \(Int(abs(d).rounded()))% vs prior yr"
        }
    }

    /// Where this address/area sits on a 0–100 scale versus comparable areas.
    struct ComparativeMetric: Identifiable {
        let label: String
        let systemImage: String
        /// 0–100 position. Always "how much of the metric" — higher percentile
        /// means more of the thing being measured, regardless of desirability.
        let percentile: Double
        let framing: String
        let higherIsBetter: Bool
        var id: String { label }
    }

    let indices: [CompositeIndex]
    let trends: [TrendSeries]
    let comparisons: [ComparativeMetric]

    var isEmpty: Bool { indices.isEmpty && trends.isEmpty && comparisons.isEmpty }

    // MARK: - Entry point

    static func compute(report d: AddressReport, permitHistory: PermitHistoryResult?) -> ReportAnalytics {
        ReportAnalytics(
            indices: [familySuitability(d), investmentMomentum(d, permitHistory: permitHistory)]
                .filter { $0.isAvailable },
            trends: buildTrends(d),
            comparisons: buildComparisons(d)
        )
    }

    // MARK: - 1. Composite indices

    private static func familySuitability(_ d: AddressReport) -> CompositeIndex {
        var signals: [ReportRating.Signal] = []

        // Schools — count nearby + walk distance to the closest.
        if !d.moduleFailed(.schools), !d.nearbySchools.isEmpty {
            let count = d.nearbySchools.count
            let nearest = d.nearbySchools.compactMap { $0.distanceMeters }.min()
            var s: Double
            switch count {
            case 0:    s = 0
            case 1:    s = 55
            case 2:    s = 75
            default:   s = 90
            }
            if let nearest, nearest < 800 { s = min(s + 10, 100) }
            let distNote = nearest.map { " · closest \(Int($0.rounded())) m" } ?? ""
            signals.append(.init(
                label: "Schools nearby",
                score: s,
                detail: "\(count) school\(count == 1 ? "" : "s") in reach\(distNote)"
            ))
        }

        // Parks — play facilities for kids.
        if let parks = d.parks, !d.moduleFailed(.parks) {
            let facilities = parks.nearbyParks.reduce(0) { $0 + $1.playgrounds + $1.fields + $1.courts }
            let s: Double
            switch facilities {
            case 0:     s = 15
            case 1...3: s = 50
            case 4...8: s = 78
            default:    s = 100
            }
            signals.append(.init(
                label: "Play facilities",
                score: s,
                detail: "\(facilities) playground\(facilities == 1 ? "" : "s"), field\(facilities == 1 ? "" : "s") & court\(facilities == 1 ? "" : "s") nearby"
            ))
        }

        // Aquatics — wading / spray / indoor pools families use most.
        if let aq = d.aquatics, !d.moduleFailed(.aquatics) {
            let familyPools = aq.pools.filter {
                let k = $0.kind.lowercased()
                return k.contains("wading") || k.contains("spray") || k.contains("indoor") || k.contains("outdoor")
            }.count
            let s: Double
            switch familyPools {
            case 0:     s = 20
            case 1:     s = 60
            case 2:     s = 80
            default:    s = 100
            }
            signals.append(.init(
                label: "Pools & spray pads",
                score: s,
                detail: familyPools == 0 ? "None within reach"
                                         : "\(familyPools) pool\(familyPools == 1 ? "" : "s") / spray pad\(familyPools == 1 ? "" : "s") nearby"
            ))
        }

        // Library access.
        if let library = d.library, !d.moduleFailed(.library) {
            var s = 55.0
            if let m = ReportRating.parseMeters(library.distanceDescription) {
                if m < 800 { s += 25 } else if m < 1500 { s += 12 }
            }
            if library.accessibility { s += 10 }
            signals.append(.init(
                label: "Library access",
                score: min(s, 100),
                detail: "Nearest branch \(library.distanceDescription)"
            ))
        }

        // Safety — crime versus the citywide average (reuses the rating's math).
        if let last = d.policeCrime?.yearlyCounts.last, last.citywideAverage > 0, !d.moduleFailed(.policeCrime) {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            signals.append(.init(
                label: "Area safety",
                score: clamped(100 - (ratio - 1.0) * 80, 0, 100),
                detail: relativeToAverage(ratio, noun: "reported crime")
            ))
        }

        return CompositeIndex(
            name: "Family-Suitability",
            systemImage: "figure.2.and.child.holdinghands",
            accent: .cleanIndigo,
            blurb: "Schools, play space, pools, library & local safety for households with kids.",
            section: ReportRating.SectionScore(signals: signals, capacity: 5)
        )
    }

    private static func investmentMomentum(_ d: AddressReport, permitHistory: PermitHistoryResult?) -> CompositeIndex {
        var signals: [ReportRating.Signal] = []

        // On-property permit investment (optional — may be unavailable here).
        if let h = permitHistory {
            let s: Double
            let detail: String
            if h.analytics.majorRenovationDetected {
                s = 100; detail = "Major renovation on permit record"
            } else if h.analytics.permitCount > 5 {
                s = 85;  detail = "\(h.analytics.permitCount) permits filed over time"
            } else if h.analytics.permitCount > 0 {
                s = 65;  detail = "\(h.analytics.permitCount) permit\(h.analytics.permitCount == 1 ? "" : "s") on record"
            } else {
                s = 40;  detail = "No permit history on this property"
            }
            signals.append(.init(label: "Property investment", score: s, detail: detail))
        }

        // Neighbourhood permit activity trend (last-3 slope).
        if d.permitActivity.count >= 2, !d.moduleFailed(.permitActivity) {
            let recent = d.permitActivity.suffix(3)
            let first = Double(recent.first?.count ?? 0)
            let last  = Double(recent.last?.count ?? 0)
            let s: Double
            if first == 0                  { s = 55 }
            else if last > first * 1.1     { s = 88 }
            else if last >= first * 0.85   { s = 66 }
            else                           { s = 38 }
            signals.append(.init(
                label: "Area permit trend",
                score: s,
                detail: trendDetail(last - first, unit: "permits")
            ))
        }

        // Development pipeline — recent development permits + planning notices.
        let devPermits = d.moduleFailed(.development) ? 0 : (d.development?.recentPermits.count ?? 0)
        let notices    = d.moduleFailed(.planning) ? 0 : (d.planning?.publicNotices.count ?? 0)
        if d.development != nil || d.planning != nil {
            let pipeline = devPermits + notices
            let s: Double
            switch pipeline {
            case 0:      s = 35
            case 1...2:  s = 60
            case 3...5:  s = 80
            default:     s = 100
            }
            signals.append(.init(
                label: "Development pipeline",
                score: s,
                detail: pipeline == 0 ? "No active development permits or notices nearby"
                                      : "\(devPermits) permit\(devPermits == 1 ? "" : "s") · \(notices) planning notice\(notices == 1 ? "" : "s") nearby"
            ))
        }

        // Assessed value versus the neighbourhood (real percentile from bins).
        if let assessed = d.property?.totalAssessedValue, !d.neighbourhoodValues.isEmpty {
            let pct = valuePercentile(assessed: assessed, bins: d.neighbourhoodValues)
            signals.append(.init(
                label: "Relative value",
                score: pct,
                detail: "Assessed above \(Int(pct.rounded()))% of nearby value bands"
            ))
        }

        return CompositeIndex(
            name: "Investment-Momentum",
            systemImage: "chart.line.uptrend.xyaxis",
            accent: .cleanAmber,
            blurb: "Renovation, permit activity, development pipeline & relative value — signals of a moving market, not a forecast.",
            section: ReportRating.SectionScore(signals: signals, capacity: 4)
        )
    }

    // MARK: - 2. Temporal trends

    private static func buildTrends(_ d: AddressReport) -> [TrendSeries] {
        var out: [TrendSeries] = []

        func add(_ label: String, _ image: String, _ points: [YearCount], higherIsBetter: Bool, failed: Bool) {
            let usable = points.sorted { $0.year < $1.year }
            guard !failed, usable.count >= 2 else { return }
            out.append(.init(label: label, systemImage: image, points: usable,
                             higherIsBetter: higherIsBetter))
        }

        if let crime = d.policeCrime {
            let pts = crime.yearlyCounts.map { YearCount(year: $0.year, count: $0.neighbourhood) }
            add("Reported crime", "shield.lefthalf.filled", pts, higherIsBetter: false, failed: d.moduleFailed(.policeCrime))
        }
        if let em = d.emergency {
            add("Emergency calls", "cross.case", em.yearlyCalls, higherIsBetter: false, failed: d.moduleFailed(.emergency))
        }
        add("Neighbourhood permits", "hammer", d.permitActivity, higherIsBetter: true, failed: d.moduleFailed(.permitActivity))
        if let bylaw = d.bylaw {
            add("Bylaw investigations", "exclamationmark.bubble", bylaw.yearly, higherIsBetter: false, failed: d.moduleFailed(.bylaw))
        }
        if let risk = d.neighbourhoodRisk {
            add("Vacant-property fires", "flame", risk.vacantFireTrend, higherIsBetter: false, failed: d.moduleFailed(.neighbourhoodRisk))
        }

        return out
    }

    // MARK: - 3. Comparative percentiles

    private static func buildComparisons(_ d: AddressReport) -> [ComparativeMetric] {
        var out: [ComparativeMetric] = []

        // Assessed value — a true percentile from the neighbourhood value bins.
        if let assessed = d.property?.totalAssessedValue, !d.neighbourhoodValues.isEmpty {
            let pct = valuePercentile(assessed: assessed, bins: d.neighbourhoodValues)
            out.append(.init(
                label: "Assessed value",
                systemImage: "dollarsign.circle",
                percentile: pct,
                framing: "Higher than \(Int(pct.rounded()))% of nearby homes",
                higherIsBetter: true
            ))
        }

        // Crime vs the citywide average for a neighbourhood.
        if let last = d.policeCrime?.yearlyCounts.last, last.citywideAverage > 0, !d.moduleFailed(.policeCrime) {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            let pct = clamped(50 + (ratio - 1) * 40, 2, 98)
            out.append(.init(
                label: "Crime volume",
                systemImage: "shield",
                percentile: pct,
                framing: ratio <= 1.02
                    ? "Fewer incidents than ~\(Int((100 - pct).rounded()))% of areas"
                    : "More incidents than ~\(Int(pct.rounded()))% of areas",
                higherIsBetter: false
            ))
        }

        // Emergency calls vs the citywide median.
        if let em = d.emergency, let median = em.citywideMedian, median > 0, !d.moduleFailed(.emergency) {
            let ratio = Double(em.totalLastYear) / Double(median)
            let pct = clamped(50 + (ratio - 1) * 40, 2, 98)
            out.append(.init(
                label: "Emergency calls",
                systemImage: "cross.case",
                percentile: pct,
                framing: ratio <= 1.02
                    ? "Below the citywide median"
                    : "Above ~\(Int(pct.rounded()))% of areas",
                higherIsBetter: false
            ))
        }

        // Transit reliability — on-time percentage as a quality position.
        if let onTime = d.transit?.onTimePercentage, !d.moduleFailed(.transit) {
            out.append(.init(
                label: "Transit on-time",
                systemImage: "bus",
                percentile: clamped(onTime, 0, 100),
                framing: "\(Int(onTime.rounded()))% of buses run on time",
                higherIsBetter: true
            ))
        }

        // Green space — estimated band from neighbourhood parkland hectares.
        if let ha = d.parks?.neighbourhoodHectares, !d.moduleFailed(.parks) {
            let pct: Double
            switch ha {
            case ..<10:   pct = 25
            case 10..<30: pct = 50
            case 30..<80: pct = 75
            default:      pct = 92
            }
            out.append(.init(
                label: "Green space",
                systemImage: "leaf",
                percentile: pct,
                framing: "\(Int(ha.rounded())) ha of parkland — above ~\(Int(pct.rounded()))% of areas",
                higherIsBetter: true
            ))
        }

        return out
    }

    // MARK: - Helpers

    /// Share of neighbourhood value bands this assessment sits above (0–100).
    /// Mirrors the existing House Score property percentile.
    private static func valuePercentile(assessed: Double, bins: [AssessmentValueBin]) -> Double {
        let sorted = bins.sorted { $0.midpoint < $1.midpoint }
        guard !sorted.isEmpty else { return 50 }
        let below = sorted.filter { $0.midpoint < assessed }.count
        return Double(below) / Double(sorted.count) * 100
    }

    private static func clamped(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }

    private static func relativeToAverage(_ ratio: Double, noun: String) -> String {
        if abs(ratio - 1.0) < 0.05 { return "About the citywide average for \(noun)" }
        return ratio < 1.0
            ? "\(Int(((1 - ratio) * 100).rounded()))% below the citywide average for \(noun)"
            : "\(Int(((ratio - 1) * 100).rounded()))% above the citywide average for \(noun)"
    }

    private static func trendDetail(_ delta: Double, unit: String) -> String {
        let n = Int(abs(delta).rounded())
        if n == 0 { return "Holding steady year over year" }
        return delta < 0 ? "Down \(n) \(unit) over recent years"
                         : "Up \(n) \(unit) over recent years"
    }
}
