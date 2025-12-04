//
//  Category.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

struct Category: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String // Store color as hex string for persistence
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    init(id: UUID = UUID(), name: String, icon: String, color: Color) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = color.toHex() ?? "#007AFF"
    }
    
    // Custom coding keys to handle color conversion
    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex
    }
}

// Color extensions for hex conversion
extension Color {
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else { return nil }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


