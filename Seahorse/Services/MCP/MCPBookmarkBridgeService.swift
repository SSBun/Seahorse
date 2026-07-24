#if os(macOS)
import Foundation

struct MCPBridgeRequest: Decodable {
    let action: String
    let payload: [String: JSONValue]?
}

struct MCPBridgeResponse: Encodable {
    let ok: Bool
    let result: JSONValue?
    let error: MCPBridgeError?

    static func success(_ result: JSONValue) -> MCPBridgeResponse {
        MCPBridgeResponse(ok: true, result: result, error: nil)
    }

    static func failure(code: String, message: String) -> MCPBridgeResponse {
        MCPBridgeResponse(ok: false, result: nil, error: MCPBridgeError(code: code, message: message))
    }
}

struct MCPBridgeError: Encodable {
    let code: String
    let message: String
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var stringArrayValue: [String]? {
        if case .array(let values) = self {
            return values.compactMap(\.stringValue)
        }
        return nil
    }
}

private struct MCPBookmarkSearchKey: Equatable {
    let query: String
    let categoryID: UUID?
    let tagIDs: Set<UUID>
    let favoriteOnly: Bool
}

private struct MCPBookmarkSearchCache {
    let version: Int
    let key: MCPBookmarkSearchKey
    let bookmarks: [Bookmark]
}

private struct MCPBookmarkSerializationContext {
    let categoriesByID: [UUID: Category]
    let tagsByID: [UUID: Tag]

    func summaries(_ bookmarks: [Bookmark]) -> [JSONValue] {
        let formatter = ISO8601DateFormatter()
        return bookmarks.map { bookmark in
            .object([
                "id": .string(bookmark.id.uuidString),
                "title": .string(bookmark.title),
                "url": .string(bookmark.url),
                "notesPreview": .string(String((bookmark.notes ?? "").prefix(240))),
                "category": categoryJSON(categoriesByID[bookmark.categoryId]),
                "tags": .array(bookmark.tagIds.compactMap { tagsByID[$0] }.map(tagJSON)),
                "isFavorite": .bool(bookmark.isFavorite),
                "addedDate": .string(formatter.string(from: bookmark.addedDate)),
                "modifiedDate": bookmark.modifiedDate.map { .string(formatter.string(from: $0)) } ?? .null
            ])
        }
    }

    func details(_ bookmarks: [Bookmark]) -> [JSONValue] {
        let formatter = ISO8601DateFormatter()
        return bookmarks.map { bookmark in
            var object: [String: JSONValue] = [
                "id": .string(bookmark.id.uuidString),
                "title": .string(bookmark.title),
                "url": .string(bookmark.url),
                "notes": bookmark.notes.map(JSONValue.string) ?? .null,
                "category": categoryJSON(categoriesByID[bookmark.categoryId]),
                "tags": .array(bookmark.tagIds.compactMap { tagsByID[$0] }.map(tagJSON)),
                "isFavorite": .bool(bookmark.isFavorite),
                "addedDate": .string(formatter.string(from: bookmark.addedDate)),
                "modifiedDate": bookmark.modifiedDate.map { .string(formatter.string(from: $0)) } ?? .null
            ]
            if let metadata = bookmark.metadata {
                object["metadata"] = .object([
                    "title": metadata.title.map(JSONValue.string) ?? .null,
                    "description": metadata.description.map(JSONValue.string) ?? .null,
                    "imageURL": metadata.imageURL.map(JSONValue.string) ?? .null,
                    "faviconURL": metadata.faviconURL.map(JSONValue.string) ?? .null,
                    "siteName": metadata.siteName.map(JSONValue.string) ?? .null,
                    "url": metadata.url.map(JSONValue.string) ?? .null
                ])
            } else {
                object["metadata"] = .null
            }
            return .object(object)
        }
    }

    private func categoryJSON(_ category: Category?) -> JSONValue {
        guard let category else { return .null }
        return .object([
            "id": .string(category.id.uuidString),
            "name": .string(category.name),
            "icon": .string(category.icon),
            "colorHex": .string(category.colorHex)
        ])
    }

    private func tagJSON(_ tag: Tag) -> JSONValue {
        .object([
            "id": .string(tag.id.uuidString),
            "name": .string(tag.name),
            "colorHex": .string(tag.colorHex)
        ])
    }
}

