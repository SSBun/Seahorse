//
//  ChromeBookmarkSyncService.swift
//  Seahorse
//
//  Writes Seahorse bookmarks directly into Chrome's local Bookmarks file.
//

import AppKit
import Foundation

enum ChromeBookmarkSyncError: LocalizedError {
    case chromeRunning
    case chromeProfileNotFound
    case invalidBookmarkFile

    var errorDescription: String? {
        switch self {
        case .chromeRunning:
            return "Quit Chrome before syncing bookmarks."
        case .chromeProfileNotFound:
            return "Chrome bookmark profile not found."
        case .invalidBookmarkFile:
            return "Chrome Bookmarks file is not valid JSON."
        }
    }
}

@MainActor
final class ChromeBookmarkSyncService: ObservableObject {
    static let shared = ChromeBookmarkSyncService()

    @Published var isSyncing = false
    @Published var lastSyncCount = 0
    @Published var lastError: String?
    @Published var lastProfileName: String?

    private init() {}

    func syncToChrome(from dataStorage: DataStorage) async {
        isSyncing = true
        lastError = nil

        do {
            let profile = try chromeProfile()
            try sync(bookmarks: dataStorage.bookmarks, categories: dataStorage.categories, to: profile.bookmarksURL)
            lastSyncCount = dataStorage.bookmarks.count
            lastProfileName = profile.name
            Log.info("Synced \(dataStorage.bookmarks.count) bookmarks to Chrome profile \(profile.name)", category: .storage)
        } catch {
            lastError = error.localizedDescription
            Log.error("Chrome bookmark sync failed: \(error.localizedDescription)", category: .storage)
        }

        isSyncing = false
    }

    private func sync(bookmarks: [Bookmark], categories: [Category], to bookmarksURL: URL) throws {
        guard !isChromeRunning else {
            throw ChromeBookmarkSyncError.chromeRunning
        }

        let data = try Data(contentsOf: bookmarksURL)
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var roots = root["roots"] as? [String: Any],
              var bookmarkBar = roots["bookmark_bar"] as? [String: Any] else {
            throw ChromeBookmarkSyncError.invalidBookmarkFile
        }

        try backup(bookmarksURL)

        var nextId = maxBookmarkId(in: root) + 1
        var children = bookmarkBar["children"] as? [[String: Any]] ?? []
        let existingFolder = children.first { ($0["type"] as? String) == "folder" && ($0["name"] as? String) == "Seahorse" }
        let seahorseId = existingFolder?["id"] as? String ?? String(nextId)
        if existingFolder == nil { nextId += 1 }

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let grouped = Dictionary(grouping: bookmarks) { bookmark in
            categoryMap[bookmark.categoryId] ?? "Uncategorized"
        }

        let seahorseChildren = grouped.keys.sorted().map { categoryName -> [String: Any] in
            let folderId = String(nextId)
            nextId += 1
            let bookmarkNodes = grouped[categoryName, default: []]
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                .map { bookmark -> [String: Any] in
                    let nodeId = String(nextId)
                    nextId += 1
                    return [
                        "date_added": chromeTimestamp(bookmark.addedDate),
                        "id": nodeId,
                        "name": bookmark.title,
                        "type": "url",
                        "url": bookmark.url,
                    ]
                }
            return [
                "children": bookmarkNodes,
                "date_added": chromeTimestamp(Date()),
                "date_modified": chromeTimestamp(Date()),
                "id": folderId,
                "name": categoryName,
                "type": "folder",
            ]
        }

        let seahorseFolder: [String: Any] = [
            "children": seahorseChildren,
            "date_added": existingFolder?["date_added"] as? String ?? chromeTimestamp(Date()),
            "date_modified": chromeTimestamp(Date()),
            "id": seahorseId,
            "name": "Seahorse",
            "type": "folder",
        ]

        children.removeAll { ($0["type"] as? String) == "folder" && ($0["name"] as? String) == "Seahorse" }
        children.append(seahorseFolder)
        bookmarkBar["children"] = children
        roots["bookmark_bar"] = bookmarkBar
        root["roots"] = roots
        root.removeValue(forKey: "checksum")

        let output = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: bookmarksURL, options: .atomic)
    }

    private var isChromeRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.google.Chrome"
        }
    }

    private func chromeProfile() throws -> (name: String, bookmarksURL: URL) {
        let chromeRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let defaultBookmarks = chromeRoot.appendingPathComponent("Default/Bookmarks")
        if FileManager.default.fileExists(atPath: defaultBookmarks.path) {
            return ("Default", defaultBookmarks)
        }

        let contents = (try? FileManager.default.contentsOfDirectory(at: chromeRoot, includingPropertiesForKeys: nil)) ?? []
        if let bookmarksURL = contents
            .map({ $0.appendingPathComponent("Bookmarks") })
            .filter({ FileManager.default.fileExists(atPath: $0.path) })
            .sorted(by: { $0.path < $1.path })
            .first {
            return (bookmarksURL.deletingLastPathComponent().lastPathComponent, bookmarksURL)
        }

        throw ChromeBookmarkSyncError.chromeProfileNotFound
    }

    private func backup(_ bookmarksURL: URL) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupURL = bookmarksURL.deletingLastPathComponent()
            .appendingPathComponent("Bookmarks.seahorse-\(formatter.string(from: Date())).bak")
        try FileManager.default.copyItem(at: bookmarksURL, to: backupURL)
    }

    private func chromeTimestamp(_ date: Date) -> String {
        let chromeEpoch = Date(timeIntervalSince1970: -11644473600)
        let microseconds = Int64(date.timeIntervalSince(chromeEpoch) * 1_000_000)
        return String(microseconds)
    }

    private func maxBookmarkId(in value: Any) -> Int {
        if let dictionary = value as? [String: Any] {
            let current = Int(dictionary["id"] as? String ?? "") ?? 0
            return dictionary.values.reduce(current) { max($0, maxBookmarkId(in: $1)) }
        }
        if let array = value as? [Any] {
            return array.reduce(0) { max($0, maxBookmarkId(in: $1)) }
        }
        return 0
    }
}
