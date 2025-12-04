//
//  LanguageManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "app_language")
            applyLanguage()
        }
    }
    
    private init() {
        // Load from UserDefaults or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage.allCases.first(where: { $0.rawValue == savedLanguage }) {
            self.appLanguage = language
        } else {
            // Default to English or match system language
            self.appLanguage = Self.detectSystemLanguage()
        }
    }
    
    private static func detectSystemLanguage() -> AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        
        if preferredLanguage.hasPrefix("zh-Hans") {
            return .simplifiedChinese
        } else if preferredLanguage.hasPrefix("zh-Hant") || preferredLanguage.hasPrefix("zh-HK") || preferredLanguage.hasPrefix("zh-TW") {
            return .traditionalChinese
        } else if preferredLanguage.hasPrefix("ja") {
            return .japanese
        } else if preferredLanguage.hasPrefix("ko") {
            return .korean
        } else if preferredLanguage.hasPrefix("fr") {
            return .french
        } else if preferredLanguage.hasPrefix("de") {
            return .german
        } else if preferredLanguage.hasPrefix("es") {
            return .spanish
        } else if preferredLanguage.hasPrefix("it") {
            return .italian
        } else if preferredLanguage.hasPrefix("pt") {
            return .portuguese
        } else if preferredLanguage.hasPrefix("ru") {
            return .russian
        } else if preferredLanguage.hasPrefix("ar") {
            return .arabic
        }
        
        return .english
    }
    
    private func applyLanguage() {
        // Set the app language override
        UserDefaults.standard.set([appLanguage.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        print("🌍 App language changed to: \(appLanguage.rawValue)")
        print("  Note: Restart the app to fully apply the language change")
    }
}

