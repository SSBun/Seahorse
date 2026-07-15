import Foundation

enum CollectionSearch {
    enum Kind: Equatable {
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
        var additionalQuery = ""
        var kind: Kind = .all
        var categoryID: UUID?
        var favoriteOnly = false
        var tagIDs: Set<UUID> = []
        var matchesAllTags = false
        var addedOnOrAfter: Date?
        var addedBefore: Date?
        var unorganizedOnly = false
        var unorganizedCategoryID: UUID?
        var matchesNothing = false
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
        let additionalQuery = criteria.additionalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var matches: [Record] = []
        matches.reserveCapacity(records.count)
        for (index, record) in records.enumerated() {
            if index.isMultiple(of: 256), Task<Never, Never>.isCancelled {
                return []
            }
            let item = record.item
            guard !criteria.matchesNothing,
                  matchesKind(item, criteria.kind),
                  criteria.categoryID == nil || item.categoryId == criteria.categoryID,
                  !criteria.favoriteOnly || isFavorite(item),
                  matchesTags(item, criteria),
                  criteria.addedOnOrAfter == nil || item.addedDate >= criteria.addedOnOrAfter!,
                  criteria.addedBefore == nil || item.addedDate < criteria.addedBefore!,
                  !criteria.unorganizedOnly
                    || item.tagIds.isEmpty
                    || item.categoryId == criteria.unorganizedCategoryID,
                  query.isEmpty || record.searchText.localizedStandardContains(query),
                  additionalQuery.isEmpty || record.searchText.localizedStandardContains(additionalQuery) else {
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

    /// Converts a persisted smart collection into executable search criteria.
    static func criteria(
        for smartCollection: SmartCollection,
        availableCategoryIDs: Set<UUID>,
        availableTagIDs: Set<UUID>,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Criteria {
        let categoryIsValid = smartCollection.categoryId.map(availableCategoryIDs.contains) ?? true
        let tagsAreValid = Set(smartCollection.tagIds).isSubset(of: availableTagIDs)
        let dateRange = dateRange(
            for: smartCollection,
            calendar: calendar,
            now: now
        )

        return Criteria(
            query: smartCollection.query,
            kind: kind(for: smartCollection.itemType),
            categoryID: smartCollection.categoryId,
            favoriteOnly: smartCollection.favoriteOnly,
            tagIDs: Set(smartCollection.tagIds),
            matchesAllTags: smartCollection.matchesAllTags,
            addedOnOrAfter: dateRange.start,
            addedBefore: dateRange.end,
            matchesNothing: !categoryIsValid || !tagsAreValid || dateRange.isInvalid,
            order: order(for: smartCollection.sortOption)
        )
    }
}

private extension CollectionSearch {
    static func matchesTags(_ item: AnyCollectionItem, _ criteria: Criteria) -> Bool {
        guard !criteria.tagIDs.isEmpty else { return true }
        let itemTagIDs = Set(item.tagIds)
        return criteria.matchesAllTags
            ? criteria.tagIDs.isSubset(of: itemTagIDs)
            : !criteria.tagIDs.isDisjoint(with: itemTagIDs)
    }

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

    static func kind(for itemType: CollectionItemType?) -> Kind {
        switch itemType {
        case .bookmark: .bookmark
        case .image: .image
        case .text: .text
        case .none: .all
        }
    }

    static func order(for sortOption: SortOption) -> Order {
        switch sortOption {
        case .none: .none
        case .nameAscending: .nameAscending
        case .newestFirst: .newestFirst
        case .oldestFirst: .oldestFirst
        case .groupBySite: .groupBySite
        }
    }

    static func dateRange(
        for smartCollection: SmartCollection,
        calendar: Calendar,
        now: Date
    ) -> (start: Date?, end: Date?, isInvalid: Bool) {
        let startOfToday = calendar.startOfDay(for: now)
        switch smartCollection.dateFilter {
        case .anyTime:
            return (nil, nil, false)
        case .today:
            return (
                startOfToday,
                calendar.date(byAdding: .day, value: 1, to: startOfToday),
                false
            )
        case .lastSevenDays:
            return (
                calendar.date(byAdding: .day, value: -6, to: startOfToday),
                calendar.date(byAdding: .day, value: 1, to: startOfToday),
                false
            )
        case .lastThirtyDays:
            return (
                calendar.date(byAdding: .day, value: -29, to: startOfToday),
                calendar.date(byAdding: .day, value: 1, to: startOfToday),
                false
            )
        case .custom:
            guard let start = smartCollection.customStartDate,
                  let end = smartCollection.customEndDate else {
                return (nil, nil, true)
            }
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            guard startDay <= endDay else { return (nil, nil, true) }
            return (
                startDay,
                calendar.date(byAdding: .day, value: 1, to: endDay),
                false
            )
        }
    }
}
