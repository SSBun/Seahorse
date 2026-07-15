import XCTest
@testable import Seahorse

final class CollectionSearchTests: XCTestCase {
    private let categoryA = UUID()
    private let categoryB = UUID()
    private let swiftTag = Tag(name: "SwiftUI", color: .blue)

    func testSearchMatchesAllItemFieldsAndTagNames() {
        let records = CollectionSearch.makeRecords(
            items: [
                AnyCollectionItem(bookmark(title: "Architecture", url: "https://example.com", notes: "Actor isolation")),
                AnyCollectionItem(ImageItem(imagePath: "poster.png", categoryId: categoryA, notes: "Ocean reference")),
                AnyCollectionItem(TextItem(content: "Unicode café notes", categoryId: categoryA, tagIds: [swiftTag.id]))
            ],
            tagsByID: [swiftTag.id: swiftTag]
        )

        XCTAssertEqual(search(records, query: "architecture").count, 1)
        XCTAssertEqual(search(records, query: "example.com").count, 1)
        XCTAssertEqual(search(records, query: "actor isolation").count, 1)
        XCTAssertEqual(search(records, query: "ocean").count, 1)
        XCTAssertEqual(search(records, query: "cafe").count, 1)
        XCTAssertEqual(search(records, query: "swiftui").count, 1)
    }

    func testCombinedFiltersMatchKindCategoryFavoriteAndAnyTag() {
        let otherTag = Tag(name: "Other", color: .red)
        let matching = bookmark(
            title: "Match",
            categoryId: categoryA,
            isFavorite: true,
            tagIds: [swiftTag.id]
        )
        let records = CollectionSearch.makeRecords(
            items: [
                AnyCollectionItem(matching),
                AnyCollectionItem(bookmark(title: "Wrong category", categoryId: categoryB, isFavorite: true, tagIds: [swiftTag.id])),
                AnyCollectionItem(bookmark(title: "Wrong favorite", categoryId: categoryA, tagIds: [swiftTag.id])),
                AnyCollectionItem(ImageItem(imagePath: "wrong-kind.png", categoryId: categoryA, isFavorite: true, tagIds: [swiftTag.id]))
            ],
            tagsByID: [swiftTag.id: swiftTag, otherTag.id: otherTag]
        )

        let criteria = CollectionSearch.Criteria(
            kind: .bookmark,
            categoryID: categoryA,
            favoriteOnly: true,
            tagIDs: [otherTag.id, swiftTag.id]
        )

        XCTAssertEqual(CollectionSearch.items(in: records, matching: criteria).map(\.id), [matching.id])
    }

    func testTagFilterCanRequireAllSelectedTags() {
        let otherTag = Tag(name: "Other", color: .red)
        let both = bookmark(title: "Both", tagIds: [swiftTag.id, otherTag.id])
        let one = bookmark(title: "One", url: "https://one.example.com", tagIds: [swiftTag.id])
        let records = CollectionSearch.makeRecords(
            items: [AnyCollectionItem(both), AnyCollectionItem(one)],
            tagsByID: [swiftTag.id: swiftTag, otherTag.id: otherTag]
        )

        let criteria = CollectionSearch.Criteria(
            tagIDs: [swiftTag.id, otherTag.id],
            matchesAllTags: true
        )

        XCTAssertEqual(CollectionSearch.items(in: records, matching: criteria).map(\.id), [both.id])
    }

    func testSmartCollectionUsesInclusiveCalendarDaysAndRejectsInvalidReferences() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 00:00:00 UTC
        let recent = bookmark(title: "Recent", addedDate: now.addingTimeInterval(-6 * 86_400))
        let tooOld = bookmark(
            title: "Too Old",
            url: "https://old.example.com",
            addedDate: now.addingTimeInterval(-7 * 86_400)
        )
        let records = CollectionSearch.makeRecords(
            items: [AnyCollectionItem(recent), AnyCollectionItem(tooOld)],
            tagsByID: [:]
        )
        let smartCollection = SmartCollection(name: "Recent", dateFilter: .lastSevenDays)
        let criteria = CollectionSearch.criteria(
            for: smartCollection,
            availableCategoryIDs: [categoryA],
            availableTagIDs: [],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(CollectionSearch.items(in: records, matching: criteria).map(\.id), [recent.id])

        let invalid = SmartCollection(name: "Missing", categoryId: UUID())
        let invalidCriteria = CollectionSearch.criteria(
            for: invalid,
            availableCategoryIDs: [categoryA],
            availableTagIDs: []
        )
        XCTAssertTrue(CollectionSearch.items(in: records, matching: invalidCriteria).isEmpty)
    }

