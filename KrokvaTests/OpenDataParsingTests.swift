import XCTest
@testable import Krokva

/// Covers the `[String: Any]` decoding helpers used to parse loosely-typed Socrata rows,
/// where a numeric field may arrive as a String, Int, or Double depending on the dataset.
final class OpenDataParsingTests: XCTestCase {

    func testStringFromStringAndNonString() {
        let row: [String: Any] = ["name": "Arnold", "count": 12]
        XCTAssertEqual(row.string("name"), "Arnold")
        XCTAssertEqual(row.string("count"), "12")
        XCTAssertNil(row.string("missing"))
    }

    func testIntFromIntAndString() {
        let row: [String: Any] = ["a": 5, "b": "7", "c": "nope"]
        XCTAssertEqual(row.int("a"), 5)
        XCTAssertEqual(row.int("b"), 7)
        XCTAssertNil(row.int("c"))
        XCTAssertNil(row.int("missing"))
    }

    func testDoubleFromMixedTypes() {
        let row: [String: Any] = ["d": 3.5, "i": 4, "s": "2.25", "bad": "x"]
        XCTAssertEqual(row.double("d"), 3.5)
        XCTAssertEqual(row.double("i"), 4.0)
        XCTAssertEqual(row.double("s"), 2.25)
        XCTAssertNil(row.double("bad"))
    }

    func testBoolAcceptsCommonTruthyForms() {
        XCTAssertTrue((["v": "true"] as [String: Any]).bool("v"))
        XCTAssertTrue((["v": "YES"] as [String: Any]).bool("v"))
        XCTAssertTrue((["v": "1"] as [String: Any]).bool("v"))
        XCTAssertTrue((["v": 1] as [String: Any]).bool("v"))
        XCTAssertTrue((["v": true] as [String: Any]).bool("v"))
    }

    func testBoolFalsyAndMissingDefaultToFalse() {
        XCTAssertFalse((["v": "false"] as [String: Any]).bool("v"))
        XCTAssertFalse((["v": "0"] as [String: Any]).bool("v"))
        XCTAssertFalse((["v": 0] as [String: Any]).bool("v"))
        XCTAssertFalse(([:] as [String: Any]).bool("missing"))
    }
}
