import XCTest
@testable import Krokva

final class AddressNormalizerTests: XCTestCase {
    private let normalizer = WinnipegAddressNormalizer()

    func testNormalizeSplitsNumberStreetAndCity() {
        let result = normalizer.normalize("196 Arnold Avenue, Winnipeg")
        XCTAssertEqual(result.civicNumber, 196)
        XCTAssertEqual(result.streetName, "Arnold Avenue")
        XCTAssertEqual(result.cityName, "Winnipeg")
        XCTAssertEqual(result.raw, "196 Arnold Avenue, Winnipeg")
    }

    func testNormalizeWithoutCivicNumber() {
        let result = normalizer.normalize("Portage Avenue, Winnipeg")
        XCTAssertNil(result.civicNumber)
        XCTAssertEqual(result.streetName, "Portage Avenue")
    }

    func testNormalizeWithoutCityComponent() {
        let result = normalizer.normalize("8 Solstice Line")
        XCTAssertEqual(result.civicNumber, 8)
        XCTAssertEqual(result.streetName, "Solstice Line")
        XCTAssertEqual(result.cityName, "")
    }

    func testDisplayAddressIsRawInput() {
        let result = normalizer.normalize(" 1 York , Winnipeg ")
        XCTAssertEqual(result.displayAddress, " 1 York , Winnipeg ")
    }

    // The "line" suffix must be stripped so "8 Solstice Line" resolves to the dataset's bare
    // core name "SOLSTICE" — a documented Winnipeg-specific normalization rule.
    func testStreetVariantsStripsLineSuffix() {
        let address = normalizer.normalize("8 Solstice Line")
        let variants = normalizer.streetVariants(for: address)
        XCTAssertTrue(variants.contains("SOLSTICE"), "variants were \(variants)")
    }

    func testStreetVariantsProducesAvenueAbbreviations() {
        let address = normalizer.normalize("196 Arnold Avenue, Winnipeg")
        let variants = normalizer.streetVariants(for: address)
        XCTAssertTrue(variants.contains("Arnold Av"))
        XCTAssertTrue(variants.contains("Arnold Ave"))
        XCTAssertTrue(variants.contains("Arnold Avenue"))
    }

    func testStreetVariantsNeverContainsEmptyString() {
        let address = normalizer.normalize("100 Main Street, Winnipeg")
        let variants = normalizer.streetVariants(for: address)
        XCTAssertFalse(variants.contains(""))
    }
}
