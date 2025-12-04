//
//  CollectionItem.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import Foundation

/// Type of collection item
enum CollectionItemType: String, Codable {
    case bookmark
    case image
    case text
}

/// Protocol defining common properties for all collection items
protocol CollectionItem: Identifiable, Hashable, Codable {
    var id: UUID { get }
    var categoryId: UUID { get set }
    var tagIds: [UUID] { get set }
    var addedDate: Date { get set }
    var modifiedDate: Date? { get set }
    var notes: String? { get set }
    var isFavorite: Bool { get set }
    var isParsed: Bool { get set }
    var itemType: CollectionItemType { get }
    
    // Tag management methods
    func hasTag(_ tagId: UUID) -> Bool
    mutating func addTag(_ tagId: UUID)
    mutating func removeTag(_ tagId: UUID)
    mutating func toggleTag(_ tagId: UUID)
}

// Default implementations for tag management
extension CollectionItem {
    func hasTag(_ tagId: UUID) -> Bool {
        tagIds.contains(tagId)
    }
    
    mutating func addTag(_ tagId: UUID) {
        if !tagIds.contains(tagId) {
            tagIds.append(tagId)
        }
    }
    
    mutating func removeTag(_ tagId: UUID) {
        tagIds.removeAll { $0 == tagId }
    }
    
    mutating func toggleTag(_ tagId: UUID) {
        if hasTag(tagId) {
            removeTag(tagId)
        } else {
            addTag(tagId)
        }
    }
}
