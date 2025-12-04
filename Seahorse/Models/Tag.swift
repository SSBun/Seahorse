//
//  Tag.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

struct Tag: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String // Store color as hex string for persistence
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    init(id: UUID = UUID(), name: String, color: Color) {
        self.id = id
        self.name = name
        self.colorHex = color.toHex() ?? "#007AFF"
    }
    
    // Custom coding keys to handle color conversion
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex
    }
}


