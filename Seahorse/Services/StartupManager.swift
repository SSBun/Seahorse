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
            let currentStatus = SMAppService.mainApp.status

            if enabled {
                // Only register if not already enabled
                switch currentStatus {
                case .enabled:
                    Log.info("Launch at login already enabled", category: .general)
                    return
                case .notRegistered, .notFound:
                    try SMAppService.mainApp.register()
                    Log.info("Launch at login enabled", category: .general)
                case .requiresApproval:
                    // Try to register even if requires approval
                    try SMAppService.mainApp.register()
                    Log.info("Launch at login enabled (requires approval)", category: .general)
                @unknown default:
                    try SMAppService.mainApp.register()
                    Log.info("Launch at login enabled (unknown status)", category: .general)
                }
            } else {
                // Only unregister if currently enabled or requires approval
                switch currentStatus {
                case .enabled, .requiresApproval:
                    try SMAppService.mainApp.unregister()
                    Log.info("Launch at login disabled", category: .general)
                case .notRegistered, .notFound:
                    Log.info("Launch at login already disabled", category: .general)
                    return
                @unknown default:
                    try SMAppService.mainApp.unregister()
                    Log.info("Launch at login disabled (unknown status)", category: .general)
                }
            }
        } catch {
            Log.error("Failed to update launch at login: \(error.localizedDescription)", category: .general)
        }
    }
}

