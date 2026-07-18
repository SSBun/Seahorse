//
//  JSONStorage.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import OSLog

/// JSON-based persistent storage implementation
class JSONStorage: DatabaseProtocol {
    enum RecoveryState: Equatable {
        case normal
        case recovered
        case readOnly
    }

    private struct StorageSnapshot: Codable {
        let schemaVersion: Int
        let items: [AnyCollectionItem]
        let categories: [Category]
        let tags: [Tag]
        let smartCollections: [SmartCollection]
        let preferences: [String: String]
    }

    private(set) var recoveryState: RecoveryState = .normal

    // Persistent storage
    private var items: [AnyCollectionItem] = []  // All collection items
    // bookmarks array removed - derived from items when needed
    private var categories: [Category] = []
    private var tags: [Tag] = []
    private var smartCollections: [SmartCollection] = []
    private var preferences: [String: String] = [:]
    
    // Thread-safe access
    private let queue = DispatchQueue(label: "com.seahorse.database", attributes: .concurrent)
    private let writeQueue = DispatchQueue(label: "com.seahorse.database.writer")
    private let saveDelay: TimeInterval
    private let writeData: (Data, URL) throws -> Void
    private var itemsSaveGeneration = 0
    
    // File URLs for persistence
    private let itemsURL: URL
    private let categoriesURL: URL
    private let tagsURL: URL
    private let smartCollectionsURL: URL
    private let preferencesURL: URL
    private let lastGoodURL: URL
    private let recoveryMarkerURL: URL
    
    convenience init() {
        self.init(dataDirectory: StorageManager.shared.getDataDirectory())
    }

    init(
        dataDirectory: URL,
        saveDelay: TimeInterval = 0.25,
        writeData: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.saveDelay = saveDelay
        self.writeData = writeData

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            Log.info("✅ Data directory ready: \(dataDirectory.path)", category: .database)
        } catch {
            Log.error("❌ Failed to create data directory: \(error)", category: .database)
        }
        
        itemsURL = dataDirectory.appendingPathComponent("items.json")
        categoriesURL = dataDirectory.appendingPathComponent("categories.json")
        tagsURL = dataDirectory.appendingPathComponent("tags.json")
        smartCollectionsURL = dataDirectory.appendingPathComponent("smart-collections.json")
        preferencesURL = dataDirectory.appendingPathComponent("preferences.json")
        lastGoodURL = dataDirectory.appendingPathComponent("last-good.json")
        recoveryMarkerURL = dataDirectory.appendingPathComponent("recovery-in-progress")
        
        // Load data from storage
        loadData()

