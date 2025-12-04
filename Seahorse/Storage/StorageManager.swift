//
//  StorageManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import Foundation
import OSLog

/// Centralized storage path management
/// Provides unified access to all storage directories
class StorageManager {
    static let shared = StorageManager()
    
    // Security-scoped resource
    private var securityScopedURL: URL?
    
    private init() {
        // Initialize and acquire security-scoped access
        let (_, scopedURL) = getStorageDirectoryWithAccess()
        self.securityScopedURL = scopedURL
    }
    
    deinit {
        // Release security-scoped resource
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Directory Access
    
    /// Get the root storage directory (user-selected or default)
    func getStorageRoot() -> URL {
        let (directory, _) = getStorageDirectoryWithAccess()
        return directory
    }
    
    /// Get the Data directory for JSON files
    func getDataDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Data", isDirectory: true)
    }
    
    /// Get the Images directory for local images
    func getImagesDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Images", isDirectory: true)
    }
    
    /// Get the Backups directory for auto-backups
    func getBackupsDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Backups", isDirectory: true)
    }
    
    // MARK: - Security-Scoped Access
    
    /// Get storage directory with active security-scoped access
    /// Returns tuple: (directory URL, security-scoped parent URL if applicable)
    private func getStorageDirectoryWithAccess() -> (URL, URL?) {
        // Try to resolve security-scoped bookmark first
        if let bookmarkData = UserDefaults.standard.data(forKey: "seahorse.storage.bookmarkData") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if !isStale {
                    // Start accessing security-scoped resource
                    if url.startAccessingSecurityScopedResource() {
                        let seahorseDirectory = url.appendingPathComponent("Seahorse", isDirectory: true)
                        Log.info("📂 Using security-scoped bookmark path: \(seahorseDirectory.path)", category: .storage)
                        Log.info("🔓 Active security-scoped access established", category: .storage)
                        
                        // Verify we can actually access the directory
                        if FileManager.default.isReadableFile(atPath: seahorseDirectory.path) {
                            Log.info("✅ Directory is readable", category: .storage)
                        } else {
                            Log.warning("⚠️ Directory not readable yet, but access granted", category: .storage)
                        }
                        
                        return (seahorseDirectory, url)
                    } else {
                        Log.error("❌ Failed to start accessing security-scoped resource", category: .storage)
                    }
                } else {
                    Log.warning("⚠️ Security-scoped bookmark is stale", category: .storage)
                }
            } catch {
                Log.error("❌ Failed to resolve bookmark: \(error)", category: .storage)
            }
        }
        
        
        // Default path (Application Support - no security scope needed)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultPath = appSupport.appendingPathComponent("Seahorse", isDirectory: true)
        Log.info("📂 Using default path: \(defaultPath.path)", category: .storage)
        return (defaultPath, nil)
    }
    
    // MARK: - Directory Initialization
    
    /// Ensure all required directories exist
    func ensureDirectoriesExist() {
        let directories = [
            getStorageRoot(),
            getDataDirectory(),
            getImagesDirectory(),
            getBackupsDirectory()
        ]
        
        for directory in directories {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                Log.info("✓ Directory ready: \(directory.lastPathComponent)", category: .storage)
            } catch {
                Log.error("❌ Failed to create directory \(directory.lastPathComponent): \(error)", category: .storage)
            }
        }
    }
}
