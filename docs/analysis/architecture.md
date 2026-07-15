# 架构分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 架构模式

Seahorse 的可部署形态是一个**本地优先的模块化单体，加一个仅 macOS 启用的 Node.js sidecar**：101 个 Swift 文件共同编译进单一 `Seahorse` App target，目录按 Models、Views、Services、Database、Storage、Utilities 技术层组织；MCP Helper 是独立进程，但随 macOS App 一起打包，不拥有数据存储。证据是 Xcode 工程仅有 App 与测试两个 native target（`Seahorse.xcodeproj/project.pbxproj`），而 App 通过 `Process` 启动 Helper（`Seahorse/Services/MCP/MCPHelperManager.swift:43-73`），Helper 的所有数据动作再回调 App bridge（`MCPHelper/src/bridgeClient.ts:19-42`）。

App 内部采用**分层架构 + Observable Store / MVVM 风格**，但不是严格 MVVM、Clean Architecture 或 Hexagonal Architecture：

- View 通过 `@EnvironmentObject`、`@StateObject` 和 `@ObservedObject` 订阅 `DataStorage` 及各服务状态（`Seahorse/ContentView.swift:28-58`；`Seahorse/Views/iOS/iOSHomePageView.swift:37-47`）。
- `DataStorage` 同时是 `@MainActor ObservableObject`、应用数据门面、内存 store、索引缓存和部分业务规则承载者（`Seahorse/Storage/DataStorage.swift:12-38,105-136`）。这相当于一个集中式 ViewModel/Store，而不是每个页面拥有独立 ViewModel。
- `DatabaseProtocol` 把上层与 JSON 实现隔开，`DataStorage(database:)` 可注入 `JSONStorage` 或 `MockDatabase`（`Seahorse/Database/DatabaseProtocol.swift:8-48`；`Seahorse/Storage/DataStorage.swift:16-21,105-108`），但许多服务和 View 仍直接访问 `.shared` singleton，所以依赖反转只覆盖持久化边界。
- 领域模型并非纯领域层：`Category`、`Tag` 直接使用 SwiftUI `Color`（`Seahorse/Models/Category.swift:8-25`；`Seahorse/Models/Tag.swift:8-23`），View 也会直接组合 `StorageManager`、`ImageFileService` 和 `DataStorage` 完成封面写入（`Seahorse/ContentView.swift:405-425`）。因此依赖方向主要靠约定，而非编译目标强制。

macOS 与 iOS 共用一个 target、同一套 Models、DataStorage、JSONStorage 和搜索核心；入口和 UI 通过条件编译分开。macOS 入口创建主窗口、详情窗口、Settings、剪贴板监控和 MCP 生命周期（`Seahorse/SeahorseApp.swift:11-97`），iOS 入口只建立 `WindowGroup` 和两栏 Tab（`Seahorse/SeahorseApp.swift:166-187`；`Seahorse/Views/iOS/iOSContentView.swift:9-32`）。

## 分层结构

依赖主路径如下。箭头表示调用或数据依赖，虚线部分是 macOS 专属 MCP 进程边界。

```text
用户 / 剪贴板 / 文件 / 系统事件                 外部 MCP Client
              │                                      │
              ▼                                      ▼
SwiftUI Views + AppKit adapters               Node MCP Helper
macOS ContentView / iOS Views                schema + session + auth
              │                                      │
              ▼                                      ▼
Application Services                         localhost /bridge + token
Paste / Copy / AI / Search / Import  ◀──── MCPBridgeServer / BridgeService
              │
              ▼
DataStorage (@MainActor Observable Store / Facade)
              │
      ┌───────┼───────────┐
      ▼       ▼           ▼
Domain Models  DatabaseProtocol   StorageManager / UserDefaults
               │                 paths / images / settings
               ▼
          JSONStorage
  items/categories/tags/preferences JSON
              │
              ▼
      File system / Network APIs
```

### 写入与反馈流

