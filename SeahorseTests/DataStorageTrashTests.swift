import Foundation
import XCTest
@testable import Seahorse

@MainActor
final class DataStorageTrashTests: XCTestCase {
    func testDeleteIsIdempotentAndExcludesItemFromActiveViews() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let bookmark = Bookmark(
            title: "Trash Me",
            url: "https://trash.example.com",
            categoryId: category.id
        )
        try storage.addBookmark(bookmark)
        let item = AnyCollectionItem(bookmark)

        try storage.deleteItem(item)
        try storage.deleteItem(item)

        XCTAssertNil(storage.item(for: bookmark.id))
        XCTAssertNotNil(storage.itemIncludingDeleted(for: bookmark.id))
        XCTAssertTrue(storage.bookmarks.isEmpty)
        XCTAssertEqual(storage.trashItems.map(\.id), [bookmark.id])
        XCTAssertTrue(CollectionSearch.items(
            in: storage.searchRecordsSnapshot(),
            matching: CollectionSearch.Criteria(query: "Trash Me")
        ).isEmpty)
    }

    func testBatchDeleteDoesNotPartiallyApplyWhenAnItemIsMissing() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let bookmark = Bookmark(
            title: "Keep Me",
            url: "https://keep.example.com",
            categoryId: category.id
        )
        try storage.addBookmark(bookmark)

        XCTAssertThrowsError(try storage.deleteItems(ids: [bookmark.id, UUID()]))
        XCTAssertNotNil(storage.item(for: bookmark.id))
        XCTAssertTrue(storage.trashItems.isEmpty)
    }

    func testRestoreSanitizesMissingReferences() throws {
        let storage = DataStorage(database: MockDatabase())
        let noneCategory = Category(name: "None", icon: "folder", color: .gray)
        let validTag = Tag(name: "Valid", color: .blue)
        try storage.addCategory(noneCategory)
        try storage.addTag(validTag)
        let bookmark = Bookmark(
            title: "Restore",
            url: "https://restore.example.com",
            categoryId: UUID(),
            tagIds: [validTag.id, UUID()]
        )
        storage.addItem(AnyCollectionItem(bookmark))
        try storage.deleteItem(AnyCollectionItem(bookmark))

        let result = try storage.restoreItem(AnyCollectionItem(bookmark))
        let restored = try XCTUnwrap(result.item.asBookmark)

        XCTAssertTrue(result.categoryWasReset)
        XCTAssertEqual(result.removedTagCount, 1)
        XCTAssertEqual(restored.categoryId, noneCategory.id)
        XCTAssertEqual(restored.tagIds, [validTag.id])
        XCTAssertNil(restored.deletedAt)
    }

    func testRestoreRejectsDuplicateActiveBookmarkURL() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let original = Bookmark(
            title: "Original",
            url: "https://duplicate.example.com/path",
            categoryId: category.id
        )
        try storage.addBookmark(original)
        try storage.deleteBookmark(original)
        let replacement = Bookmark(
            title: "Replacement",
            url: "HTTPS://duplicate.example.com/path/",
            categoryId: category.id
        )
        try storage.addBookmark(replacement)

        XCTAssertThrowsError(try storage.restoreItem(AnyCollectionItem(original))) { error in
            guard case DatabaseError.duplicateBookmarkURL = error else {
                return XCTFail("Expected duplicateBookmarkURL, got \(error)")
            }
        }
        XCTAssertTrue(storage.itemIncludingDeleted(for: original.id)?.isDeleted == true)
        XCTAssertNotNil(storage.item(for: replacement.id))
    }

    func testPermanentDeleteDoesNotRemoveExternalImage() throws {
        let externalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("seahorse-external-\(UUID().uuidString).png")
        try Data([0]).write(to: externalURL)
        defer { try? FileManager.default.removeItem(at: externalURL) }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let image = ImageItem(imagePath: externalURL.path, categoryId: category.id)
        storage.addItem(AnyCollectionItem(image))
        try storage.deleteItem(AnyCollectionItem(image))
        try storage.permanentlyDeleteItem(AnyCollectionItem(image))

        XCTAssertTrue(FileManager.default.fileExists(atPath: externalURL.path))
        XCTAssertNil(storage.itemIncludingDeleted(for: image.id))
    }

    func testInternalImageIsDeletedOnlyAfterLastReferenceIsPermanentlyDeleted() throws {
        let imagesDirectory = StorageManager.shared.getImagesDirectory()
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let filename = "trash-reference-test-\(UUID().uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try Data([0]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let first = ImageItem(imagePath: filename, categoryId: category.id)
        let second = ImageItem(imagePath: filename, categoryId: category.id)
        storage.addItem(AnyCollectionItem(first))
        storage.addItem(AnyCollectionItem(second))

        try storage.deleteItem(AnyCollectionItem(first))
        try storage.permanentlyDeleteItem(AnyCollectionItem(first))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try storage.deleteItem(AnyCollectionItem(second))
        try storage.permanentlyDeleteItem(AnyCollectionItem(second))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testLegacyBookmarkWithoutDeletedAtStillDecodesAsActive() throws {
        let categoryID = UUID()
        let bookmark = Bookmark(
            title: "Legacy",
            url: "https://legacy.example.com",
            categoryId: categoryID
        )
        let encoded = try JSONEncoder().encode(bookmark)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "deletedAt")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Bookmark.self, from: legacyData)
        XCTAssertNil(decoded.deletedAt)
    }
}
