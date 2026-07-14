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
        let unparsedBookmarks = dataStorage.bookmarks.filter { !$0.isParsed }
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
        var parsedBookmarks: [AnyCollectionItem] = []
        
        await withTaskGroup(of: (Int, Result<Bookmark, Error>).self) { group in
            // Start initial batch of concurrent tasks
            for i in 0..<min(maxConcurrentTasks, bookmarks.count) {
                group.addTask {
                    let result = await self.parseBookmark(bookmarks[i], dataStorage: dataStorage)
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
                case .success(let updatedBookmark):
                    parsedBookmarks.append(AnyCollectionItem(updatedBookmark))
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
                        let result = await self.parseBookmark(bookmarks[nextIndex], dataStorage: dataStorage)
                        return (nextIndex, result)
                    }
                    
                    // Update current bookmark for UI display
                    currentBookmark = bookmarks[nextIndex]
                }
            }
        }

        let liveBookmarks = parsedBookmarks.filter { dataStorage.item(for: $0.id) != nil }
        guard !liveBookmarks.isEmpty else { return }
        do {
            try dataStorage.updateItems(liveBookmarks)
        } catch {
            Log.error("Failed to save parsed bookmarks: \(error)", category: .parsing)
        }
    }
    
    /// Parse a single bookmark (extracted for concurrent processing)
    private func parseBookmark(_ bookmark: Bookmark, dataStorage: DataStorage) async -> Result<Bookmark, Error> {
        do {
            // Fetch web content
            let (content, title) = try await aiManager.fetchWebContent(url: bookmark.url)
            
            // Get categories and tags from data storage
            let availableCategories = await MainActor.run {
                dataStorage.categories
                    .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
                    .map { $0.name }
            }
            let availableTags = await MainActor.run {
                dataStorage.tags.map { $0.name }
            }
            
            // Parse with AI
            let parsed = try await aiManager.parseBookmarkContent(
                title: title,
                content: content,
                availableCategories: availableCategories,
                availableTags: availableTags
            )
            
            // Fetch favicon
            let faviconURL = await aiManager.fetchFavicon(url: bookmark.url)
            
            // Update bookmark
            var updatedBookmark = bookmark
            updatedBookmark.title = parsed.refinedTitle
            updatedBookmark.notes = parsed.summary
            updatedBookmark.isParsed = true
            
            // Set icon: prefer favicon, fallback to AI-suggested SF Symbol, then default
            if let faviconURL = faviconURL {
                updatedBookmark.icon = faviconURL
            } else if let suggestedSFSymbol = parsed.suggestedSFSymbol {
                updatedBookmark.icon = suggestedSFSymbol
            }
            
            // Update category if suggested
            if let suggestedCategoryName = parsed.suggestedCategoryName {
                let category = await MainActor.run {
                    dataStorage.categories.first(where: { $0.name == suggestedCategoryName })
                }
                if let category = category {
                    updatedBookmark.categoryId = category.id
                }
            }
            
            // Update tags (need to handle on main actor for DataStorage access)
            var tagIds: [UUID] = []
            for tagName in parsed.suggestedTagNames {
                let existingTag = await MainActor.run {
                    dataStorage.tags.first(where: { $0.name == tagName })
                }
                
                if let existingTag = existingTag {
                    tagIds.append(existingTag.id)
                } else {
                    // Create new tag
                    let newTag = Tag(name: tagName, color: .blue)
                    await MainActor.run {
                        try? dataStorage.addTag(newTag)
                    }
                    tagIds.append(newTag.id)
                }
            }
            updatedBookmark.tagIds = tagIds
            
            return .success(updatedBookmark)
            
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
