# iCloud Bookmark HTML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Seahorse 备份/导出目录根部生成一个自包含 `index.html`，让用户可从 iCloud Drive 在 iPhone/其他设备浏览自己的书签。

**Architecture:** 复用 `ExportImportManager` 的导出流程，在写完 `Data/items.json`、`categories.json`、`tags.json` 后生成移动端 HTML。HTML 内嵌轻量 bookmark payload，不通过 `fetch` 读取旁边 JSON 文件。

**Tech Stack:** Swift 5、Foundation `JSONEncoder`、纯 HTML/CSS/JavaScript。

---

### Task 1: Add HTML generation helper

**Files:**
- Modify: `Seahorse/Services/ExportImportManager.swift`

- [x] 新增 private payload structs，避免把完整 `AnyCollectionItem` 暴露到 HTML。
- [x] 新增 `writeBookmarkIndexHTML(dataStorage:to:)`，将 bookmarks/categories/tags 编码后嵌入 HTML。
- [x] 新增 `bookmarkIndexHTML(json:)` 返回自包含 HTML 字符串。

### Task 2: Hook helper into export flows

**Files:**
- Modify: `Seahorse/Services/ExportImportManager.swift`

- [x] 在 `backupToDataFolder` 写完 JSON 后调用 HTML helper。
- [x] 在 `exportData` 写完 JSON 后调用 HTML helper。
- [x] 成功 toast 文案加入 `index.html`。

### Task 3: Verify

- [x] 运行 `git diff --check`。
- [x] 运行 Debug build：`xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug`。
- [x] 检查 HTML 字符串中没有外部数据文件 fetch 依赖。
