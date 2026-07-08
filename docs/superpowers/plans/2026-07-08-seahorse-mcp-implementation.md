# Seahorse MCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Seahorse 运行时提供本机 Streamable HTTP MCP，让 agents 可以搜索、创建、读取和更新 bookmarks。

**Architecture:** Seahorse App 主进程拥有真实数据和 Settings 状态；App 启动一个 bundled Node helper 暴露 `/mcp`；helper 通过本机 bridge 调用 App 内 `DataStorage`。第一版不做 delete、不直接写 JSON、不做局域网访问。

**Tech Stack:** SwiftUI/AppKit、Swift `Network` framework、TypeScript/Node.js、官方 MCP TypeScript SDK、UserDefaults、现有 `DataStorage`/`OpenGraphService`。

## Global Constraints

- 所有 prose 文档写中文；代码、标识符、commit message 保持英文。
- MCP 外部端口固定为 `127.0.0.1:17373`。
- App bridge 端口固定为 `127.0.0.1:17374`。
- 外部 token 和内部 token 第一版存 `UserDefaults`。
- 第一版只支持 Streamable HTTP，不支持 stdio，不支持旧 HTTP+SSE。
- 第一版只管理 bookmarks；tags/categories 只读；不支持 delete。
- helper 不能直接读写 Seahorse JSON；写入必须回到 App 内 `DataStorage`。
- 每个任务完成后至少运行 `git diff --check`；Swift 改动后运行 Debug build；Node helper 改动后运行 helper 测试或 smoke test。

---

## File Structure

- `Seahorse/Services/MCP/MCPSettings.swift`：MCP 开关、端口、token、状态和 UserDefaults 持久化。
- `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`：App 内 bookmark/list/search/create/update 业务 API，包住 `DataStorage`。
- `Seahorse/Services/MCP/MCPBridgeServer.swift`：`127.0.0.1:17374` 内部 HTTP bridge。
- `Seahorse/Services/MCP/MCPHelperManager.swift`：启动/停止/监控 Node helper。
- `Seahorse/Views/Settings/MCPSettingsSectionView.swift`：Settings MCP UI。
- `Seahorse/Views/Settings/BasicSettingsView.swift`：挂载 MCP Settings section。
- `Seahorse/SeahorseApp.swift`：App launch/quit lifecycle 接入 MCP manager。
- `MCPHelper/package.json`：Node helper 包定义。
- `MCPHelper/tsconfig.json`：TypeScript 构建配置。
- `MCPHelper/src/index.ts`：MCP Streamable HTTP server 入口。
- `MCPHelper/src/bridgeClient.ts`：调用 Seahorse App bridge。
- `MCPHelper/src/tools.ts`：MCP tool schema 和 handler 注册。
- `MCPHelper/tests/bridgeClient.test.ts`：helper bridge client 单元测试。
- `scripts/build-mcp-helper.sh`：构建 helper 并准备资源目录。

## Task 1: MCP Settings State

**Files:**
- Create: `Seahorse/Services/MCP/MCPSettings.swift`
- Modify: `tasks/todo.md`

**Interfaces:**
- Produces: `MCPSettings.shared`, `MCPServerStatus`, `externalToken`, `internalToken`, `regenerateExternalToken()`, `regenerateInternalTokenIfNeeded()`

- [ ] **Step 1: Create settings model**

Create `Seahorse/Services/MCP/MCPSettings.swift`:

```swift
#if os(macOS)
import Foundation

enum MCPServerStatus: String {
    case stopped = "Stopped"
    case running = "Running"
    case failed = "Failed"
    case portUnavailable = "Port unavailable"
}

@MainActor
final class MCPSettings: ObservableObject {
    static let shared = MCPSettings()

    static let mcpHost = "127.0.0.1"
    static let mcpPort = 17373
    static let bridgePort = 17374

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var status: MCPServerStatus = .stopped

    @Published private(set) var externalToken: String {
        didSet { defaults.set(externalToken, forKey: Keys.externalToken) }
    }

    @Published private(set) var internalToken: String {
        didSet { defaults.set(internalToken, forKey: Keys.internalToken) }
    }

    var mcpURL: String {
        "http://\(Self.mcpHost):\(Self.mcpPort)/mcp"
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "seahorse.mcp.enabled"
        static let externalToken = "seahorse.mcp.externalToken"
        static let internalToken = "seahorse.mcp.internalToken"
    }

    private init() {
        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        externalToken = defaults.string(forKey: Keys.externalToken) ?? Self.makeToken()
        internalToken = defaults.string(forKey: Keys.internalToken) ?? Self.makeToken()
        defaults.set(externalToken, forKey: Keys.externalToken)
        defaults.set(internalToken, forKey: Keys.internalToken)
    }

    func regenerateExternalToken() {
        externalToken = Self.makeToken()
    }

    func regenerateInternalTokenIfNeeded() {
        if internalToken.isEmpty {
            internalToken = Self.makeToken()
        }
    }

    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return UUID().uuidString + UUID().uuidString
    }
}
#endif
```