1. View、拖放、粘贴或双复制把输入交给 `PasteHandler`；`ContentView` 的 drop 与 paste command 都复用该入口（`Seahorse/ContentView.swift:143-145,348-350,395-398`）。
2. `PasteHandler` 按 URL、文本、图片优先级识别类型，再创建 Bookmark、ImageItem 或 TextItem；URL 先写入占位 Bookmark，随后异步抓取 OpenGraph metadata 并更新（`Seahorse/Services/PasteHandler.swift:26-57,219-315`）。
3. `DataStorage` 先调用 `DatabaseProtocol`，成功后更新 `items`、`bookmarks`、ID cache、search record cache 和 `itemsVersion`，并发送通知（`Seahorse/Storage/DataStorage.swift:138-200,262-303`）。
4. `JSONStorage` 在并发 queue 上修改内存数组，再由串行 writer queue 合并 item 写入并原子替换单个 JSON 文件（`Seahorse/Database/JSONStorage.swift:11-42,165-207,302-355`）。
5. SwiftUI 通过 `@Published`/`itemsVersion` 重新计算列表；macOS 与 iOS 都从 `DataStorage.searchRecordsSnapshot()` 获取快照，并调用同一个 `CollectionSearch.itemsAsync`（`Seahorse/ContentView.swift:72-99,299-302`；`Seahorse/Views/iOS/iOSHomePageView.swift:138-153`）。

### 搜索流

`DataStorage` 为每个条目维护包含 tag 名称、排序键和原始顺序的 `CollectionSearch.Record` cache（`Seahorse/Storage/DataStorage.swift:34-98`）。`CollectionSearch.Criteria` 统一表达 query、类型、分类、收藏、标签、排序和分页，并在 detached task 中执行可取消过滤/排序（`Seahorse/Services/CollectionSearch.swift:19-28,72-142`）。macOS、iOS 与 MCP 都复用该核心；MCP 仅增加基于 `itemsVersion + query key` 的结果 cache 和 JSON 序列化（`Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:94-105,222-263`）。

### AI 处理流

新条目写入后，`DataStorage` 发布 `SeahorseItemAdded`；`AutoParsingService` 观察该通知，读取 `AISettings`，抓取 metadata 和网页内容，再通过 actor `AIManager` 调用配置的模型并回写 `DataStorage`（`Seahorse/Storage/DataStorage.swift:140-158`；`Seahorse/Services/AutoParsingService.swift:13-64,84-160`）。批处理使用最多五个 TaskGroup worker，先并发生成更新结果，再通过一次 `DataStorage.updateItems` 批量提交（`Seahorse/Services/BatchParsingService.swift:87-157`）。

### MCP 请求流

1. Helper 在 `127.0.0.1:17373/mcp` 暴露 Streamable HTTP，先校验 external bearer token，再管理 session transport（`MCPHelper/src/index.ts:10-17,28-66,76-110`）。
2. Zod schema 在工具注册层验证参数，统一 handler 把 tool name 与 payload 转交 `BridgeClient`（`MCPHelper/src/tools.ts:6-64,66-84`）。
3. `BridgeClient` 携带独立 internal bearer token 调用 App 的 `127.0.0.1:17374/bridge`（`MCPHelper/src/bridgeClient.ts:19-42`）。
4. Swift `MCPBridgeServer` 限制 POST `/bridge`、校验 internal token、限制请求体为 1 MiB，然后把 request 交给 `MCPBookmarkBridgeService`（`Seahorse/Services/MCP/MCPBridgeServer.swift:20-68,108-195`）。
5. Bridge service 把字符串 action 映射到搜索/CRUD，用 `DataStorage` 作为唯一真实数据入口；Helper 不直接读取 JSON（`Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:177-218,297-367`）。

## 模块职责

