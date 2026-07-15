import XCTest
@testable import Seahorse

@MainActor
final class DataStorageSearchIndexTests: XCTestCase {
    func testSearchIndexTracksItemAndTagUpdates() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        var tag = Tag(name: "OriginalTag", color: .blue)
        try storage.addTag(tag)
        var bookmark = Bookmark(
            title: "OriginalTitle",
            url: "https://example.com",
            categoryId: category.id,
            tagIds: [tag.id]
        )
        try storage.addBookmark(bookmark)

        XCTAssertEqual(search(storage, "OriginalTitle"), [bookmark.id])
        XCTAssertEqual(search(storage, "OriginalTag"), [bookmark.id])

        bookmark.title = "UpdatedTitle"
        try storage.updateBookmark(bookmark)
        XCTAssertTrue(search(storage, "OriginalTitle").isEmpty)
        XCTAssertEqual(search(storage, "UpdatedTitle"), [bookmark.id])

        tag.name = "UpdatedTag"
        try storage.updateTag(tag)
        XCTAssertTrue(search(storage, "OriginalTag").isEmpty)
        XCTAssertEqual(search(storage, "UpdatedTag"), [bookmark.id])
    }

    func testDeleteTagRemovesReferencesFromAllItemTypes() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let tag = Tag(name: "Delete Me", color: .blue)
        try storage.addTag(tag)
        storage.addItem(AnyCollectionItem(Bookmark(
            title: "Bookmark",
            url: "https://example.com",
            categoryId: category.id,
            tagIds: [tag.id]
        )))
        storage.addItem(AnyCollectionItem(ImageItem(
            imagePath: "/tmp/image.png",
            categoryId: category.id,
            tagIds: [tag.id]
        )))
        storage.addItem(AnyCollectionItem(TextItem(
            content: "Text",
            categoryId: category.id,
            tagIds: [tag.id]
        )))

        try storage.deleteTag(tag)

        XCTAssertNil(storage.tag(for: tag.id))
        XCTAssertTrue(storage.items.allSatisfy { !$0.tagIds.contains(tag.id) })
    }

    private func search(_ storage: DataStorage, _ query: String) -> [UUID] {
        CollectionSearch.items(
            in: storage.searchRecordsSnapshot(),
            matching: CollectionSearch.Criteria(query: query)
        ).map(\.id)
    }
}
