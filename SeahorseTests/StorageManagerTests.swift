import XCTest
@testable import Seahorse

final class StorageManagerTests: XCTestCase {
    func testStorageRootIsResolvedOnlyOnce() {
        let customRoot = URL(fileURLWithPath: "/tmp/seahorse-custom", isDirectory: true)
        let fallbackRoot = URL(fileURLWithPath: "/tmp/seahorse-fallback", isDirectory: true)
        var resolutionCount = 0

        let manager = StorageManager(resolveStorageDirectory: {
            resolutionCount += 1
            return (resolutionCount == 1 ? customRoot : fallbackRoot, nil)
        })

        XCTAssertEqual(manager.getStorageRoot(), customRoot)
        XCTAssertEqual(
            manager.getImagesDirectory(),
            customRoot.appendingPathComponent("Images", isDirectory: true)
        )
        XCTAssertEqual(
            manager.resolveImagePath("generated-cover.png"),
            customRoot.appendingPathComponent("Images/generated-cover.png").path
        )
        XCTAssertEqual(resolutionCount, 1)
    }
}
