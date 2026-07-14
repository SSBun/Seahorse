//
//  DataStorage.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import Combine
import OSLog

@MainActor
class DataStorage: ObservableObject {
    static let shared = DataStorage()
    
    static var preview: DataStorage = {
        let storage = DataStorage(database: MockDatabase())
        return storage
    }()
    
    private let database: DatabaseProtocol
    
    // Published properties for reactive UI updates
    @Published var bookmarks: [Bookmark] = []
    @Published var categories: [Category] = []
    @Published var tags: [Tag] = []

    // New: Collection items supporting multiple types
    @Published var items: [AnyCollectionItem] = []

    /// Incremented whenever items are modified (update) so views can refresh
    @Published var itemsVersion: Int = 0

    // MARK: - Performance Optimization: Lookup Caches (O(1) instead of O(n))
    private var _categoryCache: [UUID: Category] = [:]
    private var _tagCache: [UUID: Tag] = [:]
    private var _itemCache: [UUID: AnyCollectionItem] = [:]
    private var _searchRecordCache: [UUID: CollectionSearch.Record] = [:]

    /// O(1) category lookup by ID
    func category(for id: UUID) -> Category? {
        return _categoryCache[id]
    }

    /// O(1) tag lookup by ID
    func tag(for id: UUID) -> Tag? {
        return _tagCache[id]
    }

    /// O(1) tags lookup by IDs
    func tags(for ids: [UUID]) -> [Tag] {
        return ids.compactMap { _tagCache[$0] }
    }

    private func rebuildCategoryCache() {
        _categoryCache = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private func rebuildTagCache() {
        _tagCache = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
    }

    private func rebuildItemCache() {
        _itemCache = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private func rebuildSearchRecordCache() {
        _searchRecordCache = Dictionary(
            uniqueKeysWithValues: CollectionSearch.makeRecords(items: items, tagsByID: _tagCache)
                .map { ($0.item.id, $0) }
        )
    }

    private func updateSearchRecord(for item: AnyCollectionItem) {
        let order = items.firstIndex(where: { $0.id == item.id }) ?? items.count
        _searchRecordCache[item.id] = CollectionSearch.makeRecord(
            item: item,
            tagsByID: _tagCache,
            originalOrder: order
        )
    }

    private func refreshSearchRecords(referencing tagID: UUID) {
        for (index, item) in items.enumerated() where item.tagIds.contains(tagID) {
            _searchRecordCache[item.id] = CollectionSearch.makeRecord(
                item: item,
                tagsByID: _tagCache,
                originalOrder: index
            )
        }
    }

    func searchRecordsSnapshot() -> [CollectionSearch.Record] {
        items.enumerated().compactMap { index, item in
            guard let record = _searchRecordCache[item.id] else { return nil }
            return record.withOriginalOrder(index)
        }
    }

    /// O(1) item lookup by ID
    func item(for id: UUID) -> AnyCollectionItem? {
        return _itemCache[id]
    }
    
    init(database: DatabaseProtocol = JSONStorage()) {
        self.database = database
        loadInitialData()
    }
    
    // MARK: - Initial Data Loading
    
    private    func loadInitialData() {
        // Load initial data
        do {
            categories = try database.fetchAllCategories()
            tags = try database.fetchAllTags()
            
            // Load ALL items (bookmarks, images, text notes)
            items = try database.fetchAllItems()
            
            // Derive bookmarks array
            bookmarks = items.compactMap { $0.asBookmark }

            // Build lookup caches for O(1) access
            rebuildCategoryCache()
            rebuildTagCache()
            rebuildItemCache()
            rebuildSearchRecordCache()

            Log.info("✅ Loaded \(items.count) items (\(bookmarks.count) bookmarks)", category: .database)
        } catch {
            Log.error("❌ Failed to load initial data: \(error)", category: .database)
        }
        
        // Legacy image migration removed
    }
    
    // MARK: - Generic Item Operations
    
    func addItem(_ item: AnyCollectionItem) {
        do {
            try database.saveItem(item)
            items.append(item)
            _itemCache[item.id] = item
            updateSearchRecord(for: item)
            
            // Also add to type-specific array if it's a bookmark
            if let bookmark = item.asBookmark {
                bookmarks.append(bookmark)
            }
            itemsVersion += 1
            
            // Post notification for menu icon shaking animation
            NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
            
            // Show system notification if enabled
            NotificationService.shared.showNotification(for: item)
        } catch {
            Log.error("❌ Failed to save item: \(error)", category: .database)
        }
    }
    
    func updateItem(_ item: AnyCollectionItem) {
        do {
            try database.updateItem(item)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            }
            _itemCache[item.id] = item
            updateSearchRecord(for: item)

            // Also update type-specific array if it's a bookmark
            if let bookmark = item.asBookmark,
               let bookmarkIndex = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                bookmarks[bookmarkIndex] = bookmark
            }

            // Post notification for UI refresh (e.g., favorite toggle)
            NotificationCenter.default.post(name: NSNotification.Name("DataStorageItemsUpdated"), object: nil)
            itemsVersion += 1
        } catch {
            Log.error("❌ Failed to update item: \(error)", category: .database)
        }
    }

