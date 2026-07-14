# Seahorse Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复性能审计中的 P0/P1/P2 热路径，并为 P3 数据规模升级建立可量化门槛。

**Architecture:** 保留 `DataStorage + JSONStorage` 数据模型，在共享入口修复写放大和批量变更。将搜索和文件/图片 CPU-I/O 抽成接收不可变值快照的纯函数或非隔离工作器，主 actor 仅负责状态发布。

**Tech Stack:** Swift 5、SwiftUI/AppKit/UIKit、Foundation/ImageIO、Kingfisher、XCTest、TypeScript/Vitest。

## Global Constraints

- 不新增依赖，不迁移 SQLite/SwiftData。
- 保持 MCP schema 和 JSON 存储格式兼容。
- 后台工作只使用不可变快照，可观察状态只在主 actor 更新。
- 每个批次先写会失败的最小回归测试，再写生产代码。

---

### Task 1: 持久化与编辑热路径

**Files:**
- Modify: `Seahorse/Database/JSONStorage.swift`
- Modify: `Seahorse/Storage/DataStorage.swift`
- Modify: `Seahorse/Views/Previews/ItemDetailView.swift`
- Test: `SeahorseTests/JSONStoragePerformanceTests.swift`

**Interfaces:**
- Produces: `DatabaseProtocol.forceSaveAllData()` 继续作为 flush 边界；`DataStorage` 批量更新 API 供后续导入/删标签使用。

- [ ] 红灯：证明启动不写入已存在的无变化 JSON，连续变更被合并，flush 保存最新快照。
- [ ] 绿灯：删除 `ensureDataPersistence()` 和无条件规范化写入；持久化使用单一 pending snapshot，普通写入不 pretty-print/sort keys。
- [ ] 绿灯：详情页标题/备注本地编辑，debounce 保存，disappear 前提交。
- [ ] 验证：连续输入期间不再一字符一次全量写入。

### Task 2: 共享搜索核心

**Files:**
- Create: `Seahorse/Services/CollectionSearch.swift`
- Modify: `Seahorse/ContentView.swift`
- Modify: `Seahorse/Views/iOS/iOSHomePageView.swift`
- Modify: `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`
- Modify: `Seahorse/Services/MCP/MCPBridgeServer.swift`
- Test: `SeahorseTests/CollectionSearchTests.swift`

**Interfaces:**
- Produces: 纯 `CollectionSearch` API，输入 item/bookmark/tag 值快照和筛选条件，输出稳定有序结果。

- [ ] 红灯：覆盖 title/url/content/notes/tag、category/favorite/kind、排序、offset/limit 和稳定分页。
- [ ] 绿灯：单轮过滤，预计算 searchable text/sort key，使用 `localizedStandardContains`。
- [ ] 绿灯：macOS/iOS 使用可取消 task 在非主 actor 计算，只接受最新 generation。
- [ ] 绿灯：MCP 解码/搜索/编码不占用主 actor，`get_bookmark(s)` 复用 item cache。
- [ ] 验证：300/3,000/10,000 条搜索基准和 MCP 分页回归。

### Task 3: 图片管线

**Files:**
- Create: `Seahorse/Services/ImageFileService.swift`
- Modify: `Seahorse/Views/Previews/ImageViewer.swift`
- Modify: `Seahorse/Views/iOS/iOSImageView.swift`
- Modify: `Seahorse/Views/Previews/ItemDetailView.swift`
- Modify: `Seahorse/Views/Components/BookmarkIconView.swift`
- Modify: `Seahorse/Services/PasteHandler.swift`
- Modify: `Seahorse/Views/Previews/BookmarkDetailContentView.swift`
- Modify: `Seahorse/ContentView.swift`
- Modify: `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift`
- Test: `SeahorseTests/ImageFileServiceTests.swift`

**Interfaces:**
- Produces: 用于 PNG 保存和本地文件复制的窄 `ImageFileService`；图片显示继续使用已安装 Kingfisher。

- [ ] 红灯：本地图片复制验证扩展名、文件存在和目标文件内容；PNG 保存返回可移植文件名。
- [ ] 绿灯：移除 View body 内 `NSImage/UIImage(contentsOfFile:)` 和 `.loadDiskFileSynchronously()`，本地 URL 通过 Kingfisher 异步加载。
- [ ] 绿灯：编码/写入/复制在非主 actor 完成，视图只回传状态。
- [ ] 验证：本地/远程/缺失图片、大图缩放清晰度和主线程 hitch。

### Task 4: 批量变更与导入导出

**Files:**
- Modify: `Seahorse/Storage/DataStorage.swift`
- Modify: `Seahorse/Database/DatabaseProtocol.swift`
- Modify: `Seahorse/Database/JSONStorage.swift`
- Modify: `Seahorse/Views/Previews/ItemDetailView.swift`
- Modify: `Seahorse/Services/ExportImportManager.swift`
- Test: `SeahorseTests/DataStorageBatchTests.swift`

**Interfaces:**
- Consumes: Task 1 的合并持久化。
- Produces: 按快照替换数组的批量保存方法。

- [ ] 红灯：删标签和 1,000 条导入只发生一次 items 持久化，重复 ID/name/URL 语义不变。
- [ ] 绿灯：用 Set/Dictionary 预计算导入合并，一次替换、cache 重建、发布和 flush。
- [ ] 绿灯：导入导出首先快照化数据，JSON/HTML/图片复制在非主 actor 完成。
- [ ] 验证：导入部分失败不静默丢数据，UI 只发布最终状态。

### Task 5: P2 局部热点

**Files:**
- Modify: `Seahorse/Models/SortOption.swift`
- Modify: `Seahorse/Models/TextItem.swift`
- Modify: `Seahorse/Views/Cards/StandardCardView.swift`
- Modify: `Seahorse/Views/Lists/StandardListItemView.swift`
- Modify: `Seahorse/Views/Previews/ItemDetailView.swift`
- Modify: `Seahorse/Storage/DataStorage.swift`
- Modify: `Seahorse/Views/Cards/ParsingFireEffect.swift`
- Modify: `Seahorse/Views/Components/IconPickerSheet.swift`
- Test: `SeahorseTests/SortAndPreviewPerformanceTests.swift`

- [ ] 红灯：排序结果、Unicode 首行/200 字符 preview、cache 失效与 Reduce Motion 行为保持正确。
- [ ] 绿灯：排序键只提取一次，文本 preview 不全量 split/count，详情元数据不在 body 重复 I/O。
- [ ] 绿灯：category/tag/item cache 分开重建；粒子动画降频并尊重 Reduce Motion；SF Symbol 可用集合只计算一次。
- [ ] 验证：ID-only `Equatable` 不得隐藏 payload 更新。

### Task 6: 全量验证与完成审计

**Files:**
- Modify: `tasks/todo.md`
- Modify: `tasks/context.md`
- Modify: `docs/analysis/performance-audit.md`

- [ ] 运行 `xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`。
- [ ] 运行 macOS Debug build 和 iOS Simulator build。
- [ ] 运行 `npm test` 与 `npm run build`。
- [ ] 运行 300/3,000/10,000 条搜索、连续写入和批量变更基准。
- [ ] 运行 `git diff --check`，逐项对照性能审计和本计划。
- [ ] 只有在所有显式要求均有直接证据时才完成 goal。
