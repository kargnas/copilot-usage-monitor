import XCTest
@testable import CopilotMonitor

final class ZaiProviderTests: XCTestCase {

    func testProviderIdentifier() {
        let provider = ZaiProvider()
        XCTAssertEqual(provider.identifier, .zai)
    }

    func testProviderType() {
        let provider = ZaiProvider()
        XCTAssertEqual(provider.type, .quotaBased)
    }
}
