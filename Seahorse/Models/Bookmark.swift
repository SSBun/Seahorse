//
//  Bookmark.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

struct Bookmark: CollectionItem {
    let id: UUID
    var title: String
    var url: String
    var icon: String
    var categoryId: UUID
    var isFavorite: Bool
    var addedDate: Date
    var modifiedDate: Date?
    var notes: String?
    var tagIds: [UUID]
    var isParsed: Bool
    var metadata: WebMetadata? // OGP/Twitter Card Data
    
    // CollectionItem protocol requirement
    var itemType: CollectionItemType {
        return .bookmark
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        icon: String = "link.circle.fill",
        categoryId: UUID,
        isFavorite: Bool = false,
        addedDate: Date = Date(),
        modifiedDate: Date? = nil,
        notes: String? = nil,
        tagIds: [UUID] = [],
        isParsed: Bool = false,
        metadata: WebMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.icon = icon
        self.categoryId = categoryId
        self.isFavorite = isFavorite
        self.addedDate = addedDate
        self.modifiedDate = modifiedDate
        self.notes = notes
        self.tagIds = tagIds
        self.isParsed = isParsed
        self.metadata = metadata
    }
}



