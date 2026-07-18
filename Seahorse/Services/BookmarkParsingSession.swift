import Combine
import Foundation

struct BookmarkParsingOperations {
    let fetchWebContent: (String) async throws -> (title: String, content: String)
    let fetchMetadata: (URL) async throws -> WebMetadata
    let fetchFavicon: (String) async -> String?
    let parseContent: (BookmarkParsingInput) async throws -> BookmarkParsingResolution

    static func live() -> BookmarkParsingOperations {
        let aiManager = AIManager()
        return BookmarkParsingOperations(
            fetchWebContent: aiManager.fetchWebContent,
            fetchMetadata: OpenGraphService.shared.fetchMetadata,
            fetchFavicon: aiManager.fetchFavicon,
            parseContent: aiManager.parseBookmarkContent
        )
    }
}

enum BookmarkParsingStep: CaseIterable, Identifiable {
    case fetchingWebpage
    case readingMetadata
    case analyzingWithAI
    case preparingSuggestions

    var id: Self { self }

    var title: String {
        switch self {
        case .fetchingWebpage: return "Fetching webpage"
        case .readingMetadata: return "Reading metadata"
        case .analyzingWithAI: return "Analyzing with AI"
        case .preparingSuggestions: return "Preparing suggestions"
        }
    }
}

enum BookmarkParsingStepStatus: Equatable {
    case pending
    case running
    case completed(String?)
    case failed(String)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

struct BookmarkParsingSessionOutput {
    let fetchedTitle: String
    let resolution: BookmarkParsingResolution
    let faviconURL: String?
    let metadata: WebMetadata?
}

@MainActor
final class BookmarkParsingSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var hasStarted = false
    @Published private(set) var resolution: BookmarkParsingResolution?
    @Published private(set) var output: BookmarkParsingSessionOutput?
    @Published private var statuses: [BookmarkParsingStep: BookmarkParsingStepStatus] = [:]

    private let operations: BookmarkParsingOperations

    init(operations: BookmarkParsingOperations = .live()) {
        self.operations = operations
        reset()
    }

    func status(for step: BookmarkParsingStep) -> BookmarkParsingStepStatus {
        statuses[step] ?? .pending
    }

    func parse(
        url: String,
        categories: [Category],
        tags: [Tag]
    ) async throws -> BookmarkParsingSessionOutput {
        reset()
        hasStarted = true
        isRunning = true

        do {
            statuses[.fetchingWebpage] = .running
            let page = try await operations.fetchWebContent(url)
            try Task.checkCancellation()
            statuses[.fetchingWebpage] = .completed(page.title)

            guard let pageURL = URL(string: url) else {
                throw URLError(.badURL)
            }

            statuses[.readingMetadata] = .running
            let metadataTask = Task {
                do {
                    return MetadataAttempt.success(try await operations.fetchMetadata(pageURL))
                } catch {
                    return MetadataAttempt.failure(error.localizedDescription)
                }
            }
            let faviconTask = Task {
                await operations.fetchFavicon(url)
            }

            statuses[.analyzingWithAI] = .running
            let parsedResolution: BookmarkParsingResolution
            do {
                parsedResolution = try await operations.parseContent(
                    BookmarkParsingInput(
                        url: url,
                        title: page.title,
                        content: page.content,
                        categories: categories,
                        tags: tags
                    )
                )
                try Task.checkCancellation()
            } catch {
                metadataTask.cancel()
                faviconTask.cancel()
                if error is CancellationError {
                    throw error
                }
                statuses[.analyzingWithAI] = .failed(error.localizedDescription)
                throw error
            }

            resolution = parsedResolution
            statuses[.analyzingWithAI] = .completed("Suggestions received")

            let metadataAttempt = await metadataTask.value
            let faviconURL = await faviconTask.value
            try Task.checkCancellation()

            let metadata: WebMetadata?
            switch metadataAttempt {
            case .success(let value):
                metadata = value
                statuses[.readingMetadata] = .completed(value.siteName ?? value.title)
            case .failure(let message):
                metadata = nil
                statuses[.readingMetadata] = .failed(message)
            }

            statuses[.preparingSuggestions] = .running
            let parsedOutput = BookmarkParsingSessionOutput(
                fetchedTitle: page.title,
                resolution: parsedResolution,
                faviconURL: faviconURL,
                metadata: metadata
            )
            output = parsedOutput
            statuses[.preparingSuggestions] = .completed("Ready to review")
            isRunning = false
            return parsedOutput
        } catch is CancellationError {
            resolution = nil
            output = nil
            isRunning = false
            throw CancellationError()
        } catch {
            if status(for: .fetchingWebpage) == .running {
                statuses[.fetchingWebpage] = .failed(error.localizedDescription)
            }
            resolution = nil
            output = nil
            isRunning = false
            throw error
        }
    }

    func reset() {
        statuses = Dictionary(
            uniqueKeysWithValues: BookmarkParsingStep.allCases.map { ($0, .pending) }
        )
        hasStarted = false
        isRunning = false
        resolution = nil
        output = nil
    }

    private enum MetadataAttempt {
        case success(WebMetadata)
        case failure(String)
    }
}