    func testUnorganizedMatchesItemsWithNoTagsOrNoneCategory() {
        let noneCategoryID = UUID()
        let noTags = bookmark(title: "No Tags", categoryId: categoryA)
        let noneCategory = bookmark(
            title: "None Category",
            url: "https://none.example.com",
            categoryId: noneCategoryID,
            tagIds: [swiftTag.id]
        )
        let organized = bookmark(
            title: "Organized",
            url: "https://organized.example.com",
            categoryId: categoryA,
            tagIds: [swiftTag.id]
        )
        let records = CollectionSearch.makeRecords(
            items: [AnyCollectionItem(noTags), AnyCollectionItem(noneCategory), AnyCollectionItem(organized)],
            tagsByID: [swiftTag.id: swiftTag]
        )
        let criteria = CollectionSearch.Criteria(
            unorganizedOnly: true,
            unorganizedCategoryID: noneCategoryID
        )

        XCTAssertEqual(
            Set(CollectionSearch.items(in: records, matching: criteria).map(\.id)),
            [noTags.id, noneCategory.id]
        )
    }

    func testSortKeysAreStableAndPaginationUsesSortedOrder() {
        let sameDate = Date(timeIntervalSince1970: 100)
        let first = bookmark(title: "Zulu", addedDate: sameDate)
        let second = bookmark(title: "Alpha", addedDate: sameDate)
        let newest = bookmark(title: "Middle", addedDate: sameDate.addingTimeInterval(1))
        let records = CollectionSearch.makeRecords(
            items: [AnyCollectionItem(first), AnyCollectionItem(second), AnyCollectionItem(newest)],
            tagsByID: [:]
        )

        let newestCriteria = CollectionSearch.Criteria(order: .newestFirst)
        XCTAssertEqual(CollectionSearch.items(in: records, matching: newestCriteria).map(\.id), [newest.id, first.id, second.id])

        let nameCriteria = CollectionSearch.Criteria(order: .nameAscending, offset: 1, limit: 1)
        XCTAssertEqual(CollectionSearch.items(in: records, matching: nameCriteria).map(\.id), [newest.id])
    }

    func testGroupBySiteUsesDomainThenName() {
        let records = CollectionSearch.makeRecords(
            items: [
                AnyCollectionItem(bookmark(title: "Z", url: "https://www.github.com/z")),
                AnyCollectionItem(bookmark(title: "A", url: "https://example.com/a")),
                AnyCollectionItem(bookmark(title: "B", url: "https://github.com/b"))
            ],
            tagsByID: [:]
        )

        let results = CollectionSearch.items(
            in: records,
            matching: CollectionSearch.Criteria(order: .groupBySite)
        )
        XCTAssertEqual(results.compactMap(\.asBookmark).map(\.title), ["A", "B", "Z"])
    }

    func testAsyncSearchHonorsCancellation() async {
        let records = CollectionSearch.makeRecords(
            items: (0..<10_000).map { index in
                AnyCollectionItem(bookmark(title: "Item \(index)"))
            },
            tagsByID: [:]
        )
        let task = Task {
            await Task.yield()
            return await CollectionSearch.itemsAsync(
                in: records,
                matching: CollectionSearch.Criteria(query: "not present")
            )
        }
        task.cancel()

        let results = await task.value
        XCTAssertTrue(results.isEmpty)
    }

    private func search(_ records: [CollectionSearch.Record], query: String) -> [AnyCollectionItem] {
        CollectionSearch.items(in: records, matching: CollectionSearch.Criteria(query: query))
    }

    private func bookmark(
        title: String,
        url: String = "https://example.com",
        categoryId: UUID? = nil,
        isFavorite: Bool = false,
        addedDate: Date = Date(),
        notes: String? = nil,
        tagIds: [UUID] = []
    ) -> Bookmark {
        Bookmark(
            title: title,
            url: url,
            categoryId: categoryId ?? categoryA,
            isFavorite: isFavorite,
            addedDate: addedDate,
            notes: notes,
            tagIds: tagIds
        )
    }
}
