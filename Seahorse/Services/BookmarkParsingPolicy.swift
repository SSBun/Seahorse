import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// The bookmark content and taxonomy supplied to one AI parsing request.
struct BookmarkParsingInput {
    let url: String
    let title: String
    let content: String
    let categories: [Category]
    let tags: [Tag]
}

/// A parsed bookmark suggestion after applying deterministic local taxonomy rules.
struct BookmarkParsingResolution {
    let refinedTitle: String
    let summary: String
    let category: Category?
    let suggestedNewCategoryName: String?
    let existingTags: [Tag]
    let suggestedNewTagNames: [String]
    let suggestedSFSymbol: String?

    /// All resolved tag names, with existing tags before new suggestions. Complexity: O(n).
    var suggestedTagNames: [String] {
        existingTags.map(\.name) + suggestedNewTagNames
    }

    /// Returns a parsed bookmark while preserving every nonempty user-authored field.
    func bookmark(
        fillingMissingValuesIn bookmark: Bookmark,
        unclassifiedCategoryID: UUID?,
        newTagIDs: [UUID],
        provisionalTitle: String? = nil,
        provisionalSummary: String? = nil
    ) -> Bookmark {
        var updated = bookmark
        if (BookmarkParsingPolicy.isPlaceholderTitle(updated.title) || updated.title == provisionalTitle),
           !refinedTitle.isEmpty {
            updated.title = refinedTitle
        }
        if (updated.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            || updated.notes == provisionalSummary),
           !summary.isEmpty {
            updated.notes = summary
        }
        if updated.categoryId == unclassifiedCategoryID, let category {
            updated.categoryId = category.id
        }
        if updated.tagIds.isEmpty {
            var seenTagIDs = Set<UUID>()
            updated.tagIds = (existingTags.map(\.id) + newTagIDs)
                .filter { seenTagIDs.insert($0).inserted }
        }
        updated.isParsed = true
        return updated
    }
}

/// One proposed value change shown during an interactive bookmark reparse.
struct BookmarkParsingChange<Value: Equatable> {
    let currentValue: Value
    let suggestedValue: Value
    let isSelectedByDefault: Bool
}

/// The changed bookmark fields that require user confirmation after a reparse.
struct BookmarkParsingDiff {
    let title: BookmarkParsingChange<String>?
    let summary: BookmarkParsingChange<String>?
    let category: BookmarkParsingChange<String>?
    let tags: BookmarkParsingChange<[String]>?

    init(
        currentTitle: String,
        currentSummary: String,
        currentCategory: Category?,
        currentTags: [Tag],
        resolution: BookmarkParsingResolution
    ) {
        title = Self.change(
            from: currentTitle,
            to: resolution.refinedTitle,
            selectedByDefault: BookmarkParsingPolicy.isPlaceholderTitle(currentTitle)
        )
        summary = Self.change(
            from: currentSummary,
            to: resolution.summary,
            selectedByDefault: currentSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )

        let currentCategoryName = currentCategory?.name ?? "None"
        let suggestedCategoryName = resolution.category?.name ?? resolution.suggestedNewCategoryName
        if let suggestedCategoryName {
            category = Self.change(
                from: currentCategoryName,
                to: suggestedCategoryName,
                selectedByDefault: currentCategory == nil
                    || currentCategoryName.caseInsensitiveCompare("None") == .orderedSame
            )
        } else {
            category = nil
        }

        let currentTagNames = currentTags.map(\.name)
        let suggestedTagNames = resolution.suggestedTagNames
        if !suggestedTagNames.isEmpty,
           Set(currentTagNames.map { $0.lowercased() }) != Set(suggestedTagNames.map { $0.lowercased() }) {
            tags = BookmarkParsingChange(
                currentValue: currentTagNames,
                suggestedValue: suggestedTagNames,
                isSelectedByDefault: currentTagNames.isEmpty
            )
        } else {
            tags = nil
        }
    }

    var hasChanges: Bool {
        title != nil || summary != nil || category != nil || tags != nil
    }

    private static func change(
        from currentValue: String,
        to suggestedValue: String,
        selectedByDefault: Bool
    ) -> BookmarkParsingChange<String>? {
        guard !suggestedValue.isEmpty, currentValue != suggestedValue else { return nil }
        return BookmarkParsingChange(
            currentValue: currentValue,
            suggestedValue: suggestedValue,
            isSelectedByDefault: selectedByDefault
        )
    }
}

