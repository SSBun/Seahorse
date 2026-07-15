# 数据流与技术栈分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 技术栈清单

### 运行时与语言

| 组件 | 技术 | 版本 |
|-----------|-----------|---------|
| App 语言 | Swift | 工程设置 `SWIFT_VERSION = 5.0` |
| App UI | SwiftUI；macOS 桥接 AppKit，iOS 桥接 UIKit | 随系统提供；macOS deployment target `15.2`，iOS `16.0` |
| App 并发 | Swift Concurrency、actor、TaskGroup；GCD | 随 Swift/Xcode 提供 |
| App 网络 | Foundation `URLSession`；MacPaw OpenAI SDK | OpenAI SDK 锁定 `0.4.7` |
| MCP Helper 语言 | TypeScript，编译为 ES2022/NodeNext JavaScript | TypeScript 锁定 `5.9.3` |
| MCP Helper 运行时 | Node.js | 项目未固定；依赖最低要求 Node 18，本机扫描为 `22.22.2` |
| MCP 协议层 | `@modelcontextprotocol/sdk`、Zod | `1.29.0`、`3.25.76` |
| 文档站 | Ruby、Jekyll | CI Ruby `3.3`；Jekyll `~> 4.4`，无锁文件 |
| 构建 | Xcode/xcodebuild、SwiftPM、npm/tsc | Xcode 版本未固定；npm lockfile v3 |

### 数据存储

| 存储 | 技术 | 用途 |
|-------|-----------|---------|
| 运行时状态门面 | `@MainActor DataStorage: ObservableObject` | 持有 items、bookmarks、categories、tags，向 SwiftUI、AI、导入和 MCP 提供统一 CRUD |
| 领域数据 | Codable JSON：`Data/items.json`、`categories.json`、`tags.json`、`preferences.json` | 主持久化；没有数据库、ORM 或 migration 系统 |
| 图片文件 | 本机 `Images/` 目录 | 保存粘贴/导入图片、MCP 海报与 AI 生成封面；JSON 只存文件名或远程 URL |
| 存储根目录 | 默认 Application Support；可用 security-scoped bookmark 指向自选目录 | `StorageManager` 解析实际路径，`StoragePathManager` 管理选择与迁移 |
| App 设置 | `UserDefaults` / `@AppStorage` | 外观、排序、剪贴板监控、AI endpoint/token/prompt、MCP 开关/token、存储书签等 |
| 内存索引 | Swift Dictionary、数组快照 | 按 ID 查询、搜索记录、MCP 最近一次查询结果；重启后重建 |
| 导入临时区 | `FileManager.default.temporaryDirectory` | iOS 解压 ZIP，流程结束后删除 |
| 备份/导出 | 用户目录下 `Seahorse_Export_<timestamp>/` 与 `Seahorse_Bookmarks/` | JSON、图片与离线书签索引 HTML；由用户手动触发 |

JSON 文件路径由 `StorageManager.getDataDirectory()` 统一落在 `<storage root>/Data/`；图片落在 `<storage root>/Images/`。`StorageManager.getBackupsDirectory()` 虽已定义，但当前备份 UI 实际把导出目录写到 storage root 的父目录。

### 基础设施

| 组件 | 技术 |
|-----------|-----------|
| Web server | 启用 MCP 时，Node `http` 在 `127.0.0.1:17373/mcp` 提供 Streamable HTTP；App 内 `NWListener` 在 `127.0.0.1:17374/bridge` 提供内部 HTTP bridge |
| Reverse proxy | 未使用；两个服务都只绑定 loopback |
| Message queue | 无外部队列；仅使用 Swift Task/TaskGroup、actor、GCD 串行写队列与内存任务数组 |
| Cache layer | `DataStorage` 字典/搜索记录、ContentView 结果快照、MCP 单查询缓存、Kingfisher、`NSCache`、系统 URL cache |
| File storage | 本机文件系统、security-scoped resource；无 iCloud、S3 或其他远端对象存储 |
| Monitoring | OSLog 分类日志与本地性能埋点；无远端 telemetry、APM、崩溃上报或指标后端 |

## 数据移动

### 请求生命周期

Seahorse 是事件驱动的本机应用，不存在统一的“负载均衡器 → Web middleware → DB”请求。核心生命周期如下。

