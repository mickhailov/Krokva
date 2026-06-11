import Foundation

struct ReportRating {
    struct SectionScore {
        let score: Double
        let dataPoints: Int
        let capacity: Int

        var isUnavailable: Bool { dataPoints == 0 }
        var isPartial: Bool { dataPoints > 0 && dataPoints < capacity }
    }

    let property: SectionScore
    let safety: SectionScore
    let mobility: SectionScore
    let liveability: SectionScore
    let risk: SectionScore
    let overall: Double

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

    static func compute(report: AddressReport, permitHistory: PermitHistoryResult?) -> ReportRating {
        let property    = computeProperty(report)
        let safety      = computeSafety(report)
        let mobility    = computeMobility(report)
        let liveability = computeLiveability(report)
        let risk        = computeRisk(report, permitHistory: permitHistory)

        // Redistribute weight from zero-data sections so missing city data
        // doesn't drag the overall score down.
        let sections: [(score: SectionScore, weight: Double)] = [
            (property,    0.25),
            (safety,      0.20),
            (mobility,    0.20),
            (liveability, 0.20),
            (risk,        0.15),
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
        var scores: [Double] = []

        // 1. Neighbourhood value percentile
        if let assessed = d.property?.totalAssessedValue, !d.neighbourhoodValues.isEmpty {
            let sorted = d.neighbourhoodValues.sorted { $0.midpoint < $1.midpoint }
            let below = sorted.filter { $0.midpoint < assessed }.count
            scores.append(Double(below) / Double(sorted.count) * 100)
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
            scores.append(s)
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
            scores.append(s)
        }

        // 4. Key amenities (garage + basement + A/C)
        if d.property != nil {
            var bonus = 40.0
            if d.property?.garage != nil         { bonus += 20 }
            if d.property?.basement != nil       { bonus += 20 }
            if d.property?.airConditioning != nil { bonus += 20 }
            scores.append(min(bonus, 100))
        }

        return section(scores: scores, capacity: 4)
    }

    // MARK: - Safety (20%)

    private static func computeSafety(_ d: AddressReport) -> SectionScore {
        var scores: [Double] = []

        // 1. Crime level vs citywide average
        if let last = d.policeCrime?.yearlyCounts.last, last.citywideAverage > 0 {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            scores.append(clamped(100 - (ratio - 1.0) * 80, 0, 100))
        }

        // 2. Crime trend over last 3 recorded years
        if let crime = d.policeCrime, crime.yearlyCounts.count >= 2 {
            let recent = crime.yearlyCounts.suffix(3)
            let first = Double(recent.first!.neighbourhood)
            let last  = Double(recent.last!.neighbourhood)
            let delta = last - first
            let s: Double = delta < -10 ? 90 : delta < 0 ? 70 : delta < 10 ? 55 : 30
            scores.append(s)
        }

        // 3. Emergency calls vs citywide median
        if let em = d.emergency, let median = em.citywideMedian, median > 0 {
            let ratio = Double(em.totalLastYear) / Double(median)
            scores.append(clamped(100 - (ratio - 1.0) * 80, 0, 100))
        }

        // 4. Public health events vs citywide average
        if let last = d.publicHealth?.yearlyEvents.last, last.citywideAverage > 0 {
            let ratio = Double(last.neighbourhood) / last.citywideAverage
            scores.append(clamped(100 - (ratio - 1.0) * 80, 0, 100))
        }

        // 5. Vacant orders on the street
        let vacantScore: Double
        switch d.vacantOrders.count {
        case 0: vacantScore = 100
        case 1: vacantScore = 70
        case 2: vacantScore = 45
        default: vacantScore = 15
        }
        scores.append(vacantScore)

        // 6. Bylaw investigations last recorded year
        if let count = d.bylaw?.yearly.last?.count {
            scores.append(clamped(100 - Double(count) * 0.5, 0, 100))
        }

        return section(scores: scores, capacity: 6)
    }

    // MARK: - Mobility (20%)

    private static func computeMobility(_ d: AddressReport) -> SectionScore {
        var scores: [Double] = []

        if let transit = d.transit {
            if let onTime = transit.onTimePercentage {
                scores.append(onTime)
            }

            if let stop = transit.nearestStop {
                let m = parseMeters(stop.distanceDescription)
                let s: Double
                switch m {
                case ..<200:       s = 100
                case 200..<400:    s = 80
                case 400..<700:    s = 60
                case 700..<1000:   s = 35
                default:           s = 15
                }
                scores.append(s)
            }

            let routeScore: Double
            switch transit.routes.count {
            case 0: routeScore = 0
            case 1: routeScore = 30
            case 2: routeScore = 55
            case 3: routeScore = 75
            default: routeScore = 100
            }
            scores.append(routeScore)

            let passUpScore: Double
            switch transit.passUpsLastYear {
            case 0:      passUpScore = 100
            case 1...3:  passUpScore = 80
            case 4...10: passUpScore = 55
            default:     passUpScore = 20
            }
            scores.append(passUpScore)
        }

        if let street = d.streetAccess {
            let cyclingScore: Double
            switch street.cyclingRoutesNearby {
            case 0: cyclingScore = 10
            case 1: cyclingScore = 40
            case 2: cyclingScore = 70
            default: cyclingScore = 100
            }
            scores.append(cyclingScore)

            if let condition = street.pavementCondition?.lowercased() {
                let s: Double
                if condition.contains("good") || condition.contains("excellent") { s = 100 }
                else if condition.contains("fair")                               { s = 60  }
                else if condition.contains("poor")                               { s = 20  }
                else                                                             { s = 50  }
                scores.append(s)
            }
        }

        return section(scores: scores, capacity: 6)
    }

    // MARK: - Liveability (20%)

    private static func computeLiveability(_ d: AddressReport) -> SectionScore {
        var scores: [Double] = []

        if let parks = d.parks {
            let parkScore: Double
            switch parks.nearbyParks.count {
            case 0: parkScore = 0
            case 1: parkScore = 40
            case 2: parkScore = 65
            case 3: parkScore = 80
            default: parkScore = 100
            }
            scores.append(parkScore)

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
            scores.append(amenityScore)

            if let ha = parks.neighbourhoodHectares {
                let s: Double
                switch ha {
                case ..<10:   s = 30
                case 10..<30: s = 55
                case 30..<80: s = 80
                default:      s = 100
                }
                scores.append(s)
            }
        }

        if let library = d.library {
            var libScore = 50.0
            let m = parseMeters(library.distanceDescription)
            if m < 500 { libScore += 15 } else if m < 1000 { libScore += 8 }
            if library.wifi         { libScore += 8 }
            if library.accessibility { libScore += 8 }
            if library.parkingLot   { libScore += 7 }
            scores.append(min(libScore, 100))
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
            scores.append(clamped(base - openRate * 20, 0, 100))
        }

        return section(scores: scores, capacity: 5)
    }

    // MARK: - Risk & Condition (15%)

    private static func computeRisk(_ d: AddressReport, permitHistory: PermitHistoryResult?) -> SectionScore {
        var scores: [Double] = []

        // 1. On-property permit investment
        if let h = permitHistory {
            let s: Double
            if h.analytics.majorRenovationDetected { s = 100 }
            else if h.analytics.permitCount > 5    { s = 85  }
            else if h.analytics.permitCount > 0    { s = 65  }
            else                                   { s = 40  }
            scores.append(s)
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
            scores.append(s)
        }

        if let infra = d.infrastructure {
            // 3. Pothole repairs (count on this street)
            let potholeScore: Double
            switch infra.potholes {
            case 0:      potholeScore = 100
            case 1...3:  potholeScore = 80
            case 4...10: potholeScore = 55
            default:     potholeScore = 20
            }
            scores.append(potholeScore)

            // 4. DED-tagged tree ratio
            if infra.publicTrees > 0 {
                let ratio = Double(infra.taggedTrees) / Double(infra.publicTrees)
                scores.append(clamped(100 - ratio * 200, 0, 100))
            } else if infra.taggedTrees == 0 {
                scores.append(100)
            }
        }

        // 5. Active street disruptions
        if let street = d.streetAccess {
            let count = street.activeDisruptions.count + street.activeLaneClosures.count
            let s: Double
            switch count {
            case 0: s = 100
            case 1: s = 75
            case 2: s = 50
            default: s = 20
            }
            scores.append(s)
        }

        return section(scores: scores, capacity: 5)
    }

    // MARK: - Helpers

    private static func section(scores: [Double], capacity: Int) -> SectionScore {
        SectionScore(
            score: scores.isEmpty ? 50 : scores.reduce(0, +) / Double(scores.count),
            dataPoints: scores.count,
            capacity: capacity
        )
    }

    private static func clamped(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }

    // Parses distance strings like "230 m", "1.2 km", "450m" into metres.
    // Returns 500 when the format is unrecognised.
    static func parseMeters(_ text: String) -> Double {
        let t = text.lowercased()
        let tokens = t.components(
            separatedBy: CharacterSet.decimalDigits.union(.init(charactersIn: ".")).inverted
        ).filter { !$0.isEmpty }
        guard let first = tokens.first, let value = Double(first) else { return 500 }
        return t.contains("km") ? value * 1000 : value
    }
}
