//
//  BatchParsingService.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//
//  Concurrent bookmark parsing with up to 5 parallel workers
//  Uses Swift's TaskGroup for safe concurrency and an Actor for thread-safe state management

import Foundation
import SwiftUI
import OSLog

private struct BatchParsingOutput {
    let bookmarkID: UUID
    let resolution: BookmarkParsingResolution
    let preferredIcon: String?
}

@MainActor
class BatchParsingService: ObservableObject {
    @Published var isRunning = false
    @Published var currentBookmark: Bookmark?
    @Published var progress: Double = 0
    @Published var totalCount: Int = 0
    @Published var completedCount: Int = 0
    
    private var task: Task<Void, Never>?
    private let aiManager = AIManager()
    private weak var dataStorage: DataStorage?
    
    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }
    
    func start() {
        guard !isRunning, let dataStorage = dataStorage else { return }

        // Get unparsed bookmarks
        let unparsedBookmarks = dataStorage.bookmarks.filter {
            !$0.isParsed && $0.enrichmentStatus == nil
        }
        guard !unparsedBookmarks.isEmpty else { return }

        isRunning = true
        totalCount = unparsedBookmarks.count
        completedCount = 0
        progress = 0

        Log.info("🚀 Starting concurrent bookmark parsing", category: .parsing)
        Log.info("  📊 Unparsed bookmarks: \(unparsedBookmarks.count)", category: .parsing)
        Log.info("  ⚡️ Concurrent workers: 5", category: .parsing)

        let startTime = Date()

        task = Task {
            await performConcurrentParsing(bookmarks: unparsedBookmarks, dataStorage: dataStorage)
            finishTask(startTime: startTime, originalCount: unparsedBookmarks.count)
        }
    }

    /// Start batch parsing with a specific set of bookmarks
    func start(bookmarks: [Bookmark]) {
        guard !isRunning, let dataStorage = dataStorage else { return }
        let bookmarks = bookmarks.filter { bookmark in
            dataStorage.item(for: bookmark.id)?.asBookmark?.enrichmentStatus == nil
        }
        guard !bookmarks.isEmpty else { return }

        isRunning = true
        totalCount = bookmarks.count
        completedCount = 0
        progress = 0

        Log.info("🚀 Starting batch operation", category: .parsing)
        Log.info("  📊 Selected bookmarks: \(bookmarks.count)", category: .parsing)

        let startTime = Date()

        task = Task {
            await performConcurrentParsing(bookmarks: bookmarks, dataStorage: dataStorage)
            finishTask(startTime: startTime, originalCount: bookmarks.count)
        }
    }

    private func finishTask(startTime: Date, originalCount: Int) {
        let duration = Date().timeIntervalSince(startTime)
        Log.info("✅ Batch operation complete", category: .parsing)
        Log.info("  ⏱️ Duration: \(String(format: "%.2f", duration)) seconds", category: .parsing)
        Log.info("  ✨ Successfully parsed: \(self.completedCount)/\(self.totalCount)", category: .parsing)

        Task { @MainActor in
            self.isRunning = false
            self.currentBookmark = nil
        }
    }

    /// Perform concurrent parsing using TaskGroup with 5 parallel workers
    private func performConcurrentParsing(bookmarks: [Bookmark], dataStorage: DataStorage) async {
        let maxConcurrentTasks = 5
        var bookmarkIndex = 0
        var succeeded = 0
        var failed = 0
        var parsingOutputs: [BatchParsingOutput] = []
        let categories = dataStorage.categories
            .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
        let tags = dataStorage.tags
        
        await withTaskGroup(of: (Int, Result<BatchParsingOutput, Error>).self) { group in
            // Start initial batch of concurrent tasks
            for i in 0..<min(maxConcurrentTasks, bookmarks.count) {
                group.addTask {
                    let result = await self.parseBookmark(
                        bookmarks[i],
                        categories: categories,
                        tags: tags
                    )
                    return (i, result)
                }
            }
            bookmarkIndex = min(maxConcurrentTasks, bookmarks.count)
            
            // Process results and spawn new tasks
            for await (_, result) in group {
                // Check for cancellation
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }
                
                guard await MainActor.run(body: { self.isRunning }) else {
                    group.cancelAll()
                    break
                }
                
                // Collect successful results for one database commit after parsing.
                switch result {
                case .success(let output):
                    parsingOutputs.append(output)
                    succeeded += 1
                    
                case .failure(let error):
                    Log.error("Failed to parse bookmark: \(error)", category: .parsing)
                    failed += 1
                }
                
                completedCount = succeeded + failed
                progress = Double(completedCount) / Double(totalCount)
                
                // Spawn next task if there are more bookmarks to parse
                if bookmarkIndex < bookmarks.count {
                    let nextIndex = bookmarkIndex
                    bookmarkIndex += 1
                    
                    group.addTask {
                        // Small staggered delay to avoid overwhelming API
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        let result = await self.parseBookmark(
                            bookmarks[nextIndex],
                            categories: categories,
                            tags: tags
                        )
                        return (nextIndex, result)
                    }
                    
                    // Update current bookmark for UI display
                    currentBookmark = bookmarks[nextIndex]
                }
            }
        }

        let liveBookmarks = parsingOutputs.compactMap { output -> AnyCollectionItem? in
            guard let latest = dataStorage.item(for: output.bookmarkID)?.asBookmark,
                  latest.enrichmentStatus == nil else {
                return nil
            }
            let newTagIDs: [UUID]
            do {
                newTagIDs = try latest.tagIds.isEmpty && AISettings.shared.autoParsingCreateTags
                    ? dataStorage.createTagsIfNeeded(named: output.resolution.suggestedNewTagNames)
                    : []
            } catch {
                Log.error("Failed to create parsed bookmark tags: \(error)", category: .parsing)
                return nil
            }
            var updated = output.resolution.bookmark(
                fillingMissingValuesIn: latest,
                unclassifiedCategoryID: dataStorage.category(named: "None")?.id,
                newTagIDs: newTagIDs
            )
            if (updated.icon == "link.circle.fill" || updated.icon.isEmpty),
               let preferredIcon = output.preferredIcon {
                updated.icon = preferredIcon
            }
            return AnyCollectionItem(updated)
        }
        guard !liveBookmarks.isEmpty else { return }
        do {
            try dataStorage.updateItems(liveBookmarks)
        } catch {
            Log.error("Failed to save parsed bookmarks: \(error)", category: .parsing)
        }
    }
    
    /// Parse a single bookmark (extracted for concurrent processing)
    private func parseBookmark(
        _ bookmark: Bookmark,
        categories: [Category],
        tags: [Tag]
    ) async -> Result<BatchParsingOutput, Error> {
        do {
            // Fetch web content
            let (title, content) = try await aiManager.fetchWebContent(url: bookmark.url)

            // Parse with AI
            let resolution = try await aiManager.parseBookmarkContent(
                BookmarkParsingInput(
                    url: bookmark.url,
                    title: title,
                    content: content,
                    categories: categories,
                    tags: tags
                )
            )
            
            // Fetch favicon
            let faviconURL = await aiManager.fetchFavicon(url: bookmark.url)

            return .success(
                BatchParsingOutput(
                    bookmarkID: bookmark.id,
                    resolution: resolution,
                    preferredIcon: faviconURL ?? resolution.suggestedSFSymbol
                )
            )
            
        } catch {
            return .failure(error)
        }
    }
    
    func pause() {
        isRunning = false
        task?.cancel()
        task = nil
        currentBookmark = nil
    }
    
    func reset() {
        pause()
        progress = 0
        totalCount = 0
        completedCount = 0
    }
}