/// Resolves untrusted AI suggestions against the user's existing taxonomy.
enum BookmarkParsingPolicy {
    private static let maximumTagCount = 4
    private static let maximumNewTagCount = 2
    private static let maximumNameLength = 40
    private static let reservedCategoryNames = Set(["all bookmarks", "favorites", "none"])
    private static let reservedTagNames = Set(["article", "website", "link", "other"])

    /// Returns whether a title is empty or one of the application's loading placeholders.
    static func isPlaceholderTitle(_ title: String) -> Bool {
        let key = normalizedKey(title.trimmingCharacters(in: .whitespacesAndNewlines))
        return key.isEmpty || key == "loading..." || key == "untitled"
    }

    /// Resolves AI output into category and tag suggestions that are safe to present or save.
    static func resolve(
        _ parsedData: ParsedBookmarkData,
        sourceURL: String,
        categories: [Category],
        tags: [Tag]
    ) -> BookmarkParsingResolution {
        let category: Category? = normalizedName(parsedData.suggestedCategoryName).flatMap { candidate in
            let key = normalizedKey(candidate)
            guard !reservedCategoryNames.contains(key) else { return nil }
            return categories.first { normalizedKey($0.name) == key }
        }

        let categoryKey = category.map { normalizedKey($0.name) }
        let disallowedHostNames = hostNames(from: sourceURL)
        var seenKeys = Set<String>()
        var existingTags: [Tag] = []
        var newTagNames: [String] = []

        for rawName in parsedData.suggestedTagNames {
            guard isValidTagCandidate(rawName), let name = normalizedName(rawName) else { continue }
            let key = normalizedKey(name)
            guard seenKeys.insert(key).inserted,
                  !reservedTagNames.contains(key),
                  key != categoryKey,
                  !disallowedHostNames.contains(key) else {
                continue
            }

            if let existingTag = tags.first(where: { normalizedKey($0.name) == key }) {
                existingTags.append(existingTag)
            } else {
                newTagNames.append(name)
            }
        }

        existingTags = Array(existingTags.prefix(maximumTagCount))
        let remainingTagCount = maximumTagCount - existingTags.count
        newTagNames = Array(newTagNames.prefix(min(maximumNewTagCount, remainingTagCount)))

        return BookmarkParsingResolution(
            refinedTitle: parsedData.refinedTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: parsedData.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            suggestedNewCategoryName: category == nil
                ? validNewCategoryName(parsedData.suggestedNewCategoryName, categories: categories)
                : nil,
            existingTags: existingTags,
            suggestedNewTagNames: newTagNames,
            suggestedSFSymbol: validSFSymbolName(parsedData.suggestedSFSymbol)
        )
    }

    private static func normalizedName(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedKey(_ value: String) -> String {
        value.lowercased()
    }

    private static func isValidTagCandidate(_ value: String) -> Bool {
        guard !value.contains(where: { ",;\n\r".contains($0) }),
              let normalized = normalizedName(value) else {
            return false
        }
        return normalized.count <= maximumNameLength
    }

    private static func validNewCategoryName(
        _ value: String?,
        categories: [Category]
    ) -> String? {
        guard let name = normalizedName(value), name.count <= maximumNameLength else { return nil }
        let key = normalizedKey(name)
        guard !reservedCategoryNames.contains(key),
              !categories.contains(where: { normalizedKey($0.name) == key }) else {
            return nil
        }
        return name
    }

    private static func hostNames(from sourceURL: String) -> Set<String> {
        guard let host = URL(string: sourceURL)?.host else { return [] }
        let key = normalizedKey(host)
        let normalizedHost = key.hasPrefix("www.") ? String(key.dropFirst(4)) : key
        var names: Set<String> = [key, normalizedHost]
        let labels = normalizedHost.split(separator: ".")
        for index in labels.indices {
            names.insert(String(labels[index]))
            names.insert(labels[index...].joined(separator: "."))
        }
        return names
    }

    private static func validSFSymbolName(_ value: String?) -> String? {
        guard let name = normalizedName(value) else { return nil }
#if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil ? nil : name
#elseif os(iOS)
        return UIImage(systemName: name) == nil ? nil : name
#else
        return nil
#endif
    }
}