    func updateItems(_ updatedItems: [AnyCollectionItem]) throws {
        guard !updatedItems.isEmpty else { return }
        var updatesByID: [UUID: AnyCollectionItem] = [:]
        for item in updatedItems {
            guard updatesByID.updateValue(item, forKey: item.id) == nil else {
                throw DatabaseError.duplicateEntry
            }
        }
        try database.updateItems(updatedItems)
        items = items.map { updatesByID[$0.id] ?? $0 }
        bookmarks = items.compactMap(\.asBookmark)
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
        NotificationCenter.default.post(name: NSNotification.Name("DataStorageItemsUpdated"), object: nil)
    }

    func importData(
        categories newCategories: [Category],
        tags newTags: [Tag],
        items newItems: [AnyCollectionItem]
    ) throws {
        guard !newCategories.isEmpty || !newTags.isEmpty || !newItems.isEmpty else { return }
        try database.saveImportedData(categories: newCategories, tags: newTags, items: newItems)
        categories.append(contentsOf: newCategories)
        tags.append(contentsOf: newTags)
        items.append(contentsOf: newItems)
        bookmarks = items.compactMap(\.asBookmark)
        rebuildCategoryCache()
        rebuildTagCache()
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        Log.info("Deleting item: \(item.id)", category: .database)
        // Delete physical file if it's an image stored in internal storage
        if let imageItem = item.asImageItem {
            deleteImageFile(at: imageItem.imagePath)
        }
        
        try database.deleteItem(item)
        items.removeAll { $0.id == item.id }
        _itemCache.removeValue(forKey: item.id)
        _searchRecordCache.removeValue(forKey: item.id)
        itemsVersion += 1
        
        // Also delete from type-specific array if it's a bookmark
        if let bookmark = item.asBookmark {
            bookmarks.removeAll { $0.id == bookmark.id }
        }
    }
    
