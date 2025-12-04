//
//  ExportImportManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import Foundation
import AppKit


@MainActor
class ExportImportManager: ObservableObject {
    static let shared = ExportImportManager()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastError: String?
    
    private init() {}
    
    /// Export all data to a folder (complete storage structure including images)
    func exportData(dataStorage: DataStorage) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Export Seahorse Data"
        openPanel.message = "Choose a folder to export your complete data (including images)"
        openPanel.prompt = "Export Here"
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            
            self.isExporting = true
            self.lastError = nil
            
            Task {
                do {
                    // Start accessing security-scoped resource
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    print("🔓 Accessing security-scoped resource for export: \(hasAccess)")
                    print("  Export URL: \(url.path)")
                    
                    // Create Seahorse subfolder with timestamp
                    let timestamp = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
                    let exportDirectory = url.appendingPathComponent("Seahorse_Export_\(timestamp)", isDirectory: true)
                    
                    // Create directory structure
                    try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
                    
                    // Get source storage directories
                    let storageManager = StorageManager.shared
                    let sourceImagesDir = storageManager.getImagesDirectory()
                    
                    // Create destination directories
                    let destDataDir = exportDirectory.appendingPathComponent("Data", isDirectory: true)
                    let destImagesDir = exportDirectory.appendingPathComponent("Images", isDirectory: true)
                    try FileManager.default.createDirectory(at: destDataDir, withIntermediateDirectories: true)
                    try FileManager.default.createDirectory(at: destImagesDir, withIntermediateDirectories: true)
                    
                    // Export JSON data files
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    
                    // Export all items (including bookmarks, images and text items)
                    let itemsData = try encoder.encode(dataStorage.items)
                    try itemsData.write(to: destDataDir.appendingPathComponent("items.json"))
                    
                    // Export categories.json
                    let categoriesData = try encoder.encode(dataStorage.categories)
                    try categoriesData.write(to: destDataDir.appendingPathComponent("categories.json"))
                    
                    // Export tags.json
                    let tagsData = try encoder.encode(dataStorage.tags)
                    try tagsData.write(to: destDataDir.appendingPathComponent("tags.json"))
                    
                    // Export preferences.json
                    let preferencesData = try encoder.encode([String: String]())
                    try preferencesData.write(to: destDataDir.appendingPathComponent("preferences.json"))
                    
                    // Copy Images directory (all local image files)
                    if FileManager.default.fileExists(atPath: sourceImagesDir.path) {
                        let imageFiles = try FileManager.default.contentsOfDirectory(at: sourceImagesDir, includingPropertiesForKeys: nil)
                        for imageFile in imageFiles {
                            let destFile = destImagesDir.appendingPathComponent(imageFile.lastPathComponent)
                            try FileManager.default.copyItem(at: imageFile, to: destFile)
                        }
                        print("✅ Copied \(imageFiles.count) image file(s)")
                    }
                    
                    print("✅ Export successful: \(exportDirectory.path)")
                    
                    await MainActor.run {
                        self.isExporting = false
                        // Show success notification with path
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowToast"),
                            object: nil,
                            userInfo: ["message": "Complete data exported to: \(exportDirectory.lastPathComponent)"]
                        )
                        
                        // Open the export folder in Finder
                        NSWorkspace.shared.open(exportDirectory)
                    }
                } catch {
                    print("❌ Export failed: \(error)")
                    await MainActor.run {
                        self.isExporting = false
                        self.lastError = "Export failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// Import data from a folder or JSON file
    func importData(dataStorage: DataStorage) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Seahorse Data"
        openPanel.message = "Choose a Seahorse export folder or JSON file"
        openPanel.prompt = "Import"
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            
            self.isImporting = true
            self.lastError = nil
            
            Task {
                do {
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    
                    // Start accessing security-scoped resource
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    print("🔓 Accessing security-scoped resource for import: \(hasAccess)")
                    print("  Import URL: \(url.path)")
                    
                    if isDirectory.boolValue {
                        // Import from folder
                        try await self.importFromFolder(url, into: dataStorage)
                    } else {
                        throw NSError(domain: "Seahorse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please select a folder containing exported data"])
                    }
                } catch {
                    await MainActor.run {
                        self.isImporting = false
                        self.lastError = "Import failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// Import from folder (complete storage structure including images)
    private func importFromFolder(_ folderURL: URL, into dataStorage: DataStorage) async throws {
        let decoder = JSONDecoder()
        let fileManager = FileManager.default
        
        // Check for Data/Images subdirectories
        let dataDir = folderURL.appendingPathComponent("Data", isDirectory: true)
        let imagesDir = folderURL.appendingPathComponent("Images", isDirectory: true)
        
        guard fileManager.fileExists(atPath: dataDir.path) else {
            throw NSError(domain: "Seahorse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid export format: Data directory not found"])
        }
        
        // Read JSON files from Data directory
        let categoriesURL = dataDir.appendingPathComponent("categories.json")
        let tagsURL = dataDir.appendingPathComponent("tags.json")
        let itemsURL = dataDir.appendingPathComponent("items.json")
        
        var categories: [Category] = []
        var tags: [Tag] = []
        var items: [AnyCollectionItem] = []
        
        // Load items.json (required)
        guard fileManager.fileExists(atPath: itemsURL.path) else {
            throw NSError(domain: "Seahorse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid export format: items.json not found"])
        }
        
        let itemsData = try Data(contentsOf: itemsURL)
        items = try decoder.decode([AnyCollectionItem].self, from: itemsData)
        
        // Load categories if file exists
        if fileManager.fileExists(atPath: categoriesURL.path) {
            let data = try Data(contentsOf: categoriesURL)
            categories = try decoder.decode([Category].self, from: data)
        }
        
        // Load tags if file exists
        if fileManager.fileExists(atPath: tagsURL.path) {
            let data = try Data(contentsOf: tagsURL)
            tags = try decoder.decode([Tag].self, from: data)
        }
        
        // Copy images if Images directory exists
        var imagesCopied = 0
        if fileManager.fileExists(atPath: imagesDir.path) {
            let storageManager = StorageManager.shared
            let destImagesDir = storageManager.getImagesDirectory()
            
            // Ensure destination directory exists
            try fileManager.createDirectory(at: destImagesDir, withIntermediateDirectories: true)
            
            // Copy all image files
            let imageFiles = try fileManager.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            for imageFile in imageFiles {
                // Skip directories
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: imageFile.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                    continue
                }
                
                let destFile = destImagesDir.appendingPathComponent(imageFile.lastPathComponent)
                
                // Skip if file already exists
                if fileManager.fileExists(atPath: destFile.path) {
                    continue
                }
                
                try fileManager.copyItem(at: imageFile, to: destFile)
                imagesCopied += 1
            }
            print("✅ Copied \(imagesCopied) image file(s)")
        }
        
        // Merge imported data
        await MainActor.run {
            self.mergeItemsData(items: items, categories: categories, tags: tags, into: dataStorage)
            
            self.isImporting = false
            
            var message = "Data imported: \(items.count) items, \(categories.count) categories, \(tags.count) tags"
            if imagesCopied > 0 {
                message += ", \(imagesCopied) images"
            }
            
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowToast"),
                object: nil,
                userInfo: ["message": message]
            )
        }
    }
    
    private func mergeItemsData(items: [AnyCollectionItem], categories: [Category], tags: [Tag], into dataStorage: DataStorage) {
        // Import categories (skip duplicates by name)
        for category in categories {
            if !dataStorage.categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) {
                try? dataStorage.addCategory(category)
            }
        }
        
        // Import tags (skip duplicates by name)
        for tag in tags {
            if !dataStorage.tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) {
                try? dataStorage.addTag(tag)
            }
        }
        
        // Import all items (skip duplicates by ID)
        for item in items {
            if !dataStorage.items.contains(where: { $0.id == item.id }) {
                dataStorage.addItem(item)
            }
        }
    }
    
}

