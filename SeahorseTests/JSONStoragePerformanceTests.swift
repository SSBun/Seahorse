import Foundation
import XCTest
@testable import Seahorse

final class JSONStoragePerformanceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testInitializationDoesNotRewriteExistingItemsFile() throws {
        let itemsURL = temporaryDirectory.appendingPathComponent("items.json")
        let originalData = try JSONEncoder().encode([makeItem(title: "Existing")])
        try originalData.write(to: itemsURL)

        _ = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 0.01)
        Thread.sleep(forTimeInterval: 0.05)

        XCTAssertEqual(try Data(contentsOf: itemsURL), originalData)
    }

    func testRapidUpdatesCoalesceToOneWriteAndFlushLatestValue() throws {
        let lock = NSLock()
        var itemWriteCount = 0
        let itemsURL = temporaryDirectory.appendingPathComponent("items.json")
        let storage = JSONStorage(
            dataDirectory: temporaryDirectory,
            saveDelay: 10,
            writeData: { data, url in
                if url.lastPathComponent == "items.json" {
                    lock.lock()
                    itemWriteCount += 1
                    lock.unlock()
                }
                try data.write(to: url, options: .atomic)
            }
        )
        let initial = makeItem(title: "0")
        try storage.saveItem(initial)

        for value in 1...20 {
            var bookmark = try XCTUnwrap(initial.asBookmark)
            bookmark.title = String(value)
            try storage.updateItem(AnyCollectionItem(bookmark))
        }
        storage.forceSaveAllData()

        lock.lock()
        let writes = itemWriteCount
        lock.unlock()
        let saved = try JSONDecoder().decode([AnyCollectionItem].self, from: Data(contentsOf: itemsURL))
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(saved.first?.asBookmark?.title, "20")
    }

    func testBatchUpdateOfOneThousandItemsPersistsOnce() throws {
        let categoryID = UUID()
        let initialItems = (0..<1_000).map { index in
            AnyCollectionItem(Bookmark(
                title: "Item \(index)",
                url: "https://example.com/\(index)",
                categoryId: categoryID
            ))
        }
        try JSONEncoder().encode(initialItems)
            .write(to: temporaryDirectory.appendingPathComponent("items.json"))

        let lock = NSLock()
        var itemWriteCount = 0
        let storage = JSONStorage(
            dataDirectory: temporaryDirectory,
            saveDelay: 10,
            writeData: { data, url in
                if url.lastPathComponent == "items.json" {
                    lock.lock()
                    itemWriteCount += 1
                    lock.unlock()
                }
                try data.write(to: url, options: .atomic)
            }
        )
        let updatedItems = initialItems.map { item -> AnyCollectionItem in
            var bookmark = item.asBookmark!
            bookmark.notes = "updated"
            return AnyCollectionItem(bookmark)
        }

        try storage.updateItems(updatedItems)
        storage.forceSaveAllData()

        lock.lock()
        let writes = itemWriteCount
        lock.unlock()
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(try storage.fetchAllItems().filter { $0.asBookmark?.notes == "updated" }.count, 1_000)
    }

    func testBatchUpdateFailureDoesNotApplyEarlierUpdates() throws {
        let original = makeItem(title: "Original")
        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)
        try storage.saveItem(original)

        var changedBookmark = try XCTUnwrap(original.asBookmark)
        changedBookmark.title = "Changed"
        let missing = AnyCollectionItem(Bookmark(
            title: "Missing",
            url: "https://missing.example.com",
            categoryId: UUID()
        ))

        XCTAssertThrowsError(try storage.updateItems([AnyCollectionItem(changedBookmark), missing]))
        XCTAssertEqual(try storage.fetchAllItems().first?.asBookmark?.title, "Original")
    }

    func testImportRejectsDuplicateCategoryIDsBeforeMutation() throws {
        let category = Category(name: "Existing", icon: "folder", color: .blue)
        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)
        try storage.saveCategory(category)
        let duplicateID = Category(id: category.id, name: "Different", icon: "star", color: .red)

        XCTAssertThrowsError(try storage.saveImportedData(categories: [duplicateID], tags: [], items: []))
        XCTAssertEqual(try storage.fetchAllCategories().filter { $0.id == category.id }.count, 1)
    }

    private func makeItem(title: String) -> AnyCollectionItem {
        AnyCollectionItem(Bookmark(title: title, url: "https://example.com", categoryId: UUID()))
    }
}
