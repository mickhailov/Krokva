import Foundation

/// Directional metrics used to score a move from the current address to a
/// candidate. Every field is optional — a dimension only counts when *both* the
/// current address and the candidate have a value for it.
struct RelocationMetrics {
    var propertyTax: Double?
    var crime: Double?
    var calls311: Double?
    var emergency: Double?
    var vacantOrders: Double?
    var livingArea: Double?
    var parks: Double?
    var transitOnTime: Double?
    var schools: Double?
    var income: Double?
    var businesses: Double?

    /// Pulls the comparable numbers straight out of a live report (used for the
    /// on-screen report in the relocation hint, which may not be saved yet).
    /// Mirrors the flattened fields `SavedReport.init(from:)` derives.
    static func from(report d: AddressReport) -> RelocationMetrics {
        RelocationMetrics(
            propertyTax: d.property?.propertyTax,
            crime: (d.policeCrime?.yearlyCounts.last?.neighbourhood).map(Double.init),
            calls311: (d.serviceRequests?.totalLastYear).map(Double.init),
            emergency: (d.emergency?.totalLastYear).map(Double.init),
            vacantOrders: Double(d.vacantOrders.count),
            livingArea: d.property?.livingArea,
            parks: (d.parks?.nearbyParks.count).map(Double.init),
            transitOnTime: d.transit?.onTimePercentage,
            schools: Double(d.nearbySchools.count),
            income: d.demographics?.medianHouseholdIncome,
            businesses: (d.localBusiness?.totalNearby).map(Double.init)
        )
    }

    /// Pulls the comparable numbers out of a saved snapshot plus its decoded
    /// report (the same sources `PropertyCompareView` already reads).
    static func from(saved: SavedReport, report: AddressReport?) -> RelocationMetrics {
        RelocationMetrics(
            propertyTax: saved.propertyTax,
            crime: saved.crimeLastYear.map(Double.init),
            calls311: saved.serviceRequestTotal.map(Double.init),
            emergency: (report?.emergency?.totalLastYear).map(Double.init),
            vacantOrders: Double(saved.vacantOrderCount),
            livingArea: saved.livingArea,
            parks: saved.parkCount.map(Double.init),
            transitOnTime: saved.transitOnTimePct,
            schools: report.map { Double($0.nearbySchools.count) },
            income: report?.demographics?.medianHouseholdIncome,
            businesses: (report?.localBusiness?.totalNearby).map(Double.init)
        )
    }
}

/// One candidate scored against the current address.
struct RelocationScore: Identifiable {
    let id: String          // candidate address (unique per column)
    let address: String
    let composite: Double    // > 0 → better than current overall
    let betterReasons: [String]
    let worseReasons: [String]

    var isImprovement: Bool { composite > 0.001 }
    var isRegression: Bool { composite < -0.001 }
}

/// Weighted, direction-aware verdict: how each candidate compares to the current
/// address for the purpose of moving. Pure value type — no UI, easy to test.
struct RelocationVerdict {
    let currentAddress: String
    /// Candidates sorted best → worst by composite score.
    let scores: [RelocationScore]

    /// The single strongest candidate, only if it actually beats the current place.
    var winner: RelocationScore? { scores.first(where: \.isImprovement) }

    // MARK: - Dimensions

    private struct Dimension {
        let weight: Double
        let higherIsBetter: Bool
        let betterPhrase: String
        let worsePhrase: String
        let value: (RelocationMetrics) -> Double?
    }

    private static let dimensions: [Dimension] = [
        .init(weight: 1.2, higherIsBetter: false, betterPhrase: "lower tax",        worsePhrase: "higher tax",        value: \.propertyTax),
        .init(weight: 1.5, higherIsBetter: false, betterPhrase: "less crime",       worsePhrase: "more crime",        value: \.crime),
        .init(weight: 0.7, higherIsBetter: false, betterPhrase: "fewer 311 calls",  worsePhrase: "more 311 calls",    value: \.calls311),
        .init(weight: 1.0, higherIsBetter: false, betterPhrase: "fewer emergencies", worsePhrase: "more emergencies", value: \.emergency),
        .init(weight: 0.6, higherIsBetter: false, betterPhrase: "fewer vacant orders", worsePhrase: "more vacant orders", value: \.vacantOrders),
        .init(weight: 0.8, higherIsBetter: true,  betterPhrase: "more living space", worsePhrase: "less living space", value: \.livingArea),
        .init(weight: 0.6, higherIsBetter: true,  betterPhrase: "more parks",       worsePhrase: "fewer parks",       value: \.parks),
        .init(weight: 0.7, higherIsBetter: true,  betterPhrase: "better transit",   worsePhrase: "worse transit",     value: \.transitOnTime),
        .init(weight: 0.7, higherIsBetter: true,  betterPhrase: "more schools",     worsePhrase: "fewer schools",     value: \.schools),
        .init(weight: 0.5, higherIsBetter: true,  betterPhrase: "higher area income", worsePhrase: "lower area income", value: \.income),
        .init(weight: 0.5, higherIsBetter: true,  betterPhrase: "more local business", worsePhrase: "less local business", value: \.businesses),
    ]

    /// Ignore differences smaller than this fraction to avoid noisy reasons.
    private static let noiseFloor = 0.03

    static func make(currentAddress: String,
                     current: RelocationMetrics,
                     candidates: [(address: String, metrics: RelocationMetrics)]) -> RelocationVerdict {
        let scores = candidates.map { candidate in
            score(address: candidate.address, current: current, candidate: candidate.metrics)
        }.sorted { $0.composite > $1.composite }
        return RelocationVerdict(currentAddress: currentAddress, scores: scores)
    }

    private static func score(address: String,
                              current: RelocationMetrics,
                              candidate: RelocationMetrics) -> RelocationScore {
        var composite = 0.0
        var better: [(phrase: String, magnitude: Double)] = []
        var worse: [(phrase: String, magnitude: Double)] = []

        for dim in dimensions {
            guard let c = dim.value(current), let x = dim.value(candidate) else { continue }
            let denominator = max(abs(c), abs(x), 1)
            let rel = (x - c) / denominator            // signed fractional change
            guard abs(rel) > noiseFloor else { continue }
            let direction = dim.higherIsBetter ? 1.0 : -1.0
            let contribution = max(-1, min(1, rel)) * direction * dim.weight
            composite += contribution
            if contribution > 0 {
                better.append((dim.betterPhrase, contribution))
            } else {
                worse.append((dim.worsePhrase, -contribution))
            }
        }

        let betterReasons = better.sorted { $0.magnitude > $1.magnitude }.prefix(3).map(\.phrase)
        let worseReasons = worse.sorted { $0.magnitude > $1.magnitude }.prefix(3).map(\.phrase)
        return RelocationScore(
            id: address,
            address: address,
            composite: composite,
            betterReasons: Array(betterReasons),
            worseReasons: Array(worseReasons)
        )
    }
}
