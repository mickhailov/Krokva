import Foundation

struct ReportRating {
    /// A single explainable input to a section score. `score` is the 0–100
    /// contribution; `detail` is a human-readable value so the breakdown UI can
    /// answer "why exactly this number?" rather than just showing an average.
    struct Signal: Identifiable {
        let label: String
        let score: Double
        let detail: String
        var id: String { label }
    }

    struct SectionScore {
        let signals: [Signal]
        let capacity: Int

        var score: Double {
            signals.isEmpty ? 50 : signals.reduce(0) { $0 + $1.score } / Double(signals.count)
        }
        var dataPoints: Int { signals.count }
        var isUnavailable: Bool { signals.isEmpty }
        var isPartial: Bool { dataPoints > 0 && dataPoints < capacity }
    }

    let property: SectionScore
    let safety: SectionScore
    let mobility: SectionScore
    let liveability: SectionScore
    let risk: SectionScore
    let overall: Double

    /// Weight each section carries in the overall score, before redistribution.
    static let weights: [String: Double] = [
        "Property": 0.25, "Safety": 0.20, "Mobility": 0.20,
        "Liveability": 0.20, "Risk": 0.15,
    ]

    var grade: String {
        switch overall {
        case 90...: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }

    var totalDataPoints: Int {
        property.dataPoints + safety.dataPoints + mobility.dataPoints
            + liveability.dataPoints + risk.dataPoints
    }

    /// Effective weight a section actually carries after zero-data sections are
    /// dropped and their weight redistributed. Surfaced in the breakdown sheet.
    func effectiveWeight(for name: String) -> Double {
        let sections: [(name: String, section: SectionScore)] = [
            ("Property", property), ("Safety", safety), ("Mobility", mobility),
            ("Liveability", liveability), ("Risk", risk),
        ]
        let available = sections.filter { !$0.section.isUnavailable }
        let totalWeight = available.reduce(0.0) { $0 + (Self.weights[$1.name] ?? 0) }
        guard totalWeight > 0, let base = Self.weights[name],
              available.contains(where: { $0.name == name }) else { return 0 }
        return base / totalWeight
    }

    static func compute(report: AddressReport, permitHistory: PermitHistoryResult?) -> ReportRating {
        let property    = computeProperty(report)
        let safety      = computeSafety(report)
        let mobility    = computeMobility(report)
        let liveability = computeLiveability(report)
        let risk        = computeRisk(report, permitHistory: permitHistory)

        // Redistribute weight from zero-data sections so missing city data
        // doesn't drag the overall score down.
        let sections: [(score: SectionScore, weight: Double)] = [
            (property,    weights["Property"]!),
            (safety,      weights["Safety"]!),
            (mobility,    weights["Mobility"]!),
            (liveability, weights["Liveability"]!),
            (risk,        weights["Risk"]!),
        ]
        let available = sections.filter { !$0.score.isUnavailable }
        let totalWeight = available.reduce(0.0) { $0 + $1.weight }
        let overall = totalWeight == 0
            ? 50.0
            : available.reduce(0.0) { $0 + $1.score.score * $1.weight } / totalWeight

        return ReportRating(
            property: property, safety: safety, mobility: mobility,
            liveability: liveability, risk: risk, overall: overall
        )
    }

    // MARK: - Property (25%)

    private static func computeProperty(_ d: AddressReport) -> SectionScore {
        var signals: [Signal] = []

        // 1. Neighbourhood value percentile
        if let assessed = d.property?.totalAssessedValue, !d.neighbourhoodValues.isEmpty {
            let sorted = d.neighbourhoodValues.sorted { $0.midpoint < $1.midpoint }
            let below = sorted.filter { $0.midpoint < assessed }.count
            let pct = Double(below) / Double(sorted.count) * 100
            signals.append(Signal(
                label: "Value vs neighbourhood",
                score: pct,
                detail: "Assessed above \(Int(pct.rounded()))% of nearby value bands"
            ))
        }

        // 2. Living area tier
        if let area = d.property?.livingArea {
            let s: Double
            switch area {
            case ..<800:       s = 25
            case 800..<1200:   s = 50
            case 1200..<1800:  s = 75
            default:           s = 100
            }
            signals.append(Signal(
                label: "Living area",
                score: s,
                detail: "\(Int(area.rounded())) sq ft of finished space"
            ))
        }

        // 3. Property age
        if let built = d.property?.yearBuilt {
            let age = Calendar.current.component(.year, from: Date()) - built
            let s: Double
            switch age {
            case ..<10:  s = 100
            case 10..<30: s = 80
            case 30..<60: s = 60
            default:      s = 40
            }
            signals.append(Signal(
                label: "Building age",
                score: s,
                detail: "Built \(built) · \(age) years old"
            ))
        }

        // 4. Key amenities (garage + basement + A/C)
        if d.property != nil {
            var bonus = 40.0
            var present: [String] = []
            if d.property?.garage != nil          { bonus += 20; present.append("garage") }
            if d.property?.basement != nil        { bonus += 20; present.append("basement") }
            if d.property?.airConditioning != nil { bonus += 20; present.append("A/C") }
            signals.append(Signal(
                label: "Key features",
                score: min(bonus, 100),
                detail: present.isEmpty ? "No garage, basement or A/C on record"
                                        : present.joined(separator: ", ").capitalizedFirst
            ))
        }

        return SectionScore(signals: signals, capacity: 4)
    }

    // MARK: - Safety (20%)

    private static func computeSafety(_ d: AddressReport) -> SectionScore {
        var signals: [Signal] = []

        // 1. Crime level vs citywide average
        if let last = d.policeCrime?.yearlyCounts.last, last.citywideAverage > 0 {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            signals.append(Signal(
                label: "Crime vs city",
                score: clamped(100 - (ratio - 1.0) * 80, 0, 100),
                detail: relativeToAverage(ratio, noun: "crime")
            ))
        }

        // 2. Crime trend over last 3 recorded years
        if let crime = d.policeCrime, crime.yearlyCounts.count >= 2 {
            let recent = crime.yearlyCounts.suffix(3)
            let first = Double(recent.first!.neighbourhood)
            let last  = Double(recent.last!.neighbourhood)
            let delta = last - first
            let s: Double = delta < -10 ? 90 : delta < 0 ? 70 : delta < 10 ? 55 : 30
            signals.append(Signal(
                label: "Crime trend",
                score: s,
                detail: trendDetail(delta, unit: "incidents")
            ))
        }

        // 3. Emergency calls vs citywide median
        if let em = d.emergency, let median = em.citywideMedian, median > 0 {
            let ratio = Double(em.totalLastYear) / Double(median)
            signals.append(Signal(
                label: "Emergency calls",
                score: clamped(100 - (ratio - 1.0) * 80, 0, 100),
                detail: relativeToAverage(ratio, noun: "fire/medical calls", referent: "median")
            ))
        }

        // 4. Public health events vs citywide average
        if let last = d.publicHealth?.yearlyEvents.last, last.citywideAverage > 0 {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            signals.append(Signal(
                label: "Public health",
                score: clamped(100 - (ratio - 1.0) * 80, 0, 100),
                detail: relativeToAverage(ratio, noun: "health events")
            ))
        }

        // 5. Vacant orders on the street. Skip when the source errored — an empty
        // list from a failed fetch must not be scored as a perfect 100.
        if !d.moduleFailed(.vacantOrders) {
            let count = d.vacantOrders.count
            let vacantScore: Double
            switch count {
            case 0: vacantScore = 100
            case 1: vacantScore = 70
            case 2: vacantScore = 45
            default: vacantScore = 15
            }
            signals.append(Signal(
                label: "Vacant buildings",
                score: vacantScore,
                detail: count == 0 ? "None ordered vacant on this street"
                                   : "\(count) vacant-building order\(count == 1 ? "" : "s") nearby"
            ))
        }

        // 6. Bylaw investigations last recorded year
        if let count = d.bylaw?.yearly.last?.count {
            signals.append(Signal(
                label: "Bylaw cases",
                score: clamped(100 - Double(count) * 0.5, 0, 100),
                detail: "\(count) investigation\(count == 1 ? "" : "s") in the area last year"
            ))
        }

        return SectionScore(signals: signals, capacity: 6)
    }

    // MARK: - Mobility (20%)

    private static func computeMobility(_ d: AddressReport) -> SectionScore {
        var signals: [Signal] = []

        if let transit = d.transit {
            if let onTime = transit.onTimePercentage {
                signals.append(Signal(
                    label: "On-time transit",
                    score: onTime,
                    detail: "\(Int(onTime.rounded()))% of buses run on time"
                ))
            }

            if let stop = transit.nearestStop, let m = parseMeters(stop.distanceDescription) {
                let s: Double
                switch m {
                case ..<200:       s = 100
                case 200..<400:    s = 80
                case 400..<700:    s = 60
                case 700..<1000:   s = 35
                default:           s = 15
                }
                signals.append(Signal(
                    label: "Nearest stop",
                    score: s,
                    detail: "\(Int(m.rounded())) m to the closest stop"
                ))
            }

            let routeScore: Double
            switch transit.routes.count {
            case 0: routeScore = 0
            case 1: routeScore = 30
            case 2: routeScore = 55
            case 3: routeScore = 75
            default: routeScore = 100
            }
            signals.append(Signal(
                label: "Route choice",
                score: routeScore,
                detail: "\(transit.routes.count) bus route\(transit.routes.count == 1 ? "" : "s") within reach"
            ))

            let passUpScore: Double
            switch transit.passUpsLastYear {
            case 0:      passUpScore = 100
            case 1...3:  passUpScore = 80
            case 4...10: passUpScore = 55
            default:     passUpScore = 20
            }
            signals.append(Signal(
                label: "Pass-ups",
                score: passUpScore,
                detail: transit.passUpsLastYear == 0
                    ? "No full-bus pass-ups recorded"
                    : "\(transit.passUpsLastYear) full-bus pass-up\(transit.passUpsLastYear == 1 ? "" : "s") last year"
            ))
        }

        if let street = d.streetAccess {
            let cyclingScore: Double
            switch street.cyclingRoutesNearby {
            case 0: cyclingScore = 10
            case 1: cyclingScore = 40
            case 2: cyclingScore = 70
            default: cyclingScore = 100
            }
            signals.append(Signal(
                label: "Cycling routes",
                score: cyclingScore,
                detail: street.cyclingRoutesNearby == 0
                    ? "No mapped cycling routes nearby"
                    : "\(street.cyclingRoutesNearby) cycling route\(street.cyclingRoutesNearby == 1 ? "" : "s") nearby"
            ))

            if let condition = street.pavementCondition?.lowercased() {
                let s: Double
                if condition.contains("good") || condition.contains("excellent") { s = 100 }
                else if condition.contains("fair")                               { s = 60  }
                else if condition.contains("poor")                               { s = 20  }
                else                                                             { s = 50  }
                signals.append(Signal(
                    label: "Road condition",
                    score: s,
                    detail: "Pavement rated \(condition)"
                ))
            }
        }

        return SectionScore(signals: signals, capacity: 6)
    }

    // MARK: - Liveability (20%)

    private static func computeLiveability(_ d: AddressReport) -> SectionScore {
        var signals: [Signal] = []

        if let parks = d.parks {
            let parkScore: Double
            switch parks.nearbyParks.count {
            case 0: parkScore = 0
            case 1: parkScore = 40
            case 2: parkScore = 65
            case 3: parkScore = 80
            default: parkScore = 100
            }
            signals.append(Signal(
                label: "Parks nearby",
                score: parkScore,
                detail: parks.nearbyParks.isEmpty
                    ? "No parks within walking distance"
                    : "\(parks.nearbyParks.count) park\(parks.nearbyParks.count == 1 ? "" : "s") within reach"
            ))

            let amenities = parks.nearbyParks.reduce(0) {
                $0 + $1.playgrounds + $1.fields + $1.courts
            }
            let amenityScore: Double
            switch amenities {
            case 0:     amenityScore = 10
            case 1...3: amenityScore = 40
            case 4...8: amenityScore = 70
            default:    amenityScore = 100
            }
            signals.append(Signal(
                label: "Park facilities",
                score: amenityScore,
                detail: "\(amenities) playground\(amenities == 1 ? "" : "s"), field\(amenities == 1 ? "" : "s") & court\(amenities == 1 ? "" : "s")"
            ))

            if let ha = parks.neighbourhoodHectares {
                let s: Double
                switch ha {
                case ..<10:   s = 30
                case 10..<30: s = 55
                case 30..<80: s = 80
                default:      s = 100
                }
                signals.append(Signal(
                    label: "Green space",
                    score: s,
                    detail: "\(Int(ha.rounded())) ha of parkland in the area"
                ))
            }
        }

        if let library = d.library {
            var libScore = 50.0
            if let m = parseMeters(library.distanceDescription) {
                if m < 500 { libScore += 15 } else if m < 1000 { libScore += 8 }
            }
            if library.wifi          { libScore += 8 }
            if library.accessibility { libScore += 8 }
            if library.parkingLot    { libScore += 7 }
            signals.append(Signal(
                label: "Library access",
                score: min(libScore, 100),
                detail: "Nearest branch \(library.distanceDescription)"
            ))
        }

        if let sr = d.serviceRequests {
            let total = sr.totalLastYear
            let openRate = total > 0 ? Double(sr.openLastYear) / Double(total) : 0
            let base: Double
            switch total {
            case 0...50:    base = 90
            case 51...150:  base = 70
            case 151...400: base = 50
            default:        base = 30
            }
            signals.append(Signal(
                label: "311 requests",
                score: clamped(base - openRate * 20, 0, 100),
                detail: "\(total) service request\(total == 1 ? "" : "s") last year · \(Int((openRate * 100).rounded()))% still open"
            ))
        }

        return SectionScore(signals: signals, capacity: 5)
    }

    // MARK: - Risk & Condition (15%)

    private static func computeRisk(_ d: AddressReport, permitHistory: PermitHistoryResult?) -> SectionScore {
        var signals: [Signal] = []

        // 1. On-property permit investment
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
            signals.append(Signal(label: "Permit investment", score: s, detail: detail))
        }

        // 2. Neighbourhood permit activity trend
        if d.permitActivity.count >= 2 {
            let recent = d.permitActivity.suffix(3)
            let first = Double(recent.first?.count ?? 0)
            let last  = Double(recent.last?.count ?? 0)
            let s: Double
            if first == 0          { s = 50 }
            else if last > first * 1.1  { s = 85 }
            else if last >= first * 0.85 { s = 65 }
            else                        { s = 35 }
            signals.append(Signal(
                label: "Area development",
                score: s,
                detail: trendDetail(last - first, unit: "permits")
            ))
        }

        if let infra = d.infrastructure, !d.moduleFailed(.infrastructure) {
            // 3. Pothole repairs (count on this street)
            let potholeScore: Double
            switch infra.potholes {
            case 0:      potholeScore = 100
            case 1...3:  potholeScore = 80
            case 4...10: potholeScore = 55
            default:     potholeScore = 20
            }
            signals.append(Signal(
                label: "Road repairs",
                score: potholeScore,
                detail: infra.potholes == 0 ? "No pothole repairs on this street"
                                            : "\(infra.potholes) pothole repair\(infra.potholes == 1 ? "" : "s") on this street"
            ))

            // 4. DED-tagged tree ratio
            if infra.publicTrees > 0 {
                let ratio = Double(infra.taggedTrees) / Double(infra.publicTrees)
                signals.append(Signal(
                    label: "Tree health",
                    score: clamped(100 - ratio * 200, 0, 100),
                    detail: "\(infra.taggedTrees) of \(infra.publicTrees) public trees disease-tagged"
                ))
            } else if infra.taggedTrees == 0 {
                signals.append(Signal(
                    label: "Tree health",
                    score: 100,
                    detail: "No diseased public trees recorded"
                ))
            }
        }

        // 5. Active street disruptions
        if let street = d.streetAccess, !d.moduleFailed(.streetAccess) {
            let count = street.activeDisruptions.count + street.activeLaneClosures.count
            let s: Double
            switch count {
            case 0: s = 100
            case 1: s = 75
            case 2: s = 50
            default: s = 20
            }
            signals.append(Signal(
                label: "Street disruptions",
                score: s,
                detail: count == 0 ? "No active construction or closures"
                                   : "\(count) active disruption\(count == 1 ? "" : "s") on the route"
            ))
        }

        return SectionScore(signals: signals, capacity: 5)
    }

