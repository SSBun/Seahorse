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
    @Published var smartCollections: [SmartCollection] = []

    // New: Collection items supporting multiple types
    @Published var items: [AnyCollectionItem] = []

    var activeItems: [AnyCollectionItem] {
        items.filter { !$0.isDeleted }
    }

    var trashItems: [AnyCollectionItem] {
        items.filter(\.isDeleted).sorted {
            ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
        }
    }

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
            uniqueKeysWithValues: CollectionSearch.makeRecords(items: activeItems, tagsByID: _tagCache)
                .map { ($0.item.id, $0) }
        )
    }

    private func updateSearchRecord(for item: AnyCollectionItem) {
        guard !item.isDeleted else {
            _searchRecordCache.removeValue(forKey: item.id)
            return
        }
        let order = items.firstIndex(where: { $0.id == item.id }) ?? items.count
        _searchRecordCache[item.id] = CollectionSearch.makeRecord(
            item: item,
            tagsByID: _tagCache,
            originalOrder: order
        )
    }

    private func refreshSearchRecords(referencing tagID: UUID) {
        for (index, item) in items.enumerated() where !item.isDeleted && item.tagIds.contains(tagID) {
            _searchRecordCache[item.id] = CollectionSearch.makeRecord(
                item: item,
                tagsByID: _tagCache,
                originalOrder: index
            )
        }
    }

    func searchRecordsSnapshot() -> [CollectionSearch.Record] {
        items.enumerated().compactMap { index, item in
            guard !item.isDeleted else { return nil }
            guard let record = _searchRecordCache[item.id] else { return nil }
            return record.withOriginalOrder(index)
        }
    }

    /// O(1) item lookup by ID
    func item(for id: UUID) -> AnyCollectionItem? {
        guard let item = _itemCache[id], !item.isDeleted else { return nil }
        return item
    }

    func itemIncludingDeleted(for id: UUID) -> AnyCollectionItem? {
        _itemCache[id]
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
            smartCollections = try database.fetchAllSmartCollections()
            
            // Load ALL items (bookmarks, images, text notes)
            items = try database.fetchAllItems()
            
            // Derive bookmarks array
            bookmarks = items.filter { !$0.isDeleted }.compactMap { $0.asBookmark }

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
        var item = item
        if var bookmark = item.asBookmark,
           bookmark.enrichmentStatus == nil,
           bookmark.metadata == nil,
           !bookmark.isParsed {
            bookmark.enrichmentStatus = .pending
            item = AnyCollectionItem(bookmark)
        }
        do {
            try database.saveItem(item)
            items.append(item)
            _itemCache[item.id] = item
            updateSearchRecord(for: item)
            
            // Also add to type-specific array if it's a bookmark
            if let bookmark = item.asBookmark, !item.isDeleted {
                bookmarks.append(bookmark)
            }
            itemsVersion += 1
            
            // Post notification for menu icon shaking animation
            NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: item.id)
            
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
            if item.isDeleted {
                bookmarks.removeAll { $0.id == item.id }
            } else if let bookmark = item.asBookmark {
                if let bookmarkIndex = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                    bookmarks[bookmarkIndex] = bookmark
                } else {
                    bookmarks.append(bookmark)
                }
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
        bookmarks = items.filter { !$0.isDeleted }.compactMap(\.asBookmark)
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
        NotificationCenter.default.post(name: NSNotification.Name("DataStorageItemsUpdated"), object: nil)
    }

    func importData(
        categories newCategories: [Category],
        tags newTags: [Tag],
        smartCollections newSmartCollections: [SmartCollection] = [],
        items newItems: [AnyCollectionItem]
    ) throws {
        guard !newCategories.isEmpty || !newTags.isEmpty || !newSmartCollections.isEmpty || !newItems.isEmpty else { return }
        try database.saveImportedData(
            categories: newCategories,
            tags: newTags,
            smartCollections: newSmartCollections,
            items: newItems
        )
        categories.append(contentsOf: newCategories)
        tags.append(contentsOf: newTags)
        smartCollections.append(contentsOf: newSmartCollections)
        items.append(contentsOf: newItems)
        bookmarks = items.filter { !$0.isDeleted }.compactMap(\.asBookmark)
        rebuildCategoryCache()
        rebuildTagCache()
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
        NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        try deleteItems(ids: [item.id])
    }

    func deleteItems(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        guard Set(ids).count == ids.count else { throw DatabaseError.duplicateEntry }
        let storedItems = try ids.map { id -> AnyCollectionItem in
            guard let item = itemIncludingDeleted(for: id) else { throw DatabaseError.notFound }
            return item
        }
        let deletionDate = Date()
        let updatedItems = storedItems.compactMap { item -> AnyCollectionItem? in
            guard !item.isDeleted else { return nil }
            var updated = item
            updated.deletedAt = deletionDate
            return updated
        }
        guard !updatedItems.isEmpty else { return }

        Log.info("Moving \(updatedItems.count) item(s) to trash", category: .database)
        try database.updateItems(updatedItems)
        applyUpdatedItems(updatedItems)
    }

    func restoreItem(_ item: AnyCollectionItem) throws -> ItemRestoreResult {
        try restoreItems(ids: [item.id])[0]
    }

    func restoreItems(ids: [UUID]) throws -> [ItemRestoreResult] {
        guard !ids.isEmpty else { return [] }
        guard Set(ids).count == ids.count else { throw DatabaseError.duplicateEntry }

        let results = try ids.map { id -> ItemRestoreResult in
            guard let item = itemIncludingDeleted(for: id), item.isDeleted else {
                throw DatabaseError.notFound
            }
            return try prepareForRestore(item)
        }
        try database.updateItems(results.map(\.item))
        applyUpdatedItems(results.map(\.item))
        NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
        return results
    }

    func permanentlyDeleteItem(_ item: AnyCollectionItem) throws {
        try permanentlyDeleteItems(ids: [item.id])
    }

    func permanentlyDeleteItems(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        guard Set(ids).count == ids.count else { throw DatabaseError.duplicateEntry }
        let deletedItems = try ids.map { id -> AnyCollectionItem in
            guard let item = itemIncludingDeleted(for: id), item.isDeleted else {
                throw DatabaseError.notFound
            }
            return item
        }
        let deletedIDs = Set(ids)
        let remainingItems = items.filter { !deletedIDs.contains($0.id) }
        let referencedPaths = Set(remainingItems.flatMap(imagePaths).compactMap(internalImagePath))
        let pathsToDelete = Set(deletedItems.flatMap(imagePaths).compactMap(internalImagePath))
            .subtracting(referencedPaths)

        try database.deleteItems(deletedItems)
        items.removeAll { deletedIDs.contains($0.id) }
        bookmarks = items.filter { !$0.isDeleted }.compactMap(\.asBookmark)
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
        NotificationCenter.default.post(name: NSNotification.Name("DataStorageItemsUpdated"), object: nil)

        for path in pathsToDelete {
            deleteImageFile(at: path)
        }
    }

    func emptyTrash() throws {
        try permanentlyDeleteItems(ids: trashItems.map(\.id))
    }

    private func prepareForRestore(_ item: AnyCollectionItem) throws -> ItemRestoreResult {
        var restored = item
        restored.deletedAt = nil
        let validCategoryIDs = Set(categories.map(\.id))
        let validTagIDs = Set(tags.map(\.id))
        let validTags = restored.tagIds.filter(validTagIDs.contains)
        let removedTagCount = restored.tagIds.count - validTags.count
        let categoryWasReset = !validCategoryIDs.contains(restored.categoryId)
        let fallbackCategoryID = categories.first(where: { $0.name == "None" })?.id ?? categories.first?.id
        if categoryWasReset, fallbackCategoryID == nil {
            throw DatabaseError.notFound
        }

        if var bookmark = restored.asBookmark {
            if categoryWasReset { bookmark.categoryId = fallbackCategoryID! }
            bookmark.tagIds = validTags
            bookmark.deletedAt = nil
            bookmark.modifiedDate = Date()
            restored = AnyCollectionItem(bookmark)
        } else if var imageItem = restored.asImageItem {
            if categoryWasReset { imageItem.categoryId = fallbackCategoryID! }
            imageItem.tagIds = validTags
            imageItem.deletedAt = nil
            imageItem.modifiedDate = Date()
            restored = AnyCollectionItem(imageItem)
        } else if var textItem = restored.asTextItem {
            if categoryWasReset { textItem.categoryId = fallbackCategoryID! }
            textItem.tagIds = validTags
            textItem.deletedAt = nil
            textItem.modifiedDate = Date()
            restored = AnyCollectionItem(textItem)
        }

        return ItemRestoreResult(
            item: restored,
            categoryWasReset: categoryWasReset,
            removedTagCount: removedTagCount
        )
    }

    private func applyUpdatedItems(_ updatedItems: [AnyCollectionItem]) {
        let updatesByID = Dictionary(uniqueKeysWithValues: updatedItems.map { ($0.id, $0) })
        items = items.map { updatesByID[$0.id] ?? $0 }
        bookmarks = items.filter { !$0.isDeleted }.compactMap(\.asBookmark)
        rebuildItemCache()
        rebuildSearchRecordCache()
        itemsVersion += 1
        NotificationCenter.default.post(name: NSNotification.Name("DataStorageItemsUpdated"), object: nil)
    }

    private func imagePaths(in item: AnyCollectionItem) -> [String] {
        if let bookmark = item.asBookmark, let path = bookmark.metadata?.imageURL {
            return [path]
        }
        if let imageItem = item.asImageItem {
            return [imageItem.imagePath, imageItem.thumbnailPath].compactMap { $0 }
        }
        return []
    }

    private func internalImagePath(_ path: String) -> String? {
        guard let url = internalImageURL(path) else { return nil }
        return url.path
    }
    
    private func deleteImageFile(at path: String) {
        guard let fileURL = internalImageURL(path) else {
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

    private func internalImageURL(_ path: String) -> URL? {
        let resolvedPath = StorageManager.shared.resolveImagePath(path)
        let imagesDirectoryURL = StorageManager.shared.getImagesDirectory().resolvingSymlinksInPath()
        let fileURL = URL(fileURLWithPath: resolvedPath).resolvingSymlinksInPath()
        guard fileURL.path.hasPrefix(imagesDirectoryURL.path + "/") else { return nil }
        return fileURL
    }
    
    // MARK: - Bookmark Operations
    
    func addBookmark(_ bookmark: Bookmark) throws {
        var bookmark = bookmark
        if bookmark.enrichmentStatus == nil, bookmark.metadata == nil, !bookmark.isParsed {
            bookmark.enrichmentStatus = .pending
        }
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
        NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: bookmark.id)
        
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
        try deleteItem(AnyCollectionItem(bookmark))
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
        guard let noneCategory = categories.first(where: { $0.name.caseInsensitiveCompare("None") == .orderedSame }),
              noneCategory.id != category.id else {
            throw DatabaseError.deleteFailed
        }

        let modifiedDate = Date()
        let reassignedItems = items.compactMap { item -> AnyCollectionItem? in
            if var bookmark = item.asBookmark, bookmark.categoryId == category.id {
                bookmark.categoryId = noneCategory.id
                bookmark.modifiedDate = modifiedDate
                return AnyCollectionItem(bookmark)
            }
            if var image = item.asImageItem, image.categoryId == category.id {
                image.categoryId = noneCategory.id
                image.modifiedDate = modifiedDate
                return AnyCollectionItem(image)
            }
            if var text = item.asTextItem, text.categoryId == category.id {
                text.categoryId = noneCategory.id
                text.modifiedDate = modifiedDate
                return AnyCollectionItem(text)
            }
            return nil
        }

        try updateItems(reassignedItems)
        try database.deleteCategory(category)
        categories.removeAll { $0.id == category.id }
        rebuildCategoryCache()
    }

    /// Returns the category whose name matches case-insensitively.
    func category(named name: String) -> Category? {
        categories.first { $0.name.lowercased() == name.lowercased() }
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
        let updatedItems = items.compactMap { item -> AnyCollectionItem? in
            if var bookmark = item.asBookmark, bookmark.tagIds.contains(tag.id) {
                bookmark.removeTag(tag.id)
                bookmark.modifiedDate = .now
                return AnyCollectionItem(bookmark)
            }
            if var imageItem = item.asImageItem, imageItem.tagIds.contains(tag.id) {
                imageItem.removeTag(tag.id)
                imageItem.modifiedDate = .now
                return AnyCollectionItem(imageItem)
            }
            if var textItem = item.asTextItem, textItem.tagIds.contains(tag.id) {
                textItem.removeTag(tag.id)
                textItem.modifiedDate = .now
                return AnyCollectionItem(textItem)
            }
            return nil
        }
        try updateItems(updatedItems)
        try database.deleteTag(tag)
        tags.removeAll { $0.id == tag.id }
        rebuildTagCache()
        refreshSearchRecords(referencing: tag.id)
        itemsVersion += 1
    }

    /// Returns the tag whose name matches case-insensitively.
    func tag(named name: String) -> Tag? {
        tags.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Creates any missing tags and returns the identifiers for all supplied names.
    func createTagsIfNeeded(named names: [String]) throws -> [UUID] {
        var identifiers: [UUID] = []
        for name in names {
            if let tag = tag(named: name) {
                identifiers.append(tag.id)
            } else {
                let tag = Tag(name: name, color: .blue)
                try addTag(tag)
                identifiers.append(tag.id)
            }
        }
        return identifiers
    }
    
    func tagExists(name: String, excluding: UUID? = nil) -> Bool {
        tags.contains { tag in
            if let excludeId = excluding, tag.id == excludeId {
                return false
            }
            return tag.name.lowercased() == name.lowercased()
        }
    }

    // MARK: - Smart Collection Operations

    func addSmartCollection(_ smartCollection: SmartCollection) throws {
        try database.saveSmartCollection(smartCollection)
        smartCollections.append(smartCollection)
    }

    func updateSmartCollection(_ smartCollection: SmartCollection) throws {
        try database.updateSmartCollection(smartCollection)
        guard let index = smartCollections.firstIndex(where: { $0.id == smartCollection.id }) else {
            throw DatabaseError.notFound
        }
        smartCollections[index] = smartCollection
    }

    func deleteSmartCollection(_ smartCollection: SmartCollection) throws {
        try database.deleteSmartCollection(smartCollection)
        smartCollections.removeAll { $0.id == smartCollection.id }
    }

    func smartCollectionNameExists(name: String, excluding: UUID? = nil) -> Bool {
        smartCollections.contains { smartCollection in
            smartCollection.id != excluding
                && smartCollection.name.localizedCaseInsensitiveCompare(name) == .orderedSame
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

    func reorderSmartCollections(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = smartCollections
        reordered.move(fromOffsets: source, toOffset: destination)

        do {
            try database.reorderSmartCollections(reordered)
            smartCollections = reordered
        } catch {
            Log.error("❌ Failed to reorder smart collections: \(error)", category: .database)
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