- [ ] **Step 2: Verify syntax**

Run:

```bash
git diff --check
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug
```

Expected: build succeeds.

## Task 2: App Bookmark Bridge Service

**Files:**
- Create: `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`

**Interfaces:**
- Consumes: `DataStorage`, `Bookmark`, `Category`, `Tag`
- Produces: `handle(_ request: MCPBridgeRequest) async -> MCPBridgeResponse`

- [ ] **Step 1: Add bridge service**

Create `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`:

```swift
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
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
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
    private let encoder = ISO8601DateFormatter()

    init(dataStorage: DataStorage = .shared) {
        self.dataStorage = dataStorage
    }

    func handle(_ request: MCPBridgeRequest) async -> MCPBridgeResponse {
        switch request.action {
        case "search_bookmarks":
            return searchBookmarks(request.payload ?? [:])
        case "get_bookmark":
            return getBookmark(request.payload ?? [:])
        case "create_bookmark":
            return await createBookmark(request.payload ?? [:])
        case "update_bookmark":
            return await updateBookmark(request.payload ?? [:])
        case "list_tags":
            return .success(.array(dataStorage.tags.map(tagJSON)))
        case "search_tags":
            return searchTags(request.payload ?? [:])
        case "list_categories":
            return .success(.array(dataStorage.categories.map(categoryJSON)))
        case "search_categories":
            return searchCategories(request.payload ?? [:])
        default:
            return .failure(code: "unknown_action", message: "Unknown bridge action: \(request.action)")
        }
    }
}
#endif
```

- [ ] **Step 2: Add minimal helper methods**

In the same file, add an extension below the class:

```swift
#if os(macOS)
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
            bookmarks = bookmarks.filter { !Set(tagIds).isDisjoint(with: Set($0.tagIds)) }
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
            guard tagIds.count == values.count, tagIds.allSatisfy({ dataStorage.tag(for: $0) != nil }) else {
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
#endif
```

- [ ] **Step 3: Add JSON conversion helpers**

Append:

