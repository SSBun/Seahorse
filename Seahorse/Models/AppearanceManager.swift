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
    
    @Published var cardStyle: CardStyle = .standard {
        didSet {
            saveCardStyle()
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
    
    private func saveCardStyle() {
        // Save to UserDefaults for fast access
        UserDefaults.standard.set(cardStyle.rawValue, forKey: "card_style")
        
        // Also save to JSON for backup/export
        try? DataStorage.shared.savePreference(key: "card_style", value: cardStyle.rawValue)
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
        
        // Load card style
        if let styleString = UserDefaults.standard.string(forKey: "card_style"),
           let style = CardStyle(rawValue: styleString) {
            cardStyle = style
        }
    }
}