| Module/Directory | Responsibility | Dependencies |
|-----------------|---------------|-------------|
| `SeahorseApp.swift` | 平台入口、对象生命周期、macOS 窗口、退出 flush、CopyMonitor/MCP 启停 | SwiftUI、AppKit、`DataStorage`、各 singleton 服务；证据：`Seahorse/SeahorseApp.swift:14-96,152-187` |
| `Views/` | macOS/iOS 展示、导航、表单、详情编辑、拖放与用户操作编排 | Models、EnvironmentObject store、Services、部分 AppKit/UIKit；证据：`Seahorse/ContentView.swift:28-58,120-351`、`Seahorse/Views/iOS/iOSHomePageView.swift:37-153` |
| `Models/` | Bookmark/Image/Text、Category、Tag、WebMetadata、设置和外观状态 | Foundation；部分模型直接依赖 SwiftUI `Color`/UI 类型；证据：`Seahorse/Models/CollectionItem.swift:8-48`、`Seahorse/Models/Category.swift:8-25` |
| `AnyCollectionItem` | 为三类条目提供带 `itemType` 的可编码异构容器和统一访问入口 | Bookmark、ImageItem、TextItem；证据：`Seahorse/Models/AnyCollectionItem.swift:10-124` |
| `Storage/DataStorage.swift` | App 的 canonical 访问门面、响应式内存状态、CRUD、查找与搜索 cache、通知、部分级联规则 | `DatabaseProtocol`、Models、CollectionSearch、NotificationService、StorageManager；证据：`Seahorse/Storage/DataStorage.swift:12-108,138-258,388-437` |
| `Database/` | 持久化契约、JSON 实现、Mock 实现；校验 ID/名称/URL 唯一性 | Models、FileManager、StorageManager、URL normalizer；证据：`Seahorse/Database/DatabaseProtocol.swift:8-48`、`Seahorse/Database/JSONStorage.swift:11-64,302-402` |
| `StorageManager` / `StoragePathManager` | 默认/自定义目录、安全作用域 bookmark、数据迁移、图片路径归一化 | FileManager、UserDefaults、AppKit；证据：`Seahorse/Storage/StorageManager.swift:11-161`、`Seahorse/Services/StoragePathManager.swift:27-169` |
| `CollectionSearch` | 三端共享的纯搜索、过滤、排序、分页与取消逻辑 | Models，无 UI 或存储依赖；证据：`Seahorse/Services/CollectionSearch.swift:3-142` |
| `PasteHandler` / `CopyMonitor` | 输入类型检测、双复制规则、placeholder 写入、图片文件保存和 metadata enrichment | AppKit、UTType、DataStorage、StorageManager、ImageFileService、OpenGraphService；证据：`Seahorse/Services/PasteHandler.swift:18-57,217-397`、`Seahorse/Services/CopyMonitor.swift:16-64,194-348` |
| AI 与分析服务 | AI client、网页抓取、自动/批量解析、Agent 搜索、封面生成、链接诊断 | AISettings、OpenAI package、NetworkManager、DataStorage、Swift concurrency；证据：`Seahorse/Services/AIManager.swift:12-64,271-367`、`Seahorse/Services/BatchParsingService.swift:14-157`、`Seahorse/Services/AgentService.swift:16-58` |
| `ExportImportManager` / `ImportService` | 浏览器书签导入、完整数据备份/恢复、图片复制、移动端静态 bookmark index | DataStorage、Models、StorageManager/StoragePathManager、FileManager、AppKit；证据：`Seahorse/Services/ImportService.swift:10-131`、`Seahorse/Services/ExportImportManager.swift:118-373,375-465` |
| `Services/MCP/` | App 内本机 bridge、Helper 生命周期、token/端口设置、MCP action 到 DataStorage 的适配 | Network.framework、Foundation Process、DataStorage、CollectionSearch、OpenGraphService；证据：`Seahorse/Services/MCP/MCPHelperManager.swift:6-224`、`Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:177-218` |
| `MCPHelper/src/` | MCP protocol/session/schema 边界和 App bridge client，不拥有业务数据 | Node HTTP、MCP SDK、Zod、Swift bridge；证据：`MCPHelper/src/index.ts:1-25`、`MCPHelper/src/tools.ts:1-84` |
| `Utilities/` | OSLog、本地化、URL 归一化、更新检查、SwiftUI/AppKit bridge、changelog 与 SF Symbols | Foundation、SwiftUI/AppKit、GitHub API；证据：`Seahorse/Utilities/Logger.swift:4-67`、`Seahorse/Utilities/UpdateManager.swift:45-136` |
| `SeahorseTests/` / `MCPHelper/tests/` | 搜索、JSON 写入、图片 I/O、MCP 生命周期与 schema/handler 回归 | XCTest、MockDatabase、Vitest；例如 `SeahorseTests/DataStorageSearchIndexTests.swift:7-64`、`MCPHelper/tests/tools.test.ts` |

