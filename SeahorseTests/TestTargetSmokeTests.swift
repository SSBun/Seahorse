import XCTest
@testable import Seahorse

final class TestTargetSmokeTests: XCTestCase {
    func testTargetLoadsAppModule() {
        XCTAssertEqual(CollectionItemType.bookmark.rawValue, "bookmark")
    }
}
