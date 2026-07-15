import Foundation

struct SmartCollection: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var query: String
    var itemType: CollectionItemType?
    var categoryId: UUID?
    var tagIds: [UUID]
    var matchesAllTags: Bool
    var favoriteOnly: Bool
    var dateFilter: SmartCollectionDateFilter
    var customStartDate: Date?
    var customEndDate: Date?
    var sortOption: SortOption
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        query: String = "",
        itemType: CollectionItemType? = nil,
        categoryId: UUID? = nil,
        tagIds: [UUID] = [],
        matchesAllTags: Bool = false,
        favoriteOnly: Bool = false,
        dateFilter: SmartCollectionDateFilter = .anyTime,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil,
        sortOption: SortOption = .newestFirst,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.itemType = itemType
        self.categoryId = categoryId
        self.tagIds = tagIds
        self.matchesAllTags = matchesAllTags
        self.favoriteOnly = favoriteOnly
        self.dateFilter = dateFilter
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.sortOption = sortOption
        self.createdAt = createdAt
    }
}
