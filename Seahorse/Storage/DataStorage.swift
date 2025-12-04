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
    
    private init(database: DatabaseProtocol = JSONStorage()) {
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
            
            // Also add to type-specific array if it's a bookmark
            if let bookmark = item.asBookmark {
                bookmarks.append(bookmark)
            }
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
            
            // Also update type-specific array if it's a bookmark
            if let bookmark = item.asBookmark,
               let bookmarkIndex = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                bookmarks[bookmarkIndex] = bookmark
            }
        } catch {
            Log.error("❌ Failed to update item: \(error)", category: .database)
        }
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        // Delete physical file if it's an image stored in internal storage
        if let imageItem = item.asImageItem {
            deleteImageFile(at: imageItem.imagePath)
        }
        
        try database.deleteItem(item)
        items.removeAll { $0.id == item.id }
        
        // Also delete from type-specific array if it's a bookmark
        if let bookmark = item.asBookmark {
            bookmarks.removeAll { $0.id == bookmark.id }
        }
    }
    
    private func deleteImageFile(at path: String) {
        // Only delete if the file is in our internal storage directory
        let imagesDir = StorageManager.shared.getImagesDirectory().path
        guard path.hasPrefix(imagesDir) else {
            Log.info("Skipping deletion of external image: \(path)", category: .database)
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: fileURL)
                Log.info("✅ Deleted image file: \(fileURL.lastPathComponent)", category: .database)
            }
        } catch {
            Log.error("❌ Failed to delete image file: \(error)", category: .database)
        }
    }
    
    // MARK: - Bookmark Operations
    
    func addBookmark(_ bookmark: Bookmark) throws {
        try database.saveBookmark(bookmark)
        bookmarks.append(bookmark)
        items.append(AnyCollectionItem(bookmark)) // Also add to items array
    }
    
    func updateBookmark(_ bookmark: Bookmark) throws {
        try database.updateBookmark(bookmark)
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
        }
        // Also update in items array
        if let itemIndex = items.firstIndex(where: { $0.id == bookmark.id }) {
            items[itemIndex] = AnyCollectionItem(bookmark)
        }
    }
    
    func deleteBookmark(_ bookmark: Bookmark) throws {
        try database.deleteBookmark(bookmark)
        bookmarks.removeAll { $0.id == bookmark.id }
        items.removeAll { $0.id == bookmark.id } // Also remove from items array
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
    }
    
    func updateCategory(_ category: Category) throws {
        try database.updateCategory(category)
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
    }
    
    func deleteCategory(_ category: Category) throws {
        try database.deleteCategory(category)
        categories.removeAll { $0.id == category.id }
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
    }
    
    func updateTag(_ tag: Tag) throws {
        try database.updateTag(tag)
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
        }
    }
    
    func deleteTag(_ tag: Tag) throws {
        try database.deleteTag(tag)
        tags.removeAll { $0.id == tag.id }
    }
    
    func tagExists(name: String, excluding: UUID? = nil) -> Bool {
        tags.contains { tag in
            if let excludeId = excluding, tag.id == excludeId {
                return false
            }
            return tag.name.lowercased() == name.lowercased()
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
        database.forceSaveAllData()
    }
    
    // Legacy image migration removed
}

