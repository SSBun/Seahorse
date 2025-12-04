//
//  WebMetadata.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import Foundation

struct WebMetadata: Codable, Hashable {
    var title: String?
    var description: String?
    var imageURL: String?
    var siteName: String?
    var url: String?
    var faviconURL: String?
    
    init(
        title: String? = nil,
        description: String? = nil,
        imageURL: String? = nil,
        siteName: String? = nil,
        url: String? = nil,
        faviconURL: String? = nil
    ) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName
        self.url = url
        self.faviconURL = faviconURL
    }
}
