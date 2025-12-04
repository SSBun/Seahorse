//
//  DatabaseProtocol.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

protocol DatabaseProtocol {
    // Bookmark operations
    func saveBookmark(_ bookmark: Bookmark) throws
    func updateBookmark(_ bookmark: Bookmark) throws
    func deleteBookmark(_ bookmark: Bookmark) throws
    func fetchAllBookmarks() throws -> [Bookmark]
    func fetchBookmarks(categoryId: UUID) throws -> [Bookmark]
    func fetchBookmarks(tagId: UUID) throws -> [Bookmark]
    func fetchFavoriteBookmarks() throws -> [Bookmark]
    
    // MARK: - Item Operations
    func fetchAllItems() throws -> [AnyCollectionItem]
    func saveItem(_ item: AnyCollectionItem) throws
    func updateItem(_ item: AnyCollectionItem) throws
    func deleteItem(_ item: AnyCollectionItem) throws
    
    // Category operations
    func saveCategory(_ category: Category) throws
    func updateCategory(_ category: Category) throws
    func deleteCategory(_ category: Category) throws
    func fetchAllCategories() throws -> [Category]
    func categoryExists(name: String) throws -> Bool
    
    // Tag operations
    func saveTag(_ tag: Tag) throws
    func updateTag(_ tag: Tag) throws
    func deleteTag(_ tag: Tag) throws
    func fetchAllTags() throws -> [Tag]
    func tagExists(name: String) throws -> Bool
    
    // Preferences operations
    func savePreference(key: String, value: String) throws
    func fetchPreference(key: String) throws -> String?
    func deletePreference(key: String) throws
    
    // Force save all data (for migration purposes)
    func forceSaveAllData()
}

enum DatabaseError: Error, LocalizedError {
    case saveFailed
    case updateFailed
    case deleteFailed
    case fetchFailed
    case duplicateEntry
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .saveFailed: return "Failed to save data"
        case .updateFailed: return "Failed to update data"
        case .deleteFailed: return "Failed to delete data"
        case .fetchFailed: return "Failed to fetch data"
        case .duplicateEntry: return "Item already exists"
        case .notFound: return "Item not found"
        }
    }
}