    // MARK: - Helpers

    private static func clamped(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }

    /// "32% below citywide average" / "1.4× the citywide average".
    private static func relativeToAverage(_ ratio: Double, noun: String, referent: String = "average") -> String {
        if abs(ratio - 1.0) < 0.05 {
            return "About the citywide \(referent) for \(noun)"
        } else if ratio < 1.0 {
            return "\(Int(((1 - ratio) * 100).rounded()))% below the citywide \(referent) for \(noun)"
        } else {
            return "\(Int(((ratio - 1) * 100).rounded()))% above the citywide \(referent) for \(noun)"
        }
    }

    /// "Down 14 incidents over recent years" / "Up 3 permits …" / "Steady".
    private static func trendDetail(_ delta: Double, unit: String) -> String {
        let n = Int(abs(delta).rounded())
        if n == 0 { return "Holding steady year over year" }
        return delta < 0
            ? "Down \(n) \(unit) over recent years"
            : "Up \(n) \(unit) over recent years"
    }

    // Parses distance strings like "230 m", "1.2 km", "450m" into metres.
    // Returns nil when the format is unrecognised so the caller can skip the
    // signal rather than scoring an arbitrary fallback distance.
    static func parseMeters(_ text: String) -> Double? {
        let t = text.lowercased()
        let tokens = t.components(
            separatedBy: CharacterSet.decimalDigits.union(.init(charactersIn: ".")).inverted
        ).filter { !$0.isEmpty }
        guard let first = tokens.first, let value = Double(first) else { return nil }
        return t.contains("km") ? value * 1000 : value
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
