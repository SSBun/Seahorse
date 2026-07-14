import Foundation

enum CollectionSearch {
    enum Kind {
        case all
        case bookmark
        case image
        case text
    }

    enum Order {
        case none
        case nameAscending
        case newestFirst
        case oldestFirst
        case groupBySite
    }

    struct Criteria {
        var query = ""
        var kind: Kind = .all
        var categoryID: UUID?
        var favoriteOnly = false
        var tagIDs: Set<UUID> = []
        var order: Order = .none
        var offset = 0
        var limit: Int?
    }

    struct Record {
        let item: AnyCollectionItem
        fileprivate let searchText: String
        fileprivate let sortName: String
        fileprivate let groupKey: String
        fileprivate let originalOrder: Int

        func withOriginalOrder(_ value: Int) -> Record {
            Record(
                item: item,
                searchText: searchText,
                sortName: sortName,
                groupKey: groupKey,
                originalOrder: value
            )
        }
    }

    static func makeRecords(
        items: [AnyCollectionItem],
        tagsByID: [UUID: Tag]
    ) -> [Record] {
        items.enumerated().map { index, item in
            makeRecord(item: item, tagsByID: tagsByID, originalOrder: index)
        }
    }

    static func makeRecord(
        item: AnyCollectionItem,
        tagsByID: [UUID: Tag],
        originalOrder: Int
    ) -> Record {
        let tagNames = item.tagIds.compactMap { tagsByID[$0]?.name }
        return Record(
            item: item,
            searchText: searchText(for: item, tagNames: tagNames),
            sortName: sortName(for: item),
            groupKey: groupKey(for: item),
            originalOrder: originalOrder
        )
    }

    static func items(
        in records: [Record],
        matching criteria: Criteria
    ) -> [AnyCollectionItem] {
        let query = criteria.query.trimmingCharacters(in: .whitespacesAndNewlines)
        var matches: [Record] = []
        matches.reserveCapacity(records.count)
        for (index, record) in records.enumerated() {
            if index.isMultiple(of: 256), Task<Never, Never>.isCancelled {
                return []
            }
            let item = record.item
            guard matchesKind(item, criteria.kind),
                  criteria.categoryID == nil || item.categoryId == criteria.categoryID,
                  !criteria.favoriteOnly || isFavorite(item),
                  criteria.tagIDs.isEmpty || !criteria.tagIDs.isDisjoint(with: item.tagIds),
                  query.isEmpty || record.searchText.localizedStandardContains(query) else {
                continue
            }
            matches.append(record)
        }

        switch criteria.order {
        case .none:
            break
        case .nameAscending:
            matches.sort { compare($0, $1, primary: { $0.sortName }) }
        case .newestFirst:
            matches.sort {
                if $0.item.addedDate != $1.item.addedDate {
                    return $0.item.addedDate > $1.item.addedDate
                }
                return $0.originalOrder < $1.originalOrder
            }
        case .oldestFirst:
            matches.sort {
                if $0.item.addedDate != $1.item.addedDate {
                    return $0.item.addedDate < $1.item.addedDate
                }
                return $0.originalOrder < $1.originalOrder
            }
        case .groupBySite:
            matches.sort {
                let groupComparison = $0.groupKey.localizedCaseInsensitiveCompare($1.groupKey)
                if groupComparison != .orderedSame {
                    return groupComparison == .orderedAscending
                }
                return compare($0, $1, primary: { $0.sortName })
            }
        }

        let offset = min(max(criteria.offset, 0), matches.count)
        let remaining = matches.dropFirst(offset)
        let page = criteria.limit.map { remaining.prefix(max($0, 0)) } ?? remaining.prefix(remaining.count)
        return page.map(\.item)
    }

    static func itemsAsync(
        in records: [Record],
        matching criteria: Criteria,
        priority: TaskPriority = .userInitiated
    ) async -> [AnyCollectionItem] {
        let worker = Task.detached(priority: priority) {
            items(in: records, matching: criteria)
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

private extension CollectionSearch {
    static func matchesKind(_ item: AnyCollectionItem, _ kind: Kind) -> Bool {
        switch kind {
        case .all: true
        case .bookmark: item.itemType == .bookmark
        case .image: item.itemType == .image
        case .text: item.itemType == .text
        }
    }

    static func isFavorite(_ item: AnyCollectionItem) -> Bool {
        item.asBookmark?.isFavorite
            ?? item.asImageItem?.isFavorite
            ?? item.asTextItem?.isFavorite
            ?? false
    }

    static func searchText(for item: AnyCollectionItem, tagNames: [String]) -> String {
        var fields: [String]
        if let bookmark = item.asBookmark {
            fields = [bookmark.title, bookmark.url, bookmark.notes ?? ""]
        } else if let image = item.asImageItem {
            fields = [image.imagePath, image.notes ?? ""]
        } else if let text = item.asTextItem {
            fields = [text.content, text.notes ?? ""]
        } else {
            fields = []
        }
        fields.append(contentsOf: tagNames)
        return fields.joined(separator: "\n")
    }

    static func sortName(for item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark {
            return bookmark.title
        }
        if let image = item.asImageItem {
            return image.notes ?? image.imagePath
        }
        if let text = item.asTextItem {
            if let notes = text.notes, !notes.isEmpty {
                return notes
            }
            return String(text.firstLine.prefix(50))
        }
        return ""
    }

    static func groupKey(for item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark {
            guard var host = URL(string: bookmark.url)?.host?.lowercased() else {
                return bookmark.url
            }
            if host.hasPrefix("www.") {
                host.removeFirst(4)
            }
            return host
        }
        if item.asImageItem != nil { return "Image" }
        if item.asTextItem != nil { return "Text" }
        return "Other"
    }

    static func compare(
        _ left: Record,
        _ right: Record,
        primary: (Record) -> String
    ) -> Bool {
        let comparison = primary(left).localizedCaseInsensitiveCompare(primary(right))
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return left.originalOrder < right.originalOrder
    }
}