```text
App 启动
  → StoragePathManager 建立 security-scoped access
  → DataStorage.shared 创建 JSONStorage
  → 同步读取 4 个 JSON 文件
  → 构建 item/category/tag/search 内存缓存
  → 通过 EnvironmentObject 驱动 SwiftUI

粘贴 / 拖放 / 全局双复制
  → NSItemProvider / NSPasteboard
  → PasteHandler 按 URL → 文本 → 图片识别首个支持项
  → Bookmark / ImageItem / TextItem
  → DataStorage 校验并调用 JSONStorage
  → JSONStorage barrier 更新内存副本
  → writeQueue 异步原子写单个 JSON 文件
  → DataStorage 更新缓存、itemsVersion 与通知
  → CollectionSearch 后台过滤
  → 卡片 / 列表 / 详情 UI 刷新
```

手工新增视图不经过 `PasteHandler`，但最终同样调用 `DataStorage.addBookmark` 或 `addItem`。URL 粘贴先保存标题为 `Loading...` 的占位书签，再异步调用 `OpenGraphService` 回写 title、description、favicon 与 metadata；因此用户能先看到条目，但“保存成功”只代表 JSONStorage 已接受内存变更并安排写盘，异步 I/O 错误只记录日志，不会回传给 UI。

AI 解析的数据路径为：

```text
书签 URL
  → NetworkManager 下载网页 HTML
  → AIManager 去 script/style/HTML 标签并截取前 4000 字符
  → 用户配置的 OpenAI-compatible endpoint
     （标题、摘要、分类、标签、SF Symbol 共 5 次顺序 chat 请求）
  → ParsedBookmarkData
  → 可选创建分类/标签
  → DataStorage.updateBookmark / updateItems
  → JSON + 搜索索引 + UI
```

`AutoParsingService` 订阅同步的 `SeahorseItemAdded` 通知。当前 URL 占位保存后，`PasteHandler` 的 OGP 任务和自动 AI 任务会分别抓取元数据并从各自持有的书签快照回写；后完成者可能覆盖先完成者。服务在处理一个书签时会直接忽略新的新增通知，完成后也没有 drain backlog，因而“自动解析”不是可靠队列。`BatchParsingService` 则最多并发 5 个书签，解析成功项最后通过一次 `updateItems` 提交。

Agent 搜索先在本机对全部书签做 token 命中评分，最多选 40 个候选，再把候选的标题、URL、分类、标签、description 和 notes 发给 AI endpoint，由模型返回最多 5 个 ID。普通搜索走另一套 `CollectionSearch`：索引 title、URL、notes/content/imagePath 和标签名，不包含分类名、metadata description 或 siteName，因此普通搜索与 Agent 搜索的可检索字段并不一致。

MCP 请求生命周期为：

```text
本机 MCP client
  → 127.0.0.1:17373/mcp + external Bearer token
  → MCP SDK session + Zod 参数校验
  → Node BridgeClient
  → 127.0.0.1:17374/bridge + internal Bearer token
  → MCPBookmarkBridgeService（MainActor）
  → DataStorage / CollectionSearch / ImageFileService
  → JSON bridge response
  → MCP tool text response
```

MCP helper 不直接读写 JSON。它提供书签搜索/读取/创建/更新、通用条目删除、标签删除与分类/标签查询；图片和文本条目没有完整的 MCP CRUD。创建书签会立即返回当前对象，再异步补充 OGP metadata。外部和内部 token 由 App 生成，存入 UserDefaults，并通过子进程环境注入；报告不记录其值。由于底层写盘异步，MCP 成功响应同样可能早于磁盘持久化。

### 数据管道

