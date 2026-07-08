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

@MainActor
final class MCPBookmarkBridgeService {
    private let dataStorage: DataStorage
    private let dateFormatter = ISO8601DateFormatter()

    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }

    convenience init() {
        self.init(dataStorage: .shared)
    }

    func handle(_ request: MCPBridgeRequest) async -> MCPBridgeResponse {
        switch request.action {
        case "search_bookmarks":
            searchBookmarks(request.payload ?? [:])
        case "get_bookmark":
            getBookmark(request.payload ?? [:])
        case "create_bookmark":
            await createBookmark(request.payload ?? [:])
        case "update_bookmark":
            await updateBookmark(request.payload ?? [:])
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
    func searchBookmarks(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        let query = payload["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let limit = min(max(payload["limit"]?.intValue ?? 20, 1), 100)
        let categoryId = payload["categoryId"]?.stringValue.flatMap(UUID.init(uuidString:))
        let tagIds = payload["tagIds"]?.stringArrayValue?.compactMap(UUID.init(uuidString:)) ?? []
        let favoriteOnly = payload["favoriteOnly"]?.boolValue ?? false

        var bookmarks = dataStorage.bookmarks
        if let categoryId {
            bookmarks = bookmarks.filter { $0.categoryId == categoryId }
        }
        if !tagIds.isEmpty {
            let selectedTagIds = Set(tagIds)
            bookmarks = bookmarks.filter { !selectedTagIds.isDisjoint(with: Set($0.tagIds)) }
        }
        if favoriteOnly {
            bookmarks = bookmarks.filter(\.isFavorite)
        }
        if !query.isEmpty {
            bookmarks = bookmarks.filter { bookmark in
                bookmarkSearchText(bookmark).contains(query)
            }
        }

        let results = bookmarks
            .sorted { $0.addedDate > $1.addedDate }
            .prefix(limit)
            .map(bookmarkSummaryJSON)
        return .success(.array(Array(results)))
    }

    func getBookmark(_ payload: [String: JSONValue]) -> MCPBridgeResponse {
        guard let id = payload["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              let bookmark = dataStorage.bookmarks.first(where: { $0.id == id }) else {
            return .failure(code: "not_found", message: "Bookmark not found")
        }
        return .success(bookmarkDetailJSON(bookmark))
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
            try dataStorage.addBookmark(bookmark)
            fetchMetadata(for: bookmark)
            return .success(bookmarkDetailJSON(bookmark))
        } catch {
            return .failure(code: "validation_error", message: error.localizedDescription)
        }
    }

    func updateBookmark(_ payload: [String: JSONValue]) async -> MCPBridgeResponse {
        guard let id = payload["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              var bookmark = dataStorage.bookmarks.first(where: { $0.id == id }) else {
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
        bookmark.modifiedDate = Date()

        do {
            try dataStorage.updateBookmark(bookmark)
            return .success(bookmarkDetailJSON(bookmark))
        } catch {
            return .failure(code: "validation_error", message: error.localizedDescription)
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

    func bookmarkSearchText(_ bookmark: Bookmark) -> String {
        var parts = [bookmark.title, bookmark.url]
        if let notes = bookmark.notes { parts.append(notes) }
        parts.append(contentsOf: dataStorage.tags(for: bookmark.tagIds).map(\.name))
        return parts.joined(separator: "\n").lowercased()
    }

    func bookmarkSummaryJSON(_ bookmark: Bookmark) -> JSONValue {
        .object([
            "id": .string(bookmark.id.uuidString),
            "title": .string(bookmark.title),
            "url": .string(bookmark.url),
            "notesPreview": .string(String((bookmark.notes ?? "").prefix(240))),
            "category": categoryJSON(dataStorage.category(for: bookmark.categoryId)),
            "tags": .array(dataStorage.tags(for: bookmark.tagIds).map(tagJSON)),
            "isFavorite": .bool(bookmark.isFavorite),
            "addedDate": .string(dateFormatter.string(from: bookmark.addedDate)),
            "modifiedDate": bookmark.modifiedDate.map { .string(dateFormatter.string(from: $0)) } ?? .null
        ])
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

    func fetchMetadata(for bookmark: Bookmark) {
        guard let url = URL(string: bookmark.url) else { return }
        Task {
            if let metadata = try? await OpenGraphService.shared.fetchMetadata(url: url) {
                var updated = bookmark
                updated.metadata = metadata
                if let title = metadata.title, !title.isEmpty, updated.title == "Untitled" {
                    updated.title = title
                }
                if updated.notes == nil {
                    updated.notes = metadata.description
                }
                if let favicon = metadata.faviconURL {
                    updated.icon = favicon
                }
                try? dataStorage.updateBookmark(updated)
            }
        }
    }
}
#endif