## 横切关注点

### 日志

`Log` 把 OSLog 按 general、network、database、ui、paste、storage、ai、parsing、performance 分类，DEBUG 另有会在 Release 编译掉的 `DLog`（`Seahorse/Utilities/Logger.swift:8-24,27-90`）。但是 `info`、`warning`、`error`、`fault` 全部把插值消息标为 `.public`（同文件 `45-67`），而调用点会记录 URL、文件路径、标题，AI client 甚至记录 token 前缀（`Seahorse/Services/AIManager.swift:369-400`）。日志是集中式的，但隐私边界没有在 logger API 中表达。

### 错误处理

底层有 `DatabaseError`，AI 有 `AIError`，文件与导入服务也定义各自错误（`Seahorse/Database/DatabaseProtocol.swift:50-72`；`Seahorse/Services/AIManager.swift:12-39`；`Seahorse/Services/ImageFileService.swift:8-15`；`Seahorse/Services/ImportService.swift:10-20`）。传播语义不统一：`DataStorage.addBookmark/updateBookmark` 抛错，而通用 `addItem/updateItem` 捕获后只写日志（`Seahorse/Storage/DataStorage.swift:140-184,262-304`）；`JSONStorage` 的异步落盘失败也只记录、不回传调用者（`Seahorse/Database/JSONStorage.swift:165-207`）。UI 层因此有的路径能提示失败，有的路径只能静默继续。

### 身份验证与授权

App 本身是单用户本地应用，没有账户或角色授权。唯一远程风格边界是 MCP，但它只绑定 loopback，并使用两层 bearer token：外部 client→Helper 与 Helper→App bridge 使用不同 token（`Seahorse/Services/MCP/MCPSettings.swift:16-43`；`MCPHelper/src/index.ts:28-37`；`Seahorse/Services/MCP/MCPBridgeServer.swift:171-183`）。token 由 `SecRandomCopyBytes` 生成，但与 AI API token 一样保存在 UserDefaults，而非 Keychain（`Seahorse/Services/MCP/MCPSettings.swift:38-70`；`Seahorse/Models/AISettings.swift:15-24,63-72`）。

### 配置

构建配置由 Xcode project、Info.plist 和 entitlements 管理；用户配置分散在 `@AppStorage` 与多个 UserDefaults-backed singleton，如 AISettings、MCPSettings、AppearanceManager、SortPreferenceManager 和 CopyMonitor（例如 `Seahorse/Services/CopyMonitor.swift:29-52`、`Seahorse/Models/AISettings.swift:15-103`）。MCP 端口和 host 是 Swift 常量，运行 Helper 时转成环境变量（`Seahorse/Services/MCP/MCPSettings.swift:16-18`；`Seahorse/Services/MCP/MCPHelperManager.swift:193-200`）。没有统一的大配置对象，也不需要额外配置框架。

### 验证

输入边界存在分层验证：MCP Helper 用 Zod 校验 UUID、分页和数量上限（`MCPHelper/src/tools.ts:6-50`）；Swift bridge 再验证 category/tag 是否存在和请求业务规则（`Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:337-402`）；JSONStorage 最终检查 ID、名称与规范化 URL 唯一性（`Seahorse/Database/JSONStorage.swift:302-402`）。这提供了纵深防御，但同一 URL/关系规则也在 PasteHandler、DataStorage、import merge 和数据库多处重复，修改时需要同时核对。

