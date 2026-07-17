# Workspace Context

## Components
- `ImageGenerationService` 保存待生成 bookmark ID，并把封面任务、样式、状态和图片元数据持久化到 `Data/image-generations.json`；生成 PNG 位于 `Images/`，macOS 唯一的 `Image Generation` 窗口提供样式、历史、图片详情、导出与 Apply。
- `AISettings` 保存多个命名 Agent Provider、Agent/图片选中 ID，以及独立 Codex Agent/图片模型；OpenAI/Claude-compatible token 按 profile ID 存入 macOS Keychain，profile JSON 不含凭据。
- `MCPHelper/src/codexAuth.ts` 拥有 Codex OAuth 登录、状态、断开和自动刷新；Swift 界面只通过内部鉴权 endpoint 读取状态和登录 URL。
- macOS `AgentPanelView` 通过 `AgentService.send(_:to:)` 调用 helper 的内部 `/agent` endpoint；helper 内的 Pi `Agent` 负责内存会话、LLM 调用和只读工具循环。
- Seahorse App 使用一个同时支持 macOS、iOS 和 iOS Simulator 的 Xcode target；macOS 提供完整采集/管理/MCP，iOS 界面位于 `Views/iOS/`。
- `Seahorse/Storage/StorageManager.swift` 将存储根目录分为 `Data/`、`Images/` 和 `Backups/`，JSON 数据实际位于 `Data/`。
- `MCPHelper/` 是 Seahorse 的 TypeScript/Node.js sidecar，负责 Pi Agent runtime、内部 `/agent`、外部 `/mcp`、工具 schema 和分离的 bearer token 鉴权。
- `Seahorse/Services/MCP/` 是 App 内 bridge，负责把 MCP action 转换为 `DataStorage` 操作。
- `Seahorse/Storage/DataStorage.swift` 是 bookmark、image、text 条目的统一内存与持久化入口。
- `Seahorse/Database/JSONStorage.swift` 以 `items.json`、`categories.json`、`tags.json`、`smart-collections.json` 和 `preferences.json` 实现全文件 JSON 持久化。
- `Seahorse/Services/CollectionSearch.swift` 是 macOS、iOS 和 MCP 共用的纯搜索、排序与分页核心。
- `Seahorse/Services/ImageFileService.swift` 是串行执行图片复制和 PNG 编码的 actor。
- `SeahorseTests/` 是搜索、JSON 持久化、图片 I/O 和模型性能回归测试目标。

