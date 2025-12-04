//
//  AppConfig.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI

/// Global configuration manager for app-wide selectable options
/// This centralizes all hardcoded lists like colors, icons, etc. for easy maintenance
@MainActor
class AppConfig {
    static let shared = AppConfig()
    
    /// Available colors for tags, categories, and other UI elements
    let availableColors: [Color] = [
        .red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .gray
    ]
    
    /// Default color for new tags
    let defaultTagColor: Color = .blue
    
    /// Default color for new categories
    let defaultCategoryColor: Color = .blue
    
    private init() {
        // Private initializer for singleton pattern
    }
}

