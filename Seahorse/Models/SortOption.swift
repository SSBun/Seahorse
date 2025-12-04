//
//  SortOption.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case none = "None"
    case nameAscending = "Name"
    case newestFirst = "Date Added (Newest First)"
    case oldestFirst = "Date Added (Oldest First)"
    case groupBySite = "Group by Site"
    
    var id: String { rawValue }
    
    /// Apply sorting to a collection of items (unified for all item types)
    func sort(_ items: [AnyCollectionItem]) -> [AnyCollectionItem] {
        switch self {
        case .none:
            return items
        case .nameAscending:
            return items.sorted { item1, item2 in
                let name1 = extractSortableName(from: item1)
                let name2 = extractSortableName(from: item2)
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        case .newestFirst:
            return items.sorted { item1, item2 in
                item1.addedDate > item2.addedDate
            }
        case .oldestFirst:
            return items.sorted { item1, item2 in
                item1.addedDate < item2.addedDate
            }
        case .groupBySite:
            return items.sorted { item1, item2 in
                // Extract domain or type identifier for grouping
                let domain1 = extractGroupingKey(from: item1)
                let domain2 = extractGroupingKey(from: item2)
                
                // First sort by domain/type
                let domainComparison = domain1.localizedCaseInsensitiveCompare(domain2)
                if domainComparison != .orderedSame {
                    return domainComparison == .orderedAscending
                }
                
                // Then by name within the same group
                let name1 = extractSortableName(from: item1)
                let name2 = extractSortableName(from: item2)
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
    
    /// Extract a sortable name from any item type
    private func extractSortableName(from item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark {
            return bookmark.title
        } else if let imageItem = item.asImageItem {
            // Use notes if available, otherwise use imagePath
            return imageItem.notes ?? imageItem.imagePath
        } else if let textItem = item.asTextItem {
            // Use notes if available, otherwise use first line of content
            if let notes = textItem.notes, !notes.isEmpty {
                return notes
            } else {
                // Get first line or first 50 characters
                let lines = textItem.content.components(separatedBy: .newlines)
                let firstLine = lines.first ?? textItem.content
                return String(firstLine.prefix(50))
            }
        }
        return ""
    }
    
    /// Extract grouping key (domain for bookmarks, type for others)
    private func extractGroupingKey(from item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark {
            return extractBaseDomain(from: bookmark.url)
        } else if item.asImageItem != nil {
            return "Image"
        } else if item.asTextItem != nil {
            return "Text"
        }
        return "Other"
    }
    
    /// Extract base domain from URL (e.g., "github.com" from "https://github.com/user/repo")
    private func extractBaseDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        // Remove www. prefix if present
        var domain = host.lowercased()
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        
        return domain
    }
}

