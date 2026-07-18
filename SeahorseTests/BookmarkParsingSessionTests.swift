import XCTest
@testable import Seahorse

@MainActor
final class BookmarkParsingSessionTests: XCTestCase {
    func testSuccessfulParsingCompletesEveryStepAndPublishesOutput() async throws {
        let resolution = makeResolution()
        let session = BookmarkParsingSession(
            operations: BookmarkParsingOperations(
                fetchWebContent: { _ in ("Fetched title", "Page content") },
                fetchMetadata: { _ in WebMetadata(title: "Metadata title") },
                fetchFavicon: { _ in "https://example.com/favicon.ico" },
                parseContent: { _ in resolution }
            )
        )

        let output = try await session.parse(
            url: "https://example.com",
            categories: [],
            tags: []
        )

        XCTAssertEqual(output.fetchedTitle, "Fetched title")
        XCTAssertEqual(output.metadata?.title, "Metadata title")
        XCTAssertEqual(output.faviconURL, "https://example.com/favicon.ico")
        XCTAssertEqual(session.resolution?.refinedTitle, "AI title")
        XCTAssertTrue(BookmarkParsingStep.allCases.allSatisfy {
            session.status(for: $0).isCompleted
        })
    }

    func testMetadataFailureStillPublishesAIResolution() async throws {
        let session = BookmarkParsingSession(
            operations: BookmarkParsingOperations(
                fetchWebContent: { _ in ("Fetched title", "Page content") },
                fetchMetadata: { _ in throw TestError.metadata },
                fetchFavicon: { _ in nil },
                parseContent: { _ in self.makeResolution() }
            )
        )

        let output = try await session.parse(
            url: "https://example.com",
            categories: [],
            tags: []
        )

        XCTAssertNil(output.metadata)
        XCTAssertEqual(session.resolution?.summary, "AI summary")
        XCTAssertTrue(session.status(for: .readingMetadata).isFailed)
        XCTAssertTrue(session.status(for: .analyzingWithAI).isCompleted)
        XCTAssertTrue(session.status(for: .preparingSuggestions).isCompleted)
    }

    func testResolutionIsPublishedBeforeSlowMetadataFinishes() async throws {
        let session = BookmarkParsingSession(
            operations: BookmarkParsingOperations(
                fetchWebContent: { _ in ("Fetched title", "Page content") },
                fetchMetadata: { _ in
                    try await Task.sleep(nanoseconds: 500_000_000)
                    return WebMetadata(title: "Metadata title")
                },
                fetchFavicon: { _ in nil },
                parseContent: { _ in self.makeResolution() }
            )
        )
        let task = Task {
            try await session.parse(
                url: "https://example.com",
                categories: [],
                tags: []
            )
        }

        for _ in 0..<20 where session.resolution == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(session.resolution?.refinedTitle, "AI title")
        XCTAssertNil(session.output)
        XCTAssertTrue(session.isRunning)
        _ = try await task.value
    }

    func testDetailParsingRequestIsConsumedOnce() {
        let itemId = UUID()
        let state = ItemDetailState()

        state.showItem(itemId, startsAIParsing: true)

        XCTAssertEqual(state.parsingRequestItemId, itemId)
        XCTAssertTrue(state.takeAIParsingRequest(for: itemId))
        XCTAssertFalse(state.takeAIParsingRequest(for: itemId))
    }

    func testAIFailureDoesNotPublishResolutionOrOutput() async {
        let session = BookmarkParsingSession(
            operations: BookmarkParsingOperations(
                fetchWebContent: { _ in ("Fetched title", "Page content") },
                fetchMetadata: { _ in WebMetadata() },
                fetchFavicon: { _ in nil },
                parseContent: { _ in throw TestError.ai }
            )
        )

        do {
            _ = try await session.parse(
                url: "https://example.com",
                categories: [],
                tags: []
            )
            XCTFail("Expected parsing to fail")
        } catch {
            XCTAssertNil(session.resolution)
            XCTAssertNil(session.output)
            XCTAssertTrue(session.status(for: .analyzingWithAI).isFailed)
        }
    }

    func testCancellationDoesNotPublishResolutionOrOutput() async {
        let session = BookmarkParsingSession(
            operations: BookmarkParsingOperations(
                fetchWebContent: { _ in
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    return ("Fetched title", "Page content")
                },
                fetchMetadata: { _ in WebMetadata() },
                fetchFavicon: { _ in nil },
                parseContent: { _ in self.makeResolution() }
            )
        )
        let task = Task {
            try await session.parse(
                url: "https://example.com",
                categories: [],
                tags: []
            )
        }

        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected parsing to be cancelled")
        } catch is CancellationError {
            XCTAssertNil(session.resolution)
            XCTAssertNil(session.output)
            XCTAssertFalse(session.isRunning)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeResolution() -> BookmarkParsingResolution {
        BookmarkParsingResolution(
            refinedTitle: "AI title",
            summary: "AI summary",
            category: nil,
            suggestedNewCategoryName: nil,
            existingTags: [],
            suggestedNewTagNames: ["Swift"],
            suggestedSFSymbol: "link"
        )
    }

    private enum TestError: Error {
        case metadata
        case ai
    }
}
