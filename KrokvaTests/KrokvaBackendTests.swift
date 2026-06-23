import XCTest
@testable import Krokva

final class KrokvaBackendTests: XCTestCase {

    func testDefaultsMatchTheShippingMirror() {
        XCTAssertEqual(KrokvaBackend.defaultHost, "3.99.123.190:8889")
        XCTAssertEqual(KrokvaBackend.defaultScheme, "http")
    }

    // isSecure must stay consistent with whatever scheme resolves at runtime, so flipping
    // the endpoint to https (the eventual fix) automatically reports as secure.
    func testIsSecureTracksScheme() {
        XCTAssertEqual(KrokvaBackend.isSecure, KrokvaBackend.scheme.lowercased() == "https")
    }

    func testResolvedHostFallsBackToDefaultWithoutOverride() {
        // The test host app ships no KrokvaBackendHost Info.plist key, so the default applies.
        XCTAssertEqual(KrokvaBackend.host, KrokvaBackend.defaultHost)
        XCTAssertEqual(KrokvaBackend.scheme, KrokvaBackend.defaultScheme)
    }
}
