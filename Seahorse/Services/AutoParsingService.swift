import Foundation
import OSLog

@MainActor
final class AutoParsingService: ObservableObject {
    typealias MetadataLoader = (URL) async throws -> WebMetadata

    private enum EnrichmentError: Error {
        case itemUnavailable
        case sourceChanged
    }

    private let aiManager = AIManager()
    private let metadataLoader: MetadataLoader
    private weak var dataStorage: DataStorage?
    private var pendingIDs: [UUID] = []
    private var pendingIDSet = Set<UUID>()
    private var forcedAIIDs = Set<UUID>()
    private var failedAIIDs = Set<UUID>()
    private var workerTask: Task<Void, Never>?

    @Published private(set) var parsingItemId: UUID?
    @Published private(set) var statuses: [UUID: BookmarkEnrichmentStatus] = [:]
    @Published private(set) var failureMessages: [UUID: String] = [:]

    init(
        dataStorage: DataStorage,
        metadataLoader: @escaping MetadataLoader = { url in
            try await OpenGraphService.shared.fetchMetadata(url: url)
        },
        observesNotifications: Bool = true
    ) {
        self.dataStorage = dataStorage
        self.metadataLoader = metadataLoader

        if observesNotifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleItemAdded(_:)),
                name: NSNotification.Name("SeahorseItemAdded"),
                object: nil
            )
        }

        restorePersistedState()
        Log.info("AutoParsingService: initialized with \(pendingIDs.count) queued bookmark(s)", category: .parsing)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        workerTask?.cancel()
    }

    var failedBookmarkIDs: [UUID] {
        statuses.compactMap { $0.value == .failed ? $0.key : nil }
    }

    func status(for id: UUID) -> BookmarkEnrichmentStatus? {
        statuses[id]
    }

    func failureMessage(for id: UUID) -> String? {
        failureMessages[id]
    }

    @objc private func handleItemAdded(_ notification: Notification) {
        if let id = notification.object as? UUID {
            enqueueBookmark(id: id)
        } else {
            enqueuePersistedBacklog()
        }
    }

    func enqueueBookmark(id: UUID, forceAI: Bool = false) {
        guard let bookmark = dataStorage?.item(for: id)?.asBookmark else { return }
        let requiresMetadata = bookmark.metadata == nil
        let requiresAI = forceAI || (AISettings.shared.autoParsingEnabled && !bookmark.isParsed)
        guard requiresMetadata || requiresAI else {
            clearStatus(for: id)
            return
        }

        if forceAI {
            forcedAIIDs.insert(id)
        }
        if pendingIDSet.insert(id).inserted {
            pendingIDs.append(id)
        }
        setStatus(.pending, error: nil, for: id)
        startWorkerIfNeeded()
    }

    /// Manually requests metadata plus AI parsing for a bookmark.
    func parseSpecificBookmark(id: UUID) {
        enqueueBookmark(id: id, forceAI: true)
    }

    func retryBookmark(id: UUID) {
        let forceAI = failedAIIDs.contains(id)
        failureMessages.removeValue(forKey: id)
        enqueueBookmark(id: id, forceAI: forceAI)
    }

    private func restorePersistedState() {
        guard let dataStorage else { return }
        for bookmark in dataStorage.bookmarks {
            switch bookmark.enrichmentStatus {
            case .failed:
                statuses[bookmark.id] = .failed
                failureMessages[bookmark.id] = bookmark.enrichmentError
                if !bookmark.isParsed && AISettings.shared.autoParsingEnabled {
                    failedAIIDs.insert(bookmark.id)
                }
            case .pending, .fetchingMetadata, .parsingWithAI:
                if pendingIDSet.insert(bookmark.id).inserted {
                    pendingIDs.append(bookmark.id)
                }
                statuses[bookmark.id] = .pending
            case .none:
                if !bookmark.isParsed && AISettings.shared.autoParsingEnabled {
                    pendingIDSet.insert(bookmark.id)
                    pendingIDs.append(bookmark.id)
                    statuses[bookmark.id] = .pending
                }
            }
        }
        if !pendingIDs.isEmpty {
            startWorkerIfNeeded()
        }
    }

    private func enqueuePersistedBacklog() {
        guard let dataStorage else { return }
        for bookmark in dataStorage.bookmarks {
            let status = bookmark.enrichmentStatus
            if status == .failed {
                statuses[bookmark.id] = .failed
                failureMessages[bookmark.id] = bookmark.enrichmentError
                if !bookmark.isParsed && AISettings.shared.autoParsingEnabled {
                    failedAIIDs.insert(bookmark.id)
                }
                continue
            }
            guard status == .pending || status == .fetchingMetadata || status == .parsingWithAI else {
                continue
            }
            enqueueBookmark(id: bookmark.id)
        }
    }

    private func startWorkerIfNeeded() {
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        while !pendingIDs.isEmpty, !Task.isCancelled {
            let id = pendingIDs.removeFirst()
            pendingIDSet.remove(id)
            let forceAI = forcedAIIDs.remove(id) != nil
            guard let bookmark = dataStorage?.item(for: id)?.asBookmark else {
                clearStatus(for: id)
                continue
            }
            let runAI = forceAI || (AISettings.shared.autoParsingEnabled && !bookmark.isParsed)
            parsingItemId = id

            do {
                try await enrichBookmark(id: id, runAI: runAI)
                failedAIIDs.remove(id)
                clearStatus(for: id)
            } catch EnrichmentError.itemUnavailable {
                clearStatus(for: id)
            } catch EnrichmentError.sourceChanged {
                clearStatus(for: id)
                enqueueBookmark(id: id, forceAI: runAI)
            } catch {
                if runAI {
                    failedAIIDs.insert(id)
                } else {
                    failedAIIDs.remove(id)
                }
                setStatus(.failed, error: error.localizedDescription, for: id)
                Log.error("Bookmark enrichment failed: \(error.localizedDescription)", category: .parsing)
            }
            parsingItemId = nil
        }
        workerTask = nil
    }

    private func enrichBookmark(id: UUID, runAI: Bool) async throws {
        guard let initial = dataStorage?.item(for: id)?.asBookmark else {
            throw EnrichmentError.itemUnavailable
        }
        let sourceURL = BookmarkURLNormalizer.normalize(initial.url)

        if initial.metadata == nil {
            setStatus(.fetchingMetadata, error: nil, for: id)
            guard let url = URL(string: sourceURL) else { throw URLError(.badURL) }
            do {
                let metadata = try await metadataLoader(url)
                guard var latest = dataStorage?.item(for: id)?.asBookmark else {
                    throw EnrichmentError.itemUnavailable
                }
                guard BookmarkURLNormalizer.normalize(latest.url) == sourceURL else {
                    throw EnrichmentError.sourceChanged
                }
                if latest.title == "Loading..." || latest.title == "Untitled" || latest.title.isEmpty {
                    latest.title = metadata.title ?? url.host ?? latest.title
                }
                if latest.notes == nil {
                    latest.notes = metadata.description
                }
                latest.metadata = metadata
                if let favicon = metadata.faviconURL {
                    latest.icon = favicon
                }
                latest.enrichmentStatus = .fetchingMetadata
                latest.enrichmentError = nil
                try dataStorage?.updateBookmark(latest)
            } catch let error as EnrichmentError {
                throw error
            } catch {
                updateFallbackTitle(for: id, sourceURL: sourceURL)
                throw error
            }
        }

        guard runAI else { return }
        setStatus(.parsingWithAI, error: nil, for: id)
        guard let bookmark = dataStorage?.item(for: id)?.asBookmark else {
            throw EnrichmentError.itemUnavailable
        }
        let (fetchedTitle, content) = try await aiManager.fetchWebContent(url: bookmark.url)
        let availableTags = dataStorage?.tags.map(\.name) ?? []
        let availableCategories = dataStorage?.categories
            .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
            .map(\.name) ?? []
        let parsed = try await aiManager.parseBookmarkContent(
            title: fetchedTitle,
            content: content,
            availableCategories: availableCategories,
            availableTags: availableTags
        )
        let faviconURL = await aiManager.fetchFavicon(url: bookmark.url)

        guard var latest = dataStorage?.item(for: id)?.asBookmark else {
            throw EnrichmentError.itemUnavailable
        }
        guard BookmarkURLNormalizer.normalize(latest.url) == sourceURL else {
            throw EnrichmentError.sourceChanged
        }
        latest.title = parsed.refinedTitle
        latest.notes = parsed.summary
        latest.isParsed = true
        latest.enrichmentStatus = .parsingWithAI
        latest.enrichmentError = nil
        if let faviconURL {
            latest.icon = faviconURL
        } else if let symbol = parsed.suggestedSFSymbol {
            latest.icon = symbol
        }

        if sourceURL.contains("github.com"),
           let github = dataStorage?.categories.first(where: { $0.name == "Github" }) {
            latest.categoryId = github.id
        } else if let categoryName = parsed.suggestedCategoryName {
            if let existing = dataStorage?.categories.first(where: { $0.name == categoryName }) {
                latest.categoryId = existing.id
            } else if AISettings.shared.autoParsingCreateCategories {
                let category = Category(name: categoryName, icon: "folder", color: .blue)
                try dataStorage?.addCategory(category)
                latest.categoryId = category.id
            }
        }

        var tagIDs: [UUID] = []
        for tagName in parsed.suggestedTagNames {
            if let existing = dataStorage?.tags.first(where: { $0.name == tagName }) {
                tagIDs.append(existing.id)
            } else if AISettings.shared.autoParsingCreateTags {
                let tag = Tag(name: tagName, color: .blue)
                try dataStorage?.addTag(tag)
                tagIDs.append(tag.id)
            }
        }
        latest.tagIds = tagIDs
        try dataStorage?.updateBookmark(latest)
    }

    private func updateFallbackTitle(for id: UUID, sourceURL: String) {
        guard var latest = dataStorage?.item(for: id)?.asBookmark,
              latest.title == "Loading..." || latest.title.isEmpty else {
            return
        }
        latest.title = URL(string: sourceURL)?.host ?? sourceURL
        try? dataStorage?.updateBookmark(latest)
    }

    private func setStatus(_ status: BookmarkEnrichmentStatus, error: String?, for id: UUID) {
        statuses[id] = status
        if let error {
            failureMessages[id] = error
        } else {
            failureMessages.removeValue(forKey: id)
        }
        guard var bookmark = dataStorage?.item(for: id)?.asBookmark else { return }
        guard bookmark.enrichmentStatus != status || bookmark.enrichmentError != error else { return }
        bookmark.enrichmentStatus = status
        bookmark.enrichmentError = error
        try? dataStorage?.updateBookmark(bookmark)
    }

    private func clearStatus(for id: UUID) {
        statuses.removeValue(forKey: id)
        failureMessages.removeValue(forKey: id)
        guard var bookmark = dataStorage?.item(for: id)?.asBookmark else { return }
        guard bookmark.enrichmentStatus != nil || bookmark.enrichmentError != nil else { return }
        bookmark.enrichmentStatus = nil
        bookmark.enrichmentError = nil
        try? dataStorage?.updateBookmark(bookmark)
    }
}