## Relationships
- `DataStorage.category(named:)` 与 `tag(named:)` 按持久层相同的 `lowercased()` 语义解析名称；自动与批量富化复用该入口，批量新标签的查询和创建在同一 `MainActor` 闭包内完成。
- `DiagnosticService` 将链接结果分为 Accessible、Unverified 与 Broken；HEAD 405/501 会回退带 Range 的 GET，只有 Broken 可在诊断页选择并移入回收站。
- 书签详情的 Generate Cover 入口可无参考图生成，也可复用网页选区裁剪当前视口或读取剪贴板图片；参考图在任务开始时另存为 `Images/cover-reference-*.png`、文件名随生成记录持久化，并作为 Codex Responses `input_image` 或 OpenAI-compatible Images Edits 输入。
- URL 富化与链接健康是两条独立链路：`AutoParsingService`/`BatchParsingService` 负责 OGP、AI 与分类标签写入，`DiagnosticService` 负责 HTTP 可达性检查；富化失败不等于死链。
- 分类与标签名称在持久层按 `lowercased()` 保证唯一；所有解析入口必须按同一语义复用现有对象，并且只有成功持久化的 UUID 才能写回 item。
- 封面生成完成时先保存 `generated-cover-*.png` 再原子更新记录 JSON；Apply 另存 `preview-*.png` 给 bookmark，因此清除生成历史可删除原生成文件而不破坏已应用封面。
- bookmark 详情页先把目标 bookmark 交给唯一的 `Image Generation` 窗口，用户选择 `CoverStyle` 后才排队；主页工具入口会先清除该临时目标，因此窗口只显示生成进度与历史。Codex 图片请求的 Swift timeout 为 330 秒，覆盖 helper 的 300 秒上游截止时间。
- `AgentService` 将当前 Agent Provider profile 发送给 helper，并读取 Codex 模型目录或请求 Codex 图片：Codex OAuth 由 `CodexAuth` 解析或刷新，OpenAI-compatible Agent 使用 Chat Completions，Claude-compatible Agent 使用 Anthropic Messages。
- `MCPHelperManager` 随 macOS App 始终运行 helper 和 App bridge；关闭 MCP 只禁用外部 `/mcp` route，内部 `/agent` 仍可用。
- Agent 面板与外部 MCP 共用 Node helper 和 Swift bridge：Agent 经 Pi 只读工具调用 bridge，外部 MCP 经已注册工具调用 bridge，真实数据操作最终都进入 `DataStorage`。
- URL 采集、MCP 创建和自动解析统一进入 `AutoParsingService` 的持久化 FIFO 富化队列；队列按 Bookmark ID 重新读取最新快照，串行执行 OGP 与可选 AI，失败状态可重试。
- `DataStorage.items` 保留活动与回收站条目；普通 UI、搜索、Agent 与 MCP 只读取 `deletedAt == nil`，永久删除才从 JSON 移除记录并按引用清理内部图片。
- `JSONStorage` 对单个 JSON 使用 atomic replace，单条 items 写入会延迟合并；五个 JSON 与 `Images/` 之间没有跨文件事务。
- iOS 当前通过 ZIP/文件夹导入本地副本后浏览，没有 CloudKit、文件变化监听或冲突解决，不是实时双向同步。
- 外部 agent 调用 `MCPHelper` 工具后，由 helper 调用 App 内 HTTP bridge；真实数据读写只通过 `DataStorage` 完成。
- `AnyCollectionItem` 统一封装 `Bookmark`、`ImageItem` 和 `TextItem`，其 UUID 在 `DataStorage.items` 中用于定位条目。
- `DataStorage` 是 `@MainActor ObservableObject`，CRUD 先调用 `JSONStorage`，再更新 `@Published` 数组、按类型拆分的 ID lookup cache 和搜索记录 cache。
- macOS、iOS 和 MCP 从 `DataStorage` 获取不可变搜索记录快照，并在后台调用 `CollectionSearch`；`itemsVersion` 驱动 UI 重算和 MCP 分页缓存失效。

## Domain
- `SmartCollection` 按 Category/Tag UUID 持久化筛选规则；引用缺失时规则保留但匹配为空，macOS/iOS 共用 `CollectionSearch` 语义。
- 核心 JSON 没有 schema version 或显式迁移器；Category/Tag 关系以 item 内 UUID 逻辑引用表达，没有外键。
- Seahorse collection item 包含 `bookmark`、`image`、`text` 三种类型。
- tag 的 MCP 能力支持读取和删除；category 仍只读。

