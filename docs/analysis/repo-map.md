# Seahorse 性能审计仓库地图

> 生成日期：2026-07-13

## 规模

- Swift 源文件：96
- TypeScript 源文件：5
- 源码行数：约 22,852
- CodeGraph：105 files、1,197 nodes、2,885 edges
- 最大性能影响中心：`DataStorage` impact 约 193 symbols

## 运行时边界

| 组件 | 主要路径 | 性能职责 |
|---|---|---|
| App 入口 | `Seahorse/SeahorseApp.swift` | 初始化单例、数据、监控、MCP |
| 主界面 | `Seahorse/ContentView.swift` | macOS 过滤、搜索、排序和集合分发 |
| iOS 主界面 | `Seahorse/Views/iOS/iOSHomePageView.swift` | iOS 过滤、搜索、排序 |
| 可观察数据 | `Seahorse/Storage/DataStorage.swift` | `@MainActor` 状态、CRUD、查找 cache、UI 通知 |
| 持久化 | `Seahorse/Database/JSONStorage.swift` | 全量 JSON 读写、concurrent queue + barrier |
| 列表/卡片 | `Seahorse/Views/Lists/`、`Seahorse/Views/Cards/` | lazy 容器、缩略图、动画 |
| 详情/图片 | `Seahorse/Views/Previews/` | 编辑、WebView、图片解码、截图保存 |
| 导入导出 | `Seahorse/Services/ExportImportManager.swift` | JSON/HTML 编解码、文件树复制 |
| 粘贴/剪贴板 | `PasteHandler.swift`、`CopyMonitor.swift` | 类型判定、图片转码、新增 item |
| AI 解析 | `BatchParsingService.swift`、`AutoParsingService.swift` | 有界并发网络请求、结果持久化 |
| MCP App bridge | `Seahorse/Services/MCP/` | 主 actor 数据访问、搜索、CRUD、本地 HTTP bridge |
| MCP helper | `MCPHelper/src/` | Streamable HTTP MCP、Zod schema、bridge proxy |

## 关键数据流

```text
SwiftUI 输入/操作
  -> DataStorage (@MainActor)
  -> JSONStorage barrier mutation
  -> async whole-file JSON save
  -> @Published / NotificationCenter
  -> ContentView cache invalidation + filter/sort
  -> Lazy grid/list + Kingfisher rendering
```

```text
Agent
  -> Node MCPHelper
  -> localhost /bridge
  -> MCPBridgeServer (@MainActor decode/encode)
  -> MCPBookmarkBridgeService (@MainActor search/CRUD)
  -> DataStorage -> JSONStorage
```

## 审计重点

1. 横跨 `ItemDetailView -> DataStorage -> JSONStorage -> ContentView` 的编辑热路径。
2. macOS/iOS/MCP 三套搜索逻辑的重复计算和主线程隔离。
3. 本地图片在 View body 中同步解码，以及 PNG 编码/文件复制的 actor 位置。
4. 导入、删标签、AI 批处理等 N 次 CRUD 对全量 JSON 持久化的放大。