@MainActor
final class MCPBookmarkBridgeService {
    private let dataStorage: DataStorage
    private let dateFormatter = ISO8601DateFormatter()
    private var searchCache: MCPBookmarkSearchCache?

    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }

    convenience init() {
        self.init(dataStorage: .shared)
    }

    func handle(_ request: MCPBridgeRequest) async -> MCPBridgeResponse {
        switch request.action {
        case "search_bookmarks":
            await searchBookmarks(request.payload ?? [:])
        case "get_bookmark":
            await getBookmark(request.payload ?? [:])
        case "get_bookmarks":
            await getBookmarks(request.payload ?? [:])
        case "create_bookmark":
            await createBookmark(request.payload ?? [:])
        case "update_bookmark":
            await updateBookmark(request.payload ?? [:])
        case "delete_item":
            deleteItem(request.payload ?? [:])
        case "delete_tag":
            deleteTag(request.payload ?? [:])
        case "list_tags":
            .success(.array(dataStorage.tags.map(tagJSON)))
        case "search_tags":
            searchTags(request.payload ?? [:])
        case "list_categories":
            .success(.array(dataStorage.categories.map(categoryJSON)))
        case "search_categories":
            searchCategories(request.payload ?? [:])
        default:
            .failure(code: "unknown_action", message: "Unknown bridge action: \(request.action)")
        }
    }
}

