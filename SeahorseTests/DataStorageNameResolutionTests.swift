import XCTest
@testable import Seahorse

@MainActor
final class DataStorageNameResolutionTests: XCTestCase {
    func testCategoryAndTagLookupMatchesCaseInsensitiveUniqueness() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = Category(name: "Development", icon: "folder", color: .blue)
        let tag = Tag(name: "AI", color: .blue)
        try storage.addCategory(category)
        try storage.addTag(tag)

        XCTAssertEqual(storage.category(named: "development")?.id, category.id)
        XCTAssertEqual(storage.tag(named: "ai")?.id, tag.id)
    }
}
