//
//  ImportService.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

struct ImportService {
    enum ImportError: Error {
        case fileReadError
        case invalidFormat
        case parsingError(String)
    }
    
    enum ImportFormat {
        case json
        case html // Netscape bookmark format
    }
    
    /// Import bookmarks from a file
    static func importBookmarks(from url: URL) async throws -> [Bookmark] {
        DLog("ImportService: reading file '\(url.lastPathComponent)'", category: .storage)
        guard let data = try? Data(contentsOf: url) else {
            DLog("ImportService: failed to read file data", category: .storage)
            throw ImportError.fileReadError
        }
        
        // Detect format
        let format = detectFormat(from: url, data: data)
        DLog("ImportService: detected format=\(String(describing: format)) bytes=\(data.count)", category: .storage)
        
        switch format {
        case .json:
            let bookmarks = try importFromJSON(data: data)
            DLog("ImportService: parsed JSON bookmarks count=\(bookmarks.count)", category: .storage)
            return bookmarks
        case .html:
            let bookmarks = try importFromHTML(data: data)
            DLog("ImportService: parsed HTML bookmarks count=\(bookmarks.count)", category: .storage)
            return bookmarks
        }
    }
    
    private static func detectFormat(from url: URL, data: Data) -> ImportFormat {
        let ext = url.pathExtension.lowercased()
        if ext == "json" {
            return .json
        } else if ext == "html" || ext == "htm" {
            return .html
        }
        
        // Try to detect from content
        if let string = String(data: data, encoding: .utf8) {
            if string.contains("<DT><A HREF") || string.contains("<!DOCTYPE NETSCAPE-Bookmark") {
                return .html
            }
        }
        
        return .json // Default to JSON
    }
    
    private static func importFromJSON(data: Data) throws -> [Bookmark] {
        let decoder = JSONDecoder()
        do {
            let bookmarks = try decoder.decode([Bookmark].self, from: data)
            return bookmarks
        } catch {
            DLog("ImportService: JSON decode failed: \(error.localizedDescription)", category: .storage)
            throw ImportError.parsingError("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    private static func importFromHTML(data: Data) throws -> [Bookmark] {
        guard let html = String(data: data, encoding: .utf8) else {
            DLog("ImportService: HTML decode failed (utf8)", category: .storage)
            throw ImportError.parsingError("Failed to read HTML file")
        }
        
        var bookmarks: [Bookmark] = []
        
        // Parse Netscape bookmark format (used by Chrome, Firefox, Safari, etc.)
        // Format: <DT><A HREF="url" ADD_DATE="timestamp" TAGS="tag1,tag2">Title</A>
        
        let lines = html.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("<DT><A HREF") {
                if let bookmark = parseHTMLBookmarkLine(line) {
                    bookmarks.append(bookmark)
                }
            }
        }
        
        return bookmarks
    }
    
    private static func parseHTMLBookmarkLine(_ line: String) -> Bookmark? {
        // Extract URL
        guard let hrefRange = line.range(of: "HREF=\""),
              let urlEnd = line.range(of: "\"", range: hrefRange.upperBound..<line.endIndex) else {
            return nil
        }
        let url = String(line[hrefRange.upperBound..<urlEnd.lowerBound])
        
        // Extract title
        guard let titleStart = line.range(of: ">", range: urlEnd.upperBound..<line.endIndex),
              let titleEnd = line.range(of: "</A>", range: titleStart.upperBound..<line.endIndex) else {
            return nil
        }
        let title = String(line[titleStart.upperBound..<titleEnd.lowerBound])
        
        // Create bookmark with default category (will be assigned "None" category later)
        return Bookmark(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            icon: "link.circle.fill",
            categoryId: UUID(), // Temporary ID, will be assigned None category
            isFavorite: false
        )
    }
    
    /// Export bookmarks to JSON
    static func exportBookmarks(_ bookmarks: [Bookmark], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(bookmarks)
        try data.write(to: url)
    }
}