```swift
#if os(macOS)
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
            "addedDate": .string(encoder.string(from: bookmark.addedDate)),
            "modifiedDate": bookmark.modifiedDate.map { .string(encoder.string(from: $0)) } ?? .null
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
            "addedDate": .string(encoder.string(from: bookmark.addedDate)),
            "modifiedDate": bookmark.modifiedDate.map { .string(encoder.string(from: $0)) } ?? .null
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
```

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug
```

Expected: build succeeds.

## Task 3: Internal HTTP Bridge

**Files:**
- Create: `Seahorse/Services/MCP/MCPBridgeServer.swift`

**Interfaces:**
- Consumes: `MCPSettings.shared.internalToken`, `MCPBookmarkBridgeService.handle`
- Produces: `start()`, `stop()`

- [ ] **Step 1: Implement bridge server with Network.framework**

Create `Seahorse/Services/MCP/MCPBridgeServer.swift` with a minimal HTTP POST server bound to `127.0.0.1:17374`. It accepts `POST /bridge`, requires `Authorization: Bearer <internalToken>`, decodes `MCPBridgeRequest`, calls `MCPBookmarkBridgeService`, and responds JSON. Keep parser intentionally narrow: reject non-POST, paths other than `/bridge`, bodies over 1 MB, and malformed headers.

- [ ] **Step 2: Verify unauthorized and happy path manually**

Run the app, then:

```bash
curl -i http://127.0.0.1:17374/bridge
```

Expected: `401` or `405`, not a crash.

- [ ] **Step 3: Build**

Run:

```bash
git diff --check
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug
```

Expected: build succeeds.

## Task 4: Node MCP Helper

**Files:**
- Create: `MCPHelper/package.json`
- Create: `MCPHelper/tsconfig.json`
- Create: `MCPHelper/src/index.ts`
- Create: `MCPHelper/src/bridgeClient.ts`
- Create: `MCPHelper/src/tools.ts`
- Create: `MCPHelper/tests/bridgeClient.test.ts`
- Create: `scripts/build-mcp-helper.sh`

**Interfaces:**
- Consumes: environment variables `SEAHORSE_MCP_TOKEN`, `SEAHORSE_BRIDGE_TOKEN`, `SEAHORSE_BRIDGE_URL`, `SEAHORSE_MCP_PORT`
- Produces: Streamable HTTP endpoint `/mcp`

- [ ] **Step 1: Create package**

Use official MCP TypeScript SDK packages. Prefer `@modelcontextprotocol/server` and `@modelcontextprotocol/node`; if npm install shows package names changed, use the current official package names from the SDK README and keep the helper API unchanged.

Run:

```bash
mkdir -p MCPHelper/src MCPHelper/tests
cd MCPHelper
npm init -y
npm install @modelcontextprotocol/server @modelcontextprotocol/node zod
npm install -D typescript tsx vitest @types/node
```

- [ ] **Step 2: Add helper scripts**

Update `MCPHelper/package.json` scripts:

```json
{
  "type": "module",
  "bin": {
    "seahorse-mcp-helper": "dist/index.js"
  },
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "test": "vitest run",
    "dev": "tsx src/index.ts"
  }
}
```

- [ ] **Step 3: Implement bridge client and tools**

Implement thin bridge forwarding. Every tool validates input with zod, calls `POST ${SEAHORSE_BRIDGE_URL}/bridge`, and returns bridge `result`. Bridge errors become MCP tool errors.

- [ ] **Step 4: Implement `/mcp` server**

Use the official Streamable HTTP transport. Reject requests without `Authorization: Bearer ${SEAHORSE_MCP_TOKEN}` before handing off to MCP transport. Bind only `127.0.0.1` and `SEAHORSE_MCP_PORT`.

- [ ] **Step 5: Test helper**

Run:

```bash
cd MCPHelper
npm test
npm run build
```

Expected: tests and build pass.

## Task 5: Helper Manager and Settings UI

**Files:**
- Create: `Seahorse/Services/MCP/MCPHelperManager.swift`
- Create: `Seahorse/Views/Settings/MCPSettingsSectionView.swift`
- Modify: `Seahorse/Views/Settings/BasicSettingsView.swift`
- Modify: `Seahorse/SeahorseApp.swift`

**Interfaces:**
- Consumes: `MCPSettings`, `MCPBridgeServer`
- Produces: user-visible Settings controls and lifecycle management

- [ ] **Step 1: Implement manager**

`MCPHelperManager` starts `MCPBridgeServer`, launches helper with env vars, stops both on toggle off, restarts helper once after crash, and sets status to `.portUnavailable` when fixed MCP port cannot be used.

- [ ] **Step 2: Add Settings UI**

Add `MCPSettingsSectionView` to Basic settings. Include toggle, status, URL, token, Copy Token, Copy Header, Regenerate Token.

- [ ] **Step 3: Wire lifecycle**

In `SeahorseApp`, initialize `MCPHelperManager.shared`, call `startIfNeeded()` on main window task, and stop it in `applicationShouldTerminate`.

- [ ] **Step 4: Build**

Run:

```bash
git diff --check
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug
```

Expected: build succeeds.

## Task 6: End-to-End Smoke Test

**Files:**
- Create: `scripts/smoke-mcp.sh`
- Modify: `tasks/todo.md`

**Interfaces:**
- Consumes: running Seahorse app with MCP enabled
- Produces: repeatable local verification

- [ ] **Step 1: Add smoke script**

Create `scripts/smoke-mcp.sh` that accepts token as first arg, calls `/mcp` tools/list, then calls `list_categories`, `list_tags`, and `search_bookmarks` through MCP.

- [ ] **Step 2: Run smoke**

Run:

```bash
scripts/smoke-mcp.sh "$SEAHORSE_MCP_TOKEN"
```

Expected: tools list includes the eight approved tools; no delete or tag/category write tools are present.

- [ ] **Step 3: Final verification**

Run:

```bash
git diff --check
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug
cd MCPHelper && npm test && npm run build
```

Expected: all pass.

## Self-Review

- Spec coverage: App/helper split, fixed ports, UserDefaults token, Streamable HTTP, bridge-only writes, bookmark-only CRU/search/list, read-only tags/categories, no delete, metadata async, lifecycle, Settings UI and tests are covered.
- Placeholder scan: no `TBD` or intentionally empty implementation steps.
- Type consistency: Swift names are stable across tasks; helper environment variable names are stable across tasks.
