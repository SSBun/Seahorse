import XCTest
@testable import Seahorse

@MainActor
final class DataStorageCategoryTests: XCTestCase {
    func testDeletingCategoryMovesEveryItemTypeToNone() throws {
        let storage = DataStorage(database: MockDatabase())
        let none = Category(name: "None", icon: "folder.fill", color: .gray)
        let deleted = Category(name: "Archive", icon: "archivebox.fill", color: .blue)
        try storage.addCategory(none)
        try storage.addCategory(deleted)

        let bookmark = Bookmark(
            title: "Bookmark",
            url: "https://example.com/category-delete",
            categoryId: deleted.id
        )
        let image = ImageItem(imagePath: "image.png", categoryId: deleted.id)
        let text = TextItem(
            content: "Deleted note",
            categoryId: deleted.id,
            deletedAt: .now
        )
        storage.addItem(AnyCollectionItem(bookmark))
        storage.addItem(AnyCollectionItem(image))
        storage.addItem(AnyCollectionItem(text))

        try storage.deleteCategory(deleted)

        XCTAssertNil(storage.category(for: deleted.id))
        XCTAssertEqual(storage.item(for: bookmark.id)?.categoryId, none.id)
        XCTAssertEqual(storage.item(for: image.id)?.categoryId, none.id)
        XCTAssertEqual(storage.itemIncludingDeleted(for: text.id)?.categoryId, none.id)
    }
}