### 并发与状态传播

UI store 与多数 ObservableObject 被 `@MainActor` 隔离；AI、Agent 与图片文件操作使用 actor，搜索和导入导出用 detached task 把 CPU/I/O 移出主 actor（`Seahorse/Services/AIManager.swift:49`；`Seahorse/Services/AgentService.swift:16`；`Seahorse/Services/ImageFileService.swift:8`；`Seahorse/Services/CollectionSearch.swift:129-142`；`Seahorse/Services/ExportImportManager.swift:124-143`）。状态传播同时使用 `@Published`、`itemsVersion`、EnvironmentObject 和字符串 NotificationCenter 事件（`Seahorse/Storage/DataStorage.swift:23-32,151-180`；`Seahorse/ContentView.swift:331-347`），属于混合事件模型。

## 使用的设计模式

| Pattern | Where | Purpose |
|---------|-------|---------|
| Observable Store / Facade | `DataStorage` | 为 View、Services、MCP 提供统一 CRUD、内存状态、cache 和数据库入口（`Seahorse/Storage/DataStorage.swift:12-108`） |
| Repository / Adapter | `DatabaseProtocol` + `JSONStorage` / `MockDatabase` | 隔离数据访问实现，并支持 preview/测试注入（`Seahorse/Database/DatabaseProtocol.swift:8-48`；`Seahorse/Storage/DataStorage.swift:16-21,105-108`） |
| Singleton / Service Locator | `DataStorage.shared`、StorageManager、AISettings、NetworkManager、各 Manager | 保持 app-wide 生命周期和共享设置，代价是隐式依赖（例如 `Seahorse/SeahorseApp.swift:16-36`） |
| Observer | SwiftUI `@Published`/EnvironmentObject、NotificationCenter | 驱动 UI 更新、菜单命令、自动 AI 解析和 toast（`Seahorse/ContentView.swift:261-351`；`Seahorse/Services/AutoParsingService.swift:22-31`） |
| Type Erasure / Tagged Union | `AnyCollectionItem` + `CollectionItemType` | 在单一数组和 JSON 文件中承载三类条目（`Seahorse/Models/AnyCollectionItem.swift:10-82`） |
| Criteria / Strategy-like policy | `CollectionSearch.Criteria`、`Kind`、`Order` | 用同一过滤排序引擎服务 macOS、iOS、MCP（`Seahorse/Services/CollectionSearch.swift:3-28,72-126`） |
| Actor isolation | `AIManager`、`AgentService`、`ImageFileService` | 串行化可变状态或把昂贵 I/O 与 UI state 隔离（对应文件声明行） |
| Sidecar + Adapter | Node MCP Helper、`BridgeClient`、Swift `MCPBridgeServer` | 把 MCP SDK/protocol 生命周期与 Swift App 数据域隔离（`MCPHelper/src/index.ts:16-25`；`MCPHelper/src/bridgeClient.ts:19-42`） |
| State machine | `MCPServerStatus` + `MCPHelperManager` | 表达 stopped/restarting/running/failed/portUnavailable 与受控重启（`Seahorse/Services/MCP/MCPSettings.swift:4-10`；`Seahorse/Services/MCP/MCPHelperManager.swift:76-135`） |
| Snapshot + Batch Commit | 搜索 record snapshot、BatchParsingService、ExportSnapshot | 后台计算使用不可变快照，完成后在主 store 一次更新（`Seahorse/Storage/DataStorage.swift:93-98`；`Seahorse/Services/BatchParsingService.swift:118-156`；`Seahorse/Services/ExportImportManager.swift:62-68,365-373`） |

## 架构优势