| 管道 | 触发器 | 输入 | 处理 | 输出 |
|----------|---------|-------|------------|--------|
| 启动加载 | App 构造单例 | 4 个 JSON 文件 | Codable 解码、图片路径归一化、构建 4 类内存缓存 | `@Published` 状态与首屏 UI |
| 手工采集 | 新增表单、paste、drop | URL、文本、图片或本机图片路径 | 类型识别、默认分类、URL 去重；图片复制/PNG 编码 | JSON 条目，必要时写入 `Images/` |
| 全局双复制 | macOS Cmd+C 两次且内容在 0.2–5 秒窗口内相同 | NSPasteboard | Accessibility event tap、100ms 延迟读取，再复用 PasteHandler | 新条目；权限每 2 秒轮询一次 |
| URL 元数据补全 | URL 书签创建 | 网页 HTML | OGP/Twitter/meta/title 正则解析、相对图片 URL 解析 | title、notes、favicon、WebMetadata 回写 |
| 自动 AI 解析 | `SeahorseItemAdded` 且设置启用 | 最新未解析书签 | OGP、正文清洗、5 次 chat、favicon 探测、可选创建分类/标签 | `isParsed = true` 的书签；当前无 backlog 重试 |
| 批量 AI 解析 | 用户启动批处理 | 未解析或选中的书签 | 最多 5 个 TaskGroup worker；每项抓取网页和调用 AI | 成功项一次批量更新；失败只计数/日志 |
| Agent 搜索 | 用户在 Agent 面板提问 | 查询与最多 40 个本地候选 | 本机粗排后把候选发给 AI，解析严格 JSON | 回答与最多 5 个书签 |
| 搜索/排序 | 查询 300ms debounce、筛选/排序或 itemsVersion 改变 | 内存搜索记录 | detached Task 做类型、分类、收藏、标签、文本过滤与排序 | ContentView 的 `cachedItems` |
| AI 封面生成 | 用户对书签发起 | 标题、description、siteName | image API 返回 base64 或 URL；先保存在任务内存 | 用户 Apply 后写 PNG 并更新 metadata.imageURL |
| 浏览器书签导入 | 用户选择 JSON/HTML | `[Bookmark]` 或 Netscape Bookmark HTML | 解码/逐行解析、统一分到 None、逐条写入并跳过重复 URL | 可部分成功的书签集合 |
| 完整导入/恢复 | macOS 文件夹；iOS 文件夹或 ZIP | Data JSON + Images | 解码、复制图片、按 ID/名称去重、合并 | 当前存储与 UI；macOS/iOS 使用两套实现 |
| 备份/完整导出 | 用户点击备份或导出 | 当前内存快照与整个 Images 目录 | 分文件原子编码、复制图片、生成 index.html | 带时间戳导出目录 |
| 移动书签页同步 | 用户点击工具菜单 | 书签、分类、标签快照 | 嵌入 JSON 生成自包含检索页面 | `Seahorse_Bookmarks/index.html` |
| MCP bridge | 本机 MCP tool call | JSON-RPC/MCP 参数 | 双 token、本机 HTTP、Zod + Swift 验证、DataStorage CRUD | JSON/MCP 响应 |
| JSON 延迟写盘 | 每次 item CRUD | JSONStorage 内存快照 | items 写入 250ms 合并；其余写入进入串行 writeQueue | 单文件 atomic replace；退出时 macOS 强制同步全量 |

没有检测到 cron、远端 worker、ETL 平台、事件总线或持续同步服务。备份、移动书签页同步、AI 批处理和诊断都是用户触发；唯一周期任务是 CopyMonitor 每 2 秒检查 Accessibility 权限。

### 外部集成

| 服务 | 方向 | 协议 | 用途 |
|---------|----------|----------|---------|
| 任意书签网页 | outbound | HTTPS/HTTP GET，经 URLSession | OGP 元数据、正文、favicon 与失效链接诊断 |
| 用户配置的 OpenAI-compatible API | outbound | HTTPS chat/images API | 摘要、标题、分类、标签、图标、Agent 检索与封面生成 |
| 远程图片源 | outbound | HTTPS，经 Kingfisher/URLSession | 卡片、列表、详情图片与 AI 返回图片下载 |
| GitHub Releases API | outbound | HTTPS REST | 检查 `SSBun/Seahorse` 最新版本并打开发布页 |
| 本机 MCP client | inbound | Streamable HTTP on loopback + Bearer token | 调用 Seahorse MCP 工具 |
| Node MCP Helper ↔ App bridge | 双向本机 | HTTP JSON on loopback + 独立 Bearer token | 协议适配；Helper 不接触存储文件 |
| macOS/iOS 文件系统 | inbound/outbound | security-scoped file access、JSON、HTML、ZIP | 导入、导出、备份、恢复和自定义存储目录 |
| Google favicon endpoint | outbound（仅生成页被浏览器打开时） | HTTPS | `index.html` 按域名加载 favicon；App 本身不发起此请求 |
| macOS Accessibility / Pasteboard / UserNotifications / ServiceManagement | 本机系统 API | Apple frameworks | 全局双复制、系统通知与登录启动 |

没有 webhook 接收端、云数据库、云同步或第三方分析 SDK。AI endpoint 可由用户改为非 OpenAI 服务，因此网页正文、书签 notes 和 Agent 候选数据实际发送到哪个服务取决于用户配置。

## 数据生命周期