        Log.info("✅ Database initialized. Storage location: \(dataDirectory.path)", category: .database)
    }
    // Security-scoped resource is now managed by StorageManager
    // No need for deinit here
    
    // getStorageDirectoryWithAccess() is now in StorageManager
    // Removed duplicate code
    
    private func loadData() {
        Log.info("📖 Loading data from storage folder...", category: .database)
        Log.info("  Categories file: \(categoriesURL.path)", category: .database)
        Log.info("  Items file: \(itemsURL.path)", category: .database)

        let fileManager = FileManager.default
        let primaryURLs = [itemsURL, categoriesURL, tagsURL, smartCollectionsURL, preferencesURL]
        let hasPrimaryData = primaryURLs.contains { fileManager.fileExists(atPath: $0.path) }

        if !hasPrimaryData {
            let initial = StorageSnapshot(
                schemaVersion: 1,
                items: [],
                categories: createDefaultCategories(),
                tags: [],
                smartCollections: [],
                preferences: [:]
            )
            apply(initial)
            if writeLastGoodSnapshot(initial) {
                saveCategoriesToDisk()
            } else {
                recoveryState = .readOnly
            }
            return
        }

        let primary = readPrimarySnapshot()
        let invalidURLs = primary.invalidURLs + structuralInvalidURLs(in: primary.snapshot)
        let interruptedRecovery = fileManager.fileExists(atPath: recoveryMarkerURL.path)
        guard !invalidURLs.isEmpty || interruptedRecovery else {
            apply(primary.snapshot)
            _ = writeLastGoodSnapshot(primary.snapshot)
            Log.info("  ✓ Loaded \(items.count) items and refreshed last-good snapshot", category: .database)
            return
        }

        if interruptedRecovery {
            Log.error("  ❌ Previous storage recovery was interrupted", category: .database)
        } else {
            Log.error(
                "  ❌ Invalid storage files: \(invalidURLs.map(\.lastPathComponent).joined(separator: ", "))",
                category: .database
            )
        }
        guard let recovered = readLastGoodSnapshot(), structuralInvalidURLs(in: recovered).isEmpty else {
            apply(primary.snapshot)
            recoveryState = .readOnly
            Log.error("  ❌ No valid last-good snapshot; storage is read-only", category: .database)
            return
        }

        do {
            try preserve(invalidURLs)
            try writePrimarySnapshot(recovered)
            apply(recovered)
            recoveryState = .recovered
            Log.warning("  ⚠️ Restored all core data from last-good snapshot", category: .database)
        } catch {
            apply(recovered)
            recoveryState = .readOnly
            Log.error("  ❌ Recovery could not be persisted; storage is read-only: \(error)", category: .database)
        }
    }

    private func readPrimarySnapshot() -> (snapshot: StorageSnapshot, invalidURLs: [URL]) {
        var invalidURLs: [URL] = []
        let loadedItems = decode([AnyCollectionItem].self, from: itemsURL, default: [], invalidURLs: &invalidURLs)
        let loadedCategories = decode([Category].self, from: categoriesURL, default: createDefaultCategories(), invalidURLs: &invalidURLs)
        let loadedTags = decode([Tag].self, from: tagsURL, default: [], invalidURLs: &invalidURLs)
        let loadedSmartCollections = decode([SmartCollection].self, from: smartCollectionsURL, default: [], invalidURLs: &invalidURLs)
        let loadedPreferences = decode([String: String].self, from: preferencesURL, default: [:], invalidURLs: &invalidURLs)
        return (
            StorageSnapshot(
                schemaVersion: 1,
                items: loadedItems,
                categories: loadedCategories,
                tags: loadedTags,
                smartCollections: loadedSmartCollections,
                preferences: loadedPreferences
            ),
            invalidURLs
        )
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from url: URL,
        default defaultValue: Value,
        invalidURLs: inout [URL]
    ) -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return defaultValue }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            invalidURLs.append(url)
            Log.error("  ❌ Failed to load \(url.lastPathComponent): \(error)", category: .database)
            return defaultValue
        }
    }

    private func readLastGoodSnapshot() -> StorageSnapshot? {
        guard let data = try? Data(contentsOf: lastGoodURL),
              let snapshot = try? JSONDecoder().decode(StorageSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else {
            return nil
        }
        return snapshot
    }

    private func structuralInvalidURLs(in snapshot: StorageSnapshot) -> [URL] {
        var invalidURLs: [URL] = []
        if Set(snapshot.items.map(\.id)).count != snapshot.items.count || snapshot.items.contains(where: { item in
            switch item.itemType {
            case .bookmark: return item.asBookmark?.id != item.id
            case .image: return item.asImageItem?.id != item.id
            case .text: return item.asTextItem?.id != item.id
            }
        }) {
            invalidURLs.append(itemsURL)
        }
        if Set(snapshot.categories.map(\.id)).count != snapshot.categories.count {
            invalidURLs.append(categoriesURL)
        }
        if Set(snapshot.tags.map(\.id)).count != snapshot.tags.count {
            invalidURLs.append(tagsURL)
        }
        if Set(snapshot.smartCollections.map(\.id)).count != snapshot.smartCollections.count {
            invalidURLs.append(smartCollectionsURL)
        }
        return invalidURLs
    }

    private func apply(_ snapshot: StorageSnapshot) {
        items = snapshot.items.map { normalizeItemPaths($0) }
        categories = snapshot.categories
        tags = snapshot.tags
        smartCollections = snapshot.smartCollections
        preferences = snapshot.preferences
    }

    private func currentSnapshot() -> StorageSnapshot {
        queue.sync {
            StorageSnapshot(
                schemaVersion: 1,
                items: items.map { normalizeItemPaths($0) },
                categories: categories,
                tags: tags,
                smartCollections: smartCollections,
                preferences: preferences
            )
        }
    }

    @discardableResult
    private func writeLastGoodSnapshot(_ snapshot: StorageSnapshot) -> Bool {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try writeData(data, lastGoodURL)
            return true
        } catch {
            Log.error("❌ Failed to save last-good.json: \(error)", category: .database)
            return false
        }
    }

    private func refreshLastGoodSnapshot() {
        let primary = readPrimarySnapshot()
        guard primary.invalidURLs.isEmpty, structuralInvalidURLs(in: primary.snapshot).isEmpty else {
            Log.error("❌ Refused to refresh last-good snapshot from invalid primary data", category: .database)
            return
        }
        writeLastGoodSnapshot(primary.snapshot)
    }

    private func preserve(_ invalidURLs: [URL]) throws {
        for url in Set(invalidURLs) where FileManager.default.fileExists(atPath: url.path) {
            let preservedURL = url.deletingLastPathComponent().appendingPathComponent(
                "\(url.lastPathComponent).corrupt-\(UUID().uuidString)"
            )
            try FileManager.default.copyItem(at: url, to: preservedURL)
        }
    }

    private func writePrimarySnapshot(_ snapshot: StorageSnapshot) throws {
        try writeData(Data("recovery".utf8), recoveryMarkerURL)
        try writeData(JSONEncoder().encode(snapshot.items), itemsURL)
        try writeData(JSONEncoder().encode(snapshot.categories), categoriesURL)
        try writeData(JSONEncoder().encode(snapshot.tags), tagsURL)
        try writeData(JSONEncoder().encode(snapshot.smartCollections), smartCollectionsURL)
        try writeData(JSONEncoder().encode(snapshot.preferences), preferencesURL)
        try FileManager.default.removeItem(at: recoveryMarkerURL)
    }

    private func ensureWritable() throws {
        guard recoveryState != .readOnly else { throw DatabaseError.saveFailed }
    }
    
    private func createDefaultCategories() -> [Category] {
        return [
            Category(name: "All Bookmarks", icon: "folder.fill", color: .blue),
            Category(name: "Favorites", icon: "star.fill", color: .yellow),
            Category(name: "Github", icon: "github.fill", color: .gray),
            Category(name: "None", icon: "folder.fill", color: .gray)
        ]
    }
    
    private func saveItemsToDisk() {
        writeQueue.async {
            self.itemsSaveGeneration += 1
            let generation = self.itemsSaveGeneration

            self.writeQueue.asyncAfter(deadline: .now() + self.saveDelay) {
                guard generation == self.itemsSaveGeneration else { return }
                let items = self.queue.sync {
                    self.items.map { self.normalizeItemPaths($0) }
                }
                if self.write(items, to: self.itemsURL) {
                    self.refreshLastGoodSnapshot()
                }
            }
        }
    }
    
    private func saveCategoriesToDisk() {
        writeQueue.async {
            let categories = self.queue.sync { self.categories }
            if self.write(categories, to: self.categoriesURL) {
                self.refreshLastGoodSnapshot()
            }
        }
    }
    
    private func saveTagsToDisk() {
        writeQueue.async {
            let tags = self.queue.sync { self.tags }
            if self.write(tags, to: self.tagsURL) {
                self.refreshLastGoodSnapshot()
            }
        }
    }

    private func saveSmartCollectionsToDisk() {
        writeQueue.async {
            let smartCollections = self.queue.sync { self.smartCollections }
            if self.write(smartCollections, to: self.smartCollectionsURL) {
                self.refreshLastGoodSnapshot()
            }
        }
    }
    
    private func savePreferencesToDisk() {
        writeQueue.async {
            let preferences = self.queue.sync { self.preferences }
            if self.write(preferences, to: self.preferencesURL) {
                self.refreshLastGoodSnapshot()
            }
        }
    }

    @discardableResult
    private func write<Value: Encodable>(_ value: Value, to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try writeData(data, url)
            return true
        } catch {
            Log.error("❌ Failed to save \(url.lastPathComponent): \(error)", category: .database)
            return false
        }
    }

    private func writeItemsSynchronously() throws {
        let snapshot = queue.sync {
            items.map { normalizeItemPaths($0) }
        }
        try writeQueue.sync {
            itemsSaveGeneration += 1
            let data = try JSONEncoder().encode(snapshot)
            try writeData(data, itemsURL)
            refreshLastGoodSnapshot()
        }
    }
    
    // MARK: - Path Normalization
    
    /// Ensure image-related paths are portable (filenames only) while leaving remote URLs untouched.
    private func normalizeItemPaths(_ item: AnyCollectionItem) -> AnyCollectionItem {
        func normalizePath(_ path: String?) -> String? {
            guard let path = path, !path.isEmpty else { return path }
            // Keep remote URLs as-is
            if let url = URL(string: path),
               let scheme = url.scheme,
               (scheme == "http" || scheme == "https") {
                return path
            }
            let resolved = StorageManager.shared.resolveImagePath(path)
            return StorageManager.shared.relativeImageFilename(from: resolved)
        }
        
        switch item.itemType {
        case .bookmark:
            if var bookmark = item.asBookmark {
                if var metadata = bookmark.metadata {
                    metadata.imageURL = normalizePath(metadata.imageURL)
                    bookmark.metadata = metadata
                }
                return AnyCollectionItem(bookmark)
            }
        case .image:
            if var imageItem = item.asImageItem {
                if let normalized = normalizePath(imageItem.imagePath) {
                    imageItem.imagePath = normalized
                }
                if let thumb = imageItem.thumbnailPath,
                   let normalizedThumb = normalizePath(thumb) {
                    imageItem.thumbnailPath = normalizedThumb
                }
                return AnyCollectionItem(imageItem)
            }
        case .text:
            return item
        }
        
        return item
    }
    
    // MARK: - Bookmark Operations
    
    func saveBookmark(_ bookmark: Bookmark) throws {
        // Delegate to the generic item pipeline so all validation/normalization lives in one place.
        try saveItem(AnyCollectionItem(bookmark))
    }
    
    func updateBookmark(_ bookmark: Bookmark) throws {
        // Delegate to the generic item pipeline so all validation/normalization lives in one place.
        try updateItem(AnyCollectionItem(bookmark))
    }
    
    func deleteBookmark(_ bookmark: Bookmark) throws {
        // Delegate to the generic item pipeline so all validation/normalization lives in one place.
        try deleteItem(AnyCollectionItem(bookmark))
    }
    
    func fetchAllBookmarks() throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.deletedAt == nil }
        }
    }
    
    func fetchBookmarks(categoryId: UUID) throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.deletedAt == nil && $0.categoryId == categoryId }
        }
    }
    
    func fetchBookmarks(tagId: UUID) throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.deletedAt == nil && $0.tagIds.contains(tagId) }
        }
    }
    
    func fetchFavoriteBookmarks() throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.deletedAt == nil && $0.isFavorite }
        }
    }
    
    // MARK: - Item Operations
    
    func fetchAllItems() throws -> [AnyCollectionItem] {
        queue.sync {
            items
        }
    }
    
    func saveItem(_ item: AnyCollectionItem) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard !items.contains(where: { $0.id == item.id }) else {
                throw DatabaseError.duplicateEntry
            }
            
            // Enforce duplicate URL rule for bookmark items too
            if let bookmark = item.asBookmark, bookmark.deletedAt == nil {
                let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
                if items.compactMap({ $0.asBookmark }).contains(where: {
                    $0.deletedAt == nil && BookmarkURLNormalizer.normalize($0.url) == normalizedURL
                }) {
                    throw DatabaseError.duplicateBookmarkURL
                }
            }
            items.append(normalizeItemPaths(item))
        }
        saveItemsToDisk()
    }
    
    func updateItem(_ item: AnyCollectionItem) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else {
                throw DatabaseError.notFound
            }
            
            // Enforce duplicate URL rule for bookmark items too (excluding self)
            if let bookmark = item.asBookmark, bookmark.deletedAt == nil {
                let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
                if items.compactMap({ $0.asBookmark }).contains(where: {
                    $0.id != bookmark.id
                        && $0.deletedAt == nil
                        && BookmarkURLNormalizer.normalize($0.url) == normalizedURL
                }) {
                    throw DatabaseError.duplicateBookmarkURL
                }
            }
            items[index] = normalizeItemPaths(item)
        }
        saveItemsToDisk()
    }

    func updateItems(_ updatedItems: [AnyCollectionItem]) throws {
        try ensureWritable()
        var previousItems: [AnyCollectionItem] = []
        try queue.sync(flags: .barrier) {
            previousItems = items
            var updatesByID: [UUID: AnyCollectionItem] = [:]
            for item in updatedItems {
                guard updatesByID.updateValue(item, forKey: item.id) == nil else {
                    throw DatabaseError.duplicateEntry
                }
                guard items.contains(where: { $0.id == item.id }) else {
                    throw DatabaseError.notFound
                }
            }

            let candidate = items.map { updatesByID[$0.id] ?? $0 }
            try validateUniqueBookmarkURLs(candidate)
            items = candidate.map(normalizeItemPaths)
        }
        do {
            try writeItemsSynchronously()
        } catch {
            queue.sync(flags: .barrier) {
                items = previousItems
            }
            throw error
        }
    }

    func saveImportedData(
        categories importedCategories: [Category],
        tags importedTags: [Tag],
        smartCollections importedSmartCollections: [SmartCollection],
        items importedItems: [AnyCollectionItem]
    ) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            let candidateItems = items + importedItems
            let candidateCategories = categories + importedCategories
            let candidateTags = tags + importedTags
            let candidateSmartCollections = smartCollections + importedSmartCollections
            guard Set(candidateItems.map(\.id)).count == candidateItems.count else {
                throw DatabaseError.duplicateEntry
            }
            guard Set(candidateCategories.map(\.id)).count == candidateCategories.count,
                  Set(candidateCategories.map { $0.name.lowercased() }).count == candidateCategories.count,
                  Set(candidateTags.map(\.id)).count == candidateTags.count,
                  Set(candidateTags.map { $0.name.lowercased() }).count == candidateTags.count,
                  Set(candidateSmartCollections.map(\.id)).count == candidateSmartCollections.count,
                  Set(candidateSmartCollections.map { $0.name.lowercased() }).count == candidateSmartCollections.count else {
                throw DatabaseError.duplicateEntry
            }
            try validateUniqueBookmarkURLs(candidateItems)
            categories = candidateCategories
            tags = candidateTags
            smartCollections = candidateSmartCollections
            items = candidateItems.map(normalizeItemPaths)
        }
        saveCategoriesToDisk()
        saveTagsToDisk()
        saveSmartCollectionsToDisk()
        saveItemsToDisk()
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        try deleteItems([item])
    }

    func deleteItems(_ deletedItems: [AnyCollectionItem]) throws {
        guard !deletedItems.isEmpty else { return }
        try ensureWritable()
        var previousItems: [AnyCollectionItem] = []
        try queue.sync(flags: .barrier) {
            previousItems = items
            let ids = Set(deletedItems.map(\.id))
            guard ids.count == deletedItems.count,
                  ids.allSatisfy({ id in items.contains(where: { $0.id == id }) }) else {
                throw DatabaseError.notFound
            }
            items.removeAll { ids.contains($0.id) }
        }
        do {
            try writeItemsSynchronously()
        } catch {
            queue.sync(flags: .barrier) {
                items = previousItems
            }
            throw error
        }
    }

    private func validateUniqueBookmarkURLs(_ items: [AnyCollectionItem]) throws {
        var urls = Set<String>()
        for bookmark in items.compactMap(\.asBookmark) where bookmark.deletedAt == nil {
            guard urls.insert(BookmarkURLNormalizer.normalize(bookmark.url)).inserted else {
                throw DatabaseError.duplicateBookmarkURL
            }
        }
    }
    
    // MARK: - Category Operations
    
    func saveCategory(_ category: Category) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard !categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) else {
                throw DatabaseError.duplicateEntry
            }
            categories.append(category)
        }
        saveCategoriesToDisk()
    }
    
    func updateCategory(_ category: Category) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
                throw DatabaseError.notFound
            }
            // Check for duplicate name (excluding self)
            if categories.contains(where: { $0.id != category.id && $0.name.lowercased() == category.name.lowercased() }) {
                throw DatabaseError.duplicateEntry
            }
            categories[index] = category
        }
        saveCategoriesToDisk()
    }
    
    func deleteCategory(_ category: Category) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
                throw DatabaseError.notFound
            }
            categories.remove(at: index)
        }
        saveCategoriesToDisk()
    }
    
    func fetchAllCategories() throws -> [Category] {
        queue.sync {
            categories
        }
    }
    
    func categoryExists(name: String) throws -> Bool {
        queue.sync {
            categories.contains(where: { $0.name.lowercased() == name.lowercased() })
        }
    }
    
    // MARK: - Tag Operations
    
    func saveTag(_ tag: Tag) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard !tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) else {
                throw DatabaseError.duplicateEntry
            }
            tags.append(tag)
        }
        saveTagsToDisk()
    }
    
    func updateTag(_ tag: Tag) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = tags.firstIndex(where: { $0.id == tag.id }) else {
                throw DatabaseError.notFound
            }
            // Check for duplicate name (excluding self)
            if tags.contains(where: { $0.id != tag.id && $0.name.lowercased() == tag.name.lowercased() }) {
                throw DatabaseError.duplicateEntry
            }
            tags[index] = tag
        }
        saveTagsToDisk()
    }
    
    func deleteTag(_ tag: Tag) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = tags.firstIndex(where: { $0.id == tag.id }) else {
                throw DatabaseError.notFound
            }
            tags.remove(at: index)
        }
        saveTagsToDisk()
    }
    
    func fetchAllTags() throws -> [Tag] {
        queue.sync {
            tags
        }
    }
    
    func tagExists(name: String) throws -> Bool {
        queue.sync {
            tags.contains(where: { $0.name.lowercased() == name.lowercased() })
        }
    }
    
    // MARK: - Reorder Operations
    
    func reorderCategories(_ newCategories: [Category]) throws {
        try ensureWritable()
        queue.sync(flags: .barrier) {
            categories = newCategories
        }
        saveCategoriesToDisk()
    }
    
    func reorderTags(_ newTags: [Tag]) throws {
        try ensureWritable()
        queue.sync(flags: .barrier) {
            tags = newTags
        }
        saveTagsToDisk()
    }

    // MARK: - Smart Collection Operations

    func saveSmartCollection(_ smartCollection: SmartCollection) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard !smartCollections.contains(where: {
                $0.id == smartCollection.id || $0.name.localizedCaseInsensitiveCompare(smartCollection.name) == .orderedSame
            }) else {
                throw DatabaseError.duplicateEntry
            }
            smartCollections.append(smartCollection)
        }
        saveSmartCollectionsToDisk()
    }

    func updateSmartCollection(_ smartCollection: SmartCollection) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = smartCollections.firstIndex(where: { $0.id == smartCollection.id }) else {
                throw DatabaseError.notFound
            }
            guard !smartCollections.contains(where: {
                $0.id != smartCollection.id && $0.name.localizedCaseInsensitiveCompare(smartCollection.name) == .orderedSame
            }) else {
                throw DatabaseError.duplicateEntry
            }
            smartCollections[index] = smartCollection
        }
        saveSmartCollectionsToDisk()
    }

    func deleteSmartCollection(_ smartCollection: SmartCollection) throws {
        try ensureWritable()
        try queue.sync(flags: .barrier) {
            guard let index = smartCollections.firstIndex(where: { $0.id == smartCollection.id }) else {
                throw DatabaseError.notFound
            }
            smartCollections.remove(at: index)
        }
        saveSmartCollectionsToDisk()
    }

    func fetchAllSmartCollections() throws -> [SmartCollection] {
        queue.sync { smartCollections }
    }

    func reorderSmartCollections(_ newSmartCollections: [SmartCollection]) throws {
        try ensureWritable()
        queue.sync(flags: .barrier) {
            smartCollections = newSmartCollections
        }
        saveSmartCollectionsToDisk()
    }
    
    // MARK: - Preferences Operations
    
    func savePreference(key: String, value: String) throws {
        try ensureWritable()
        queue.sync(flags: .barrier) {
            preferences[key] = value
        }
        savePreferencesToDisk()
    }
    
    func fetchPreference(key: String) throws -> String? {
        queue.sync {
            preferences[key]
        }
    }
    
    func deletePreference(key: String) throws {
        try ensureWritable()
        queue.sync(flags: .barrier) {
            _ = preferences.removeValue(forKey: key)
        }
        savePreferencesToDisk()
    }
    
    // MARK: - Force Save All Data
    
    /// Force save all data synchronously (used before migration)
    func forceSaveAllData() {
        guard recoveryState != .readOnly else {
            Log.error("❌ Refused force save because storage is read-only", category: .database)
            return
        }
        let snapshot = currentSnapshot()

        writeQueue.sync {
            itemsSaveGeneration += 1
            let writes = [
                write(snapshot.items, to: itemsURL),
                write(snapshot.categories, to: categoriesURL),
                write(snapshot.tags, to: tagsURL),
                write(snapshot.smartCollections, to: smartCollectionsURL),
                write(snapshot.preferences, to: preferencesURL)
            ]
            if writes.allSatisfy({ $0 }) {
                writeLastGoodSnapshot(snapshot)
            }
        }
    }
}
