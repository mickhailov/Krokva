import XCTest
@testable import Krokva

final class ReportRatingTests: XCTestCase {

    // MARK: - parseMeters

    func testParseMetersFromPlainMetres() {
        XCTAssertEqual(ReportRating.parseMeters("230 m"), 230)
        XCTAssertEqual(ReportRating.parseMeters("450m"), 450)
    }

    func testParseMetersConvertsKilometres() {
        XCTAssertEqual(ReportRating.parseMeters("1.2 km"), 1200)
    }

    func testParseMetersReturnsNilForUnparseable() {
        XCTAssertNil(ReportRating.parseMeters("nearby"))
        XCTAssertNil(ReportRating.parseMeters(""))
    }

    // MARK: - SectionScore

    func testSectionScoreAveragesSignals() {
        let section = ReportRating.SectionScore(signals: [
            .init(label: "a", score: 40, detail: ""),
            .init(label: "b", score: 60, detail: ""),
        ], capacity: 4)
        XCTAssertEqual(section.score, 50)
        XCTAssertEqual(section.dataPoints, 2)
        XCTAssertFalse(section.isUnavailable)
        XCTAssertTrue(section.isPartial, "2 of 4 signals should be partial")
    }

    func testEmptySectionScoreDefaultsToFiftyAndIsUnavailable() {
        let section = ReportRating.SectionScore(signals: [], capacity: 4)
        XCTAssertEqual(section.score, 50)
        XCTAssertTrue(section.isUnavailable)
        XCTAssertFalse(section.isPartial)
    }

    func testFullSectionIsNotPartial() {
        let signals = (0..<3).map { ReportRating.Signal(label: "s\($0)", score: 70, detail: "") }
        let section = ReportRating.SectionScore(signals: signals, capacity: 3)
        XCTAssertFalse(section.isPartial)
    }

    // MARK: - grade

    func testGradeBoundaries() {
        XCTAssertEqual(rating(overall: 95).grade, "A+")
        XCTAssertEqual(rating(overall: 90).grade, "A+")
        XCTAssertEqual(rating(overall: 85).grade, "A")
        XCTAssertEqual(rating(overall: 75).grade, "B")
        XCTAssertEqual(rating(overall: 65).grade, "C")
        XCTAssertEqual(rating(overall: 55).grade, "D")
        XCTAssertEqual(rating(overall: 40).grade, "F")
    }

    // MARK: - effectiveWeight redistribution

    func testEffectiveWeightWhenAllSectionsAvailable() {
        let r = rating(overall: 80, allAvailable: true)
        // Property base weight 0.25 over a full 1.0 total.
        XCTAssertEqual(r.effectiveWeight(for: "Property"), 0.25, accuracy: 0.0001)
    }

    func testEffectiveWeightRedistributesFromMissingSections() {
        // Only Property and Safety have data → their weights renormalize to sum to 1.
        let r = ReportRating(
            property: section(score: 80),
            safety: section(score: 70),
            mobility: .init(signals: [], capacity: 6),
            liveability: .init(signals: [], capacity: 5),
            risk: .init(signals: [], capacity: 5),
            overall: 75
        )
        let propW = r.effectiveWeight(for: "Property")
        let safetyW = r.effectiveWeight(for: "Safety")
        XCTAssertEqual(propW + safetyW, 1.0, accuracy: 0.0001)
        // 0.25 / (0.25 + 0.20)
        XCTAssertEqual(propW, 0.25 / 0.45, accuracy: 0.0001)
        XCTAssertEqual(r.effectiveWeight(for: "Mobility"), 0, "unavailable section carries no weight")
    }

    // MARK: - Helpers

    private func section(score: Double) -> ReportRating.SectionScore {
        ReportRating.SectionScore(signals: [.init(label: "x", score: score, detail: "")], capacity: 1)
    }

    private func rating(overall: Double, allAvailable: Bool = true) -> ReportRating {
        let s = allAvailable ? section(score: 70) : ReportRating.SectionScore(signals: [], capacity: 1)
        return ReportRating(property: s, safety: s, mobility: s, liveability: s, risk: s, overall: overall)
    }
}
