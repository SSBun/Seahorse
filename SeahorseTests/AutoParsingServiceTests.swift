import Foundation
import XCTest
@testable import Seahorse

@MainActor
final class AutoParsingServiceTests: XCTestCase {
    func testQueueDrainsPersistedBacklogWithoutDroppingNewWork() async throws {
        let originalSetting = AISettings.shared.autoParsingEnabled
        AISettings.shared.autoParsingEnabled = false
        defer { AISettings.shared.autoParsingEnabled = originalSetting }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let loader = MetadataLoaderStub(delayNanoseconds: 50_000_000)
        let first = bookmark("first", categoryID: category.id)
        try storage.addBookmark(first)
        let service = AutoParsingService(
            dataStorage: storage,
            metadataLoader: { try await loader.load($0) },
            observesNotifications: false
        )

        try await waitUntil { await loader.callCount == 1 }
        let second = bookmark("second", categoryID: category.id)
        let third = bookmark("third", categoryID: category.id)
        try storage.addBookmark(second)
        try storage.addBookmark(third)
        service.enqueueBookmark(id: second.id)
        service.enqueueBookmark(id: third.id)

        try await waitUntil {
            storage.bookmarks.allSatisfy { $0.metadata != nil && $0.enrichmentStatus == nil }
                && storage.bookmarks.count == 3
        }
        let loadedCount = await loader.callCount
        XCTAssertEqual(loadedCount, 3)
        XCTAssertNil(service.parsingItemId)
    }

    func testMetadataMergeUsesLatestBookmarkSnapshot() async throws {
        let originalSetting = AISettings.shared.autoParsingEnabled
        AISettings.shared.autoParsingEnabled = false
        defer { AISettings.shared.autoParsingEnabled = originalSetting }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let loader = MetadataLoaderStub(delayNanoseconds: 80_000_000)
        let original = bookmark("merge", categoryID: category.id)
        try storage.addBookmark(original)
        let service = AutoParsingService(
            dataStorage: storage,
            metadataLoader: { try await loader.load($0) },
            observesNotifications: false
        )
        try await waitUntil { await loader.callCount == 1 }

        var edited = try XCTUnwrap(storage.item(for: original.id)?.asBookmark)
        edited.isFavorite = true
        edited.notes = "User note"
        try storage.updateBookmark(edited)

        try await waitUntil { storage.item(for: original.id)?.asBookmark?.enrichmentStatus == nil }
        let result = try XCTUnwrap(storage.item(for: original.id)?.asBookmark)
        XCTAssertTrue(result.isFavorite)
        XCTAssertEqual(result.notes, "User note")
        XCTAssertNotNil(result.metadata)
        XCTAssertTrue(service.failedBookmarkIDs.isEmpty)
    }

    func testFailureIsPersistedAndRetrySucceeds() async throws {
        let originalSetting = AISettings.shared.autoParsingEnabled
        AISettings.shared.autoParsingEnabled = false
        defer { AISettings.shared.autoParsingEnabled = originalSetting }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let loader = MetadataLoaderStub(failFirstRequest: true)
        let original = bookmark("retry", categoryID: category.id)
        try storage.addBookmark(original)
        let service = AutoParsingService(
            dataStorage: storage,
            metadataLoader: { try await loader.load($0) },
            observesNotifications: false
        )

        try await waitUntil { service.status(for: original.id) == .failed }
        let failed = try XCTUnwrap(storage.item(for: original.id)?.asBookmark)
        XCTAssertEqual(failed.enrichmentStatus, .failed)
        XCTAssertNotNil(failed.enrichmentError)

        service.retryBookmark(id: original.id)
        try await waitUntil {
            storage.item(for: original.id)?.asBookmark?.metadata != nil
                && service.status(for: original.id) == nil
        }
        let recovered = try XCTUnwrap(storage.item(for: original.id)?.asBookmark)
        XCTAssertNil(recovered.enrichmentStatus)
        XCTAssertNil(recovered.enrichmentError)
        let loadedCount = await loader.callCount
        XCTAssertEqual(loadedCount, 2)
    }

    func testURLChangeDuringFetchRequeuesInsteadOfApplyingStaleMetadata() async throws {
        let originalSetting = AISettings.shared.autoParsingEnabled
        AISettings.shared.autoParsingEnabled = false
        defer { AISettings.shared.autoParsingEnabled = originalSetting }

        let storage = DataStorage(database: MockDatabase())
        let category = try XCTUnwrap(storage.categories.first)
        let loader = MetadataLoaderStub(delayNanoseconds: 80_000_000)
        let original = bookmark("old", categoryID: category.id)
        try storage.addBookmark(original)
        let service = AutoParsingService(
            dataStorage: storage,
            metadataLoader: { try await loader.load($0) },
            observesNotifications: false
        )
        try await waitUntil { await loader.callCount == 1 }

        var edited = try XCTUnwrap(storage.item(for: original.id)?.asBookmark)
        edited.url = "https://new.example.com"
        try storage.updateBookmark(edited)

        try await waitUntil {
            storage.item(for: original.id)?.asBookmark?.metadata?.title == "new.example.com"
                && service.status(for: original.id) == nil
        }
        let loadedCount = await loader.callCount
        XCTAssertEqual(loadedCount, 2)
    }

    private func bookmark(_ host: String, categoryID: UUID) -> Bookmark {
        Bookmark(
            title: "Loading...",
            url: "https://\(host).example.com",
            categoryId: categoryID
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping () async -> Bool
    ) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        while !(await condition()) {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                XCTFail("Timed out waiting for asynchronous condition")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor MetadataLoaderStub {
    private let delayNanoseconds: UInt64
    private var failFirstRequest: Bool
    private(set) var callCount = 0

    init(delayNanoseconds: UInt64 = 0, failFirstRequest: Bool = false) {
        self.delayNanoseconds = delayNanoseconds
        self.failFirstRequest = failFirstRequest
    }

    func load(_ url: URL) async throws -> WebMetadata {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if failFirstRequest {
            failFirstRequest = false
            throw URLError(.timedOut)
        }
        return WebMetadata(
            title: url.host,
            description: "Metadata for \(url.host ?? "unknown")",
            url: url.absoluteString,
            faviconURL: url.appendingPathComponent("favicon.ico").absoluteString
        )
    }
}
