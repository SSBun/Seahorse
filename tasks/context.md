# Workspace Context

## Components
- `MCPHelper/` 是 Seahorse 的 TypeScript/Node.js MCP 协议层，负责工具 schema、Streamable HTTP 和外部 token 鉴权。
- `Seahorse/Services/MCP/` 是 App 内 bridge，负责把 MCP action 转换为 `DataStorage` 操作。
- `Seahorse/Storage/DataStorage.swift` 是 bookmark、image、text 条目的统一内存与持久化入口。
- `Seahorse/Database/JSONStorage.swift` 以 `items.json`、`categories.json`、`tags.json` 和 `preferences.json` 实现全文件 JSON 持久化。
- `Seahorse/Services/CollectionSearch.swift` 是 macOS、iOS 和 MCP 共用的纯搜索、排序与分页核心。
- `Seahorse/Services/ImageFileService.swift` 是串行执行图片复制和 PNG 编码的 actor。
- `SeahorseTests/` 是搜索、JSON 持久化、图片 I/O 和模型性能回归测试目标。

## Relationships
- 外部 agent 调用 `MCPHelper` 工具后，由 helper 调用 App 内 HTTP bridge；真实数据读写只通过 `DataStorage` 完成。
- `AnyCollectionItem` 统一封装 `Bookmark`、`ImageItem` 和 `TextItem`，其 UUID 在 `DataStorage.items` 中用于定位条目。
- `DataStorage` 是 `@MainActor ObservableObject`，CRUD 先调用 `JSONStorage`，再更新 `@Published` 数组、按类型拆分的 ID lookup cache 和搜索记录 cache。
- macOS、iOS 和 MCP 从 `DataStorage` 获取不可变搜索记录快照，并在后台调用 `CollectionSearch`；`itemsVersion` 驱动 UI 重算和 MCP 分页缓存失效。

## Domain
- Seahorse collection item 包含 `bookmark`、`image`、`text` 三种类型。
- tag 和 category 的 MCP 能力当前只读。

## Decisions and Conventions
- Seahorse App 当前版本为 `1.8.0`，build number 为 `7`；source of truth 是 Xcode target 的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`。
- MCP server 仅监听本机固定端口，并使用 bearer token 鉴权。
- MCP helper 不直接读写 Seahorse JSON 存储。
- MCP helper 使用 SDK `registerTool()` 配置对象注册 schema、annotations 和 handler，避免旧 `tool()` API 对普通对象的重载歧义。
- MCP 使用通用 `delete_item(id)` 删除 bookmark、image 或 text；tag 和 category 不提供写操作。
- 图片删除只允许作用于解析符号链接后仍位于 Seahorse `Images/` 目录内的文件。
- `JSONStorage` 对频繁 item 更新进行延迟合并；App 退出、存储迁移和显式 `forceSaveAllData()` 会同步写入最新快照。
- 多条 item 更新和数据导入使用批量数据库 API，整批验证通过后才修改内存或持久化数据。
- 缩略图允许异步下采样，全屏图片查看器保留原始分辨率。
- macOS 侧边栏的 tags 按本地化标准字母顺序展示；持久化顺序和 Tag 管理页顺序不受影响。
