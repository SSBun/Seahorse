//
//  StoragePathManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import Foundation
import AppKit
import OSLog

struct MigrationResult {
    let migratedFiles: Int
    let skippedFiles: Int
    let errors: [String]
    
    var isSuccess: Bool {
        errors.isEmpty
    }
    
    var hasData: Bool {
        migratedFiles > 0 || skippedFiles > 0
    }
}

@MainActor
class StoragePathManager: ObservableObject {
    static let shared = StoragePathManager()
    
    @Published var customPath: String?
    
    private let bookmarkDataKey = "seahorse.storage.bookmarkData"
    private let userDefaultsKey = "seahorse.storage.customPath"
    private var currentSecurityScopedURL: URL?
    
    private init() {
        // Try to resolve security-scoped bookmark first
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkDataKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    Log.warning("⚠️ Security-scoped bookmark is stale, will need to re-select folder", category: .storage)
                } else if url.startAccessingSecurityScopedResource() {
                    // Store the parent URL that has security access
                    currentSecurityScopedURL = url
                    // Set customPath to the Seahorse subdirectory
                    let seahorseDirectory = url.appendingPathComponent("Seahorse", isDirectory: true)
                    customPath = seahorseDirectory.path
                    Log.info("✅ Security-scoped bookmark resolved and accessed", category: .storage)
                    Log.info("  Parent URL (with access): \(url.path)", category: .storage)
                    Log.info("  Seahorse directory: \(seahorseDirectory.path)", category: .storage)
                } else {
                    Log.error("❌ Failed to access security-scoped resource", category: .storage)
                }
            } catch {
                Log.error("❌ Failed to resolve bookmark: \(error)", category: .storage)
            }
        }
    }
    
    deinit {
        // Stop accessing security-scoped resource
        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
    
    /// Get the current storage directory URL
    func getStorageDirectory() -> URL {
        if let customPath = customPath, !customPath.isEmpty {
            // Expand tilde and resolve path
            let expandedPath = NSString(string: customPath).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath, isDirectory: true)
        }
        
        // Default path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Seahorse", isDirectory: true)
    }
    
    /// Get display path (with tilde)
    func getDisplayPath() -> String {
        let directory = getStorageDirectory()
        let path = directory.path
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        
        if path.hasPrefix(homeDirectory) {
            return "~" + path.dropFirst(homeDirectory.count)
        }
        return path
    }
    
    /// Change storage location
    func changeStorageLocation(dataStorage: DataStorage, completion: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Choose Storage Location"
        openPanel.message = "Select a folder to store your bookmarks and settings"
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else {
                completion(false)
                return
            }
            
            // Create security-scoped bookmark for the selected URL
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // Create Seahorse subdirectory
                let seahorseDirectory = url.appendingPathComponent("Seahorse", isDirectory: true)
                
                // IMPORTANT: Force save all current data to disk BEFORE migration
                Log.info("📝 Forcing data save before migration...", category: .storage)
                dataStorage.forceSaveAllData()
                Log.info("  ✓ All current data saved to disk", category: .storage)
                
                // Create new directory if needed
                try FileManager.default.createDirectory(at: seahorseDirectory, withIntermediateDirectories: true)
                
                // Get current storage directory before changing
                let oldDirectory = self.getStorageDirectory()
                
                Log.info("🔄 Starting migration:", category: .storage)
                Log.info("  From: \(oldDirectory.path)", category: .storage)
                Log.info("  To: \(seahorseDirectory.path)", category: .storage)
                
                // Migrate data from old location to new location
                let migrationResult = self.migrateData(from: oldDirectory, to: seahorseDirectory)
                
                // Stop accessing old security-scoped resource
                if let oldURL = self.currentSecurityScopedURL {
                    oldURL.stopAccessingSecurityScopedResource()
                }
                
                // Save security-scoped bookmark
                UserDefaults.standard.set(bookmarkData, forKey: self.bookmarkDataKey)
                
                // Save new path
                let path = seahorseDirectory.path
                self.customPath = path
                UserDefaults.standard.set(path, forKey: self.userDefaultsKey)
                
                // Start accessing new security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    self.currentSecurityScopedURL = url
                    Log.info("✅ Security-scoped access granted to: \(url.path)", category: .storage)
                }
                
                Log.info("✅ Migration complete. New storage path and security bookmark saved.", category: .storage)
                
                // Notify that storage location changed - app will need to restart
                DispatchQueue.main.async {
                    self.showRestartAlert(migrationResult: migrationResult)
                    completion(true)
                }
            } catch {
                Log.error("❌ Migration failed: \(error)", category: .storage)
                DispatchQueue.main.async {
                    self.showErrorAlert(message: "Failed to create new storage directory: \(error.localizedDescription)")
                }
                completion(false)
            }
        }
    }
    
    /// Migrate data files from old location to new location
    private func migrateData(from oldDirectory: URL, to newDirectory: URL) -> MigrationResult {
        let fileManager = FileManager.default
        let dataFiles = ["items.json", "categories.json", "tags.json", "preferences.json"]
        
        var migratedFiles = 0
        var skippedFiles = 0
        var errors: [String] = []
        
        for fileName in dataFiles {
            let oldFile = oldDirectory.appendingPathComponent(fileName)
            let newFile = newDirectory.appendingPathComponent(fileName)
            
            // Check if file exists in old location
            guard fileManager.fileExists(atPath: oldFile.path) else {
                skippedFiles += 1
                continue
            }
            
            do {
                // If file already exists in new location, skip it to avoid overwriting
                if fileManager.fileExists(atPath: newFile.path) {
                    skippedFiles += 1
                    continue
                }
                
                // Copy file to new location
                try fileManager.copyItem(at: oldFile, to: newFile)
                migratedFiles += 1
            } catch {
                errors.append("\(fileName): \(error.localizedDescription)")
            }
        }
        
        return MigrationResult(
            migratedFiles: migratedFiles,
            skippedFiles: skippedFiles,
            errors: errors
        )
    }
    
    /// Reset to default storage location
    func resetToDefaultLocation() {
        // Stop accessing security-scoped resource
        if let url = currentSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            currentSecurityScopedURL = nil
        }
        
        // Clear saved data
        customPath = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: bookmarkDataKey)
        
        Log.info("✅ Reset to default storage location", category: .storage)
        showRestartAlert(migrationResult: nil)
    }
    
    private func showRestartAlert(migrationResult: MigrationResult?) {
        let alert = NSAlert()
        alert.messageText = "Restart Required"
        
        var infoText = "The storage location has been changed."
        
        if let result = migrationResult {
            if result.migratedFiles > 0 {
                infoText += "\n\n✅ Successfully migrated \(result.migratedFiles) data file(s) to the new location."
            }
            
            if result.skippedFiles > 0 {
                infoText += "\n\n⚠️ Skipped \(result.skippedFiles) file(s) (not found or already exists in new location)."
            }
            
            if !result.errors.isEmpty {
                infoText += "\n\n❌ Errors:\n" + result.errors.joined(separator: "\n")
            }
            
            if !result.hasData {
                infoText += "\n\nℹ️ No existing data found to migrate."
            }
        }
        
        infoText += "\n\nPlease restart Seahorse for the changes to take effect."
        
        alert.informativeText = infoText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit Now")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Storage Location Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

