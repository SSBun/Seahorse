//
//  AppearanceManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

enum CardAspectRatio: String, CaseIterable, Codable {
    case square = "1:1"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case threeTwo = "3:2"

    var value: CGFloat? {
        switch self {
        case .square: return 1.0
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .threeTwo: return 3.0 / 2.0
        }
    }
}

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var selectedMode: AppearanceMode = .system {
        didSet {
            applyAppearance()
            savePreference()
        }
    }
    
    @Published var accentColor: Color = .blue {
        didSet {
            saveAccentColor()
        }
    }

    @Published var gridColumnCount: Int = 3 {
        didSet {
            saveGridColumnCount()
        }
    }

    // Auto column count: true means automatically adjust columns based on window size
    @Published var isAutoColumnCount: Bool = true {
        didSet {
            saveAutoColumnCount()
        }
    }

    // Minimum card width in Auto mode (in points)
    @Published var cardMinWidth: CGFloat = 280 {
        didSet {
            saveCardMinWidth()
        }
    }

    @Published var cardAspectRatio: CardAspectRatio = .fourThree {
        didSet {
            saveCardAspectRatio()
        }
    }

    private init() {
        loadPreferences()
        applyAppearance()
    }
    
    func applyAppearance() {
        switch selectedMode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    private func savePreference() {
        // Save to UserDefaults for fast access
        UserDefaults.standard.set(selectedMode.rawValue, forKey: "appearance_mode")
        
        // Also save to JSON for backup/export
        try? DataStorage.shared.savePreference(key: "appearance_mode", value: selectedMode.rawValue)
    }
    
    private func saveAccentColor() {
        if let hex = accentColor.toHex() {
            // Save to UserDefaults for fast access
            UserDefaults.standard.set(hex, forKey: "accent_color")
            
            // Also save to JSON for backup/export
            try? DataStorage.shared.savePreference(key: "accent_color", value: hex)
        }
    }
    
    private func loadPreferences() {
        // Load appearance mode
        if let modeString = UserDefaults.standard.string(forKey: "appearance_mode"),
           let mode = AppearanceMode(rawValue: modeString) {
            selectedMode = mode
        }
        
        // Load accent color
        if let hex = UserDefaults.standard.string(forKey: "accent_color"),
           let color = Color(hex: hex) {
            accentColor = color
        }

        // Load grid column count
        let savedCount = UserDefaults.standard.integer(forKey: "grid_column_count")
        if savedCount == 0 {
            isAutoColumnCount = true
        } else if savedCount >= 2 && savedCount <= 6 {
            gridColumnCount = savedCount
            isAutoColumnCount = false
        }

        // Load card aspect ratio
        if let ratioString = UserDefaults.standard.string(forKey: "card_aspect_ratio"),
           let ratio = CardAspectRatio(rawValue: ratioString) {
            cardAspectRatio = ratio
        }

        // Load card minimum width
        let savedMinWidth = UserDefaults.standard.double(forKey: "card_min_width")
        if savedMinWidth >= 120 && savedMinWidth <= 400 {
            cardMinWidth = CGFloat(savedMinWidth)
        }
    }

    private func saveGridColumnCount() {
        if isAutoColumnCount {
            UserDefaults.standard.set(0, forKey: "grid_column_count")
        } else {
            UserDefaults.standard.set(gridColumnCount, forKey: "grid_column_count")
        }
    }

    private func saveAutoColumnCount() {
        if isAutoColumnCount {
            UserDefaults.standard.set(0, forKey: "grid_column_count")
        } else {
            UserDefaults.standard.set(gridColumnCount, forKey: "grid_column_count")
        }
    }

    private func saveCardMinWidth() {
        UserDefaults.standard.set(Double(cardMinWidth), forKey: "card_min_width")
    }

    private func saveCardAspectRatio() {
        UserDefaults.standard.set(cardAspectRatio.rawValue, forKey: "card_aspect_ratio")
    }
}


