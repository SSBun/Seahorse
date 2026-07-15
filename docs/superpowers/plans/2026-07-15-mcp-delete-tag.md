# MCP 删除 Tag 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 destructive MCP 工具 `delete_tag(id)`，统一清理 bookmark、image、text 的 Tag 引用；书签继续使用 `delete_item(id)`。

**Architecture:** MCP helper 只负责 UUID schema 和工具注册，Swift bridge 负责请求与错误响应，`DataStorage.deleteTag` 负责共享级联清理。现有 UI 删除入口移除各自的关联清理代码，统一调用存储层。

**Tech Stack:** TypeScript、Zod、MCP SDK、Swift、SwiftUI、XCTest、Vitest。

---

### Task 1: MCP 工具注册

**Files:**
- Modify: `MCPHelper/tests/tools.test.ts`
- Modify: `MCPHelper/src/tools.ts`

- [ ] **Step 1: 写注册红灯测试**

在现有 tool registration 测试中调用 `delete_tag`：

```typescript
const tagId = "00000000-0000-4000-8000-000000000000";
const deleteTagResult = await client.callTool({ name: "delete_tag", arguments: { id: tagId } });
expect(deleteTagResult.isError).not.toBe(true);
expect(call).toHaveBeenCalledWith("delete_tag", { id: tagId });

const tools = await client.listTools();
expect(tools.tools.find((tool) => tool.name === "delete_tag")?.annotations?.destructiveHint).toBe(true);
```

- [ ] **Step 2: 运行测试并确认因工具缺失失败**

Run: `cd MCPHelper && npm test -- tests/tools.test.ts`

Expected: FAIL，`delete_tag` 返回 unknown tool 或 destructive annotation 缺失。

- [ ] **Step 3: 复用 UUID schema 注册工具**

在 `registerTools` 中增加：

```typescript
registerBridgeTool(server, bridge, "delete_tag", deleteItemShape, { destructiveHint: true });
```

- [ ] **Step 4: 运行测试并确认通过**

Run: `cd MCPHelper && npm test -- tests/tools.test.ts`

Expected: PASS。

### Task 2: 共享 Tag 级联删除

**Files:**
- Modify: `SeahorseTests/DataStorageSearchIndexTests.swift`
- Modify: `Seahorse/Storage/DataStorage.swift`
- Modify: `Seahorse/Views/Management/TagManagementView.swift`
- Modify: `Seahorse/Views/Previews/ItemDetailView.swift`

- [ ] **Step 1: 写三种 item 的级联删除红灯测试**

在 `DataStorageSearchIndexTests` 中创建共享 Tag 的 bookmark、image、text，调用 `deleteTag` 后验证：

```swift
func testDeleteTagRemovesReferencesFromAllItemTypes() throws {
    let storage = DataStorage(database: MockDatabase())
    let category = try XCTUnwrap(storage.categories.first)
    let tag = Tag(name: "Shared", color: .blue)
    try storage.addTag(tag)

    storage.addItem(AnyCollectionItem(Bookmark(
        title: "Bookmark",
        url: "https://example.com/tag-delete",
        categoryId: category.id,
        tagIds: [tag.id]
    )))
    storage.addItem(AnyCollectionItem(ImageItem(
        imagePath: "/tmp/tag-delete.png",
        categoryId: category.id,
        tagIds: [tag.id]
    )))
    storage.addItem(AnyCollectionItem(TextItem(
        content: "Text",
        categoryId: category.id,
        tagIds: [tag.id]
    )))

    try storage.deleteTag(tag)

    XCTAssertNil(storage.tag(for: tag.id))
    XCTAssertTrue(storage.items.allSatisfy { !$0.tagIds.contains(tag.id) })
}
```

- [ ] **Step 2: 运行测试并确认引用仍存在**

Run: `xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' DEVELOPMENT_TEAM=2795FFTPWT CODE_SIGN_IDENTITY='Apple Development' -only-testing:SeahorseTests/DataStorageSearchIndexTests`

Expected: FAIL，Tag 已删除但至少一个 item 仍含 Tag ID。

- [ ] **Step 3: 在 DataStorage 中批量清理后删除 Tag**

在 `deleteTag` 内：

```swift
let updatedItems = items.compactMap { item -> AnyCollectionItem? in
    guard item.tagIds.contains(tag.id) else { return nil }
    if var bookmark = item.asBookmark {
        bookmark.removeTag(tag.id)
        bookmark.modifiedDate = .now
        return AnyCollectionItem(bookmark)
    }
    if var imageItem = item.asImageItem {
        imageItem.removeTag(tag.id)
        imageItem.modifiedDate = .now
        return AnyCollectionItem(imageItem)
    }
    if var textItem = item.asTextItem {
        textItem.removeTag(tag.id)
        textItem.modifiedDate = .now
        return AnyCollectionItem(textItem)
    }
    return nil
}
try updateItems(updatedItems)
try database.deleteTag(tag)
```

保留现有 Tag 数组、cache 和 `itemsVersion` 更新。

- [ ] **Step 4: 删除 UI 调用方重复清理**

`TagManagementView.deleteTag` 和 `ItemDetailView.deleteTag` 只调用：

```swift
try dataStorage.deleteTag(tag)
```

保留各自成功状态和错误提示。

- [ ] **Step 5: 运行定向 Swift 测试**

Run: `xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' DEVELOPMENT_TEAM=2795FFTPWT CODE_SIGN_IDENTITY='Apple Development' -only-testing:SeahorseTests/DataStorageSearchIndexTests`

Expected: PASS。

### Task 3: Swift bridge 与完整验证

**Files:**
- Modify: `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`
- Modify: `tasks/context.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: 增加 bridge action 与错误响应**

在 dispatch 中增加 `delete_tag`，并实现：

```swift
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
            "id": .string(tag.id.uuidString),
            "name": .string(tag.name)
        ]))
    } catch {
        return .failure(code: "delete_failed", message: error.localizedDescription)
    }
}
```

- [ ] **Step 2: 运行完整验证**

Run: `cd MCPHelper && npm test && npm run build`

Expected: 7 项以上测试 PASS，TypeScript build 成功。

Run: `xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' DEVELOPMENT_TEAM=2795FFTPWT CODE_SIGN_IDENTITY='Apple Development'`

Expected: 全量测试 PASS。

Run: `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug -destination 'platform=macOS' DEVELOPMENT_TEAM=2795FFTPWT CODE_SIGN_IDENTITY='Apple Development'`

Expected: BUILD SUCCEEDED。

Run: `git diff --check`

Expected: 无输出。

- [ ] **Step 3: 更新项目记录**

在 `tasks/context.md` 将 Tag MCP 能力从只读更新为支持删除，category 仍只读；在 `tasks/todo.md` 记录测试结果和剩余风险。
