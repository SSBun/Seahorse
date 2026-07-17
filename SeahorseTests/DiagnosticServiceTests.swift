import XCTest
@testable import Seahorse

@MainActor
final class DiagnosticServiceTests: XCTestCase {
    func testHeadMethodNotAllowedFallsBackToGet() async throws {
        let storage = DataStorage(database: MockDatabase())
        let bookmark = makeBookmark(storage: storage)
        let recorder = RequestRecorder(headStatusCode: 405, getStatusCode: 200)
        let service = DiagnosticService(
            dataStorage: storage,
            requestLoader: { request in try await recorder.load(request) }
        )

        service.start(bookmarks: [bookmark])
        try await waitUntil { !service.isRunning && service.checkedCount == 1 }

        let methods = await recorder.methods
        XCTAssertEqual(methods, ["HEAD", "GET"])
        XCTAssertEqual(service.results.first?.status, .accessible)
        XCTAssertTrue(service.brokenBookmarks.isEmpty)
        XCTAssertTrue(service.unverifiedBookmarks.isEmpty)
    }

    func testOnlyGoneIsClassifiedAsBroken() {
        XCTAssertEqual(
            DiagnosticService.status(forHTTPStatusCode: 410),
            .broken(reason: "Gone (410)")
        )

        for statusCode in [401, 403, 404, 429, 500, 503] {
            guard case .unverified = DiagnosticService.status(forHTTPStatusCode: statusCode) else {
                return XCTFail("Expected HTTP \(statusCode) to be unverified")
            }
        }
    }

    func testTimeoutIsUnverifiedInsteadOfBroken() async throws {
        let storage = DataStorage(database: MockDatabase())
        let bookmark = makeBookmark(storage: storage)
        let service = DiagnosticService(
            dataStorage: storage,
            requestLoader: { _ in throw URLError(.timedOut) }
        )

        service.start(bookmarks: [bookmark])
        try await waitUntil { !service.isRunning && service.checkedCount == 1 }

        XCTAssertTrue(service.brokenBookmarks.isEmpty)
        XCTAssertEqual(service.unverifiedBookmarks.count, 1)
        XCTAssertEqual(service.unverifiedBookmarks.first?.status, .unverified(reason: "Timeout"))
    }

    private func makeBookmark(storage: DataStorage) -> Bookmark {
        Bookmark(
            title: "Example",
            url: "https://example.com",
            categoryId: storage.categories[0].id
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping () -> Bool
    ) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        while !condition() {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                XCTFail("Timed out waiting for diagnostic completion")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor RequestRecorder {
    private let headStatusCode: Int
    private let getStatusCode: Int
    private(set) var methods: [String] = []

    init(headStatusCode: Int, getStatusCode: Int) {
        self.headStatusCode = headStatusCode
        self.getStatusCode = getStatusCode
    }

    func load(_ request: URLRequest) throws -> (Data, URLResponse) {
        let method = request.httpMethod ?? "GET"
        methods.append(method)
        let statusCode = method == "HEAD" ? headStatusCode : getStatusCode
        guard let url = request.url,
              let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else {
            throw URLError(.badURL)
        }
        return (Data(), response)
    }
}
