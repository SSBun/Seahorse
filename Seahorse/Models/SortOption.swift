//
//  SortOption.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import Foundation

enum SortOption: String, CaseIterable, Codable, Identifiable {
    case none = "None"
    case nameAscending = "Name"
    case newestFirst = "Newest"
    case oldestFirst = "Oldest"
    case groupBySite = "Group by Site"
    
    var id: String { rawValue }
    
    /// Apply sorting to a collection of items (unified for all item types)
    func sort(_ items: [AnyCollectionItem]) -> [AnyCollectionItem] {
        switch self {
        case .none:
            return items
        case .nameAscending:
            let keyed = items.enumerated().map { ($0.offset, $0.element, extractSortableName(from: $0.element)) }
            return keyed.sorted { left, right in
                let (leftIndex, _, leftName) = left
                let (rightIndex, _, rightName) = right
                return compare(leftName, rightName, leftIndex: leftIndex, rightIndex: rightIndex)
            }.map { $0.1 }
        case .newestFirst:
            return items.enumerated().sorted { left, right in
                left.element.addedDate == right.element.addedDate
                    ? left.offset < right.offset
                    : left.element.addedDate > right.element.addedDate
            }.map(\.element)
        case .oldestFirst:
            return items.enumerated().sorted { left, right in
                left.element.addedDate == right.element.addedDate
                    ? left.offset < right.offset
                    : left.element.addedDate < right.element.addedDate
            }.map(\.element)
        case .groupBySite:
            let keyed = items.enumerated().map {
                ($0.offset, $0.element, extractSortableName(from: $0.element), extractGroupingKey(from: $0.element))
            }
            return keyed.sorted { left, right in
                let (leftIndex, _, leftName, leftGroup) = left
                let (rightIndex, _, rightName, rightGroup) = right
                let domainComparison = leftGroup.localizedCaseInsensitiveCompare(rightGroup)
                if domainComparison != .orderedSame {
                    return domainComparison == .orderedAscending
                }
                return compare(leftName, rightName, leftIndex: leftIndex, rightIndex: rightIndex)
            }.map { $0.1 }
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
                return String(textItem.firstLine.prefix(50))
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

    private func compare(_ left: String, _ right: String, leftIndex: Int, rightIndex: Int) -> Bool {
        let comparison = left.localizedCaseInsensitiveCompare(right)
        return comparison == .orderedSame ? leftIndex < rightIndex : comparison == .orderedAscending
    }
}
