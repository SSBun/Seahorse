//
//  TextItem.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import Foundation

struct TextItem: CollectionItem {
    let id: UUID
    var categoryId: UUID
    var tagIds: [UUID]
    var addedDate: Date
    var modifiedDate: Date?
    var notes: String?
    var isFavorite: Bool
    var isParsed: Bool
    
    // Text-specific properties
    var content: String // The actual text content
    
    // Computed property for preview (first 200 characters)
    var contentPreview: String {
        if content.count <= 200 {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: 200)
        return String(content[..<index]) + "..."
    }
    
    // CollectionItem protocol requirement
    var itemType: CollectionItemType {
        return .text
    }
    
    init(
        id: UUID = UUID(),
        content: String,
        categoryId: UUID,
        isFavorite: Bool = false,
        addedDate: Date = Date(),
        modifiedDate: Date? = nil,
        notes: String? = nil,
        tagIds: [UUID] = [],
        isParsed: Bool = false
    ) {
        self.id = id
        self.content = content
        self.categoryId = categoryId
        self.isFavorite = isFavorite
        self.addedDate = addedDate
        self.modifiedDate = modifiedDate
        self.notes = notes
        self.tagIds = tagIds
        self.isParsed = isParsed
    }
}