1. **真实数据所有权清楚。** UI、AI、导入和 MCP 最终都经过 `DataStorage`/`DatabaseProtocol`；Node Helper 不绕过 App 直接碰 JSON。尤其 MCP 用 external/internal token 分离两个本机边界，sidecar 崩溃还有受控重启和父进程守护（`MCPHelper/src/index.ts:68-74`；`Seahorse/Services/MCP/MCPHelperManager.swift:123-135`）。
2. **跨平台与外部接口共享核心规则。** macOS、iOS、MCP 共用 `CollectionSearch`，URL 唯一性最终由 JSONStorage 规范化校验，避免三端各自演进出不同搜索与持久化语义（`Seahorse/Services/CollectionSearch.swift:72-142`；`Seahorse/Database/JSONStorage.swift:302-402`）。
3. **在当前规模下有足够的测试 seam。** `DataStorage(database:)`、`JSONStorage(dataDirectory:saveDelay:writeData:)`、BridgeClient 的 `fetchImpl` 都可注入，已有 MockDatabase/XCTest/Vitest 使用这些边界验证搜索、写盘与 MCP（`Seahorse/Storage/DataStorage.swift:105-108`；`Seahorse/Database/JSONStorage.swift:37-45`；`MCPHelper/src/bridgeClient.ts:19-24`）。
4. **并发边界总体可辨认。** UI state 留在 MainActor，搜索、文件、AI 和批处理有 actor/detached task/cancellation；批量 AI 结果通过 `updateItems` 合并提交，而不是每项都立即刷新全局状态（`Seahorse/Services/BatchParsingService.swift:87-157`）。
5. **没有为扩展性提前拆成多模块。** 单 target、一个数据库协议和少数 actor 足以支撑当前约 23K 行 App；新增功能仍可沿稳定的 Models→DataStorage→Database 路径交付，不需要先引入内部 framework、DI 容器或事件总线。

## 架构风险

1. **`DataStorage` 是过宽的变化中心。** 它同时维护 canonical `items`、派生但又独立可变的 `bookmarks`、四类 cache、通知、副作用、物理图片删除、分类/标签规则和数据库调用（`Seahorse/Storage/DataStorage.swift:21-103,138-258,260-437`）。新条目类型或 undo/smart collection 若继续在这里叠分支，会同时影响内存一致性、搜索索引、UI 刷新和持久化。
2. **“操作成功”与“已持久化”不是同一语义。** JSONStorage 先修改内存，再异步写文件；写盘异常仅记录日志，调用者无法感知（`Seahorse/Database/JSONStorage.swift:165-207,302-355`）。通用 `DataStorage.addItem/updateItem` 又吞掉数据库错误，而 bookmark API 会抛错（`Seahorse/Storage/DataStorage.swift:140-184,262-304`）。这会让不同入口表现不一致，并使可靠的 undo、批量整理或自动化回执难以建立。
3. **跨文件和文件+记录操作缺少统一提交边界。** 导入分别调度 categories、tags、items 三个 JSON 写入（`Seahorse/Database/JSONStorage.swift:357-383`）；删除 Tag 先批量更新 item，再单独删 Tag（`Seahorse/Storage/DataStorage.swift:412-437`）；删除图片则先删物理文件再尝试删除数据库记录（`Seahorse/Storage/DataStorage.swift:221-258`）。单文件写使用 `.atomic`，但整个业务操作不是原子的，进程中断或第二步失败可能留下半完成状态。
4. **存储路径职责重复。** `StorageManager` 和 `StoragePathManager` 都解析同一 security-scoped bookmark、持有访问生命周期并计算默认/自定义目录（`Seahorse/Storage/StorageManager.swift:11-141`；`Seahorse/Services/StoragePathManager.swift:27-92`）。App 还必须依赖初始化顺序确保 DataStorage 看到正确路径（`Seahorse/SeahorseApp.swift:16-45`）。这使迁移、备份、JSON 和图片路径的 source of truth 不够单一。
5. **依赖和事件大量隐式化。** 多数类型直接访问 `.shared`，跨组件命令使用 `"ShowImportDialog"`、`"ShowToast"`、`"SeahorseItemAdded"` 等字符串通知（`Seahorse/SeahorseApp.swift:73-79`；`Seahorse/ContentView.swift:331-347`；`Seahorse/Storage/DataStorage.swift:153-157`）。通知没有 payload 类型保证；`AutoParsingService` 收到的事件甚至不包含 item ID，只能重扫未解析 Bookmark（`Seahorse/Services/AutoParsingService.swift:26-54`）。
6. **敏感配置与日志的边界偏弱。** AI token、MCP external/internal token 存在 UserDefaults，OSLog wrapper 又把动态消息统一标为 public（`Seahorse/Models/AISettings.swift:21-24,69-72`；`Seahorse/Services/MCP/MCPSettings.swift:26-43`；`Seahorse/Utilities/Logger.swift:45-67`）。这不是层次结构错误，但会让任何新增联网/共享功能继承不安全的默认配置习惯。
7. **MCP 契约由两端字符串手工同步。** TypeScript 注册工具名与 Swift `switch request.action` 是两份独立清单（`MCPHelper/src/tools.ts:52-64`；`Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:191-217`），中间 payload 是通用 `[String: JSONValue]`。已有测试降低风险，但新增工具仍可能出现 schema 已发布、Swift action 未实现或字段解释不一致；Helper 运行还依赖外部 Node（`Seahorse/Services/MCP/MCPHelperManager.swift:56-59`）。
8. **编译层不会阻止反向依赖。** Models 使用 SwiftUI 类型，Views 直接组合文件服务与存储，所有 Swift 源又位于同一 target。当前规模尚可，但目录命名本身无法阻止业务规则进入 View 或底层类型引用 UI；`ContentView.applyGeneratedCover` 已展示这种跨层编排（`Seahorse/ContentView.swift:405-425`）。

