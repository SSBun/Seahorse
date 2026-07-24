import XCTest
@testable import Seahorse

@MainActor
final class DataStorageDuplicateBookmarkTests: XCTestCase {
    func testDuplicateBookmarkRefreshesOnlyAddedDateWhenEnabled() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let original = Bookmark(
            title: "Original",
            url: "https://example.com/path",
            categoryId: category.id,
            addedDate: Date(timeIntervalSince1970: 1),
            notes: "Keep me"
        )
        try storage.addBookmark(original, updateDuplicateAddedDate: false)

        let duplicate = Bookmark(
            title: "Replacement",
            url: "HTTPS://EXAMPLE.COM/path/",
            categoryId: category.id,
            notes: "Do not use"
        )
        try storage.addBookmark(duplicate, updateDuplicateAddedDate: true)

        let refreshed = try XCTUnwrap(storage.bookmarks.first)
        XCTAssertEqual(storage.bookmarks.count, 1)
        XCTAssertEqual(refreshed.id, original.id)
        XCTAssertEqual(refreshed.title, original.title)
        XCTAssertEqual(refreshed.notes, original.notes)
        XCTAssertGreaterThan(refreshed.addedDate, original.addedDate)
    }

    func testDuplicateBookmarkStillThrowsWhenRefreshIsDisabled() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let original = Bookmark(
            title: "Original",
            url: "https://example.com",
            categoryId: category.id
        )
        try storage.addBookmark(original, updateDuplicateAddedDate: false)

        XCTAssertThrowsError(
            try storage.addBookmark(original, updateDuplicateAddedDate: false)
        ) { error in
            guard case DatabaseError.duplicateBookmarkURL = error else {
                return XCTFail("Expected duplicateBookmarkURL, got \(error)")
            }
        }
        XCTAssertEqual(storage.bookmarks.count, 1)
    }

    func testRefreshedBookmarkIsFirstWhenSortedNewestFirst() throws {
        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let original = Bookmark(
            title: "Original",
            url: "https://original.example.com",
            categoryId: category.id,
            addedDate: Date(timeIntervalSince1970: 1)
        )
        let newer = Bookmark(
            title: "Newer",
            url: "https://newer.example.com",
            categoryId: category.id,
            addedDate: Date(timeIntervalSince1970: 2)
        )
        try storage.addBookmark(original, updateDuplicateAddedDate: false)
        try storage.addBookmark(newer, updateDuplicateAddedDate: false)

        try storage.addBookmark(original, updateDuplicateAddedDate: true)

        let sorted = CollectionSearch.items(
            in: storage.searchRecordsSnapshot(),
            matching: CollectionSearch.Criteria(order: .newestFirst)
        )
        XCTAssertEqual(sorted.first?.id, original.id)
    }
}
