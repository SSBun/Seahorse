# MCP 删除全部条目类型 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Seahorse MCP 增加按 UUID 永久删除 bookmark、image、text 的统一 `delete_item` 工具。

**Architecture:** MCPHelper 只负责校验 UUID 和注册工具；App 内 bridge 在 `DataStorage.items` 中定位条目，并调用现有 `DataStorage.deleteItem(_:)` 完成数据库、内存缓存和内部图片文件清理。工具成功返回 `id` 与 `type`，不存在时返回 `not_found`。

**Tech Stack:** TypeScript、Zod、Vitest、Swift、SwiftUI/macOS、Xcode

## Global Constraints

- 不新增依赖。
- tag 和 category 继续只读。
- 删除逻辑必须复用 `DataStorage.deleteItem(_:)`。
- 只删除 Seahorse 内部存储中的图片文件，不删除外部路径或远程 URL。
- 内部图片路径判断必须解析符号链接，并要求路径位于 `Images/` 目录边界内。

---

### Task 1: MCP 工具契约

**Files:**
- Modify: `MCPHelper/tests/tools.test.ts`
- Modify: `MCPHelper/src/tools.ts`
- Modify: `scripts/smoke-mcp.sh`

**Interfaces:**
- Consumes: MCP helper 现有 `registerBridgeTool` 注册方式。
- Produces: `delete_item`，输入 `{ id: UUID }`。

- [x] **Step 1: 写入失败测试**

导入 `deleteItemShape`，用 `z.object(deleteItemShape)` 验证合法 UUID，并拒绝普通字符串。

- [x] **Step 2: 运行测试确认红灯**

Run: `cd MCPHelper && npm test -- tests/tools.test.ts`
Expected: FAIL，因为 `deleteItemShape` 尚未导出。

- [x] **Step 3: 实现最小工具 schema 和注册**

在 `MCPHelper/src/tools.ts` 导出只包含 `id: z.string().uuid()` 的 `deleteItemShape`，并注册 `delete_item`；在 smoke test 的预期工具列表加入该名称。

- [x] **Step 4: 运行测试确认绿灯**

Run: `cd MCPHelper && npm test -- tests/tools.test.ts`
Expected: PASS。

### Task 2: App bridge 删除实现

**Files:**
- Modify: `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`
- Modify: `Seahorse/Storage/DataStorage.swift`

**Interfaces:**
- Consumes: `DataStorage.items` 和 `DataStorage.deleteItem(_:)`。
- Produces: bridge action `delete_item`；成功结果为 `{ id, type }`，失败 code 为 `not_found` 或 `delete_failed`。

- [x] **Step 1: 在 action switch 中接入 `delete_item`**

将 payload 传给同文件内私有 `deleteItem(_:)` 方法。

- [x] **Step 2: 实现统一删除**

解析 UUID，在 `dataStorage.items` 中定位条目；找不到时返回 `not_found`。记录删除前的 `itemType.rawValue`，调用 `dataStorage.deleteItem(item)`，成功返回 id/type，异常返回 `delete_failed`。

- [x] **Step 3: 执行完整验证**

将 `DataStorage.deleteImageFile(at:)` 的目录判断改为解析符号链接后的 `Images/` 边界判断，避免相邻目录或符号链接逃逸路径被删除。

Run: `cd MCPHelper && npm test && npm run build`
Expected: 全部通过。

Run: `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug`
Expected: `BUILD SUCCEEDED`。

Run: `git diff --check`
Expected: 无输出且退出码为 0。
