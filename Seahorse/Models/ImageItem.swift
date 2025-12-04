//
//  ImageItem.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import Foundation

struct ImageItem: CollectionItem {
    let id: UUID
    var categoryId: UUID
    var tagIds: [UUID]
    var addedDate: Date
    var modifiedDate: Date?
    var notes: String?
    var isFavorite: Bool
    var isParsed: Bool
    
    // Image-specific properties
    var imagePath: String // Path to the image file (local or remote URL)
    var thumbnailPath: String? // Optional thumbnail path
    var imageSize: CGSize? // Optional image dimensions
    
    // CollectionItem protocol requirement
    var itemType: CollectionItemType {
        return .image
    }
    
    init(
        id: UUID = UUID(),
        imagePath: String,
        categoryId: UUID,
        isFavorite: Bool = false,
        addedDate: Date = Date(),
        modifiedDate: Date? = nil,
        notes: String? = nil,
        tagIds: [UUID] = [],
        isParsed: Bool = false,
        thumbnailPath: String? = nil,
        imageSize: CGSize? = nil
    ) {
        self.id = id
        self.imagePath = imagePath
        self.categoryId = categoryId
        self.isFavorite = isFavorite
        self.addedDate = addedDate
        self.modifiedDate = modifiedDate
        self.notes = notes
        self.tagIds = tagIds
        self.isParsed = isParsed
        self.thumbnailPath = thumbnailPath
        self.imageSize = imageSize
    }
}