    private func deleteImageFile(at path: String) {
        let resolvedPath = StorageManager.shared.resolveImagePath(path)
        // Only delete if the file is in our internal storage directory
        let imagesDirectoryURL = StorageManager.shared.getImagesDirectory().resolvingSymlinksInPath()
        let fileURL = URL(fileURLWithPath: resolvedPath).resolvingSymlinksInPath()
        guard fileURL.path.hasPrefix(imagesDirectoryURL.path + "/") else {
            Log.info("Skipping deletion of external image: \(path)", category: .database)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                Log.info("✅ Deleted image file: \(fileURL.lastPathComponent)", category: .database)
            }
        } catch {
            Log.error("❌ Failed to delete image file: \(error)", category: .database)
        }
    }
    
    // MARK: - Bookmark Operations
    
    func addBookmark(_ bookmark: Bookmark) throws {
        let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
        if bookmarks.contains(where: { BookmarkURLNormalizer.normalize($0.url) == normalizedURL }) {
            throw DatabaseError.duplicateBookmarkURL
        }
        DLog("DataStorage: addBookmark start id=\(bookmark.id.uuidString) url='\(normalizedURL)'", category: .database)
        try database.saveBookmark(bookmark)
        bookmarks.append(bookmark)
        let item = AnyCollectionItem(bookmark)
        items.append(item) // Also add to items array
        _itemCache[bookmark.id] = item
        updateSearchRecord(for: item)
        itemsVersion += 1
        DLog("DataStorage: addBookmark success id=\(bookmark.id.uuidString) bookmarks=\(bookmarks.count) items=\(items.count)", category: .database)
        
        // Post notification for menu icon shaking animation
        NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
        
        // Show system notification if enabled
        NotificationService.shared.showNotification(for: item)
    }
    
    func updateBookmark(_ bookmark: Bookmark) throws {
        let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
        if bookmarks.contains(where: { $0.id != bookmark.id && BookmarkURLNormalizer.normalize($0.url) == normalizedURL }) {
            throw DatabaseError.duplicateBookmarkURL
        }
        DLog("DataStorage: updateBookmark start id=\(bookmark.id.uuidString) title='\(bookmark.title)'", category: .database)
        try database.updateBookmark(bookmark)
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
        }
        // Also update in items array
        let item = AnyCollectionItem(bookmark)
        if let itemIndex = items.firstIndex(where: { $0.id == bookmark.id }) {
            items[itemIndex] = item
        }
        _itemCache[bookmark.id] = item
        updateSearchRecord(for: item)
        // Increment version to notify views of in-place update
        itemsVersion += 1
        DLog("DataStorage: updateBookmark success id=\(bookmark.id.uuidString)", category: .database)
    }
    
    func deleteBookmark(_ bookmark: Bookmark) throws {
        try database.deleteBookmark(bookmark)
        bookmarks.removeAll { $0.id == bookmark.id }
        items.removeAll { $0.id == bookmark.id } // Also remove from items array
        _itemCache.removeValue(forKey: bookmark.id)
        _searchRecordCache.removeValue(forKey: bookmark.id)
        itemsVersion += 1
    }
    
    func fetchBookmarks(for category: Category) throws -> [Bookmark] {
        if category.name == "All Bookmarks" {
            return bookmarks
        } else if category.name == "Favorites" {
            return try database.fetchFavoriteBookmarks()
        } else {
            return try database.fetchBookmarks(categoryId: category.id)
        }
    }
    
    func fetchBookmarks(for tag: Tag) throws -> [Bookmark] {
        try database.fetchBookmarks(tagId: tag.id)
    }
    
    // MARK: - Bookmark-Tag Relationship
    
    func toggleBookmarkTag(bookmark: Bookmark, tagId: UUID) throws {
        var updated = bookmark
        updated.toggleTag(tagId)
        try updateBookmark(updated)
    }
    
    func addTagToBookmark(bookmark: Bookmark, tagId: UUID) throws {
        var updated = bookmark
        updated.addTag(tagId)
        try updateBookmark(updated)
    }
    
    func removeTagFromBookmark(bookmark: Bookmark, tagId: UUID) throws {
        var updated = bookmark
        updated.removeTag(tagId)
        try updateBookmark(updated)
    }
    
    func getBookmarkTags(_ bookmark: Bookmark) -> [Tag] {
        tags.filter { bookmark.tagIds.contains($0.id) }
    }
    
    // MARK: - Category Operations
    
    func addCategory(_ category: Category) throws {
        // Check uniqueness
        if try database.categoryExists(name: category.name) {
            throw DatabaseError.duplicateEntry
        }
        try database.saveCategory(category)
        categories.append(category)
        rebuildCategoryCache()
    }

    func updateCategory(_ category: Category) throws {
        try database.updateCategory(category)
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
        rebuildCategoryCache()
    }

    func deleteCategory(_ category: Category) throws {
        try database.deleteCategory(category)
        categories.removeAll { $0.id == category.id }
        rebuildCategoryCache()
    }
    
    func categoryExists(name: String, excluding: UUID? = nil) -> Bool {
        categories.contains { category in
            if let excludeId = excluding, category.id == excludeId {
                return false
            }
            return category.name.lowercased() == name.lowercased()
        }
    }
    
    // MARK: - Tag Operations
    
    func addTag(_ tag: Tag) throws {
        // Check uniqueness
        if try database.tagExists(name: tag.name) {
            throw DatabaseError.duplicateEntry
        }
        try database.saveTag(tag)
        tags.append(tag)
        rebuildTagCache()
        refreshSearchRecords(referencing: tag.id)
        itemsVersion += 1
    }

    func updateTag(_ tag: Tag) throws {
        try database.updateTag(tag)
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
        }
        rebuildTagCache()
        refreshSearchRecords(referencing: tag.id)
        itemsVersion += 1
    }

    func deleteTag(_ tag: Tag) throws {
        try database.deleteTag(tag)
        tags.removeAll { $0.id == tag.id }
        rebuildTagCache()
        refreshSearchRecords(referencing: tag.id)
        itemsVersion += 1
    }
    
    func tagExists(name: String, excluding: UUID? = nil) -> Bool {
        tags.contains { tag in
            if let excludeId = excluding, tag.id == excludeId {
                return false
            }
            return tag.name.lowercased() == name.lowercased()
        }
    }
    
    // MARK: - Reorder Operations
    
    func reorderCategories(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        
        do {
            try database.reorderCategories(reordered)
            categories = reordered
        } catch {
            Log.error("❌ Failed to reorder categories: \(error)", category: .database)
        }
    }
    
    func reorderTags(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = tags
        reordered.move(fromOffsets: source, toOffset: destination)
        
        do {
            try database.reorderTags(reordered)
            tags = reordered
        } catch {
            Log.error("❌ Failed to reorder tags: \(error)", category: .database)
        }
    }
    
    // MARK: - Preferences Operations
    
    func savePreference(key: String, value: String) throws {
        try database.savePreference(key: key, value: value)
    }
    
    func fetchPreference(key: String) throws -> String? {
        try database.fetchPreference(key: key)
    }
    
    func deletePreference(key: String) throws {
        try database.deletePreference(key: key)
    }
    
    // MARK: - Force Save
    
    /// Force save all current data to disk (used before migration)
    func forceSaveAllData() {
        NotificationCenter.default.post(name: .autoSyncStarted, object: nil)
        defer { NotificationCenter.default.post(name: .autoSyncEnded, object: nil) }
        database.forceSaveAllData()
    }
    
    // Legacy image migration removed
}

extension Notification.Name {
    static let autoSyncStarted = Notification.Name("SeahorseAutoSyncStarted")
    static let autoSyncEnded = Notification.Name("SeahorseAutoSyncEnded")
}
