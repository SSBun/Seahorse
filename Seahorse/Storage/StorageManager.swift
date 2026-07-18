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

    private let storageRoot: URL

    // Security-scoped resource
    private var securityScopedURL: URL?

    private convenience init() {
        self.init(resolveStorageDirectory: Self.resolveStorageDirectoryWithAccess)
    }

    /// Creates a manager that resolves and retains one storage root for its lifetime.
    init(resolveStorageDirectory: () -> (root: URL, securityScopedURL: URL?)) {
        let resolvedDirectory = resolveStorageDirectory()
        storageRoot = resolvedDirectory.root
        securityScopedURL = resolvedDirectory.securityScopedURL
    }
    
    deinit {
        // Release security-scoped resource
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Directory Access
    
    /// Get the root storage directory (user-selected or default)
    func getStorageRoot() -> URL {
        storageRoot
    }
    
    /// Get the Data directory for JSON files
    func getDataDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Data", isDirectory: true)
    }
    
    /// Get the Images directory for local images
    func getImagesDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Images", isDirectory: true)
    }
    
    /// Convert a stored image path (which may be a filename, absolute path, or remote URL)
    /// into a usable absolute path for local files. Remote URLs are returned unchanged.
    func resolveImagePath(_ storedPath: String) -> String {
        guard !storedPath.isEmpty else { return storedPath }
        
        // Remote URL - return as-is
        if let url = URL(string: storedPath),
           let scheme = url.scheme,
           scheme == "http" || scheme == "https" {
            return storedPath
        }
        
        // File URL string
        if let url = URL(string: storedPath), url.isFileURL {
            let path = url.path
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
            return getImagesDirectory().appendingPathComponent(url.lastPathComponent).path
        }
        
        // Absolute path (legacy)
        if storedPath.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: storedPath) {
                return storedPath
            }
            let filename = URL(fileURLWithPath: storedPath).lastPathComponent
            return getImagesDirectory().appendingPathComponent(filename).path
        }
        
        // Filename (new behavior)
        return getImagesDirectory().appendingPathComponent(storedPath).path
    }
    
    /// Reduce an absolute image path under the Images directory to just the filename.
    /// If the path is outside the Images directory, the original string is returned.
    func relativeImageFilename(from absolutePath: String) -> String {
        let imagesPath = getImagesDirectory().path
        if absolutePath.hasPrefix(imagesPath) {
            return URL(fileURLWithPath: absolutePath).lastPathComponent
        }
        return absolutePath
    }
    
    /// Get the Backups directory for auto-backups
    func getBackupsDirectory() -> URL {
        return getStorageRoot().appendingPathComponent("Backups", isDirectory: true)
    }
    
    // MARK: - Security-Scoped Access
    
    /// Get storage directory with active security-scoped access
    /// Returns tuple: (directory URL, security-scoped parent URL if applicable)
    private static func resolveStorageDirectoryWithAccess() -> (root: URL, securityScopedURL: URL?) {
        #if os(macOS)
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
        #endif

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
