//
//  ExportImportManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

#if os(macOS)
import Foundation
import AppKit


@MainActor
class ExportImportManager: ObservableObject {
    static let shared = ExportImportManager()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var isBackingUp = false
    @Published var isSyncingBookmarkIndex = false
    @Published var lastError: String?

    private init() {}

    private struct BookmarkIndexPayload: Codable {
        let generatedAt: String
        let bookmarks: [BookmarkIndexBookmark]
        let categories: [BookmarkIndexCategory]
        let tags: [BookmarkIndexTag]
    }

    private struct BookmarkIndexBookmark: Codable {
        let id: String
        let title: String
        let url: String
        let domain: String
        let categoryId: String
        let categoryName: String
        let isFavorite: Bool
        let addedDate: String
        let modifiedDate: String?
        let notes: String?
        let description: String?
        let siteName: String?
        let tagIds: [String]
        let tagNames: [String]
    }

    private struct BookmarkIndexCategory: Codable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
    }

    private struct BookmarkIndexTag: Codable {
        let id: String
        let name: String
        let colorHex: String
    }

    private struct ExportSnapshot {
        let items: [AnyCollectionItem]
        let categories: [Category]
        let tags: [Tag]
        let smartCollections: [SmartCollection]
        let bookmarks: [Bookmark]
        let sourceImagesDirectory: URL
    }

    private struct ImportedData {
        let items: [AnyCollectionItem]
        let categories: [Category]
        let tags: [Tag]
        let smartCollections: [SmartCollection]
        let imagesCopied: Int
    }

    // MARK: - Backup Methods

    /// Get the parent directory of the current storage location
    func getBackupDirectory() -> URL {
        let storageDir = StoragePathManager.shared.getStorageDirectory()
        return storageDir.deletingLastPathComponent()
    }

    /// Scan for existing backup folders in the backup directory
    func scanBackupFolders() async -> [URL] {
        let backupDir = getBackupDirectory()
        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: backupDir.path) else { return [] }
            do {
                return try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
                    .filter { $0.lastPathComponent.hasPrefix("Seahorse_Export_") && $0.hasDirectoryPath }
                    .sorted { $0.lastPathComponent > $1.lastPathComponent }
            } catch {
                return []
            }
        }.value
    }

    /// Format backup folder name for display (e.g., "2026-4-2-193055" -> "2026-04-02 19:30:55")
    func formatBackupName(_ url: URL) -> String {
        let name = url.lastPathComponent
        // Remove "Seahorse_Export_" prefix
        let timestamp = name.replacingOccurrences(of: "Seahorse_Export_", with: "")

        // Parse timestamp: yyyy-M-d-HHmmss
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d-HHmmss"
        if let date = formatter.date(from: timestamp) {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        return timestamp
    }

    /// Backup data to the parent directory of the storage folder
    func backupToDataFolder(dataStorage: DataStorage, completion: @escaping (Bool, URL?) -> Void) {
        isBackingUp = true
        lastError = nil
        let backupDirectory = getBackupDirectory()
        let snapshot = exportSnapshot(from: dataStorage)

        Task {
            do {
                let exportDirectory = try await Task.detached(priority: .utility) {
                    try Self.writeFullExport(snapshot, to: backupDirectory)
                }.value

                print("✅ Backup successful: \(exportDirectory.path)")

                await MainActor.run {
                    self.isBackingUp = false
                    completion(true, exportDirectory)
                }
            } catch {
                print("❌ Backup failed: \(error)")
                await MainActor.run {
                    self.isBackingUp = false
                    self.lastError = "Backup failed: \(error.localizedDescription)"
                    completion(false, nil)
                }
            }
        }
    }

    func syncBookmarkIndexToBackupFolder(dataStorage: DataStorage, completion: @escaping (Bool, URL?) -> Void) {
        guard !isSyncingBookmarkIndex else { return }

        isSyncingBookmarkIndex = true
        lastError = nil
        let outputDirectory = getBackupDirectory().appendingPathComponent("Seahorse_Bookmarks", isDirectory: true)
        let snapshot = exportSnapshot(from: dataStorage)

        Task {
            do {
                try await Task.detached(priority: .utility) {
                    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                    try Self.writeBookmarkIndexHTML(snapshot: snapshot, to: outputDirectory)
                }.value

                await MainActor.run {
                    self.isSyncingBookmarkIndex = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowToast"),
                        object: nil,
                        userInfo: ["message": "Mobile bookmark page synced: \(outputDirectory.lastPathComponent)"]
                    )
                    NSWorkspace.shared.open(outputDirectory)
                    completion(true, outputDirectory)
                }
            } catch {
                await MainActor.run {
                    self.isSyncingBookmarkIndex = false
                    self.lastError = "Bookmark page sync failed: \(error.localizedDescription)"
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowToast"),
                        object: nil,
                        userInfo: [
                            "message": self.lastError ?? "Bookmark page sync failed",
                            "icon": "xmark.circle.fill"
                        ]
                    )
                    completion(false, nil)
                }
            }
        }
    }

    /// Restore from a backup folder
    func restoreFromBackup(_ backupURL: URL, dataStorage: DataStorage, completion: @escaping (Bool) -> Void) {
        isImporting = true
        lastError = nil

        Task {
            do {
                try await importFromFolder(backupURL, into: dataStorage)
                await MainActor.run {
                    self.isImporting = false
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.lastError = "Restore failed: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
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
            let snapshot = self.exportSnapshot(from: dataStorage)
            
            Task {
                do {
                    let exportDirectory = try await Task.detached(priority: .utility) {
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer {
                            if hasAccess { url.stopAccessingSecurityScopedResource() }
                        }
                        return try Self.writeFullExport(snapshot, to: url)
                    }.value
                    
                    print("✅ Export successful: \(exportDirectory.path)")
                    
                    await MainActor.run {
                        self.isExporting = false
                        // Show success notification with path
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowToast"),
                            object: nil,
                            userInfo: ["message": "Complete data and mobile index.html exported to: \(exportDirectory.lastPathComponent)"]
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
        let destinationImagesDirectory = StorageManager.shared.getImagesDirectory()
        let imported = try await Task.detached(priority: .utility) {
            try Self.loadImportedData(
                from: folderURL,
                destinationImagesDirectory: destinationImagesDirectory
            )
        }.value

        try mergeItemsData(
            items: imported.items,
            categories: imported.categories,
            tags: imported.tags,
            smartCollections: imported.smartCollections,
            into: dataStorage
        )
        isImporting = false

        var message = "Data imported: \(imported.items.count) items, \(imported.categories.count) categories, \(imported.tags.count) tags, \(imported.smartCollections.count) smart collections"
        if imported.imagesCopied > 0 {
            message += ", \(imported.imagesCopied) images"
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowToast"),
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    private func mergeItemsData(
        items: [AnyCollectionItem],
        categories: [Category],
        tags: [Tag],
        smartCollections: [SmartCollection],
        into dataStorage: DataStorage
    ) throws {
        var categoryNames = Set(dataStorage.categories.map { $0.name.lowercased() })
        let newCategories = categories.filter { categoryNames.insert($0.name.lowercased()).inserted }

        var tagNames = Set(dataStorage.tags.map { $0.name.lowercased() })
        let newTags = tags.filter { tagNames.insert($0.name.lowercased()).inserted }

        if let conflict = smartCollections.first(where: { imported in
            dataStorage.smartCollections.contains {
                $0.id != imported.id
                    && $0.name.localizedCaseInsensitiveCompare(imported.name) == .orderedSame
            }
        }) {
            throw NSError(
                domain: "Seahorse",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "A smart collection named ‘\(conflict.name)’ already exists. Rename it before importing."
                ]
            )
        }
        var smartCollectionIDs = Set(dataStorage.smartCollections.map(\.id))
        var smartCollectionNames = Set(dataStorage.smartCollections.map { $0.name.lowercased() })
        let newSmartCollections = smartCollections.filter {
            smartCollectionIDs.insert($0.id).inserted
                && smartCollectionNames.insert($0.name.lowercased()).inserted
        }

        var itemIDs = Set(dataStorage.items.map(\.id))
        var bookmarkURLs = Set(dataStorage.bookmarks.map { BookmarkURLNormalizer.normalize($0.url) })
        let newItems = items.filter { item in
            guard itemIDs.insert(item.id).inserted else { return false }
            guard let bookmark = item.asBookmark else { return true }
            return bookmarkURLs.insert(BookmarkURLNormalizer.normalize(bookmark.url)).inserted
        }

        try dataStorage.importData(
            categories: newCategories,
            tags: newTags,
            smartCollections: newSmartCollections,
            items: newItems
        )
    }

    private func exportSnapshot(from dataStorage: DataStorage) -> ExportSnapshot {
        ExportSnapshot(
            items: dataStorage.items,
            categories: dataStorage.categories,
            tags: dataStorage.tags,
            smartCollections: dataStorage.smartCollections,
            bookmarks: dataStorage.bookmarks,
            sourceImagesDirectory: StorageManager.shared.getImagesDirectory()
        )
    }

    nonisolated private static func writeFullExport(
        _ snapshot: ExportSnapshot,
        to parentDirectory: URL
    ) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d-HHmmss"
        let exportDirectory = parentDirectory.appendingPathComponent(
            "Seahorse_Export_\(formatter.string(from: Date()))",
            isDirectory: true
        )
        let dataDirectory = exportDirectory.appendingPathComponent("Data", isDirectory: true)
        let imagesDirectory = exportDirectory.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot.items).write(
            to: dataDirectory.appendingPathComponent("items.json"),
            options: .atomic
        )
        try encoder.encode(snapshot.categories).write(
            to: dataDirectory.appendingPathComponent("categories.json"),
            options: .atomic
        )
        try encoder.encode(snapshot.tags).write(
            to: dataDirectory.appendingPathComponent("tags.json"),
            options: .atomic
        )
        try encoder.encode(snapshot.smartCollections).write(
            to: dataDirectory.appendingPathComponent("smart-collections.json"),
            options: .atomic
        )
        try encoder.encode([String: String]()).write(
            to: dataDirectory.appendingPathComponent("preferences.json"),
            options: .atomic
        )
        try writeBookmarkIndexHTML(snapshot: snapshot, to: exportDirectory)

        if FileManager.default.fileExists(atPath: snapshot.sourceImagesDirectory.path) {
            for source in try FileManager.default.contentsOfDirectory(
                at: snapshot.sourceImagesDirectory,
                includingPropertiesForKeys: nil
            ) {
                try FileManager.default.copyItem(
                    at: source,
                    to: imagesDirectory.appendingPathComponent(source.lastPathComponent)
                )
            }
        }
        return exportDirectory
    }

    nonisolated private static func loadImportedData(
        from folderURL: URL,
        destinationImagesDirectory: URL
    ) throws -> ImportedData {
        let fileManager = FileManager.default
        let dataDirectory = folderURL.appendingPathComponent("Data", isDirectory: true)
        let sourceImagesDirectory = folderURL.appendingPathComponent("Images", isDirectory: true)
        let itemsURL = dataDirectory.appendingPathComponent("items.json")
        guard fileManager.fileExists(atPath: dataDirectory.path),
              fileManager.fileExists(atPath: itemsURL.path) else {
            throw NSError(
                domain: "Seahorse",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid export format: Data/items.json not found"]
            )
        }

        let decoder = JSONDecoder()
        let items = try decoder.decode([AnyCollectionItem].self, from: Data(contentsOf: itemsURL))
        let categoriesURL = dataDirectory.appendingPathComponent("categories.json")
        let tagsURL = dataDirectory.appendingPathComponent("tags.json")
        let categories = fileManager.fileExists(atPath: categoriesURL.path)
            ? try decoder.decode([Category].self, from: Data(contentsOf: categoriesURL))
            : []
        let tags = fileManager.fileExists(atPath: tagsURL.path)
            ? try decoder.decode([Tag].self, from: Data(contentsOf: tagsURL))
            : []
        let smartCollectionsURL = dataDirectory.appendingPathComponent("smart-collections.json")
        let smartCollections = fileManager.fileExists(atPath: smartCollectionsURL.path)
            ? try decoder.decode([SmartCollection].self, from: Data(contentsOf: smartCollectionsURL))
            : []

        var imagesCopied = 0
        if fileManager.fileExists(atPath: sourceImagesDirectory.path) {
            try fileManager.createDirectory(at: destinationImagesDirectory, withIntermediateDirectories: true)
            for source in try fileManager.contentsOfDirectory(at: sourceImagesDirectory, includingPropertiesForKeys: nil) {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else { continue }
                let destination = destinationImagesDirectory.appendingPathComponent(source.lastPathComponent)
                guard !fileManager.fileExists(atPath: destination.path) else { continue }
                try fileManager.copyItem(at: source, to: destination)
                imagesCopied += 1
            }
        }
        return ImportedData(
            items: items,
            categories: categories,
            tags: tags,
            smartCollections: smartCollections,
            imagesCopied: imagesCopied
        )
    }

    nonisolated private static func writeBookmarkIndexHTML(
        snapshot: ExportSnapshot,
        to exportDirectory: URL
    ) throws {
        let payload = bookmarkIndexPayload(from: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        guard var json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Seahorse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode bookmark index data"])
        }
        json = json.replacingOccurrences(of: "</", with: "<\\/")
        let html = bookmarkIndexHTML(json: json)
        try html.write(to: exportDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    }

    nonisolated private static func bookmarkIndexPayload(from snapshot: ExportSnapshot) -> BookmarkIndexPayload {
        let dateFormatter = ISO8601DateFormatter()
        let categoryById = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0) })
        let tagById = Dictionary(uniqueKeysWithValues: snapshot.tags.map { ($0.id, $0) })

        let categories = snapshot.categories.map {
            BookmarkIndexCategory(
                id: $0.id.uuidString,
                name: $0.name,
                icon: $0.icon,
                colorHex: $0.colorHex
            )
        }

        let tags = snapshot.tags.map {
            BookmarkIndexTag(
                id: $0.id.uuidString,
                name: $0.name,
                colorHex: $0.colorHex
            )
        }

        let bookmarks = snapshot.bookmarks.map { bookmark in
            let category = categoryById[bookmark.categoryId]
            let bookmarkTags = bookmark.tagIds.compactMap { tagById[$0] }
            return BookmarkIndexBookmark(
                id: bookmark.id.uuidString,
                title: bookmark.title,
                url: bookmark.url,
                domain: domainName(from: bookmark.url),
                categoryId: bookmark.categoryId.uuidString,
                categoryName: category?.name ?? "None",
                isFavorite: bookmark.isFavorite,
                addedDate: dateFormatter.string(from: bookmark.addedDate),
                modifiedDate: bookmark.modifiedDate.map { dateFormatter.string(from: $0) },
                notes: bookmark.notes,
                description: bookmark.metadata?.description,
                siteName: bookmark.metadata?.siteName,
                tagIds: bookmark.tagIds.map { $0.uuidString },
                tagNames: bookmarkTags.map { $0.name }
            )
        }

        return BookmarkIndexPayload(
            generatedAt: dateFormatter.string(from: Date()),
            bookmarks: bookmarks,
            categories: categories,
            tags: tags
        )
    }

    nonisolated private static func domainName(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    nonisolated private static func bookmarkIndexHTML(json: String) -> String {
        """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <title>Seahorse Bookmarks</title>
          <style>
            :root {
              color-scheme: light dark;
              --bg: #f5f7f8;
              --panel: #ffffff;
              --panel-2: #edf1f3;
              --text: #172124;
              --muted: #687579;
              --line: rgba(23, 33, 36, 0.1);
              --accent: #0a84ff;
              --favorite: #ffcc00;
              --shadow: 0 10px 30px rgba(28, 40, 44, 0.08);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
            }

            @media (prefers-color-scheme: dark) {
              :root {
                --bg: #111617;
                --panel: #1d2426;
                --panel-2: #283033;
                --text: #f4f7f7;
                --muted: #9ca7aa;
                --line: rgba(255, 255, 255, 0.1);
                --shadow: 0 12px 34px rgba(0, 0, 0, 0.25);
              }
            }

            * { box-sizing: border-box; }

            body {
              margin: 0;
              min-height: 100vh;
              background: var(--bg);
              color: var(--text);
              letter-spacing: 0;
            }

            a { color: inherit; text-decoration: none; }
            button, input { font: inherit; }
            button { cursor: pointer; }

            .app {
              max-width: 980px;
              margin: 0 auto;
              padding: max(18px, env(safe-area-inset-top)) 14px max(24px, env(safe-area-inset-bottom));
            }

            .header {
              position: sticky;
              top: 0;
              z-index: 10;
              margin: -18px -14px 14px;
              padding: max(18px, env(safe-area-inset-top)) 14px 12px;
              border-bottom: 1px solid var(--line);
              background: var(--bg);
              backdrop-filter: saturate(180%) blur(18px);
            }

            .title-row {
              display: flex;
              align-items: center;
              justify-content: space-between;
              gap: 12px;
              margin-bottom: 12px;
            }

            h1 {
              margin: 0;
              font-size: 24px;
              line-height: 1.12;
              font-weight: 780;
            }

            .summary {
              color: var(--muted);
              font-size: 13px;
              white-space: nowrap;
            }

            .search {
              width: 100%;
              height: 44px;
              border: 1px solid var(--line);
              border-radius: 12px;
              padding: 0 14px;
              color: var(--text);
              background: var(--panel);
              outline: none;
              box-shadow: var(--shadow);
            }

            .search:focus {
              border-color: var(--accent);
              box-shadow: 0 0 0 3px rgba(10, 132, 255, 0.18), var(--shadow);
            }

            .chips {
              display: flex;
              gap: 8px;
              margin: 12px 0 0;
              overflow-x: auto;
              padding-bottom: 2px;
              scrollbar-width: none;
            }

            .chips::-webkit-scrollbar { display: none; }

            .chip {
              flex: 0 0 auto;
              min-height: 32px;
              border: 1px solid var(--line);
              border-radius: 999px;
              padding: 0 12px;
              color: var(--muted);
              background: var(--panel);
              font-size: 13px;
              font-weight: 700;
            }

            .chip.active {
              color: white;
              background: var(--accent);
              border-color: var(--accent);
            }

            .list {
              display: grid;
              gap: 10px;
            }

            .card {
              display: grid;
              grid-template-columns: 44px minmax(0, 1fr);
              gap: 12px;
              min-height: 92px;
              border: 1px solid var(--line);
              border-radius: 14px;
              padding: 12px;
              background: var(--panel);
              box-shadow: var(--shadow);
            }

            .icon {
              width: 44px;
              height: 44px;
              border-radius: 10px;
              background: var(--panel-2);
              object-fit: cover;
            }

            .bookmark-title {
              display: -webkit-box;
              overflow: hidden;
              margin: 0;
              -webkit-line-clamp: 2;
              -webkit-box-orient: vertical;
              font-size: 15px;
              line-height: 1.26;
              font-weight: 760;
            }

            .url {
              overflow: hidden;
              margin-top: 4px;
              color: var(--muted);
              font-size: 12px;
              text-overflow: ellipsis;
              white-space: nowrap;
            }

            .desc {
              display: -webkit-box;
              overflow: hidden;
              margin: 7px 0 0;
              color: var(--muted);
              -webkit-line-clamp: 2;
              -webkit-box-orient: vertical;
              font-size: 12px;
              line-height: 1.42;
            }

            .tags {
              display: flex;
              flex-wrap: wrap;
              gap: 5px;
              margin-top: 9px;
            }

            .tag {
              max-width: 110px;
              overflow: hidden;
              border-radius: 6px;
              padding: 3px 6px;
              color: var(--accent);
              background: rgba(10, 132, 255, 0.13);
              font-size: 11px;
              font-weight: 720;
              text-overflow: ellipsis;
              white-space: nowrap;
            }

            .star {
              color: var(--favorite);
            }

            .empty {
              display: none;
              padding: 56px 18px;
              color: var(--muted);
              text-align: center;
            }

            .empty.visible { display: block; }

            @media (min-width: 760px) {
              .app { padding-left: 22px; padding-right: 22px; }
              .header { margin-left: -22px; margin-right: -22px; padding-left: 22px; padding-right: 22px; }
              .list { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            }
          </style>
        </head>
        <body>
          <div class="app">
            <header class="header">
              <div class="title-row">
                <h1>Seahorse Bookmarks</h1>
                <div id="summary" class="summary"></div>
              </div>
              <input id="search" class="search" type="search" placeholder="Search bookmarks" autocomplete="off">
              <div id="categories" class="chips" aria-label="Categories"></div>
              <div id="filters" class="chips" aria-label="Filters">
                <button class="chip active" type="button" data-filter="all">All</button>
                <button class="chip" type="button" data-filter="favorite">Favorites</button>
              </div>
            </header>
            <main>
              <div id="list" class="list"></div>
              <div id="empty" class="empty">No matching bookmarks.</div>
            </main>
          </div>

          <script type="application/json" id="seahorse-data">\(json)</script>
          <script>
            const payload = JSON.parse(document.getElementById("seahorse-data").textContent);
            const state = { query: "", category: "all", filter: "all" };
            const list = document.getElementById("list");
            const empty = document.getElementById("empty");
            const summary = document.getElementById("summary");
            const categories = document.getElementById("categories");

            function favicon(bookmark) {
              return "https://www.google.com/s2/favicons?domain=" + encodeURIComponent(bookmark.domain || bookmark.url) + "&sz=64";
            }

            function categoryCounts() {
              const counts = new Map([["all", payload.bookmarks.length]]);
              payload.bookmarks.forEach((bookmark) => {
                counts.set(bookmark.categoryId, (counts.get(bookmark.categoryId) || 0) + 1);
              });
              return counts;
            }

            function visibleBookmarks() {
              const query = state.query.trim().toLowerCase();
              return payload.bookmarks.filter((bookmark) => {
                if (state.category !== "all" && bookmark.categoryId !== state.category) return false;
                if (state.filter === "favorite" && !bookmark.isFavorite) return false;
                if (!query) return true;

                const text = [
                  bookmark.title,
                  bookmark.url,
                  bookmark.domain,
                  bookmark.categoryName,
                  bookmark.description || "",
                  bookmark.notes || "",
                  ...(bookmark.tagNames || [])
                ].join(" ").toLowerCase();

                return text.includes(query);
              });
            }

            function renderCategories() {
              const counts = categoryCounts();
              const buttons = [
                { id: "all", name: "All", count: counts.get("all") || 0 },
                ...payload.categories.map((category) => ({
                  id: category.id,
                  name: category.name,
                  count: counts.get(category.id) || 0
                })).filter((category) => category.count > 0)
              ];

              categories.innerHTML = buttons.map((category) => `
                <button class="chip ${state.category === category.id ? "active" : ""}" type="button" data-category="${category.id}">
                  ${escapeHTML(category.name)} ${category.count}
                </button>
              `).join("");

              categories.querySelectorAll("button").forEach((button) => {
                button.addEventListener("click", () => {
                  state.category = button.dataset.category;
                  render();
                });
              });
            }

            function escapeHTML(value) {
              return String(value).replace(/[&<>"']/g, (character) => ({
                "&": "&amp;",
                "<": "&lt;",
                ">": "&gt;",
                '"': "&quot;",
                "'": "&#39;"
              }[character]));
            }

            function renderList(bookmarks) {
              list.innerHTML = bookmarks.map((bookmark) => {
                const tags = [bookmark.categoryName, ...(bookmark.tagNames || [])].filter(Boolean).slice(0, 4);
                const description = bookmark.description || bookmark.notes || "";
                return `
                  <a class="card" href="${escapeHTML(bookmark.url)}" target="_blank" rel="noopener">
                    <img class="icon" src="${favicon(bookmark)}" alt="" loading="lazy">
                    <div>
                      <h2 class="bookmark-title">${bookmark.isFavorite ? '<span class="star">★</span> ' : ""}${escapeHTML(bookmark.title)}</h2>
                      <div class="url">${escapeHTML(bookmark.domain || bookmark.url)}</div>
                      ${description ? `<p class="desc">${escapeHTML(description)}</p>` : ""}
                      <div class="tags">${tags.map((tag) => `<span class="tag">#${escapeHTML(tag)}</span>`).join("")}</div>
                    </div>
                  </a>
                `;
              }).join("");
            }

            function render() {
              const bookmarks = visibleBookmarks();
              summary.textContent = bookmarks.length + " / " + payload.bookmarks.length;
              renderCategories();
              renderList(bookmarks);
              empty.classList.toggle("visible", bookmarks.length === 0);
            }

            document.getElementById("search").addEventListener("input", (event) => {
              state.query = event.target.value;
              render();
            });

            document.getElementById("filters").querySelectorAll("button").forEach((button) => {
              button.addEventListener("click", () => {
                state.filter = button.dataset.filter;
                document.getElementById("filters").querySelectorAll("button").forEach((item) => {
                  item.classList.toggle("active", item === button);
                });
                render();
              });
            });

            render();
          </script>
        </body>
        </html>
        """
    }

}
#endif