## 建议

1. **下一版本继续用现有单 target，不做全面架构重写。** 新功能先复用 `AnyCollectionItem`、`CollectionSearch`、`DataStorage` 和 `DatabaseProtocol`；只有一个规则被 macOS、iOS、MCP 或多个 View 同时使用时，才抽到纯 service/use-case 函数。不要为“未来扩展”增加 DI 容器、事件总线或内部 framework。
2. **在增加 undo、批量整理、智能集合或更多 MCP 写操作前，先统一写入契约。** 让所有 DataStorage mutation 都明确返回/抛出结果，只在持久化确认后对外报告成功；图片删除改为记录提交成功后再清理文件。最小可行方向是复用现有 `DatabaseProtocol` 增加一个批量 mutation/snapshot 提交点，而不是另建 repository 层。
3. **把业务级一致性放在一个提交边界。** category/tag/item 导入、Tag 级联和图片记录应整批验证后一次提交；当前 JSON 方案可以通过单一 snapshot 文件或临时目录+rename 实现，无需立刻迁移 SQLite。只有数据量或并发指标证明 JSON 到达上限时再换存储引擎。
4. **合并存储路径所有权。** 保留一个负责 security-scoped bookmark 与 root/Data/Images/Backups 解析的组件，另一个只承担 UI 状态或删除。下一版本若加入同步、自动备份或恢复，这是首要前置，否则多个路径解释会放大数据迁移风险。
5. **限制新增 singleton 与字符串通知。** View 内部状态继续用 SwiftUI；跨层数据变化继续走 DataStorage；仅 App 级菜单/系统事件保留 NotificationCenter，并至少定义集中式 `Notification.Name` 与强类型 payload/item ID。无需一次性改写现有通知，修改相关功能时逐条收口。
6. **把凭据和日志隐私作为所有联网新功能的默认基础。** AI/MCP token 迁入 Keychain，logger 默认 private，只对计数、状态和非敏感 ID 显式 public；移除 token 前缀、完整 URL/文件路径的 info 日志。这样下一版本新增分享、同步或 Agent 能力时不必再次迁移安全边界。
7. **保持 MCP sidecar 薄且自包含。** 搜索、验证后的业务规则和 CRUD 继续落在 Swift/DataStorage；Helper 只处理协议与 schema。新增 action 时用一份共享生成清单或至少一项双端契约测试锁定名称/字段，并随 App 提供可预测的 Helper runtime；不应让 TypeScript 层发展第二套领域模型。
