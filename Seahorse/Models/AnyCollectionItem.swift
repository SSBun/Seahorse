//
//  AnyCollectionItem.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import Foundation

/// Type-erased wrapper for CollectionItem to enable heterogeneous arrays
struct AnyCollectionItem: Identifiable, Codable {
    let id: UUID
    let itemType: CollectionItemType
    
    private enum CodingKeys: String, CodingKey {
        case id, itemType, bookmark, imageItem, textItem
    }
    
    // Stored item
    private var bookmark: Bookmark?
    private var imageItem: ImageItem?
    private var textItem: TextItem?
    
    // MARK: - Initializers
    
    init(_ bookmark: Bookmark) {
        self.id = bookmark.id
        self.itemType = .bookmark
        self.bookmark = bookmark
    }
    
    init(_ imageItem: ImageItem) {
        self.id = imageItem.id
        self.itemType = .image
        self.imageItem = imageItem
    }
    
    init(_ textItem: TextItem) {
        self.id = textItem.id
        self.itemType = .text
        self.textItem = textItem
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        itemType = try container.decode(CollectionItemType.self, forKey: .itemType)
        
        switch itemType {
        case .bookmark:
            bookmark = try? container.decode(Bookmark.self, forKey: .bookmark)
        case .image:
            imageItem = try? container.decode(ImageItem.self, forKey: .imageItem)
        case .text:
            textItem = try? container.decode(TextItem.self, forKey: .textItem)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(itemType, forKey: .itemType)
        
        switch itemType {
        case .bookmark:
            if let bookmark = bookmark {
                try container.encode(bookmark, forKey: .bookmark)
            }
        case .image:
            if let imageItem = imageItem {
                try container.encode(imageItem, forKey: .imageItem)
            }
        case .text:
            if let textItem = textItem {
                try container.encode(textItem, forKey: .textItem)
            }
        }
    }
    
    // MARK: - Accessors
    
    var asBookmark: Bookmark? { bookmark }
    var asImageItem: ImageItem? {imageItem }
    var asTextItem: TextItem? { textItem }
    
    /// Get the added date from any item type
    var addedDate: Date {
        if let bookmark = bookmark {
            return bookmark.addedDate
        } else if let imageItem = imageItem {
            return imageItem.addedDate
        } else if let textItem = textItem {
            return textItem.addedDate
        }
        return Date()
    }
}