1. **采集与验证**：三类条目统一封装为 `AnyCollectionItem`。`DataStorage`/`JSONStorage` 校验重复 ID、书签规范化 URL、分类/标签名称；MCP 额外校验 UUID 和引用是否存在。PasteHandler 每次只处理 providers 中遇到的第一个支持项，多文件 drop 不是批量采集。
2. **转换与富化**：本机图片复制为 UUID 文件名，内存模型只保存相对文件名；远程图片保留 URL。URL 书签先成为占位数据，再由 OGP、AI 或 MCP 后台任务更新。AI 正文只保留清洗后的前 4000 字符，但 Agent 会把最多 40 个候选的 notes/metadata 发送到所配置 endpoint。
3. **持久化**：JSONStorage 先在 concurrent queue 的 barrier 中更新内存，再异步写盘。每个文件使用 atomic write，items 写入会合并 250ms 内的连续变更；四个文件之间没有事务。macOS 正常退出会 `forceSaveAllData()`，iOS 没有对应的终止钩子。
4. **索引与读取**：启动时同步读取 JSON 并重建 item/category/tag/search 字典。后续 CRUD 增量更新或全量重建缓存；SwiftUI 通过 `@Published` 和 `itemsVersion` 响应。普通搜索与 MCP 搜索共享 `CollectionSearch`，Agent 有独立候选文本规则。
5. **导入与合并**：macOS 完整导入在后台先解码并复制图片，再按分类/标签名称和 item ID/URL 过滤，最后调用一次 `DataStorage.importData`。若同名分类或标签已存在但 ID 不同，导入项不会重映射到现有 ID，可能留下无法解析的引用；若数据合并失败，已经复制的图片没有回滚。iOS 另行逐类、逐标签、逐 item 调用 CRUD，并吞掉单项错误，结果更容易部分成功。
6. **归档与恢复**：导出从主线程取内存快照，在后台写 items/categories/tags、空的 `preferences.json`、全部 Images 文件和移动 HTML。AI/MCP/UI 等 UserDefaults 设置没有进入备份，故“完整导出”实际上不包含设置。没有自动备份周期、保留策略或远端副本。
7. **删除**：删除 ImageItem 时，仅当文件位于内部 Images 目录才删除物理文件；外部路径不会删除。删除带本地 AI 海报的 Bookmark 不会清理 metadata 指向的图片，旧封面也没有引用计数，可能积累 orphan 文件。分类管理 UI 只把 Bookmark 移到 None 后再删除分类，ImageItem/TextItem 的 categoryId 可能继续引用已删除分类；删除标签则先批量移除三类条目的 tagId。

当前最重要的数据一致性边界不是容量，而是“多个异步生产者更新同一书签”和“跨 JSON/图片目录的多文件操作没有事务”。现有本机 JSON 架构仍足以支撑下一版本，不需要为了这些问题先迁移数据库。

## 缓存策略

| 缓存层 | 技术 | TTL | 失效方式 |
|------------|-----------|-----|-------------|
| ID lookup | `DataStorage` 内存 Dictionary | 进程生命周期，无 TTL | 对应 CRUD 增量更新；导入/批量更新时全量重建 |
| 搜索记录 | `[UUID: CollectionSearch.Record]` | 进程生命周期，无 TTL | item CRUD 更新；标签改名刷新引用记录；启动/导入/批量更新全量重建 |
| macOS 过滤结果 | `ContentView.cachedItems` | 无时间 TTL；查询输入 debounce 300ms | 分类、标签、类型、搜索词、排序或 `itemsVersion` 改变时取消旧任务并重算 |
| MCP 搜索 | 单个 `MCPBookmarkSearchCache` | 无时间 TTL | criteria key 或 `itemsVersion` 改变即 miss；只保留最近一种查询 |
| 远程图片 | Kingfisher memory/disk cache；列表部分使用 memory-only | 使用库默认值，项目未配置 TTL | 由 Kingfisher 默认淘汰；项目没有显式按条目失效 |
| SF Symbol/本地图标 | 进程内元组缓存、`NSCache<NSString, NSImage>` | 无 TTL；`NSCache` 可因内存压力淘汰 | 重启或系统淘汰；无显式清空 |
| HTTP | `URLSessionConfiguration.default` 的系统 cache/cookie 行为 | 服从响应头与系统策略 | 项目未配置业务 TTL 或主动失效 |

JSON 是 source of truth，以上业务缓存均可在重启后重建。项目没有 Redis/Memcached；在本机单用户规模下没有引入它们的必要。

## 建议

1. **下一版本优先做“可靠采集收件箱/处理状态”，复用现有服务而不是再加队列依赖。** 将占位创建、一次 OGP 抓取和可选 AI 解析收敛为按 bookmark ID 串行的单一路径，处理完继续 drain 未解析项，并在 UI 暴露 pending/parsing/failed/retry。这样同时消除 OGP 与 AI 竞态、忙碌时丢事件和重复网页请求，也为批量采集提供真实进度。
2. **把导入/恢复升级为可预览、可回滚的安全迁移。** 先在临时目录完整解码和校验，按名称建立 category/tag ID 重映射，展示新增/重复/冲突数量，数据提交成功后再移动图片；失败则删除 staged 文件。macOS 与 iOS 复用同一合并逻辑，并补充设置备份与 orphan 图片清理。当前 JSON 存储可以完成这些改进，无需迁移数据库。
