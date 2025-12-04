//
//  MockDatabase.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/04.
//

import Foundation

class MockDatabase: DatabaseProtocol {
    private var items: [AnyCollectionItem] = []
    private var categories: [Category] = []
    private var tags: [Tag] = []
    private var preferences: [String: String] = [:]
    
    init() {
        // Add some default data
        let defaultCategory = Category(name: "All Bookmarks", icon: "folder.fill", color: .blue)
        categories = [defaultCategory]
    }
    
    // MARK: - Bookmark Operations
    
    func saveBookmark(_ bookmark: Bookmark) throws {
        items.append(AnyCollectionItem(bookmark))
    }
    
    func updateBookmark(_ bookmark: Bookmark) throws {
        if let index = items.firstIndex(where: { $0.id == bookmark.id }) {
            items[index] = AnyCollectionItem(bookmark)
        }
    }
    
    func deleteBookmark(_ bookmark: Bookmark) throws {
        items.removeAll { $0.id == bookmark.id }
    }
    
    func fetchAllBookmarks() throws -> [Bookmark] {
        items.compactMap { $0.asBookmark }
    }
    
    func fetchBookmarks(categoryId: UUID) throws -> [Bookmark] {
        items.compactMap { $0.asBookmark }.filter { $0.categoryId == categoryId }
    }
    
    func fetchBookmarks(tagId: UUID) throws -> [Bookmark] {
        items.compactMap { $0.asBookmark }.filter { $0.tagIds.contains(tagId) }
    }
    
    func fetchFavoriteBookmarks() throws -> [Bookmark] {
        items.compactMap { $0.asBookmark }.filter { $0.isFavorite }
    }
    
    // MARK: - Item Operations
    
    func fetchAllItems() throws -> [AnyCollectionItem] {
        items
    }
    
    func saveItem(_ item: AnyCollectionItem) throws {
        items.append(item)
    }
    
    func updateItem(_ item: AnyCollectionItem) throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
    
    func deleteItem(_ item: AnyCollectionItem) throws {
        items.removeAll { $0.id == item.id }
    }
    
    // MARK: - Category Operations
    
    func saveCategory(_ category: Category) throws {
        categories.append(category)
    }
    
    func updateCategory(_ category: Category) throws {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
    }
    
    func deleteCategory(_ category: Category) throws {
        categories.removeAll { $0.id == category.id }
    }
    
    func fetchAllCategories() throws -> [Category] {
        categories
    }
    
    func categoryExists(name: String) throws -> Bool {
        categories.contains { $0.name == name }
    }
    
    // MARK: - Tag Operations
    
    func saveTag(_ tag: Tag) throws {
        tags.append(tag)
    }
    
    func updateTag(_ tag: Tag) throws {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
        }
    }
    
    func deleteTag(_ tag: Tag) throws {
        tags.removeAll { $0.id == tag.id }
    }
    
    func fetchAllTags() throws -> [Tag] {
        tags
    }
    
    func tagExists(name: String) throws -> Bool {
        tags.contains { $0.name == name }
    }
    
    // MARK: - Preferences Operations
    
    func savePreference(key: String, value: String) throws {
        preferences[key] = value
    }
    
    func fetchPreference(key: String) throws -> String? {
        preferences[key]
    }
    
    func deletePreference(key: String) throws {
        preferences.removeValue(forKey: key)
    }
    
    func forceSaveAllData() {
        // No-op for mock
    }
}
