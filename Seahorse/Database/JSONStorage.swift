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
    // Persistent storage
    private var items: [AnyCollectionItem] = []  // All collection items
    // bookmarks array removed - derived from items when needed
    private var categories: [Category] = []
    private var tags: [Tag] = []
    private var preferences: [String: String] = [:]
    
    // Thread-safe access
    private let queue = DispatchQueue(label: "com.seahorse.database", attributes: .concurrent)
    
    // File URLs for persistence
    private let itemsURL: URL
    private let categoriesURL: URL
    private let tagsURL: URL
    private let preferencesURL: URL
    
    init() {
        // Use StorageManager for all paths
        let dataDirectory = StorageManager.shared.getDataDirectory()
        
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
        preferencesURL = dataDirectory.appendingPathComponent("preferences.json")
        
        // Load data from storage
        loadData()
        
        // Ensure all data is written on startup
        ensureDataPersistence()
        
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
        
        // Verify file access
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: categoriesURL.deletingLastPathComponent().path) {
            Log.info("  ✅ Parent directory exists", category: .database)
            if fileManager.isReadableFile(atPath: categoriesURL.deletingLastPathComponent().path) {
                Log.info("  ✅ Parent directory is readable", category: .database)
            } else {
                Log.error("  ❌ Parent directory is NOT readable - permission issue!", category: .database)
            }
        } else {
            Log.warning("  ⚠️ Parent directory does not exist yet", category: .database)
        }
        
        // Load categories
        if fileManager.fileExists(atPath: categoriesURL.path) {
            Log.info("  📄 Categories file exists", category: .database)
            do {
                let data = try Data(contentsOf: categoriesURL)
                Log.info("  ✅ Read \(data.count) bytes from categories file", category: .database)
                let loaded = try JSONDecoder().decode([Category].self, from: data)
                categories = loaded
                Log.info("  ✓ Loaded \(categories.count) categories", category: .database)
            } catch {
                Log.error("  ❌ Failed to load categories: \(error)", category: .database)
                categories = createDefaultCategories()
                saveCategoriesToDisk()
            }
        } else {
            // Initialize with default categories on first launch
            categories = createDefaultCategories()
            Log.info("  ℹ️ Created \(categories.count) default categories", category: .database)
            saveCategoriesToDisk()
        }
        
        // Load tags
        if fileManager.fileExists(atPath: tagsURL.path) {
            do {
                let data = try Data(contentsOf: tagsURL)
                Log.info("  ✅ Read \(data.count) bytes from tags file", category: .database)
                let loaded = try JSONDecoder().decode([Tag].self, from: data)
                tags = loaded
                Log.info("  ✓ Loaded \(tags.count) tags", category: .database)
            } catch {
                Log.error("  ❌ Failed to load tags: \(error)", category: .database)
            }
        } else {
            Log.info("  ℹ️ No tags file found (will be created on first save)", category: .database)
        }
        
        // Load items (supports all collection types)
        if fileManager.fileExists(atPath: itemsURL.path) {
            do {
                let data = try Data(contentsOf: itemsURL)
                Log.info("  ✅ Read \(data.count) bytes from items file", category: .database)
                
                let loaded = try JSONDecoder().decode([AnyCollectionItem].self, from: data)
                items = loaded.map { normalizeItemPaths($0) }
                // Persist normalized paths so future reads stay portable
                saveItemsToDisk()
                Log.info("  ✓ Loaded \(items.count) items", category: .database)
            } catch {
                Log.error("  ❌ Failed to load items: \(error)", category: .database)
            }
        } else {
            Log.info("  ℹ️ No items file found (will be created on first save)", category: .database)
        }
        
        // Load preferences
        if fileManager.fileExists(atPath: preferencesURL.path) {
            do {
                let data = try Data(contentsOf: preferencesURL)
                let loaded = try JSONDecoder().decode([String: String].self, from: data)
                preferences = loaded
                Log.info("  ✓ Loaded \(preferences.count) preferences", category: .database)
            } catch {
                Log.error("  ❌ Failed to load preferences: \(error)", category: .database)
            }
        } else {
            Log.info("  ℹ️ No preferences file found (will be created on first save)", category: .database)
        }
    }
    
    /// Ensure all data is persisted to preference folder on startup
    private func ensureDataPersistence() {
        print("💾 Ensuring data persistence to preference folder...")
        
        // Save all data to ensure files exist in preference folder
        queue.sync(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            // Save items
            if let data = try? encoder.encode(self.items) {
                try? data.write(to: self.itemsURL)
                print("  ✓ Saved \(self.items.count) items to: \(self.itemsURL.lastPathComponent)")
            }
            
            // Save categories
            if let data = try? encoder.encode(self.categories) {
                try? data.write(to: self.categoriesURL)
                print("  ✓ Saved \(self.categories.count) categories to: \(self.categoriesURL.lastPathComponent)")
            }
            
            // Save tags
            if let data = try? encoder.encode(self.tags) {
                try? data.write(to: self.tagsURL)
                print("  ✓ Saved \(self.tags.count) tags to: \(self.tagsURL.lastPathComponent)")
            }
            
            // Save preferences
            if let data = try? encoder.encode(self.preferences) {
                try? data.write(to: self.preferencesURL)
                print("  ✓ Saved \(self.preferences.count) preferences to: \(self.preferencesURL.lastPathComponent)")
            }
        }
    }
    
    private func createDefaultCategories() -> [Category] {
        return [
            Category(name: "All Bookmarks", icon: "folder.fill", color: .blue),
            Category(name: "Favorites", icon: "star.fill", color: .yellow),
            Category(name: "None", icon: "folder.fill", color: .gray)
        ]
    }
    
    private func saveItemsToDisk() {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let normalized = self.items.map { self.normalizeItemPaths($0) }
            if let data = try? encoder.encode(normalized) {
                try? data.write(to: self.itemsURL)
            }
        }
    }
    
    private func saveCategoriesToDisk() {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(self.categories) {
                try? data.write(to: self.categoriesURL)
            }
        }
    }
    
    private func saveTagsToDisk() {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(self.tags) {
                try? data.write(to: self.tagsURL)
            }
        }
    }
    
    private func savePreferencesToDisk() {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(self.preferences) {
                try? data.write(to: self.preferencesURL)
            }
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
            items.compactMap { $0.asBookmark }
        }
    }
    
    func fetchBookmarks(categoryId: UUID) throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.categoryId == categoryId }
        }
    }
    
    func fetchBookmarks(tagId: UUID) throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.tagIds.contains(tagId) }
        }
    }
    
    func fetchFavoriteBookmarks() throws -> [Bookmark] {
        queue.sync {
            items.compactMap { $0.asBookmark }.filter { $0.isFavorite }
        }
    }
    
    // MARK: - Item Operations
    
    func fetchAllItems() throws -> [AnyCollectionItem] {
        queue.sync {
            items
        }
    }
    
    func saveItem(_ item: AnyCollectionItem) throws {
        try queue.sync(flags: .barrier) {
            guard !items.contains(where: { $0.id == item.id }) else {
                throw DatabaseError.duplicateEntry
            }
            
            // Enforce duplicate URL rule for bookmark items too
            if let bookmark = item.asBookmark {
                let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
                if items.compactMap({ $0.asBookmark }).contains(where: { BookmarkURLNormalizer.normalize($0.url) == normalizedURL }) {
                    throw DatabaseError.duplicateBookmarkURL
                }
            }
            items.append(normalizeItemPaths(item))
        }
        saveItemsToDisk()
    }
    
    func updateItem(_ item: AnyCollectionItem) throws {
        try queue.sync(flags: .barrier) {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else {
                throw DatabaseError.notFound
            }
            
            // Enforce duplicate URL rule for bookmark items too (excluding self)
            if let bookmark = item.asBookmark {
                let normalizedURL = BookmarkURLNormalizer.normalize(bookmark.url)
                if items.compactMap({ $0.asBookmark }).contains(where: { $0.id != bookmark.id && BookmarkURLNormalizer.normalize($0.url) == normalizedURL }) {
                    throw DatabaseError.duplicateBookmarkURL
                }
            }
            items[index] = normalizeItemPaths(item)
        }
        saveItemsToDisk()
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        try queue.sync(flags: .barrier) {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else {
                throw DatabaseError.notFound
            }
            items.remove(at: index)
        }
        saveItemsToDisk()
    }
    
    // MARK: - Category Operations
    
    func saveCategory(_ category: Category) throws {
        try queue.sync(flags: .barrier) {
            guard !categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) else {
                throw DatabaseError.duplicateEntry
            }
            categories.append(category)
        }
        saveCategoriesToDisk()
    }
    
    func updateCategory(_ category: Category) throws {
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
        try queue.sync(flags: .barrier) {
            guard !tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) else {
                throw DatabaseError.duplicateEntry
            }
            tags.append(tag)
        }
        saveTagsToDisk()
    }
    
    func updateTag(_ tag: Tag) throws {
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
        queue.sync(flags: .barrier) {
            categories = newCategories
        }
        saveCategoriesToDisk()
    }
    
    func reorderTags(_ newTags: [Tag]) throws {
        queue.sync(flags: .barrier) {
            tags = newTags
        }
        saveTagsToDisk()
    }
    
    // MARK: - Preferences Operations
    
    func savePreference(key: String, value: String) throws {
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
        queue.sync(flags: .barrier) {
            _ = preferences.removeValue(forKey: key)
        }
        savePreferencesToDisk()
    }
    
    // MARK: - Force Save All Data
    
    /// Force save all data synchronously (used before migration)
    func forceSaveAllData() {
        queue.sync(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            // Save items
            if let data = try? encoder.encode(self.items) {
                try? data.write(to: self.itemsURL)
            }
            
            // Save categories
            if let data = try? encoder.encode(self.categories) {
                try? data.write(to: self.categoriesURL)
            }
            
            // Save tags
            if let data = try? encoder.encode(self.tags) {
                try? data.write(to: self.tagsURL)
            }
            
            // Save preferences
            if let data = try? encoder.encode(self.preferences) {
                try? data.write(to: self.preferencesURL)
            }
        }
    }
}

