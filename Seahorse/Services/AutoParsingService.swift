//
//  AutoParsingService.swift
//  Seahorse
//
//  Auto-parses newly added bookmarks when "Auto AI Parsing" is enabled.
//  Fetches metadata first for posters and basic info, then runs AI parsing.
//

import Foundation
import SwiftUI
import OSLog

@MainActor
class AutoParsingService: ObservableObject {
    private let aiManager = AIManager()
    private weak var dataStorage: DataStorage?
    private var isProcessing = false

    /// ID of the bookmark currently being auto-parsed (nil when idle).
    @Published var parsingItemId: UUID?

    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
        Log.info("AutoParsingService: initialized", category: .parsing)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemAdded),
            name: NSNotification.Name("SeahorseItemAdded"),
            object: nil
        )
    }

    @objc private func handleItemAdded() {
        Log.info("AutoParsingService: handleItemAdded fired", category: .parsing)

        let enabled = AISettings.shared.autoParsingEnabled
        Log.info("AutoParsingService: autoParsingEnabled=\(enabled)", category: .parsing)
        guard enabled else { return }

        guard !isProcessing else {
            Log.info("AutoParsingService: skipping, already processing", category: .parsing)
            return
        }
        guard let dataStorage = dataStorage else {
            Log.info("AutoParsingService: skipping, dataStorage is nil", category: .parsing)
            return
        }

        let unparsed = dataStorage.bookmarks
            .filter { !$0.isParsed }
            .sorted { $0.addedDate > $1.addedDate }
        Log.info("AutoParsingService: found \(unparsed.count) unparsed bookmarks", category: .parsing)
        guard let bookmark = unparsed.first else { return }

        isProcessing = true
        parsingItemId = bookmark.id
        Log.info("Auto-parse started for: \(bookmark.url)", category: .parsing)

        Task {
            await parseBookmark(bookmark, dataStorage: dataStorage)
            isProcessing = false
            parsingItemId = nil
        }
    }

    /// Manually trigger AI parsing for a specific bookmark.
    func parseSpecificBookmark(id: UUID) {
        guard !isProcessing else { return }
        guard let dataStorage = dataStorage else { return }
        guard let bookmark = dataStorage.bookmarks.first(where: { $0.id == id }) else { return }

        isProcessing = true
        parsingItemId = bookmark.id
        Log.info("Manual parse started for: \(bookmark.url)", category: .parsing)

        Task {
            await parseBookmark(bookmark, dataStorage: dataStorage)
            isProcessing = false
            parsingItemId = nil
        }
    }

    private func parseBookmark(_ bookmark: Bookmark, dataStorage: DataStorage) async {
        do {
            // Step 1: Fetch OpenGraph metadata for posters and basic info
            var updated = bookmark
            if let url = URL(string: bookmark.url) {
                if let metadata = try? await OpenGraphService.shared.fetchMetadata(url: url) {
                    if updated.title == "Loading..." || updated.title == "Untitled" {
                        updated.title = metadata.title ?? updated.title
                    }
                    if updated.notes == nil, let desc = metadata.description {
                        updated.notes = desc
                    }
                    updated.metadata = metadata
                    if let favicon = metadata.faviconURL {
                        updated.icon = favicon
                    }
                    try dataStorage.updateBookmark(updated)
                    Log.info("Auto-parse: metadata fetched for \(bookmark.url)", category: .parsing)
                }
            }

            // Step 2: AI parsing
            let (content, title) = try await aiManager.fetchWebContent(url: bookmark.url)

            let availableTags = dataStorage.tags.map { $0.name }
            let availableCategories = dataStorage.categories
                .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
                .map { $0.name }

            let parsed = try await aiManager.parseBookmarkContent(
                title: title,
                content: content,
                availableCategories: availableCategories,
                availableTags: availableTags
            )

            let faviconURL = await aiManager.fetchFavicon(url: bookmark.url)

            updated.title = parsed.refinedTitle
            updated.notes = parsed.summary
            updated.isParsed = true

            if let faviconURL = faviconURL {
                updated.icon = faviconURL
            } else if let sf = parsed.suggestedSFSymbol {
                updated.icon = sf
            }

            // Category: must always assign one
            let isGithub = bookmark.url.contains("github.com")
            if isGithub, let github = dataStorage.categories.first(where: { $0.name == "Github" }) {
                updated.categoryId = github.id
            } else if let categoryName = parsed.suggestedCategoryName {
                if let existing = dataStorage.categories.first(where: { $0.name == categoryName }) {
                    updated.categoryId = existing.id
                } else if AISettings.shared.autoParsingCreateCategories {
                    let newCategory = Category(name: categoryName, icon: "folder", color: .blue)
                    try? dataStorage.addCategory(newCategory)
                    updated.categoryId = newCategory.id
                }
            }

            // Tags: use existing, optionally create new
            var tagIds: [UUID] = []
            for tagName in parsed.suggestedTagNames {
                if let existing = dataStorage.tags.first(where: { $0.name == tagName }) {
                    tagIds.append(existing.id)
                } else if AISettings.shared.autoParsingCreateTags {
                    let newTag = Tag(name: tagName, color: .blue)
                    try? dataStorage.addTag(newTag)
                    tagIds.append(newTag.id)
                }
            }
            updated.tagIds = tagIds

            try dataStorage.updateBookmark(updated)
            Log.info("Auto-parse completed for: \(bookmark.url)", category: .parsing)
        } catch {
            Log.error("Auto-parse failed: \(error.localizedDescription)", category: .parsing)
        }
    }
}