private extension MCPBookmarkBridgeService {
    func searchBookmarks(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        let query = payload["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let limit = min(max(payload["limit"]?.intValue ?? 20, 1), 100)
        let offset = max(payload["offset"]?.intValue ?? 0, 0)
        let categoryId = payload["categoryId"]?.stringValue.flatMap(UUID.init(uuidString:))
        let tagIds = payload["tagIds"]?.stringArrayValue?.compactMap(UUID.init(uuidString:)) ?? []
        let favoriteOnly = payload["favoriteOnly"]?.boolValue ?? false

        let key = MCPBookmarkSearchKey(
            query: query,
            categoryID: categoryId,
            tagIDs: Set(tagIds),
            favoriteOnly: favoriteOnly
        )
        let version = dataStorage.itemsVersion
        let bookmarks: [Bookmark]
        if let searchCache, searchCache.version == version, searchCache.key == key {
            bookmarks = searchCache.bookmarks
        } else {
            let records = dataStorage.searchRecordsSnapshot()
            let criteria = CollectionSearch.Criteria(
                query: query,
                kind: .bookmark,
                categoryID: categoryId,
                favoriteOnly: favoriteOnly,
                tagIDs: Set(tagIds),
                order: .newestFirst
            )
            bookmarks = await CollectionSearch.itemsAsync(in: records, matching: criteria)
                .compactMap(\.asBookmark)
            if dataStorage.itemsVersion == version {
                searchCache = MCPBookmarkSearchCache(version: version, key: key, bookmarks: bookmarks)
            }
        }

        let page = Array(bookmarks.dropFirst(min(offset, bookmarks.count)).prefix(limit))
        let context = serializationContext()
        let results = await Task.detached(priority: .userInitiated) {
            context.summaries(page)
        }.value
        return .success(.array(results))
    }

    func getBookmark(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        guard let id = payload["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              let bookmark = dataStorage.item(for: id)?.asBookmark else {
            return .failure(code: "not_found", message: "Bookmark not found")
        }
        let context = serializationContext()
        let detail = await Task.detached(priority: .userInitiated) {
            context.details([bookmark])[0]
        }.value
        return .success(detail)
    }

    func getBookmarks(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        guard let values = payload["ids"]?.stringArrayValue,
              !values.isEmpty,
              values.count <= 100 else {
            return .failure(code: "validation_error", message: "ids must contain 1 to 100 bookmark ids")
        }

        let ids = values.compactMap(UUID.init(uuidString:))
        guard ids.count == values.count else {
            return .failure(code: "validation_error", message: "ids contains invalid bookmark id")
        }

        let bookmarks = ids.compactMap { dataStorage.item(for: $0)?.asBookmark }
        let context = serializationContext()
        let details = await Task.detached(priority: .userInitiated) {
            context.details(bookmarks)
        }.value
        return .success(.array(details))
    }

    func deleteItem(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        guard let idString = payload["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return .failure(code: "validation_error", message: "id must be a valid item id")
        }
        guard let item = dataStorage.itemIncludingDeleted(for: id) else {
            return .failure(code: "not_found", message: "Item not found")
        }
        let wasAlreadyInTrash = item.isDeleted

        do {
            try dataStorage.deleteItem(item)
            return .success(.object([
                "id": .string(id.uuidString),
                "type": .string(item.itemType.rawValue),
                "movedToTrash": .bool(!wasAlreadyInTrash),
                "alreadyInTrash": .bool(wasAlreadyInTrash)
            ]))
        } catch {
            return .failure(code: "delete_failed", message: error.localizedDescription)
        }
    }

    func deleteTag(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        guard let idString = payload["id"]?.stringValue,
              let id = UUID(uuidString: idString) else {
            return .failure(code: "validation_error", message: "id must be a valid tag id")
        }
        guard let tag = dataStorage.tag(for: id) else {
            return .failure(code: "not_found", message: "Tag not found")
        }

        do {
            try dataStorage.deleteTag(tag)
            return .success(.object([
                "id": .string(id.uuidString),
                "name": .string(tag.name)
            ]))
        } catch {
            return .failure(code: "delete_failed", message: error.localizedDescription)
        }
    }

    func createBookmark(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        guard let url = payload["url"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty else {
            return .failure(code: "validation_error", message: "url is required")
        }
        let categoryId = payload["categoryId"]?.stringValue.flatMap(UUID.init(uuidString:)) ?? defaultCategoryId()
        guard let categoryId, dataStorage.category(for: categoryId) != nil else {
            return .failure(code: "validation_error", message: "categoryId does not exist")
        }
        let tagIds = payload["tagIds"]?.stringArrayValue?.compactMap(UUID.init(uuidString:)) ?? []
        guard tagIds.allSatisfy({ dataStorage.tag(for: $0) != nil }) else {
            return .failure(code: "validation_error", message: "tagIds contains unknown tag")
        }

        let bookmark = Bookmark(
            title: payload["title"]?.stringValue ?? URL(string: url)?.host ?? "Untitled",
            url: url,
            categoryId: categoryId,
            isFavorite: payload["isFavorite"]?.boolValue ?? false,
            notes: payload["notes"]?.stringValue,
            tagIds: tagIds
        )

        do {
            try dataStorage.addBookmark(bookmark, updateDuplicateAddedDate: false)
            return .success(bookmarkDetailJSON(bookmark))
        } catch {
            return .failure(code: "validation_error", message: error.localizedDescription)
        }
    }

    func updateBookmark(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        guard let id = payload["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              var bookmark = dataStorage.item(for: id)?.asBookmark else {
            return .failure(code: "not_found", message: "Bookmark not found")
        }

        if let value = payload["title"]?.stringValue { bookmark.title = value }
        if let value = payload["url"]?.stringValue { bookmark.url = value }
        if let value = payload["notes"] { bookmark.notes = value.stringValue }
        if let value = payload["categoryId"]?.stringValue.flatMap(UUID.init(uuidString:)) {
            guard dataStorage.category(for: value) != nil else {
                return .failure(code: "validation_error", message: "categoryId does not exist")
            }
            bookmark.categoryId = value
        }
        if let values = payload["tagIds"]?.stringArrayValue {
            let tagIds = values.compactMap(UUID.init(uuidString:))
            guard tagIds.count == values.count,
                  tagIds.allSatisfy({ dataStorage.tag(for: $0) != nil }) else {
                return .failure(code: "validation_error", message: "tagIds contains unknown tag")
            }
            bookmark.tagIds = tagIds
        }
        if let value = payload["isFavorite"]?.boolValue { bookmark.isFavorite = value }
        if let response = await updatePosterImage(payload, bookmark: &bookmark) {
            return response
        }
        bookmark.modifiedDate = Date()

        do {
            try dataStorage.updateBookmark(bookmark)
            return .success(bookmarkDetailJSON(bookmark))
        } catch {
            return .failure(code: "validation_error", message: error.localizedDescription)
        }
    }

    func updatePosterImage(_ payload: [String: JSONValue], bookmark: inout Bookmark) async -> MCPBridgeResponse? {
        if let path = payload["posterImagePath"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
            guard !path.isEmpty else {
                return .failure(code: "validation_error", message: "posterImagePath is empty")
            }
            let sourceURL: URL
            if let url = URL(string: path), url.isFileURL {
                sourceURL = url
            } else {
                sourceURL = URL(fileURLWithPath: path)
            }
            guard let filename = try? await ImageFileService.shared.copyImage(
                from: sourceURL,
                to: StorageManager.shared.getImagesDirectory()
            ) else {
                return .failure(code: "validation_error", message: "Could not copy posterImagePath to Seahorse image storage")
            }
            setPosterImage(filename, bookmark: &bookmark)
            return nil
        }

        if let urlString = payload["posterImageURL"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
            guard let url = URL(string: urlString),
                  url.scheme == "http" || url.scheme == "https" else {
                return .failure(code: "validation_error", message: "posterImageURL must be an http or https URL")
            }
            setPosterImage(urlString, bookmark: &bookmark)
        }

        return nil
    }

    func setPosterImage(_ imagePath: String, bookmark: inout Bookmark) {
        if bookmark.metadata != nil {
            bookmark.metadata?.imageURL = imagePath
        } else {
            bookmark.metadata = WebMetadata(imageURL: imagePath, url: bookmark.url)
        }
    }

}

private extension MCPBookmarkBridgeService {
    func searchTags(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        let query = payload["query"]?.stringValue?.lowercased() ?? ""
        let tags = query.isEmpty ? dataStorage.tags : dataStorage.tags.filter { $0.name.lowercased().contains(query) }
        return .success(.array(tags.map(tagJSON)))
    }

    func searchCategories(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        let query = payload["query"]?.stringValue?.lowercased() ?? ""
        let categories = query.isEmpty ? dataStorage.categories : dataStorage.categories.filter { $0.name.lowercased().contains(query) }
        return .success(.array(categories.map(categoryJSON)))
    }

    func serializationContext() -> MCPBookmarkSerializationContext {
        MCPBookmarkSerializationContext(
            categoriesByID: Dictionary(uniqueKeysWithValues: dataStorage.categories.map { ($0.id, $0) }),
            tagsByID: Dictionary(uniqueKeysWithValues: dataStorage.tags.map { ($0.id, $0) })
        )
    }

    func bookmarkDetailJSON(_ bookmark: Bookmark) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(bookmark.id.uuidString),
            "title": .string(bookmark.title),
            "url": .string(bookmark.url),
            "notes": bookmark.notes.map(JSONValue.string) ?? .null,
            "category": categoryJSON(dataStorage.category(for: bookmark.categoryId)),
            "tags": .array(dataStorage.tags(for: bookmark.tagIds).map(tagJSON)),
            "isFavorite": .bool(bookmark.isFavorite),
            "addedDate": .string(dateFormatter.string(from: bookmark.addedDate)),
            "modifiedDate": bookmark.modifiedDate.map { .string(dateFormatter.string(from: $0)) } ?? .null
        ]

        if let metadata = bookmark.metadata {
            object["metadata"] = .object([
                "title": metadata.title.map(JSONValue.string) ?? .null,
                "description": metadata.description.map(JSONValue.string) ?? .null,
                "imageURL": metadata.imageURL.map(JSONValue.string) ?? .null,
                "faviconURL": metadata.faviconURL.map(JSONValue.string) ?? .null,
                "siteName": metadata.siteName.map(JSONValue.string) ?? .null,
                "url": metadata.url.map(JSONValue.string) ?? .null
            ])
        } else {
            object["metadata"] = .null
        }
        return .object(object)
    }

    func categoryJSON(_ category: Category?) -> JSONValue {
        guard let category else { return .null }
        return .object([
            "id": .string(category.id.uuidString),
            "name": .string(category.name),
            "icon": .string(category.icon),
            "colorHex": .string(category.colorHex)
        ])
    }

    func tagJSON(_ tag: Tag) -> JSONValue {
        .object([
            "id": .string(tag.id.uuidString),
            "name": .string(tag.name),
            "colorHex": .string(tag.colorHex)
        ])
    }

    func defaultCategoryId() -> UUID? {
        dataStorage.categories.first(where: { $0.name == "None" })?.id ?? dataStorage.categories.first?.id
    }

}
#endif
