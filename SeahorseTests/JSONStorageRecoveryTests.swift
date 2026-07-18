import Foundation
import XCTest
@testable import Seahorse

final class JSONStorageRecoveryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testCorruptPrimaryFileRestoresWholeLastGoodSnapshot() throws {
        let primaryCategory = Seahorse.Category(name: "Primary", icon: "folder", color: .blue)
        let recoveredCategory = Seahorse.Category(name: "Recovered", icon: "archivebox", color: .green)
        let recoveredItem = AnyCollectionItem(Bookmark(
            title: "Recovered bookmark",
            url: "https://example.com/recovered",
            categoryId: recoveredCategory.id
        ))
        try write([primaryCategory], to: "categories.json")
        let corruptData = Data("{not-json".utf8)
        try corruptData.write(to: url("items.json"))
        try writeSnapshot(categories: [recoveredCategory], items: [recoveredItem])

        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)

        XCTAssertEqual(storage.recoveryState, .recovered)
        XCTAssertEqual(try storage.fetchAllCategories().map(\.id), [recoveredCategory.id])
        XCTAssertEqual(try storage.fetchAllItems().map(\.id), [recoveredItem.id])
        let persistedItems = try JSONDecoder().decode(
            [AnyCollectionItem].self,
            from: Data(contentsOf: url("items.json"))
        )
        XCTAssertEqual(persistedItems.map(\.id), [recoveredItem.id])
        let preservedURL = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
                .first { $0.lastPathComponent.hasPrefix("items.json.corrupt-") }
        )
        XCTAssertEqual(try Data(contentsOf: preservedURL), corruptData)
    }

    func testCorruptPrimaryAndSnapshotRejectWritesWithoutOverwritingSource() throws {
        let category = Seahorse.Category(name: "Primary", icon: "folder", color: .blue)
        try write([category], to: "categories.json")
        let corruptData = Data("{not-json".utf8)
        try corruptData.write(to: url("items.json"))
        try Data("{also-not-json".utf8).write(to: url("last-good.json"))

        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)

        XCTAssertEqual(storage.recoveryState, .readOnly)
        XCTAssertThrowsError(try storage.savePreference(key: "unsafe", value: "write"))
        storage.forceSaveAllData()
        XCTAssertEqual(try Data(contentsOf: url("items.json")), corruptData)
    }

    func testValidPrimaryDataRefreshesLastGoodSnapshot() throws {
        let category = Seahorse.Category(name: "Primary", icon: "folder", color: .blue)
        let item = AnyCollectionItem(Bookmark(
            title: "Primary bookmark",
            url: "https://example.com/primary",
            categoryId: category.id
        ))
        try write([category], to: "categories.json")
        try write([item], to: "items.json")

        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)

        XCTAssertEqual(storage.recoveryState, .normal)
        let snapshot = try JSONDecoder().decode(
            TestStorageSnapshot.self,
            from: Data(contentsOf: url("last-good.json"))
        )
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.categories.map(\.id), [category.id])
        XCTAssertEqual(snapshot.items.map(\.id), [item.id])
    }

    func testInterruptedRecoveryRetriesTheLastGoodSnapshot() throws {
        let primaryCategory = Seahorse.Category(name: "Primary", icon: "folder", color: .blue)
        let recoveredCategory = Seahorse.Category(name: "Recovered", icon: "archivebox", color: .green)
        let primaryItem = AnyCollectionItem(Bookmark(
            title: "Primary bookmark",
            url: "https://example.com/primary",
            categoryId: primaryCategory.id
        ))
        let recoveredItem = AnyCollectionItem(Bookmark(
            title: "Recovered bookmark",
            url: "https://example.com/recovered",
            categoryId: recoveredCategory.id
        ))
        try write([primaryCategory], to: "categories.json")
        try write([primaryItem], to: "items.json")
        try writeSnapshot(categories: [recoveredCategory], items: [recoveredItem])
        try Data("recovery".utf8).write(to: url("recovery-in-progress"))

        let storage = JSONStorage(dataDirectory: temporaryDirectory, saveDelay: 10)

        XCTAssertEqual(storage.recoveryState, .recovered)
        XCTAssertEqual(try storage.fetchAllCategories().map(\.id), [recoveredCategory.id])
        XCTAssertEqual(try storage.fetchAllItems().map(\.id), [recoveredItem.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url("recovery-in-progress").path))
    }

    private func write<Value: Encodable>(_ value: Value, to filename: String) throws {
        try JSONEncoder().encode(value).write(to: url(filename), options: .atomic)
    }

    private func writeSnapshot(categories: [Seahorse.Category], items: [AnyCollectionItem]) throws {
        try write(
            TestStorageSnapshot(
                schemaVersion: 1,
                items: items,
                categories: categories,
                tags: [],
                smartCollections: [],
                preferences: [:]
            ),
            to: "last-good.json"
        )
    }

    private func url(_ filename: String) -> URL {
        temporaryDirectory.appendingPathComponent(filename)
    }
}

private struct TestStorageSnapshot: Codable {
    let schemaVersion: Int
    let items: [AnyCollectionItem]
    let categories: [Seahorse.Category]
    let tags: [Tag]
    let smartCollections: [SmartCollection]
    let preferences: [String: String]
}
