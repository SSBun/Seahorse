//
//  StartupManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/05.
//

import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class StartupManager: ObservableObject {
    static let shared = StartupManager()
    
    @Published var launchAtLogin: Bool {
        didSet {
            updateLoginItem(enabled: launchAtLogin)
            persistPreference()
        }
    }
    
    private static let launchAtLoginKey = "launchAtLogin"
    
    private init() {
        let storedValue = UserDefaults.standard.object(forKey: Self.launchAtLoginKey) as? Bool ?? false
        self.launchAtLogin = storedValue
        
        // Keep the login item state aligned with the stored preference on startup.
        updateLoginItem(enabled: storedValue)
    }
    
    /// Re-applies the current preference to the system login item.
    func applyCurrentPreference() {
        updateLoginItem(enabled: launchAtLogin)
    }
    
    // MARK: - Private Helpers
    
    private func persistPreference() {
        UserDefaults.standard.set(launchAtLogin, forKey: Self.launchAtLoginKey)
    }
    
    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else {
                    return
                }
                try SMAppService.mainApp.register()
                Log.info("Launch at login enabled", category: .general)
            } else {
                guard SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval else {
                    return
                }
                try SMAppService.mainApp.unregister()
                Log.info("Launch at login disabled", category: .general)
            }
        } catch {
            Log.error("Failed to update launch at login: \(error.localizedDescription)", category: .general)
        }
    }
}