## Decisions and Conventions
- URL 保存成功即代表书签可用；OGP、AI、分类或标签富化属于辅助能力，失败不影响链接健康，也不赋予删除资格。
- 链接健康检查不把 HTTP 404 放入可批量删除集合，只显示“当前未找到”；HTTP 410 才自动归为已失效。
- timeout、HTTP 429 和 5xx 等临时富化失败首版只手动重试；不增加后台自动重试器。
- 修复富化名称语义后不自动重跑旧失败记录；批量恢复必须由用户主动触发，避免意外 AI 费用和内容变化。
- 链接健康检查将 HTTP 401/403、429、5xx、timeout、DNS 和 TLS 错误统一归为“无法确认”，并排除批量删除。
- 工具栏只显示富化问题数量并打开独立问题列表，不再把所有失败记录直接展开为超长菜单。
- 富化一致性与问题列表、HTTP 三态链接健康检查分成两个独立提交，分别验证和回滚。
- 已完成的封面记录在同一生成窗口内打开详情，图片交互复用 `ImageViewer`，导出复用 macOS `NSSavePanel`；不新增详情窗口或图片浏览依赖。
- 封面样式固定为 Editorial、Minimal、Gradient、Illustration、Cinematic、Surreal、Soft 3D、Geometric；每个样式的真实生成示例以 1536×1024 PNG 嵌入 Asset Catalog，资源名与实际 prompt 共享 `CoverStyle` 模型。
- 内置 Agent 支持多个命名的 `openai-compatible`、`claude-compatible` profile 和固定 `openai-codex` profile，并只激活其中一个；Compatible token 存入 Keychain，旧单组设置首次迁移为默认 OpenAI profile。
- Codex Agent/图片模型从 Pi `openai-codex` 目录搜索选择；Codex 图片通过 OAuth 调用 Responses `image_generation`，OpenAI-compatible 图片复用 profile Keychain token 与 Base URL，Claude-compatible 不进入图片 Provider；旧单组字段只保留给自动 AI 解析，prompt 设置独立展示。
- Codex OAuth 凭据固定保存在 Application Support 的 `Seahorse/Codex/auth.json`，文件权限为 `0600`；不保存到 UserDefaults、自定义数据目录或日志。
- 内置 Agent 固定使用 Pi `0.80.7` 的 `pi-agent-core`/`pi-ai`，首版只开放 bookmark/tag/category 的 search/get/list 工具；没有确认 UI 前不开放写工具。
- 回收站的批量移入、恢复和永久删除会同步确认 `items.json` 原子写入；写盘失败时 JSONStorage 回滚内存候选状态并向调用方返回错误。
- MCP 使用通用 `delete_item(id)` 将 bookmark、image 或 text 幂等移入回收站，并返回 `movedToTrash`/`alreadyInTrash`。
- 图片删除只允许作用于解析符号链接后仍位于 Seahorse `Images/` 目录内、且永久删除后不再被任何条目引用的文件。
- Xcode 当前实际最低版本是 macOS 15.2、iOS 16.0；README/官网的 macOS 13.0+ 声明尚未与构建目标对齐。
- GitHub 最新 tag 仍为 `v1.7.0`，而 App/CHANGELOG 已为 `1.9.0`；发布工作流依赖 tag/Latest Release。
- Seahorse App 当前版本为 `1.9.0`，build number 为 `8`；source of truth 是 Xcode target 的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`。
- MCP server 仅监听本机固定端口，并使用 bearer token 鉴权。
- MCP helper 不直接读写 Seahorse JSON 存储。
- `scripts/create-dmg.sh` 会先构建 helper，再将 `dist`、production-only Node 依赖、Pi/Node 许可证和兼容的 Node `>=22.19.0` 独立运行时写入 App bundle，并使用原身份重签名后生成 DMG。
- MCP helper 使用 SDK `registerTool()` 配置对象注册 schema、annotations 和 handler，避免旧 `tool()` API 对普通对象的重载歧义。
- MCP 设置页提供 `Force Restart`：只清理命令精确匹配当前 helper 脚本的进程，等待终止后再启动；helper 通过父 PID 守护避免 App 异常退出后成为孤儿进程。
- MCP 使用 destructive `delete_tag(id)` 删除 Tag；`DataStorage.deleteTag` 会先批量清除全部 item 类型中的关联，category 仍不提供写操作。
- `JSONStorage` 对频繁 item 更新进行延迟合并；App 退出、存储迁移和显式 `forceSaveAllData()` 会同步写入最新快照。
- 多条 item 更新和数据导入使用批量数据库 API，整批验证通过后才修改内存或持久化数据。
- 缩略图允许异步下采样，全屏图片查看器保留原始分辨率。
- macOS 侧边栏的 tags 按本地化标准字母顺序展示；持久化顺序和 Tag 管理页顺序不受影响。
- Advanced Settings 从 App bundle 的 `CHANGELOG.md` 读取并只展示当前 marketing version 的变更；入口是 `Updates` 标题旁的 `info.circle`。
