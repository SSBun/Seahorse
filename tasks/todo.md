# 补全 Codex Agent 临时错误重试

## 状态

- 已完成（2026-07-19）

## 目标

- Codex 默认请求路径遇到临时 429/5xx 时最多重试一次。
- 400/401 等不可重试错误保持单次请求并原样失败。
- 重试不得重复已完成的工具调用，也不得改变其他 Provider。

## 边界

- 只修改 helper 的 Codex Agent stream 配置与定向测试。
- 复用 Pi provider；不新增依赖、不修改 UI、不扩大到图片生成。
- 覆盖 HTTP 临时错误、不可重试错误和错误响应前已开始输出等边界，避免重复部分响应。

## 计划

- [x] 先添加会在当前实现下失败的回归测试。
- [x] 实现一次、分类明确且不重复部分输出的重试。
- [x] 运行定向测试、全量测试、TypeScript 构建、macOS 构建和差异检查。
- [x] 通过独立对抗式审查。

## Review status

- Gate: APPROVED
- Reviewer: `/root/codex_retry_reviewer`
- Round: 3/3
- Scope: `MCPHelper/src/agentRuntime.ts`、`MCPHelper/tests/agentRuntime.test.ts`、`tasks/context.md` 的本任务事实及需求与验证证据
- Resolved: R1–R6；Reviewer 已批准最终受审差异
- Unresolved: none

# 审查当前本地改动

## 状态

- 已完成（2026-07-19）

## 目标

- 以 `HEAD` 为基线审查当前未提交改动的规范符合度与需求符合度。
- 运行与变更风险相称的最小验证，并只报告可操作问题。

## 边界

- 不修改产品代码。
- 保留工作区现有未提交改动；本任务记录不纳入待审产品差异。

## 计划

- [x] 固定原始差异与需求来源。
- [x] 并行完成规范与需求审查。
- [x] 复核发现并运行最小验证。

## 审查记录

- 发现默认 WebSocket 路径收到 Codex 500 error event 时不会执行配置的一次重试；本地错误注入只产生一次请求并失败。
- 发现 SSE 路径会把 401 等不可重试 HTTP 错误也重试一次；新增测试只验证 `maxRetries` 参数透传，没有覆盖错误分类与真实重试。
- helper 全量 26 项测试、TypeScript 构建、Swift 解析、macOS Debug 构建与 `git diff --check` 均通过；除上述问题外未发现 UI 行为缺陷。

# 修复 Codex Agent 临时 500 错误

## 状态

- 已完成（2026-07-19）

## 目标

- Codex 上游出现临时 429/5xx 时不立即让聊天失败。
- 保持不可重试错误、工具执行和其他 Provider 行为不变。

## 边界

- 复用 Pi Codex provider 的内置重试判断，只重试一次。
- 不在 UI 吞掉错误，不实现自定义重试器。

## 计划

- [x] 用真实 helper 路径复现并定位失败边界。
- [x] 为 Codex provider 请求启用一次内置重试。
- [x] 运行 helper 测试、构建与 macOS 构建。
- [x] 通过独立对抗式代码审查。

## 审查记录

- 真实 helper 的普通问候和书签工具查询均可成功；失败日志确认错误边界位于 Codex 上游请求，Pi Codex 默认不重试临时 500。
- Codex Agent 现在复用 Pi 的临时错误判断并最多重试一次；重试发生在单次模型响应完成前，不会重复已经完成的工具调用，其他 Provider 与最终错误展示不变。
- helper 定向测试 7 项、全量测试 26 项、TypeScript 构建、macOS Debug 构建与 `git diff --check` 均通过；独立 Reviewer 批准最终完整差异。

# 恢复 Agent 窗口的标准层级

## 状态

- 已完成（2026-07-19）

## 目标

- Agent 保持独立窗口，但不再始终置于其他窗口上方。

## 边界

- 只移除显式 AppKit 浮动层级，不改变窗口、聊天或详情行为。

## 计划

- [x] 移除 `.floating` 层级并更新持久上下文。
- [x] 运行 Swift 解析、构建和差异检查。
- [x] 通过独立对抗式代码审查。

## 审查记录

- `agent-chat` 保持唯一、可调整尺寸的普通 SwiftUI Window，并移除 AppKit `.floating` 层级，因此不再始终置顶。
- Swift 解析、macOS Debug 构建与 `git diff --check` 均通过；独立 Reviewer 批准完整差异。

# 将 Agent 聊天迁移为独立浮动窗口

## 状态

- 已完成（2026-07-19）

## 目标

- 从主内容分栏移除 Agent 聊天。
- 工具栏 Agent 按钮打开唯一、可调整尺寸的浮动窗口。
- 保留 Markdown、书签卡片、会话和详情打开行为。

## 边界

- 使用现有 SwiftUI Window 场景与 WindowAccessor，不增加窗口管理抽象。
- 不修改 Agent 服务、搜索协议或消息模型。

## 计划

- [x] 新增 Agent Window 场景并设置浮动层级。
- [x] 从主窗口移除内嵌分栏和可见性状态。
- [x] 运行 Swift 解析、构建和差异检查。
- [x] 通过独立对抗式代码审查。

## 审查记录

- 主窗口已移除 Agent 分栏和可见性状态，工具栏按钮统一打开唯一 `agent-chat` Window。
- Agent Window 复用现有 `WindowAccessor` 设置 AppKit `.floating` 层级，默认 380×680 点，并保留可调整尺寸、Markdown、书签卡片和详情窗口行为。
- Swift 解析、macOS Debug 构建与 `git diff --check` 均通过；独立 Reviewer 批准完整差异。

# 优化 Agent 聊天界面与交互

## 状态

- 已完成（2026-07-19）

## 目标

- 修正消息气泡占满整行和聊天区域层级失衡的问题。
- 使用 macOS 系统颜色、材质、控件样式与间距组织标题、消息和输入区。
- 支持拖拽调整 Agent 侧栏宽度，并用系统能力渲染 Markdown 回复。
- 优化内联书签卡片的信息层级和点击呈现。
- 保持现有 Agent 搜索、结果打开和会话行为不变。

## 边界

- 只修改 Agent 面板及其主窗口分栏容器，不重构 Agent 服务。
- 不引入自定义设计系统、第三方依赖或新功能入口。

## 计划

- [x] 调整消息行、滚动区和输入区布局。
- [x] 接入可拖拽系统分栏和 Markdown 渲染。
- [x] 优化内联书签卡片。
- [x] 运行 Swift 解析、构建和差异检查。
- [x] 通过独立对抗式代码审查。

## 审查记录

- 主内容和 Agent 面板改用原生 `HSplitView`，主内容最小宽度 420 点，Agent 面板可在 300–600 点间拖拽，理想宽度为 380 点。
- Agent 回复通过系统 `AttributedString(markdown:)` 渲染，解析失败回退原文；用户输入和错误文本保持字面显示。
- 内联书签卡片使用系统字体、图标底板、分隔色和导航提示，详情窗口与 Agent 会话行为未变。
- Swift 解析、macOS Debug 构建与 `git diff --check` 均通过；构建只包含既有警告，独立 Reviewer 解决 R1 后批准最终实现。

# 发布 Seahorse 1.10.0

## 状态

- 已完成（2026-07-18）

## 目标

- 将 App minor 版本从 `1.9.0 (8)` 升级到 `1.10.0 (9)`，同步 CHANGELOG。
- 构建并验证包含 MCP helper 的签名 Release App 与 DMG。
- 经远端动作确认后推送 `main`、创建 `v1.10.0` 并发布 DMG。
- 首次公开发布 npm 原生 App wrapper：`@ssbun/seahorse@1.10.0`。

## 边界

- 复用现有 `scripts/create-dmg.sh` 与 tag-triggered GitHub workflow。
- 正式附件使用本地签名 DMG，不把 CI 的 `NO_SIGN=1` 构建描述为签名分发包。
- npm 包只提供标准库下载/打开脚本，DMG 保留在 GitHub Release，不嵌入 npm tarball。
- 本轮不增加 notarization、Sparkle appcast 或新的发布系统。

## 计划

- [x] 更新版本、build number、CHANGELOG 与发布任务记录。
- [x] 运行完整测试，构建并验证 Release App、DMG、签名和校验和。
- [x] 提交发布元数据并复核工作区。
- [x] 列出远端 push/tag/release 动作，取得确认后执行并监控完成。
- [x] 添加并演练 `@ssbun/seahorse` 的最小原生 App npm wrapper。
- [x] 上传 GitHub Release DMG 后正式发布 npm，并验证 registry 版本。

## 审查记录

- 完整 macOS 测试套件通过；`scripts/create-dmg.sh 1.10.0` 成功构建 Release App、生产依赖和内嵌 Node `22.22.2`。
- `hdiutil verify`、SHA256、DMG 挂载检查和内外两份 App 的 `codesign --verify --deep --strict` 均通过；产物版本为 `1.10.0 (9)`，SHA256 为 `a31e7f5956d1621971d235a17ddfe2c1139183e2e7f62435e8a2080cf2d9d1b5`。
- App 使用 Apple Development 身份签名，未包含 notarization ticket；正式发布时必须明确这一限制。
- 发布元数据提交为 `release: prepare 1.10.0`；构建产物位于忽略的 `dist/`，没有污染跟踪文件。
- `@ssbun/seahorse@1.10.0` 尚未占用；`npm pack --dry-run` 只包含 3 个文件、包体 3.7KB，`npm publish --dry-run --access public` 通过且没有 metadata 修正警告。
- 首次 `v1.10.0` workflow 在打包阶段失败：runner 默认 Homebrew Node 依赖 `@rpath/libnode.127.dylib`，触发可移植性保护；workflow 改为用 `actions/setup-node` 固定官方独立 Node `22.22.2`。
- 修复后的 workflow `29644944600` 在提交 `b4ba4e2` 上通过，并创建 `Seahorse 1.10.0` Release；本地签名 DMG 与 SHA256 已上传，公开下载返回 HTTP 200。
- `npm publish --access public` 成功；registry 的 `latest` 为 `@ssbun/seahorse@1.10.0`，公开 tarball 可安装且只包含 README、安装脚本和 manifest。

# 实现 JSON 损坏保护与 last-good 恢复

## 状态

- 已完成（2026-07-18）

## 目标

- 核心 JSON 任一文件损坏时，禁止用默认值或空数组静默覆盖用户数据。
- 从一份跨文件一致的 last-good 快照恢复；主数据与快照均不可用时拒绝写入。
- 保留损坏原文件，并提供可诊断的恢复状态。

## 边界

- 保留现有五个 JSON 文件、`JSONStorage` 和原子写入机制，不迁移数据库或增加依赖。
- 只保护 categories、tags、smart collections、items 与 preferences；图片和其他独立服务记录不纳入该快照。
- 先覆盖确定的数据丢失路径，不增加恢复管理 UI。

## 计划

- [x] 添加损坏主文件、损坏快照与写入保护的回归测试，并确认旧实现失败。
- [x] 在 `JSONStorage` 中实现一致快照、恢复和不可写状态。
- [x] 运行定向测试、完整测试、Release 构建和差异检查。

## 审查记录

- 旧实现下三个恢复测试均失败：损坏主文件不会恢复整组快照、损坏快照时仍可写入、有效主数据不会生成 last-good；证明测试覆盖了原始数据丢失路径。
- `JSONStorage` 现在只从实际持久化状态刷新 schema 1 `last-good.json`：已存在的主文件必须可解码，历史版本缺失的文件沿用兼容默认值；任一主文件损坏时保留 `.corrupt-<UUID>` 原件并恢复整组快照，中断恢复通过 `recovery-in-progress` 标记在下次启动重试。
- 主文件和 last-good 都不可用时进入 `.readOnly`，所有公开写入和 `forceSaveAllData()` 均拒绝覆盖现有文件；首次启动仍创建默认分类并建立首份快照。
- 4 个恢复测试、7 个既有 JSON 性能测试和完整 `xcodebuild test` 均通过；Release `xcodebuild build` 与 `git diff --check` 通过，只有既有构建警告。

# 删除分类时迁移全部条目到 None

## 状态

- 已完成（2026-07-18）

## 目标

- 删除自定义分类时，把 Bookmark、Image 与 Text（含回收站记录）统一迁移到 `None`。
- 只有批量迁移成功后才删除分类，避免任何悬空 `categoryId`。

## 边界

- 规则实现于 `DataStorage`，UI 只发起一次删除请求。
- 复用现有同步 `updateItems`，不增加事务框架或数据库迁移。
- 本任务不实现 JSON last-good 恢复。

## 计划

- [x] 添加三类条目与回收站记录的回归测试，并确认旧实现失败。
- [x] 在数据层批量迁移后删除分类，移除 UI 的 Bookmark 专用循环。
- [x] 运行定向测试、完整测试和构建验证。

## 审查记录

- 旧实现下回归测试失败：分类已删除，但 Bookmark、Image 和回收站 Text 仍引用旧分类。
- `DataStorage.deleteCategory` 现在先用一次 `updateItems` 把三类条目（含回收站）迁移到 `None`，迁移失败会直接中止删除；分类管理 UI 不再逐条处理 Bookmark。
- 定向测试通过：`DataStorageCategoryTests.testDeletingCategoryMovesEveryItemTypeToNone()`。
- 完整 `xcodebuild test`、Release `xcodebuild build` 与 `git diff --check` 均通过；构建仍有既有资源名和 Swift 并发警告，本任务未新增警告。

# 设计分类引用与 JSON 恢复修复

## 状态

- 已完成（2026-07-18）

## 目标

- 给出删除分类时不产生 Bookmark、Image 或 Text 悬空引用的最小数据层方案。
- 给出 JSON 解码或完整性校验失败时不会静默覆盖用户数据的恢复方案。

## 边界

- 本轮只确认根因和修复设计，不修改生产代码。
- 保留现有 JSON 主存储，不迁移 SQLite/SwiftData。
- 复用现有批量 item 更新、原子文件写入和手工备份能力。

## 计划

- [x] 核对分类删除的 UI、DataStorage 与 JSONStorage 调用顺序。
- [x] 核对 JSON 加载失败、写入失败和现有备份恢复行为。
- [x] 比较最小修复、每文件备份与一致快照方案并形成推荐设计。

## 审查记录

- 分类管理 UI 当前只重映射 Bookmark，逐条失败后仍继续删除分类；Image 与 Text 不处理。应由 `DataStorage.deleteCategory` 一次构造三类 item 更新，先同步持久化到 `None`，成功后再删除分类；中途失败最多留下空分类，不能留下悬空引用。
- `JSONStorage` 当前在 `categories.json` 解码失败时创建并写回默认分类，在 `items.json` 解码失败时继续使用空数组；后续写入可能覆盖原数据。加载失败必须进入 recovered 或 unavailable 状态，不能按首次启动处理。
- 推荐保留现有五个 JSON，并增加一个包含 schema version 与五类数据的 `last-good` 一致快照；主文件全部加载并通过引用完整性校验后才能更新快照。任一主文件失败时保留损坏原件、恢复整组快照并提示用户；主文件与快照都失败时切换只读恢复状态并禁止写入。
- 不推荐五个文件各自独立回退，因为不同 generation 可能产生 category/tag/item 组合不一致；也不需要为该问题迁移 SQLite。

# 审计列表滚动性能

## 状态

- 已完成（2026-07-18）

## 目标

- 找出 macOS 主列表滚动期间可复现的主线程、图片加载和视图重算热点。
- 按影响与修复成本排序，给出可验证的最小优化建议。

## 边界

- 本轮只审计，不修改生产代码。
- 优先检查主列表数据流和可见列表行，不扩展到无关管理页面。
- 保留工作区全部现有未提交改动。

## 计划

- [x] 跟踪主列表从筛选结果到列表行渲染的完整调用链。
- [x] 检查滚动热路径中的同步 I/O、解码、重复计算和不稳定视图身份。
- [x] 核对现有测试与可测量手段，形成按优先级排序的审计结论。

## 审查记录

- macOS 列表已使用固定 64 点行高、稳定 UUID 和 `LazyVStack`；图片通过 Kingfisher 下采样，当前没有证据支持改写为自定义 cell 回收或分页。
- 最高优先级热点是每个 `StandardListItemView` 都订阅整个 `DataStorage`，而 `ItemCollectionView` 还保留未使用的同类订阅；单条数据更新会发布 `bookmarks`、`items` 和 `itemsVersion`，自动解析状态又会额外触发根视图更新，滚动期间可能重复计算全部可见行。
- `ContentView` 同时观察自动解析、批处理、诊断、导入导出和图片生成进度；这些与列表内容无关的高频发布也会使包含列表的根 body 失效，应先隔离工具栏/任务状态，再考虑更大结构调整。
- iOS `iOSItemListRow` 每次 body 都创建 `RelativeDateTimeFormatter`；应改用原生相对日期 `Text` 或共享格式器。macOS 已使用 `Text(date, style:)`，没有该问题。
- 本机真实数据为 292 条，其中 239 个远程书签图标；Kingfisher 磁盘缓存已有 591 个文件。现有搜索基准通过：300 条记录构建 0.649 ms、查询 p95 0.822 ms，3,000 条 p95 9.853 ms，10,000 条 p95 27.676 ms，因此不应先重写搜索。
- 本机 UI 控制通道启动失败，未取得交互式 Instruments 样本；动态收益仍需在 Release 构建中用 SwiftUI/Time Profiler 对比验证，当前运行进程是 Debug 构建。
- 用户确认只处理 Critical 性能问题；本次没有发现该级别问题，所有静态优化建议保持未实现。

# 从富化问题列表移除无效书签

## 状态

- 已完成（2026-07-18）

## 目标

- 为每条富化问题提供移入回收站按钮。
- 删除前明确提示富化失败不等于链接失效，并要求用户确认。
- 移入回收站后立即从问题列表和工具栏问题计数中消失。

## 边界

- 只移入可恢复的回收站，不执行永久删除或自动判定无效链接。
- 复用 `DataStorage.deleteBookmark`，保留现有 Open 与 Retry 行为。
- 保留工作区其他未提交改动。

## 计划

- [x] 用回归测试锁定回收站书签不计入富化失败数量。
- [x] 添加带确认和错误反馈的移入回收站按钮。
- [x] 运行定向测试、macOS 构建与差异检查。

## 审查记录

- 富化问题行新增红色垃圾桶按钮；确认框明确说明富化失败不等于链接失效，确认后调用现有 `DataStorage.deleteBookmark` 移入可恢复的回收站，写盘失败则在当前窗口提示错误。
- `failedBookmarkIDs` 只返回仍处于活动集合的失败书签，因此移入回收站后列表和工具栏计数立即更新，同时保留原失败状态供恢复后继续显示。
- 新增回归测试先复现计数残留，再验证修复；完整 `AutoParsingServiceTests` 5 项、macOS Debug 构建与 `git diff --check` 均通过。

# 为富化问题列表添加人工检查入口

## 状态

- 已完成（2026-07-18）

## 目标

- 允许用户从每条富化问题直接打开 Seahorse 详情页。
- 允许用户用默认浏览器人工检查原始链接。

## 边界

- 复用现有单例详情窗口与系统默认浏览器，不新增窗口或链接检查逻辑。
- 保留 Retry 行为和“富化失败不等于链接失效”的现有语义。
- 保留工作区其他未提交改动。

## 计划

- [x] 在问题行添加原生 Open 菜单并接入两条现有打开路径。
- [x] 运行 macOS 构建与差异检查。

## 审查记录

- 每条富化问题新增一个原生 `Open` 菜单：`Open Details` 复用单例详情窗口，`Open in Browser` 交给 macOS 默认浏览器。
- Retry 与现有富化状态语义保持不变；没有把 HTTP/TLS 富化错误误判为链接失效。
- macOS Debug 构建与 `git diff --check` 通过，仅保留项目已有编译警告。

# 统一书签详情编辑与 AI 解析进度

## 状态

- 已完成（2026-07-17）

## 目标

- 现有书签只在详情页编辑，移除与新增页重复的编辑流程。
- 主动 AI 解析在详情页展示真实执行步骤、阶段状态和解析建议。
- 解析结果继续通过逐字段差异确认后保存，不静默覆盖用户数据。

## 边界

- `AddBookmarkView` 只负责新增书签，保留新增时的预览与解析能力。
- 不实现伪流式字段输出、百分比进度或新的持久化状态。
- 复用现有 `BookmarkParsingPolicy`、diff 组件与数据模型，保留工作区其他未提交改动。

## 计划

- [x] 用测试定义共享解析会话的步骤、部分失败、AI 失败与取消行为。
- [x] 实现新增页和详情页共用的最小解析会话。
- [x] 将卡片主动解析和编辑入口统一路由到详情页。
- [x] 在详情页展示 URL、解析步骤、建议摘要和逐字段 diff。
- [x] 运行定向测试、完整测试、Release 构建与差异检查。

## 审查记录

- `AddBookmarkView` 已收敛为纯新增页；标准卡片、矩形卡片和列表的 Edit / AI Parse 都打开唯一的 `ItemDetailView`，AI Parse 通过一次性请求在目标详情页自动启动。
- 新增与详情共用 `BookmarkParsingSession`，按网页抓取、元数据读取、AI 分析和建议准备展示真实状态；AI resolution 在慢元数据完成前即可发布，元数据单独失败不阻断建议。
- 详情页现在可直接编辑 URL、标题、收藏、分类、标签与备注；主动解析先展示建议摘要，再通过现有逐字段 diff 确认，取消、AI 失败或切换条目不会写入建议。
- 6 个解析会话定向测试、完整 macOS 测试套件、macOS Release 构建、iOS Simulator Debug 构建及 `git diff --check` 均通过；仅保留项目已有编译警告。

# 实现标准化 AI 书签解析

## 状态

- 已完成（2026-07-17）

## 目标

- 用一次结构化 AI 请求替代五次串行自由文本请求。
- 用同一套本地规则统一分类、标签、自动合并和主动重解析行为。
- 为主动重解析提供逐字段 diff 与确认，保护人工元数据。

## 边界

- 按已确认设计实现，不增加多阶段 Agent、向量检索、审核队列或存储迁移。
- 保留现有网页抓取、OGP、富化状态与数据存储结构。
- 只改本任务需要的文件，保留工作区中的其他改动。

## 计划

- [x] 用失败测试建立结构化解码、本地策略和安全合并行为。
- [x] 改为单次 AI 请求并迁移自动、批量和手动入口。
- [x] 实现主动重解析 diff，收敛设置并删除旧分支。
- [x] 运行完整测试、Release 构建和差异审查。

## 审查记录

- 书签解析已收敛为一次启用 JSON Object 格式的 AI 请求；固定 system prompt 与 `BookmarkParsingPolicy` 共同保证分类白名单、标签清理/去重、总数最多 4 个、新标签最多 2 个、站点与泛化标签过滤及有效 SF Symbol。
- 自动、批量和手动新增共用同一 resolution；自动与批量只填补缺失值，且只在本轮 OGP 临时值仍未被用户改动时允许 AI 替换。剪贴板与新增入口的 GitHub 分类特判已删除，自动/批量不会创建分类。
- `AI Parse…` 会直接启动主动重解析，展示标题、摘要、分类和标签 diff；用户逐项确认后立即保存。设置页移除四个自由 prompt 和自动建分类开关，只保留附加解析偏好、语言及新标签控制。
- TDD 覆盖结构化解码、分类/标签规则、安全合并、OGP 临时值保护和 diff 默认选择；完整 macOS 测试套件、macOS Release 构建、iOS Simulator 构建与 `git diff --check` 均通过。构建仅保留项目已有警告。

# 修复封面图片路径回退

## 状态

- 已完成（2026-07-17）

## 目标

- 让自定义存储目录的封面记录始终从实际 Images 目录加载缩略图。
- 恢复已完成任务行的点击、图片详情、导出与 Apply。
- 用回归测试证明存储根目录不会因后续 bookmark 解析失败而漂移。

## 边界

- 根修复只放在共享 `StorageManager`，不修改生成记录或复制用户图片。
- 不调整封面列表和图片浏览器的现有启用条件。
- 保留工作区中其他未提交改动，不提交本任务改动。

## 计划

- [x] 添加存储根目录稳定性的回归测试并确认旧实现失败。
- [x] 缓存初始化时取得的存储根目录，避免每次访问重新解析 bookmark。
- [x] 运行定向测试、完整测试、Release 构建和差异检查。

## 审查记录

- 回归测试先在旧实现上因缺少可注入的目录解析入口而失败；修复后证明同一 `StorageManager` 只解析一次根目录，后续 Images 路径与图片解析始终复用该根。
- `StorageManager` 初始化时缓存存储根并持续持有 security-scoped URL；没有修改生成记录、用户图片、任务列表或图片浏览器逻辑。
- 定向回归测试、完整 Swift 测试套件、Release 构建和 `git diff --check` 均通过；现有无关编译警告未改变。
- 已有记录与图片无需迁移；用户重新启动包含修复的新构建后生效。

# 定位封面记录无法显示图片

## 状态

- 已完成（2026-07-17）

## 目标

- 确认已完成封面记录没有缩略图且无法打开详情的直接原因。
- 用日志、持久化记录与磁盘文件状态验证根因。
- 给出最小修复位置与影响范围。

## 边界

- 本任务先诊断，不修改生产代码。
- 不删除或重建用户的生成记录与图片。
- 保留 `tasks/todo.md` 中其他正在进行的本地改动。

## 计划

- [x] 检查视图的缩略图和点击启用条件。
- [x] 核对本地生成记录中的文件名与实际图片路径。
- [x] 对照日志和近期提交确认根因并记录结论。

## 审查记录

- 两条完成记录都包含 `imageFilename`，对应 PNG 实际存在于 iCloud Drive 的 `Seahorse/Images`，并能被 `sips` 正确读取为 1693×929 和 1672×941；记录与图片本身没有损坏。
- 打开窗口期间日志持续出现 security-scoped bookmark 解析失败：`NSCocoaErrorDomain Code=256 Failed to retrieve app-scope key`。`StorageManager.getStorageRoot()` 每次读取图片都重新解析 bookmark，失败后静默退回 Application Support，因此相对文件名被拼到错误目录。
- `ImageGenerationTask.generatedImage` 因错误路径返回 `nil`；任务行随即显示绿色完成图标，并由 `.disabled(task.generatedImage == nil)` 禁用点击。这同时解释了缺少缩略图和无法进入图片详情。
- 根修复应位于 `StorageManager`：复用初始化时已取得并保持 security-scoped access 的存储根目录，避免每次路径解析重新创建 bookmark URL；不需要修改任务记录或图片浏览器。

# 标准化 AI 书签解析流程

## 状态

- 已完成（2026-07-17）

## 目标

- 梳理现有 AI 解析输入、调用、输出解析与分类/标签写回路径。
- 明确分类与标签生成的产品规则、低置信度行为和人工数据保护边界。
- 比较可行方案并形成一份可测试、可分阶段落地的优化设计。

## 边界

- 本任务只进行需求澄清与方案设计，不修改生产代码。
- 优先复用现有模型和服务，不引入多阶段 Agent、向量检索或新存储层，除非现有证据证明必要。
- 不干扰工作区中正在进行的提交整理任务及其他本地改动。
- 已确认：分类是稳定的单选目录；AI 只选择已有分类，无合适项时保持未分类，新分类仅在用户确认后创建。
- 已确认：正常情况下生成 2–4 个标签，优先复用已有标签；每次最多自动创建 2 个具体、可复用的新标签，并过滤分类重复、纯站点名和宽泛词。
- 已确认：内容不足或置信度低时允许放弃分类和标签判断，不强制补齐、不自动重试，标题与摘要仍可独立成功。
- 已确认：自动与批量解析只填补完全缺失的分类或标签；用户主动重解析先展示建议并确认，不静默覆盖人工数据。
- 已确认：核心解析协议及分类/标签规则固定；设置只保留语言、语气、关注点等附加偏好，且不能覆盖核心约束。
- 已确认：新标签使用 AI 语言设置；已有标签保留原名称与大小写；本地清理空白并按大小写不敏感方式去重。
- 已确认：新分类建议只在手动新增或用户主动重解析时展示并等待确认；自动与批量解析保持未分类，不增加审核队列。
- 已确认：自动与批量解析只替换占位标题并填补空摘要；用户主动重解析展示标题、摘要、分类和标签 diff，由用户逐项确认覆盖。

## 计划

- [x] 核对当前 prompt、输出模型与三条写回路径。
- [x] 逐项确认分类、标签、低置信度与重解析语义。
- [x] 比较 2–3 个实现方向并推荐最小可靠方案。
- [x] 分段确认完整设计并补全审查记录。

## 审查记录

- 用户逐项确认了分类、新分类建议、标签上限、低置信度、人工数据保护、附加偏好、语言与主动 diff 规则；最终采用一次结构化请求加本地确定性策略，不引入多阶段 Agent、向量检索、审核队列或存储迁移。
- 设计文档已写入 /Users/caishilin/Desktop/personal/Seahorse/docs/plans/2026-07-17-ai-bookmark-parsing-standardization.md，并作为后续实现与验收依据。

# 按功能拆分并提交本地改动

## 状态

- 进行中（2026-07-17）

## 目标

- 审计所有 Git 可见的本地改动，并拆分为可独立回滚的功能提交。
- 每个提交包含对应的代码、测试、资源与必要文档，不纳入忽略的构建产物或本地配置。
- 最终保持工作区干净，并保留清晰、可验证的提交历史。

## 边界

- 只提交 `git status` 可见的改动，不提交 `.DS_Store`、构建产物或本地工具配置。
- 不改写、合并或修订已有提交，不推送远端。
- 共享文件按实际功能归属拆分暂存；无法合理拆分时归入最早需要它的基础功能。

## 计划

- [x] 映射文件与差异块到具体功能并确定提交顺序。
- [x] 逐组暂存、检查并提交功能改动。
- [x] 完成最终状态、提交历史与差异检查，并补全审查记录。

## 审查记录

- Agent、Provider、Codex OAuth/模型/图片服务、helper 与打包运行时归入 `c2877e0`；封面窗口、样式资源、持久化、详情、导出和参考图归入 `71c4e3f`；自动提取的本地化目录变化独立归入 `3c5122b`。
- `SeahorseApp.swift` 按差异块拆分：helper 始终启动属于 Agent 基础设施，独立图片窗口属于封面工作流；其余共享配置按最早需要它的 Provider 基础能力归档。
- 验证通过：helper 25 项测试、TypeScript build、完整 Swift 测试套件、macOS Release build、字符串目录 JSON 校验以及每组 `git diff --cached --check`；未调用真实图片 API。
- 只提交了 `git status` 可见内容，忽略的 DMG、构建目录、`.DS_Store` 和本地工具配置未进入提交。

# 修复书签富化与链接健康误判

## 状态

- 已完成（2026-07-17）

## 目标

- 统一分类和标签名称解析，避免确定性富化失败与悬空 Tag UUID。
- 用独立列表展示富化问题，并提供单条重试和用户主动的可恢复问题批量重试。
- 将链接健康检查改成可访问、无法确认、已失效三态，保护批量删除边界。

## 边界

- 复用现有 `DataStorage`、富化状态与诊断 UI，不增加工作流引擎、数据库迁移或后台自动重试。
- 分成两个独立提交；不提交工作区中与本任务无关的已有改动。
- 不自动重跑旧失败记录，不修改用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 添加名称一致性回归测试并修复自动/批量富化路径。
- [x] 用独立问题列表替代工具栏超长菜单并验证第一提交。
- [x] 添加 HTTP 分类回归测试并实现三态诊断与删除边界。
- [x] 运行定向测试、完整测试、Release 构建和差异审查。

## 审查记录

- `DataStorage.category(named:)` 与 `tag(named:)` 复用持久层的大小写不敏感语义；自动解析和批量解析都使用真实已保存 ID，批量路径不再吞掉标签创建失败。
- 工具栏的富化警告改为独立问题列表，展示错误原因、单条重试与带费用提示的用户主动批量恢复；没有自动重跑旧失败记录。
- 链接检查在 `HEAD` 返回 405/501 时用带 Range 的 `GET` 复查；410 和无效 URL 才进入 Broken，401/403/404/429、5xx 与传输错误进入不可删除的 Unverified 分组。
- 两个独立提交为 `90c8663` 和 `e0c378e`；只暂存了 `ContentView.swift` 中本任务 hunks，未提交工作区中已有的封面、Agent、MCP 和本地化改动。
- 验证通过：名称解析定向测试、HTTP 分类定向测试、完整 Swift 54 项测试、macOS Release 构建、提交范围 `git diff --check`。

# 为封面生成增加参考图片

## 状态

- 已完成（2026-07-17）

## 目标

- 在书签详情点击 Generate Cover 时，可选择无参考图、裁剪当前网页快照或粘贴剪贴板图片。
- 参考图进入实际 Codex/OpenAI-compatible 图片请求，并在生成窗口中可见。
- 生成任务将参考图片保存到 Seahorse 本地存储，重启后仍可查看对应记录。

## 边界

- 复用现有网页选区、剪贴板、ImageFileService 和生成任务持久化，不引入图片编辑依赖。
- 不改变书签现有“捕获快照作为预览图”的行为。
- 避开并保留工作区中已有的未提交改动。

## 计划

- [x] 扩展详情页入口与网页选区，收集可选参考图。
- [x] 将参考图接入生成任务、Codex/compatible 请求和本地记录。
- [x] 增加回归测试并运行 helper、Swift 测试、Release 构建和差异检查。

## 审查记录

- Generate Cover 改为原生选项菜单：可直接无参考图生成、进入当前网页视口的既有选区裁剪，或读取剪贴板中的图片；裁剪用途与原有“保存为书签预览”明确分离，生成窗口会预览并允许移除参考图。
- 每个生成任务把参考图独立写入 `Images/cover-reference-*.png`，文件名随 `image-generations.json` 持久化，清理任务时与生成图一并安全删除；旧记录缺少新字段仍可解码。
- Codex 请求把 PNG 作为 Responses `input_image`，OpenAI-compatible 请求复用已安装 OpenAI Swift SDK 的 Images Edits；验证通过 helper 25 项测试、TypeScript build、Swift 51 项测试、macOS Release build 和 `git diff --check`，未发起真实图片生成请求。

# 让主页封面窗口只显示生成进度

## 状态

- 已完成（2026-07-16）

## 目标

- 从主页工具入口打开封面窗口时，只展示生成记录与当前进度，不展示生成选项或上次书签。
- 从书签详情的 Generate Cover 入口打开时，仍展示该书签的样式选择和生成操作。
- 不影响正在运行任务、持久化历史、详情查看与 Apply。

## 边界

- 复用现有 `preparedBookmarkID` 区分创建与监控场景，不增加新的页面模式状态。
- 只修改两个入口、条件渲染和必要测试，不调整生成任务生命周期。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 让每个窗口入口显式设置或清除临时书签目标。
- [x] 没有临时目标时隐藏创建区域，只保留 Generations。
- [x] 运行定向测试、完整 Swift 测试、Release 构建与差异检查。

## 审查记录

- 根因是详情入口写入的 `preparedBookmarkID` 存在共享单例中，主页入口重开窗口时既没有清理它，窗口也无条件渲染创建区域，因此复用了上次书签。
- 主页工具入口现在先调用 `clearPreparedBookmark()` 再打开窗口；详情入口继续调用 `prepare(for:)`。窗口仅在临时目标能解析为 bookmark 时构建样式选择与 Generate Cover，否则只展示 Generations。
- 验证通过：Agent Provider/封面定向测试、完整 Swift 50 项测试、macOS Release build 和 `git diff --check`；正在运行的任务与持久化历史没有改动，用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 确定链接与富化失败的修复方案

## 状态

- 已完成（2026-07-17）

## 目标

- 用现有代码与实际数据区分链接健康检查、网页元数据抓取和 AI 富化失败。
- 依据 Apple 与 IETF 一手文档确定 HTTP 状态和重试语义。
- 通过逐项压力测试形成最小、可验证的修复方案。

## 边界

- 本任务只调查和设计，不修改产品代码。
- 研究只引用官方文档、标准与仓库源码，并在仓库中保存一份中文 Markdown 报告。

## 计划

- [x] 核对当前实现、失败数据与官方协议语义。
- [x] 否决会掩盖部分成功或制造重试风暴的方案。
- [x] 与用户逐项确认产品语义并完成方案审查。

## 审查记录

- 研究报告保存于 `docs/analysis/enrichment-and-link-health-resolution.md`，依据仓库源码、实际失败数据、Apple URLSession 文档、IETF RFC 9110 与 RFC 6585。
- 已确认富化不影响书签可用性，旧失败只由用户主动恢复，临时网络错误只手动重试；链接健康采用可访问、无法确认、已失效三态，404 不进入批量删除，410 才自动判定失效。
- 交付拆成两个独立提交：先修富化名称一致性、悬空 UUID 和问题列表，再修 HTTP 三态检查。本任务仅调查和设计，未修改产品代码。
- `git diff --check` 通过。

# 用真实生成图片替换封面样式模板

## 状态

- 已完成（2026-07-16）

## 目标

- 封面生成页展示 8 张真实 AI 生成的样式示例，不再使用 SF Symbol、渐变或原生图形拼接模板。
- 每张示例作为 Asset Catalog 资源嵌入 App，并与一个实际封面生成 prompt 一一对应。
- 向用户列出最终 8 条封面样式 prompt。

## 边界

- 使用内置图片生成工具逐张生成；不使用 CLI、外部图片或新增依赖。
- 示例统一为无文字、无 Logo、无水印的横向封面，避免把模板文字带入用户生成结果。
- 只修改样式模型、样式卡展示、Asset Catalog 与对应测试，避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 定义 8 个样式、prompt 与资源名，并生成 8 张真实示例图。
- [x] 将图片写入 Asset Catalog，删除代码绘制模板并接入样式卡。
- [x] 验证图片资源、Swift 测试、Release 构建与差异。

## 审查记录

- 使用内置图片生成工具产出 Editorial、Minimal、Gradient、Illustration、Cinematic、Surreal、Soft 3D、Geometric 八张不同的 1536×1024 PNG；生成原件保留在 Codex 目录，项目副本分别写入八个 Asset Catalog imageset。
- 样式卡统一通过 `Image(style.exampleAssetName)` 展示实际位图，已删除整段 SwiftUI 渐变、图形和 SF Symbol 样式预览；每个资源名与实际传入图片生成链路的 `CoverStyle.prompt` 一一对应。
- 验证通过：八张图片尺寸一致且哈希各不相同，测试会实际加载全部八个 image asset；完整 Swift 50 项测试、资源定向测试、macOS Release build 和 `git diff --check` 均通过，用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 持久化封面生成记录并提供图片详情

## 状态

- 已完成（2026-07-16）

## 目标

- 点击已生成的封面记录可进入详情页，通过现有图片浏览器缩放、平移查看图片。
- 详情页展示生成与文件元数据，并可通过系统保存面板导出图片。
- 生成图片和全部任务记录保存到 Seahorse 本地存储，重启后可恢复。

## 边界

- 复用现有 `ImageViewer`、`Images/` 与 `Data/` 目录，不新增窗口、数据库或依赖。
- 明确清除记录时同步清除该记录的生成文件；Apply 继续保存独立 bookmark 预览副本，避免清除历史破坏封面。
- 不发起会消耗用户额度的真实图片生成验证，并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 将生成图片与可恢复任务元数据持久化，并添加 Codable 回归测试。
- [x] 为已完成记录增加可点击详情页、图片浏览、元数据和导出。
- [x] 运行 Swift 测试、Release 构建和差异审查。

## 审查记录

- 图片生成成功后先写入 `Images/generated-cover-*.png`，再把任务、状态、样式、文件名、尺寸、格式和字节数原子写入 `Data/image-generations.json`；重启恢复全部记录，未完成任务会明确标记为中断。
- 已完成记录的缩略图/标题可点击进入同窗口详情页；详情复用 `ImageViewer` 的缩放、平移和双击复位，右侧展示元数据，并通过 `NSSavePanel` 导出 PNG。
- Apply 继续创建独立 `preview-*.png`，因此用户明确清除历史时可以安全删除对应生成文件，不会破坏 bookmark 当前封面。
- 验证通过：完整 Swift 49 项测试、持久化定向回归、macOS Release build 和 `git diff --check`；未发起真实图片生成请求，用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 为封面生成提供样式与示例

## 状态

- 已完成（2026-07-16）

## 目标

- 封面生成窗口提供多种可选择的视觉样式及对应示例图。
- 用户先选择样式再发起生成，所选样式必须进入实际图片 prompt。

## 边界

- 示例图使用原生 SwiftUI 绘制，不新增静态位图资源或图片下载依赖。
- 继续复用现有任务队列、Provider 路由和 Apply 流程，不增加图片编辑器或持久化历史。
- 不发起会消耗用户额度的真实图片生成验证，并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 定义有限的封面样式及 prompt 映射，并添加回归测试。
- [x] 将生成窗口改为先选样式、查看示例、再生成的流程。
- [x] 运行 Swift 测试、Release 构建和差异审查。

## 审查记录

- 封面生成窗口提供 Editorial、Minimal、Gradient、Illustration、Cinematic 五种样式；示例由 SwiftUI 原生绘制，并补充选中态与辅助功能语义，没有新增图片资源或依赖。
- bookmark 详情页现在只准备目标并打开生成窗口；用户选择样式并点击生成后才排队，任务会记录样式，且同一 `CoverStyle.prompt` 会进入 Codex 或 OpenAI-compatible 图片请求。
- 验证通过：完整 Swift 48 项测试、macOS Release build 和 `git diff --check`；为避免消耗用户额度，未发起真实图片生成请求，用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 修复图片生成无反馈并提供独立窗口

## 状态

- 已完成（2026-07-16）

## 目标

- 图片生成请求不再被 Swift 默认 60 秒超时提前取消。
- 从详情页或主窗口触发生成时，打开独立图片生成窗口并持续展示进行中、失败和结果状态。

## 边界

- 复用现有图片生成任务列表与封面应用逻辑，不新增图片编辑器或历史存储系统。
- 不发起会消耗用户额度的真实图片生成验证。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 对齐 Codex 图片请求与 helper 的长任务超时并添加回归断言。
- [x] 将现有图片任务面板迁移为独立窗口，连接详情页和主窗口入口。
- [x] 运行 Node/Swift 测试、Release 构建和差异审查。

## 审查记录

- 日志确认两次点击均已请求本机 helper，但 Swift 分别在 60.54 秒和 60.15 秒触发 `NSURLErrorDomain -1001`；原先的状态 popover 只挂在主窗口 Tools 按钮上，详情窗口触发后没有就地可见反馈。
- Codex 图片请求 timeout 调整为 330 秒，略长于 helper 的 300 秒上游截止时间；回归测试直接断言请求值，其他 Codex 请求继续使用默认 timeout。
- 原有任务面板改为唯一的 `Image Generation` 窗口；详情页生成按钮会在排队后立即打开窗口，主窗口 Tools 入口也打开同一窗口，生成中、失败、结果和 Apply 操作都留在该窗口。
- 验证通过：完整 Swift 47 项测试、AgentService 6 项定向测试、macOS Release build 和 `git diff --check`；为避免消耗用户额度，未发起真实图片生成请求，用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 扩展 Codex 模型与图片 Provider 选择

## 状态

- 已完成（2026-07-16）

## 目标

- Codex 设置可从 Pi 当前目录搜索并选择全部可用 Codex 模型。
- 图片生成可从已配置且支持图片的 Provider 中选择。
- Codex 被选为图片 Provider 时，通过 ChatGPT OAuth 和 Responses `image_generation` tool 生成封面。

## 边界

- 不开放 Pi 目录中的其他鉴权 Provider；继续支持 Codex、OpenAI-compatible 和 Claude-compatible。
- Claude-compatible 不声明 OpenAI Image API 能力，因此不进入图片 Provider 列表。
- 不维护会过期的 Codex 模型硬编码副本；模型目录由已安装 Pi 提供。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 暴露 Codex 模型目录和 OAuth 图片生成内部 endpoint，并添加边界测试。
- [x] 在 Swift 设置与服务中保存图片 Provider、加载 Codex 模型并路由图片请求。
- [x] 为 Codex 增加可搜索模型选择，为图片区域增加 Provider 选择。
- [x] 运行 Node/Swift 测试、Release 构建和差异审查。

## 审查记录

- Codex 设置从已安装 Pi 的 `openai-codex` 目录读取模型，并分别提供可搜索的 Agent 模型与图片模型选择；图片列表只展示声明支持图片输入的模型。
- 图片生成区可选择 Codex 或任意 OpenAI-compatible profile；Codex 通过 helper 内部持有的 ChatGPT OAuth 调用 Responses `image_generation`，Compatible 请求复用 profile 的 Keychain token 与 Base URL，Claude-compatible 不进入图片 Provider 列表。
- OAuth 凭据始终留在 helper 内部，Swift 只接收模型目录和生成结果；为避免消耗用户额度，本轮未发起真实图片生成请求。
- 验证通过：helper 25 项测试、TypeScript build、Swift 47 项测试、macOS Release build 和 `git diff --check`；用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 移除旧 AI API 重复设置

## 状态

- 已完成（2026-07-16）

## 目标

- AI 设置页不再重复展示旧的 Base URL、Token、Model 和测试连接入口。
- 保留 Provider 列表以及现有图片生成、自动解析和 prompt 设置。

## 边界

- 本轮只清理重复 UI；旧字段暂留内部，避免改变图片生成和自动解析行为。
- 不改动用户已有的 `Seahorse/Localizable.xcstrings` 内容。

## 计划

- [x] 删除重复设置区块及其无用 View 状态和 action。
- [x] 更新 Provider 说明文案与项目 lesson/context。
- [x] 运行 Swift 测试、构建和差异检查。

## 审查记录

- AI 设置页已移除旧 Base URL、Token、Model 和 Test Connection 区块，同时删除对应的测试状态、alert 和 action；Provider 列表成为 Agent 配置的唯一可见入口。
- 旧单组字段仅保留为图片生成和自动解析链路的内部兼容数据，本轮没有扩大这两条链路的重构范围。
- 验证通过：Swift 44 项测试、macOS Release build 和 `git diff --check`；用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 支持多 Agent Provider 配置

## 状态

- 已完成（2026-07-16）

## 目标

- AI 设置允许保存多个命名 Provider 配置并选择当前 Agent Provider。
- 支持 Codex OAuth、OpenAI-compatible 和 Claude-compatible（Anthropic Messages）。
- 保留现有图像生成、自动解析和 prompt 设置行为。

## 边界

- 不引入通用 Provider 插件系统或远程模型发现。
- Compatible Provider 只供内置 Agent 使用；其他 AI 功能继续使用现有单组 API 设置。
- 新 Provider Token 存入 macOS Keychain，不写入 Provider JSON 或日志。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 实现 Provider 配置、迁移、选中状态和 Keychain 凭据存储。
- [x] 重构 AI 设置页的 Provider 列表、新增、编辑、删除和 Codex 连接。
- [x] 让 Swift/Node Agent 路由支持三种 Provider 配置。
- [x] 添加迁移、请求编码、Claude runtime 和 HTTP 边界回归测试。
- [x] 运行 Node/Swift 测试、Release 构建和差异审查。

## 审查记录

- AI 设置页现在可新增任意数量的 OpenAI-compatible 与 Claude-compatible profile，编辑名称、Base URL、Token、模型，删除非 Codex profile，并选择一个 profile 驱动内置 Agent；Codex 保持一键连接/断开且未连接时不可选中。
- 旧 `ai_api_base_url`、`ai_api_token`、`ai_model` 首次迁移为默认 OpenAI-compatible profile；旧单组设置本身仍保留给图像生成和自动解析，Compatible Agent token 的新副本只存入 Keychain。
- Swift 请求按选中 profile 编码 `openai-codex`、`openai-compatible` 或 `claude-compatible`；helper 分别路由到 Pi Codex Responses、OpenAI Chat Completions 和 Anthropic Messages。
- 验证通过：helper 22 项测试、TypeScript build、Swift 44 项测试、macOS Release build 和 `git diff --check`；Claude 集成测试确认实际请求 `/v1/messages`、使用 `x-api-key` 并解析 SSE 响应。
- Release 构建仍输出项目已有的 asset symbol、actor 隔离、废弃 API 和未使用值 warnings，本任务没有扩大处理范围；用户已有的 `Seahorse/Localizable.xcstrings` 改动未被覆盖。

# 为内置 Agent 添加 Codex 一键登录

## 状态

- 已完成（2026-07-15）

## 目标

- 使用 Pi 内置 `openai-codex` OAuth 让用户一键连接 ChatGPT Plus/Pro 账号。
- 连接后让 Seahorse 内置 Agent 使用 Codex 模型，现有 OpenAI-compatible 设置继续服务于其他 AI 功能。
- 提供明确的已连接状态和断开入口，不暴露 OAuth 凭据。

## 边界

- 不把 ChatGPT/Codex 订阅凭据交给 Swift 界面，不写入 UserDefaults 或日志。
- 不新增第三方依赖，不引入远程中转服务。
- 本轮只将 Codex 接入内置 Agent，不改写图像生成和自动 AI 解析链路。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 核对 Pi `openai-codex` OAuth、模型和刷新能力。
- [x] 为 helper 添加本机安全持久化、登录状态与 Agent 提供者路由。
- [x] 在 AI 设置页添加一键连接、状态和断开交互。
- [x] 为 OAuth HTTP 边界、Codex Agent 配置和 Swift 请求添加回归测试。
- [x] 运行 Node/Swift 测试、构建和差异审查。

## 审查记录

- 已确认 Pi `0.80.7` 内置 `openai-codex` provider，支持 ChatGPT Plus/Pro OAuth、Codex Responses 模型和刷新 token；本实现没有使用 Codex Desktop MCP 反向注册。
- AI 设置页的 `Connect Codex` 会调用内部鉴权 endpoint、打开 Pi 生成的 OpenAI PKCE 登录页并轮询状态；成功后 Agent 切换到 `gpt-5.4-mini`，断开后回退 OpenAI-compatible 配置。
- helper 独占 OAuth 凭据和自动刷新；凭据以 atomic rename 写入 Application Support 的独立 `auth.json`，强制 `0600`，失败响应不透传上游敏感详情。
- 验证通过：helper 19 项测试、TypeScript build、完整 Swift 测试套件、macOS Release build 和 `git diff --check`。
- 真实 Pi OAuth 启动验证生成 `auth.openai.com/oauth/authorize` URL，包含 state、PKCE challenge 和 `localhost:1455/auth/callback`；测试没有登录账号或写入真实凭据。
- Xcode 仍输出项目已有的 asset symbol、actor 隔离和 AppIntents metadata warnings，本任务没有扩大处理范围。

# 定位修正 Base URL 后的 Agent 失败

## 状态

- 已完成（2026-07-15）

## 目标

- 从 `/Users/caishilin/.venom/logs/Seahorse.log` 定位最新 Agent 请求的实际失败点。
- 用当前配置建立可重复的最小复现，区分 LLM 流、Pi 工具循环、helper bridge 与 Swift 数据层错误。
- 本轮只诊断并给出根因；未获得修复授权前不修改产品实现。

## 边界

- 不输出 API token、内部 bearer token、完整模型回复或用户收藏内容。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。
- 只读取日志和运行非破坏性诊断命令。

## 计划

- [x] 提取最新 Agent/helper/bridge 错误链和时间线。
- [x] 建立并运行能够捕获当前症状的最小复现。
- [x] 验证排序后的候选根因。
- [x] 完成诊断审查并记录证据。

## 审查记录

- 日志中最新 UI Agent 请求在 18:24:55 连接本机 helper `127.0.0.1:17373`，0.9 秒后收到 HTTP 500；请求和响应长度与当前 `/agent` 失败链一致。
- 当前持久化 `ai_api_base_url` 仍是 `https://api.bltcy.ai`，没有上次诊断要求的 `/v1`；App 于 18:24:45 启动的新进程和 helper 于 18:24:46 启动的新进程均不是旧进程残留。
- 直接调用当前正在运行的 `/agent`，使用当前持久化配置和 `hello` 可在 0.85 秒内稳定复现 HTTP 500、`Stream ended without finish_reason`。
- 同一个 helper 仅在诊断请求中临时把 Base URL 改为 `https://api.bltcy.ai/v1` 后，`hello` 返回 HTTP 200 和非空答案；带收藏搜索意图的请求也经完整 Agent/bridge 链返回 HTTP 200。
- 在先前失败过的同一个 Pi session 上改用 `/v1` 后同样返回 HTTP 200，因此排除会话缓存、helper 旧版本和新增 bridge 故障；根因仍是设置值未包含 `/v1`。
- 本轮只更新任务诊断记录，没有修改产品实现或用户设置。

# 定位 Agent 流式响应缺少 finish_reason

## 状态

- 已完成（2026-07-15）

## 目标

- 用 Seahorse 当前配置复现 `Stream ended without finish_reason`。
- 确认故障发生在 App、Pi 适配器还是上游 OpenAI-compatible 流式接口。
- 给出证据充分的根因和最小修复选项，本轮不修改产品实现。

## 边界

- 诊断输出不得包含 API token、完整请求内容或模型回复正文。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。
- 不在未确认根因前调整 provider 兼容参数或回退非流式调用。

## 计划

- [x] 定位 Pi 抛错条件并核对当前 helper 运行版本。
- [x] 复现当前 Agent 调用链，记录稳定失败信号。
- [x] 检查上游 SSE 结束事件并验证候选根因。
- [x] 完成诊断审查并记录可复现证据。

## 审查记录

- App 当前配置的 Base URL 是 `https://api.bltcy.ai`；Pi 因而请求 `/chat/completions`，该地址实际返回 `200 text/html`，没有任何 SSE `data:` 事件。
- Pi `0.80.7` 的 OpenAI completions adapter 会忽略非 SSE 内容，并在流结束后因从未收到非空 `choices[0].finish_reason` 抛出 `Stream ended without finish_reason`；完整 `AgentRuntime` 可稳定复现同一错误。
- 同一服务改用 `https://api.bltcy.ai/v1/chat/completions` 后返回 `200 text/event-stream`，共观察到 13 个事件、一个 `finish_reason: "stop"` 和一个 `[DONE]`，没有 JSON 解析错误。
- 临时把 Agent 配置的 Base URL 改为 `https://api.bltcy.ai/v1` 后，完整 Pi `AgentRuntime` 在 1.6 秒内成功返回非空答案；由此排除旧 helper、模型响应格式和网络提前断流。
- 本轮只更新任务诊断记录，没有修改产品实现或用户设置。

# 用 pi 替换旧 Agent 实现

## 状态

- 已完成（2026-07-15）

## 目标

- 在现有 Node helper 中集成 `@earendil-works/pi-agent-core`，提供有状态的多轮工具调用 Agent。
- Agent 面板改为调用内部鉴权 endpoint，并删除 Swift 侧候选排序、prompt 拼装与严格 JSON 解析旧实现。
- 复用现有 App bridge 和 `DataStorage`，只向 Agent 开放搜索、读取和列表工具。
- 外部 MCP 关闭时 Agent 仍可使用；MCP endpoint 自身继续服从现有开关。

## 边界

- 不嵌入 coding-agent CLI、TUI 或文件系统工具，不重写存储层。
- 没有用户确认 UI 前，不开放 create、update、delete 等写工具。
- AI token、base URL 和 model 只随内部 loopback 请求传递，不在 helper 中持久化。
- 保留并避开用户已有的 `Seahorse/Localizable.xcstrings` 改动。

## 计划

- [x] 为 Pi 工具循环、会话延续与内部 HTTP 路由添加回归测试。
- [x] 实现 Pi runtime、只读工具和独立于 MCP 开关的 helper 生命周期。
- [x] 替换 Swift `AgentService` 与 `AgentPanelView` 调用链。
- [x] 运行 Node 测试/build、Swift 测试/macOS build、真实链路验证和 diff 审查。

## 审查记录

- helper 已集成 Pi `0.80.7`：同一 `sessionId` 保留多轮上下文，模型通过 7 个 search/get/list 工具读取 bookmark、tag 和 category；工具继续经现有 Swift bridge 进入 `DataStorage`。
- `/agent` 使用 internal token，`/mcp` 使用 external token；helper 与 bridge 随 App 常驻，MCP 开关通过重启只改变外部 route，不再关闭 Agent 基础设施。
- Swift `AgentService.send(_:to:)` 只发送会话、用户消息和当前 AI 配置；旧的 40 条候选排序、prompt 拼装、严格 JSON 解析和整库快照传递已删除。
- DMG 打包会校验并内置 Node `>=22.19.0`、production dependencies 和 Pi/Node 许可证；App 优先运行 bundle 内 Node，开发构建才回退到 PATH。
- 验证通过：helper 12 项测试、TypeScript build、Swift 40 项测试、macOS Release build、脚本语法与 `git diff --check`；production staging 中自带 Node `v22.22.2` 可启动 helper，未鉴权 `/agent` 返回预期 401。
- production staging 实测 Node 可执行文件约 108 MB、production `node_modules` 约 146 MB；这是采用完整 Pi provider 栈和自带 runtime 的当前发布体积成本。
- Xcode 仍输出项目已有的 asset symbol 冲突、`NotificationService` actor 隔离和 AppIntents metadata warnings，本任务没有扩大处理范围。

# 设计 pi 的 App 注入方式

## 状态

- 已完成（2026-07-15）

## 目标

- 区分 pi 各包支持的运行环境，确认是否能直接嵌入原生 Swift App。
- 为 Seahorse 定义最小且可测试的 Swift ↔ Agent runtime seam。
- 说明 helper 生命周期、鉴权、AI 配置和打包方式。

## 边界

- 本轮只回答架构与注入方式，不修改产品源码或依赖。
- 不把 coding-agent CLI、TUI 或文件系统工具嵌入 App。
- 保留现有 App bridge 与 `DataStorage` 作为唯一数据访问路径。

## 审查记录

- `pi-ai` 核心可用于浏览器，但 pi coding-agent 和当前 `pi-agent-core` npm 包的正式运行要求是 Node `>=22.19.0`；Seahorse 没有可直接导入的 Swift/C ABI。
- 推荐 seam 是 Swift `AgentClient` 的单一 `send(_:to:)` interface，调用点为 `agentClient.send(message, to: sessionID)`；生产 adapter 是本机 HTTP/NDJSON，测试 adapter 是内存 fake。
- pi 实现放入现有 Node helper 代码库，并把进程角色提升为通用 Seahorse helper；内部 Agent endpoint 与外部 MCP endpoint 必须分别鉴权和启停。
- 当前 helper 仅在 MCP 开启时启动并依赖 `/usr/bin/env node`，因此 Agent 接入前需要把 helper 生命周期与 MCP 开关解耦，并提供自带兼容 runtime 或独立可执行文件。
- AI token、base URL 和 model 应由 Swift 在内部鉴权请求中临时传入，不在 helper 再保存一份；Agent 工具继续通过现有 `BridgeClient` 调用 Swift bridge。

# 评估 pi 作为基础 Agent 基础设施

## 状态

- 已完成（2026-07-15）

## 目标

- 核对 `earendil-works/pi` 的官方能力、运行时边界、授权和嵌入方式。
- 对照 Seahorse 现有 SwiftUI App、MCP helper、App bridge 与数据层，判断是否值得集成。
- 给出最小接入方案、明确非目标、风险和可验证的下一步。

## 边界

- 本轮只做证据驱动的可行性评估，不修改产品源码、不引入依赖。
- 保留并避开现有未提交的 `Seahorse/Localizable.xcstrings` 改动。
- 优先复用现有 MCP 边界；不重写 `DataStorage`、JSON 存储或 SwiftUI UI。

## 计划

- [x] 建立 Seahorse Agent/MCP 相关工作图。
- [x] 阅读 pi 官方仓库、文档、包结构与许可证。
- [x] 比较集成选项并确定最小边界。
- [x] 复核假设、风险与验证路径，完成审查记录。

## 审查记录

- 结论是可集成，但只应采用 `@earendil-works/pi-agent-core`/`pi-ai`，嵌入现有 Node helper；不采用 coding-agent CLI、TUI 或 RPC 模式，也不替换 Swift `DataStorage` 与 App bridge。
- 目标流为 Agent 面板 → 内部鉴权的 helper agent endpoint → pi 工具循环 → 现有 `BridgeClient` → `MCPBookmarkBridgeService` → `DataStorage`；首版只开放 search/get/list 只读工具并使用内存会话。
- 当前 Agent 面板是无状态的一次性 LLM 重排器；pi 可以补齐多轮上下文、工具调用、流式事件、取消和后续会话能力。
- pi 不内置 MCP 或权限确认；未实现确认 UI 前不得向模型开放 create/update/delete 等写工具。
- pi `0.80.7` 为 MIT，要求 Node `>=22.19.0`；Seahorse 当前通过 `/usr/bin/env node` 启动 helper，因此生产接入前必须解决自带兼容 Node runtime 或独立可执行文件。
- 临时安装测量显示，现有 production helper 依赖约 23 MB，直接加入 pi-agent-core 后约 146 MB；正式发布前应验证 bundle/可执行文件方案和 DMG 增量。
- 已用 pi faux provider 运行临时只读工具闭环：prompt、tool call、tool result、第二轮响应和完整 agent 事件序列均通过；未修改产品源码或依赖。

# 实现下一版本全部 P0 功能

## 状态

- 已完成（2026-07-15）

## 目标

- 逐项实现 `docs/analysis/next-version-features.md` 的 P0：智能集合/保存筛选、条目回收站与恢复、可靠书签富化流程。
- macOS 提供完整智能集合与回收站管理；iOS 复用同一查询和持久化模型并能读取结果。
- UI、批量诊断和 MCP 删除统一进入回收站；只有永久删除才清理受控图片文件。
- OGP 与 AI 富化按 bookmark ID 串行，新增任务不丢失，失败可见且可重试。

## 边界

- 复用 `CollectionSearch`、`DataStorage`、`DatabaseProtocol` 和现有 JSON 存储，不迁移数据库、不新增第三方依赖。
- 不实现报告中 P1/P2：Share Extension、OCR、重新发现、全文归档、云同步或协作。
- 保留当前未提交的分析报告与任务记录，不覆盖或混入无关重构。

## 计划

- [x] 审计 P0 验收范围、工作区和全部受影响调用链。
- [x] 实现智能集合查询模型、持久化、导入导出、测试和 macOS/iOS UI。
- [x] 实现回收站、恢复、永久删除、图片清理、测试和 MCP 统一语义。
- [x] 实现可靠富化队列、状态、重试与竞态回归测试。
- [x] 运行全量测试、双平台构建、迁移验证和 diff 审查。

## 边界情况

- [x] 智能集合引用的 Category/Tag 删除或改名时不得扩大匹配范围或崩溃。
- [x] ANY/ALL 标签、日期边界、待整理和空结果语义一致。
- [x] 恢复 Bookmark 遇到重复 URL 时阻止覆盖并返回明确错误。
- [x] 原 Category/Tag 缺失时恢复到 `None` 并清理无效 Tag 引用。
- [x] 重复删除幂等，批量删除/恢复不得部分成功。
- [x] 外部/远程图片永不删除，内部图片仅在永久删除且无引用时清理。
- [x] 旧版数据缺少新字段时可直接加载；迁移失败保留原始数据。
- [x] 新 Bookmark 在富化忙碌期间不会漏处理，OGP 与 AI 不互相覆盖。

## 审查记录

- 智能集合已覆盖创建、编辑、重命名、删除、排序、实时计数、ANY/ALL 标签、收藏、类型、分类、关键词、日期范围和保存排序；缺失引用保持规则但匹配为空，并提供可见警告与编辑入口。
- 智能集合写入 `smart-collections.json`，完整导出/导入和自定义存储文件清单已包含该文件；macOS 侧栏与 iOS Filter 使用同一个 `CollectionSearch.Criteria` 转换。
- Bookmark/Image/Text 通过可选 `deletedAt` 共用回收站；卡片、列表、诊断批量操作和 MCP `delete_item` 均移入回收站，支持单条/批量恢复、永久删除和清空。
- 恢复会原子校验重复 URL，并把缺失 Category 降级到 `None`、移除失效 Tag；批量 items 写入同步确认原子落盘，写入失败会回滚 JSONStorage 内存候选状态。
- 内部 ImageItem、thumbnail 和 Bookmark 本地封面仅在永久删除且无其他引用时清理；外部路径和远程 URL 不会被删除。
- `AutoParsingService` 现在是持久化 FIFO 队列；Paste、MCP 和自动 AI 解析不再各自并发写 OGP。队列按 ID 合并最新快照，URL 中途变化会重排，失败状态在卡片和工具栏可见并可重试。
- 验证通过：38 个 Swift 测试、MCP helper 7 个测试、macOS test build、iOS Simulator build、`git diff --check`。构建仍显示项目原有的 Swift 6 actor 隔离、生成资源名冲突和旧 `onChange` 等警告，本任务没有扩大处理范围。

# 下一版本功能建议分析

## 状态

- 已完成（2026-07-15）

## 目标

- 基于 `1.9.0` 当前源码完成 standard 深度全项目分析，覆盖结构、依赖、历史、构建发布、架构、数据流、业务流程、API 面和数据模型。
- 结合当前同类产品基线，生成 `docs/analysis/next-version-features.md`，明确下一 minor 版本应增加的功能及优先级。
- 每项建议包含用户问题、现有证据、最小范围、依赖与数据变化、关键边界情况、验收指标和不做范围。

## 边界

- 只修改 `docs/analysis/` 报告与任务记录，不修改产品源码，不执行项目或发布动作。
- 不把纯技术债包装成新功能；不建议超出当前单机收藏管理定位的大型平台化能力。
- 市场信息只用于校准功能基线，最终优先级必须由 Seahorse 当前代码和产品闭环支持。

## 计划

- [x] 完成 Phase 1 的结构、依赖、构建发布和开发历史报告。
- [x] 完成 Phase 2 的架构、数据流、业务流程、API 面和数据模型报告。
- [x] 调研当前同类产品功能基线并记录来源。
- [x] 建立候选功能价值/成本/风险矩阵，逐项检查边界情况。
- [x] 生成 SUMMARY 和下一版本功能建议报告。
- [x] 检查报告链接、事实引用、占位符和工作区 diff。

## 审查记录

- 已按 standard 深度生成 9 份主题报告，并更新 `docs/analysis/SUMMARY.md`；另新增 `docs/analysis/next-version-features.md` 汇总下一版本决策。
- 当前产品是本地优先的 SwiftUI 模块化单体 + Node MCP sidecar；核心搜索由 macOS、iOS、MCP 共享，JSON 仍足以支撑下一版本，不建议先换数据库或拆 framework。
- 下一版本建议主题为“找得到，删得回”：P0 交付智能集合/保存筛选与条目回收站；系统 Share Extension、图片 OCR、重新发现和真正跨设备同步按依赖后置。
- 推荐范围明确了用户问题、最小数据/代码改动、删除/导入/引用失效/重复 URL 等边界、非目标和验收门槛；技术债单列为发布条件，没有包装成新功能。
- 市场基线只引用 Raindrop、Anybox、Eagle、mymind 官方功能页；GitHub issue 列表为空，因此报告显式标注缺少用户访谈/遥测证据的假设边界。
- 关键发布风险已记录：CI artifact glob 与 `dist/` 不匹配、公开 DMG 未 Developer ID/notarize、MCP 隐式依赖 Node、实际 macOS 15.2 与文档 13.0+ 冲突、1.9.0 源码与最新 `v1.7.0` tag 不一致。
- 已检查 11 份本次报告的相对链接、模板占位符、行尾空白和源码事实；`git diff --check` 通过。按任务边界未运行项目、构建、发布，也未修改产品源码。

# Seahorse 1.9.0 本地发布

## 状态

- 已完成（2026-07-15）

## 目标

- 将 App 从 `1.8.0 (7)` 更新到 minor 版本 `1.9.0 (8)`，并同步用户可见 CHANGELOG。
- 构建并验证 MCP helper、Swift 测试、Release App 和 DMG。
- 将当前工作区全部改动纳入一次本地提交，完成后保持工作区干净。

## 发布边界

- 使用项目现有 `scripts/create-dmg.sh` 生成本地 DMG。
- 本次不创建 tag，不 push，不上传 GitHub Release，不 notarize，也不覆盖 `/Applications/Seahorse.app`。

## 计划

- [x] 审阅全部待提交改动并确认 CHANGELOG 内容。
- [x] 更新 Xcode marketing version、build number 和 CHANGELOG。
- [x] 构建并测试 MCP helper。
- [x] 运行 Swift 测试和 Release 构建。
- [x] 生成并验证 DMG 与 SHA256。
- [x] 更新审查记录并提交全部本地改动。

## 审查记录

- App source of truth 已从 `1.8.0 (7)` 更新为 `1.9.0 (8)`；`Info.plist` 使用构建设置，README、RELEASE、installer 和 appcast 无需同步旧版本引用。
- `CHANGELOG.md` 已发布当前版本更新日志面板、MCP `delete_tag`、helper 强制重启/父进程守护、Tag 关联清理、设置页对齐和 DMG helper 打包修复。
- `MCPHelper/package.json` 是 private helper 的独立版本，继续保持 `0.1.0`；lockfile 无版本变更需求。
- MCP helper TypeScript 构建成功，Node 全量 7 项测试通过；macOS 全量 23 项 XCTest 通过。
- `scripts/create-dmg.sh` 现在自动构建 helper，将 `dist` 与 production-only 依赖写入 App bundle，并使用原 Apple Development 身份重签名；bundle 内依赖导入和真实 MCP initialize HTTP 200 均通过。
- Release build 成功；保留既有 asset symbol、Swift 并发隔离、废弃 API 和未使用结果等 warnings。
- DMG 位于 `dist/Seahorse-1.9.0_20260715_160312/Seahorse-1.9.0.dmg`，`hdiutil verify` 与 SHA256 校验通过。
- SHA256：`765b3e0e5882dcb76f8aaa6295a56641d34ff79ac1c0dcb720053472de44de20`。
- Release App 为 `1.9.0 (8)`，bundle CHANGELOG 与源码一致，`codesign --verify --deep --strict` 通过；签名类型为 Apple Development，未 notarized。
- 本次未覆盖 `/Applications/Seahorse.app`，未创建 tag，未 push，未上传 GitHub Release。
- `bash -n scripts/create-dmg.sh`、`git diff --check` 和最终工作区检查通过。

# MCP 删除 Tag

## 目标
- 新增 destructive MCP 工具 `delete_tag(id)`，并在删除 Tag 前清除 bookmark、image、text 的关联。
- 书签继续通过现有 `delete_item(id)` 删除，不增加重复工具。

## 计划
- [x] 确认现有 MCP 工具、bridge 和存储删除语义。
- [x] 确认最小设计与书签删除入口。
- [x] 写入并复核设计规格。
- [x] 编写实施计划。
- [x] 增加 MCP 注册和存储级联删除红灯测试。
- [x] 实现共享存储删除语义与 `delete_tag` bridge。
- [x] 运行 Swift、Node、构建和真实 MCP 验证。

## 边界情况
- [x] 无效 UUID 返回 validation error。
- [x] 不存在的 Tag 返回 not found。
- [x] 删除 Tag 后三种 item 均不得保留该 ID。
- [x] 关联条目批量更新失败时不得删除 Tag。
- [x] `delete_item` 删除 bookmark 的行为保持不变。

## 审查记录
- `DataStorage.deleteTag` 当前只删除 Tag；两个 UI 调用方分别在外部清理引用，且 Tag 管理页只覆盖 bookmark。共享存储层需要统一级联清理。
- `delete_tag(id)` 复用 UUID schema 并标记 `destructiveHint: true`；书签仍由通用 `delete_item(id)` 删除。
- `DataStorage.deleteTag` 先通过 `updateItems` 批量清除 bookmark、image、text 引用，再删除 Tag；两个 UI 调用方已移除重复清理。
- TDD 红灯分别证明 `delete_tag` 尚未注册，以及旧 `deleteTag` 会留下 item 引用；修复后 Node 7 项、Swift 23 项测试通过，TypeScript 和 Debug build 成功。
- 最新 Debug App 已真实列出 destructive `delete_tag`；随机不存在 UUID 返回 MCP `not_found`，未修改用户数据。
- Task 1、Task 3 的规格与代码质量复核通过；Task 2 规格复核通过，质量 reviewer 连续空结果后由主线程按相同清单复核；最终整体验收 reviewer 批准。

# MCP helper 强制重启

## 目标
- 从设置页安全清理 Seahorse 残留 helper 并重启 MCP 服务，避免孤儿 Node 进程长期占用固定端口。

## 计划
- [x] 复现失败并确认残留 helper、端口和父进程状态。
- [x] 确认强制重启设计与进程清理边界。
- [x] 增加精确 helper 进程识别测试。
- [x] 实现等待终止、超时强杀和 force restart。
- [x] 增加设置页入口和 Node 父进程守护。
- [x] 运行单元测试、构建和真实端口恢复验证。

## 边界情况
- [x] 不终止仅占用 `17373` 但命令不匹配 Seahorse helper 的进程。
- [x] 旧 termination handler 不得清空新 helper 引用。
- [x] 多次点击 Force Restart 不得并发重启。
- [x] 正常退出和 MCP 开关关闭语义保持不变。

## 审查记录
- 复现时 PID `36747` 为父 PID `1` 的孤儿 Node helper，持有 `127.0.0.1:17373`；当前 App 无 `17374` bridge listener。
- `Force Restart` 先终止当前管理的 `Process`，等待 1 秒后超时强杀，再仅清理命令精确等于当前 `node <MCPHelper/dist/index.js>` 的残留进程；不会按端口终止无关进程。
- termination handler 以 `Process` 实例身份校验当前 helper，旧进程回调无法清空新 helper；`Restarting` 状态会禁用 MCP 开关和重复重启按钮。
- Node helper 每秒检查父 PID；独立测试确认父进程异常退出后 helper 在 2 秒内自行退出。
- 真实故障恢复已清理孤儿 PID `36747`，新 helper 由当前 Debug App 托管，`17373` 和 `17374` 恢复监听，MCP initialize 返回 HTTP 200；连续触发仍只有一个 helper。
- MCP 开关关闭后两个 listener 均停止，重新开启后状态恢复 `Running`。
- macOS 全量 22 项测试、MCP helper 7 项测试、TypeScript build、Debug build 和 `git diff --check` 通过；Xcode 测试需显式统一 `DEVELOPMENT_TEAM`，否则现有 test target 的 ad-hoc 签名与宿主 Team ID 不一致。

# 当前版本变更日志面板

## 目标
- 在 Advanced Settings 的 `Updates` 标题旁增加图标按钮，打开只显示当前版本内容的原生 changelog sheet。

## 计划
- [x] 确认内容范围、入口位置和数据源设计。
- [x] 写入并自审设计规格。
- [x] 用户复核规格。
- [x] 编写实施计划。
- [x] 实现解析器、资源打包与 sheet UI。
- [x] 运行解析测试、macOS 构建、资源检查和空白检查。

## 边界情况
- [x] CHANGELOG resource 缺失时显示 fallback。
- [x] 当前版本章节不存在或为空时显示 fallback。
- [x] 解析必须在下一个版本标题处停止。
- [x] 长内容可滚动，sheet 可通过按钮或 Escape 关闭。
- [x] 图标按钮包含 tooltip 和无障碍标签。

## 审查记录
- 设计规格：`docs/superpowers/specs/2026-07-14-current-changelog-panel-design.md`。
- `ChangelogParser` 精确匹配当前版本标题，只解析 H3 分类和短横线列表，并在下一个 H2 标题处停止；3 项定向测试覆盖版本隔离、精确匹配和空结果。
- 根目录 `CHANGELOG.md` 已加入 App Resources；Debug 产物内资源与源文件逐字节一致。
- Advanced Settings 的 `Updates` 标题旁新增 `info.circle`，打开 520×420 原生 sheet；缺失内容显示 fallback。
- 真实 Debug 进程已验证 tooltip、当前 1.8.0 的新增/改进/修复内容、长内容滚动、关闭按钮和 Escape 关闭。
- macOS 全量 21 项测试通过，Debug build、`git diff --check` 和资源检查通过；仅保留既有 asset symbol、Swift 并发隔离和 AppIntents metadata warnings。

# Seahorse 1.8.0 本地发布

## 目标
- 将 App 从 `1.7.0 (6)` 更新到 minor 版本 `1.8.0 (7)`，生成并验证 DMG，备份旧 App 后安装到 `/Applications`。

## 计划
- [x] 更新 Xcode marketing version、build number 和 CHANGELOG。
- [x] 构建并测试 MCP helper。
- [x] 运行 Swift 测试和 Release 构建。
- [x] 使用现有 `scripts/create-dmg.sh` 生成 DMG 与 SHA256。
- [x] 验证 DMG、App 版本和签名。
- [x] 正常退出运行中的 Seahorse 与 helper，备份并安装到 `/Applications`。
- [x] 提交本地发布变更并确认工作区状态。

## 边界情况
- [x] `/Applications/Seahorse.app` 覆盖前必须保留时间戳备份。
- [x] 不热覆盖运行中的 App 或 helper。
- [x] `MCPHelper/package.json` 是私有 helper 的独立版本，不随 App marketing version 更新。
- [x] README、Info.plist、installer 和 lockfile 无需版本同步时必须有检查证据。
- [x] 未执行 notarization、GitHub Release upload、远端 tag 或 push。

## 审查记录
- App 版本由 Xcode `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 管理，已从 `1.7.0 (6)` 更新为 `1.8.0 (7)`；Info.plist 使用构建设置，不含硬编码版本。
- `CHANGELOG.md` 已发布 Unreleased 内容并补充性能优化、侧边栏排序和 MCP handler 修复；README 无写死版本。
- MCP helper 2 个测试文件、7 项测试通过，TypeScript 构建通过；private package version `0.1.0` 与 lockfile 无需改变。
- Swift macOS 18 项测试通过，Release build 成功；保留既有 asset symbol、Swift concurrency 和 deprecated API warnings。
- DMG 位于 `dist/Seahorse-1.8.0_20260714_152037/Seahorse-1.8.0.dmg`，`hdiutil verify` 与 SHA256 校验通过。
- SHA256：`0218c8c13d3aff76d84125e2d6a10592fb1da03ac9134628afe9e14d04946b33`。
- 已将旧 App 备份到 `/Applications/Seahorse-1.7.0-backup-20260714_152318.app`，并安装 `/Applications/Seahorse.app`；安装版本为 `1.8.0 (7)`，`codesign --verify --deep --strict` 通过。
- App 使用 Apple Development 签名，未使用 Developer ID Application 签名，且未 notarized；该 DMG 仅作为本地安装包验证。
- 现有 release SOP 不覆盖 GitHub Release upload，且用户未单独确认 tag/push，因此未执行远端动作。

# 侧边栏 Tag 字母排序

## 目标
- 侧边栏 `TAGS` 区域按 tag 名称的本地化字母顺序稳定展示，不改变持久化顺序和管理页拖拽顺序。

## 计划
- [x] 在 `SidebarView` 展示边界生成排序后的 tags。
- [x] 保持 tag 选择与数据模型不变。
- [x] 运行 macOS 构建和空白检查。

## 边界情况
- [x] 大小写、数字和本地化字符使用系统标准比较规则。
- [x] 空 tag 列表保持正常。
- [x] 排序不写回 `DataStorage`。

## 审查记录
- `SidebarView.sortedTags` 使用 `localizedStandardCompare`，`ForEach` 只消费排序后的展示副本。
- 未修改 `DataStorage.tags`、Tag 管理页或拖拽重排逻辑。
- macOS Debug 构建和 `git diff --check` 通过；仅保留既有 `seahorse_icon` asset symbol warning。

# MCP 工具 handler 注册修复

## 目标
- 用真实 MCP tool call 复现 `typedHandler is not a function`，改用无重载歧义的 SDK 注册 API，并验证普通工具与 destructive annotation。

## 计划
- [x] 用 SDK 内存 transport 复现带参数工具调用失败。
- [x] 增加工具调用回归测试并确认修复前失败。
- [x] 改用 `registerTool()` 注册 schema、annotations 和 handler。
- [x] 运行 MCP 全量测试、TypeScript 构建和空白检查。

## 边界情况
- [x] 零参数工具仍能调用。
- [x] 参数 schema 仍执行校验和默认值处理。
- [x] `delete_item` 仍暴露 `destructiveHint: true`。
- [x] bridge 错误仍通过 MCP tool result 返回，不被注册层吞掉。

## 审查记录
- SDK 内存 transport 在修复前稳定复现：参数化 `search_bookmarks` 返回 `typedHandler is not a function`，零参数工具正常。
- 共享注册函数改用 `registerTool(name, { inputSchema, annotations }, handler)`，并传入显式 Zod object，避免 `tool()` 的 schema/annotations 重载歧义。
- 回归测试覆盖参数默认值、零参数调用、destructive annotation 和 bridge 错误传播；MCP helper 2 个测试文件、7 项测试通过。
- TypeScript 构建与 `git diff --check` 通过。
- 已让 Seahorse 重启 helper，并对运行中的 `http://127.0.0.1:17373/mcp` 执行真实 `search_bookmarks`，调用成功。

# 全项目性能优化实现

## 目标
- 完成 `docs/analysis/performance-audit.md` 中 P0、P1、P2 问题的根因修复，并为 P3 扩展性建立可量化的升级门槛。
- 不新增第三方依赖，不迁移 SQLite/SwiftData，不改变 MCP 工具契约。

## 计划
- [x] 建立 Swift 性能回归测试和可重复数据 fixture。
- [x] 合并 JSON 写入，支持同步 flush，并删除启动冗余写入。
- [x] 详情编辑改为 draft + debounce/flush，避免按键级 CRUD。
- [x] 统一 macOS、iOS、MCP 纯搜索核心，支持取消和非主 actor 计算。
- [x] 缓存 MCP 稳定分页结果，并复用 O(1) item cache。
- [x] 本地图片加载改为异步下采样，移除同步图标磁盘读取。
- [x] 将粘贴、截图、生成封面和 MCP poster 的图片编码/复制移出主 actor。
- [x] 将导入导出的 JSON/HTML/文件 I/O 移出主 actor。
- [x] 增加批量更新路径，收敛删标签和导入的 N 次全量写。
- [x] 预计算排序键，缓存详情元数据，减少长文本全量遍历。
- [x] 拆分 lookup cache 重建，降低解析动画刷新率，缓存 SF Symbol 可用性。
- [x] 运行 Swift/MCP 测试、性能基准、macOS/iOS 构建和空白检查。

## 边界情况
- [x] App 退出、窗口关闭和迁移存储位置前，所有 debounce/coalesced write 必须 flush。
- [x] 旧搜索 task 不得覆盖新查询，tag/title/url/notes 变更不得留下 stale index。
- [x] 后台任务只处理不可变快照，`DataStorage` 与 SwiftUI 状态仍只在主 actor 修改。
- [x] 图片查看器保留放大清晰度；缩略图才强制下采样。
- [x] 批量更新不得改变重复 URL、部分失败和图片删除语义。
- [x] 性能优化不得依赖 ID-only `Equatable` 而隐藏 payload 更新。

## 审查记录
- JSON 持久化已改为延迟合并、紧凑原子写入和同步 flush；启动不再重写现有数据，批量更新与导入在写入前完成整体验证。
- macOS、iOS 与 MCP 共用 `CollectionSearch` 和预计算搜索记录；搜索支持任务取消、稳定排序、分页及按 `itemsVersion` 失效的 MCP 结果缓存。
- 图片编码、复制和缩略图读取已移出主 actor；全屏查看器仍加载原图，避免缩放质量退化。
- 导入、导出、备份与目录扫描使用不可变快照在后台执行；删标签、批量 AI 解析和导入改为批量持久化。
- 排序键、详情元数据、SF Symbol 目录和 lookup cache 已按用途预计算或拆分；解析动画降低到 20 Hz。
- macOS 全量测试通过：18 项；覆盖搜索取消与索引失效、JSON 合并写和批量原子性、图片 I/O、长文本处理。
- 搜索基准：300 条 p95 0.67 ms，3,000 条 p95 5.59 ms，10,000 条 p95 33.47 ms；当前不满足迁移数据库的必要性。
- iOS Simulator Debug 构建通过；MCP helper 的 6 项测试和 TypeScript 构建通过；`git diff --check` 通过。
- 仍需在真实用户操作下用 Instruments 采集 Time Profiler、Main Thread 和文件 I/O；该动态测量不阻塞当前 P0、P1、P2 修复。

# 全项目性能审计

## 假设
- 审计目标是运行时性能：启动、交互、滚动、搜索、图片、存储、网络、并发和 MCP。
- 只报告有具体代码证据且值得测量或修改的优化点，不把纯风格建议列为性能问题。
- 本轮只生成分析报告，不修改业务源码。

## 计划
- [x] 建立项目结构、核心数据流和热点调用地图。
- [x] 扫描 Swift/SwiftUI、存储、图片、网络、MCP 与依赖使用中的性能模式。
- [x] 阅读高风险热点及直接调用方，区分真实瓶颈、条件性风险和无需处理项。
- [x] 生成按优先级排序的性能审计报告与摘要。
- [x] 复核每项建议的证据、影响、验证方法和最小修复方向。

## 边界情况
- [x] 避免建议会造成 stale cache、数据竞争、主线程越界或图片质量下降的优化。
- [x] 区分数据量较小时无收益的微优化与随数据量增长会恶化的算法问题。
- [x] 对缺少 Instruments/基准数据的结论明确标记为“需测量”，不宣称已证实。
- [x] 不在报告或命令输出中记录 token、凭据或用户数据。

## 审查记录
- CodeGraph 已索引 105 个文件、1,197 个节点和 2,885 条边；性能热路径集中在 `DataStorage`、`JSONStorage`、三套搜索和图片 I/O。
- 本机仅核对了性能相关的聚合指标：287 条 item、`items.json` 约 438 KB、存储位于 iCloud Drive；未记录条目内容或凭据。
- 完整报告位于 `docs/analysis/performance-audit.md`，摘要与仓库地图位于同目录的 `SUMMARY.md` 和 `repo-map.md`。
- 已对写入合并的退出丢数据、后台搜索乱序、索引失效、图片质量和 actor 数据竞争五个最可能失败模式给出缓解。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug CODE_SIGNING_ALLOWED=NO` 通过，仅有 destination 选择和 AppIntents metadata skipped 提示。
- `MCPHelper` 的 `npm test` 通过，2 个测试文件、6 个测试通过。
- `git diff --check` 通过。
- 本轮未运行 Instruments 或构造 3,000/10,000 条性能 fixture；报告已将静态证实与需动态量化的建议分开。

# MCP 删除全部条目类型

## 假设
- 新增一个通用 `delete_item`，按全局 UUID 删除 bookmark、image 或 text，不为每种类型复制工具。
- 删除是永久操作；不存在的 UUID 返回 `not_found`，不会静默成功。
- 成功响应包含被删除条目的 `id` 和 `type`，方便 agent 校验结果。
- 图片条目复用 `DataStorage.deleteItem(_:)`，仅清理 Seahorse 内部图片文件；外部路径和远程 URL 不删除。
- tag 和 category 继续只读，不在本次范围内。

## 计划
- [x] 增加 `delete_item` schema 红灯测试并确认因工具缺失失败。
- [x] 注册 MCP 工具并更新工具列表 smoke test。
- [x] 在 Swift bridge 中按 UUID 定位 `AnyCollectionItem`，复用统一删除入口。
- [x] 跑相关测试、helper build、Swift build 和空白检查。

## 边界情况
- [x] 拒绝格式错误的 UUID。
- [x] 对不存在的 UUID 返回 `not_found`。
- [x] 删除 bookmark 时同步更新 `bookmarks`、`items` 和 `_itemCache`。
- [x] 删除 image 时仅清理 Seahorse 内部存储中的本地文件。
- [x] 相邻目录或经符号链接逃逸到 `Images` 外部的路径不得被删除。
- [x] 删除 text 时不触发任何文件清理。

## 审查记录
- 红灯测试：`npm test -- tests/tools.test.ts` 先失败，原因是 `deleteItemShape` 尚未导出。
- 新增通用 `delete_item(id)`，通过 `DataStorage.item(for:)` 定位全部三类条目并复用 `DataStorage.deleteItem(_:)`。
- 工具标记 `destructiveHint: true`；合法性错误、条目不存在和底层删除失败分别返回 `validation_error`、`not_found`、`delete_failed`。
- 图片路径边界改为解析符号链接后的 `Images/` 目录判断，避免相邻目录和链接逃逸。
- `MCPHelper` 的 `npm test` 通过，2 个测试文件、6 个测试通过。
- `MCPHelper` 的 `npm run build` 通过；额外检查确认注册工具带有 `destructiveHint: true`。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有 destination 选择和 AppIntents metadata skipped warning。
- `git diff --check` 通过。
- 未对用户正在运行的 App 执行真实删除 smoke test，避免破坏现有 bookmark/image/text 数据；需要安装并重启新构建后再做人工删除验证。

# MCP bookmark poster image

## 假设
- `update_bookmark` 增加 `posterImageURL` 和 `posterImagePath`，不新增单独工具。
- `posterImageURL` 直接写入 `bookmark.metadata.imageURL`。
- `posterImagePath` 支持普通绝对路径和 `file://`，复制到 Seahorse `Images` 存储目录后写入文件名。
- 两者同时传入时优先使用 `posterImagePath`。

## 计划
- [x] 先增加 TypeScript schema 红灯测试。
- [x] 扩展 `update_bookmark` schema。
- [x] 在 Swift bridge 更新 bookmark metadata poster。
- [x] 跑 helper 测试/build、Swift build 和空白检查。

## 审查记录
- 红灯测试：`npm test -- tests/tools.test.ts` 先失败，原因是 `updateBookmarkShape` 未导出/未暴露 poster 字段。
- `update_bookmark` schema 已新增 `posterImageURL` 和 `posterImagePath`。
- Swift bridge 已支持远程 poster URL；本地 poster path 会复制到 Seahorse `Images` 目录，再把文件名写入 `metadata.imageURL`。
- 两个字段同时存在时优先使用 `posterImagePath`。
- `MCPHelper` 的 `npm test` 通过，2 个测试文件、5 个测试通过。
- `MCPHelper` 的 `npm run build` 通过。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；本次有 Xcode destination warning 和 AppIntents metadata skipped warning。
- `git diff --check` 通过。

# MCP get_bookmarks

## 假设
- `get_bookmarks` 用于按 ids 批量读取 bookmark 详情，减少 agent 连续调用 `get_bookmark`。
- 输入为 `ids: [UUID]`，数量限制为 1...100，避免单次响应过大。
- 返回结构为 bookmark detail array，按传入 id 顺序返回；不存在的 id 跳过，调用方可用返回的 `id` 自行对比缺失项。

## 计划
- [x] 在 TypeScript MCP schema 和工具注册里新增 `get_bookmarks`。
- [x] 在 Swift bridge 里新增 `getBookmarks` 分支和实现。
- [x] 更新 smoke test 预期工具列表。
- [x] 增加最小 schema 测试。
- [x] 跑 helper 测试/build、Swift build 和空白检查。

## 审查记录
- `get_bookmarks` schema 已新增 `ids`，约束为 UUID array，长度 1...100。
- Swift bridge 已新增 `getBookmarks`，按传入顺序返回 bookmark detail array，缺失 id 跳过。
- `scripts/smoke-mcp.sh` 预期工具列表已新增 `get_bookmarks`。
- `MCPHelper` 的 `npm test` 通过，2 个测试文件、4 个测试通过。
- `MCPHelper` 的 `npm run build` 通过。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；本次有 Xcode destination warning 和 AppIntents metadata skipped warning。
- `git diff --check` 通过。

# MCP bookmark 分页

## 假设
- “related mcp functions” 指当前可查询 bookmarks 的 `search_bookmarks`，不新增重复的 `list_bookmarks` 工具。
- 保留 `limit <= 100`，新增 `offset >= 0`，让 agent 分批取全量。
- 返回结构继续保持 array，避免破坏现有 MCP 调用方；调用方用返回数量小于 limit 判断结束。

## 计划
- [x] 在 TypeScript MCP schema 里给 `search_bookmarks` 增加 `offset`。
- [x] 在 Swift bridge 的 `searchBookmarks` 里解析并应用 `offset`。
- [x] 增加最小测试覆盖 offset 参数透传或分页行为。
- [x] 跑 helper 测试/build、Swift build 和空白检查。

## 审查记录
- `search_bookmarks` schema 已新增 `offset`，约束为整数且 `>= 0`。
- Swift bridge 已在排序后应用 `dropFirst(offset).prefix(limit)`，保留 `limit <= 100`。
- 新增 `MCPHelper/tests/tools.test.ts` 覆盖 `offset` 接受非负数、拒绝负数。
- `git diff --check` 通过。
- `MCPHelper` 的 `npm test && npm run build` 通过，2 个测试文件、3 个测试通过。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；本次仅有 Xcode 选择首个匹配 destination 的常规 warning。

# Seahorse MCP 实现

## 假设
- 先做可验证纵切：App 内 bridge、Node MCP helper、Settings、生命周期和 smoke test。
- “随 App 打包 Node runtime”需要构建/发布脚本收口，不在代码里假装系统 Node 就是最终发布形态。
- helper 不直接读写 JSON，所有写入回到 App 内 `DataStorage`。

## 计划
- [x] 写入实现计划。
- [x] 实现 MCP Settings 状态。
- [x] 实现 App bookmark bridge service。
- [x] 实现内部 HTTP bridge。
- [x] 实现 Node MCP helper。
- [x] 接入 Settings UI 和 helper lifecycle。
- [x] 跑端到端 smoke test 和构建验证。

## 审查记录
- 实现计划已写入 docs/superpowers/plans/2026-07-08-seahorse-mcp-implementation.md。
- 已新增 App 内 MCP settings、bookmark bridge service、内部 HTTP bridge、helper manager 和 Settings UI。
- 已新增 TypeScript/Node MCP helper，使用稳定版 `@modelcontextprotocol/sdk@1.29.0`。
- helper 单元测试和 TypeScript build 已通过。
- Swift Debug build 已通过；保留既有 `seahorse_icon` asset symbol warning。
- `git diff --check` 已通过。
- 独立启动 helper 后，`scripts/smoke-mcp.sh smoke-token` 已验证 `/mcp` 初始化和 `tools/list`，返回 8 个预期工具。
- 真实 App 内 Settings toggle 到 bridge 的手工端到端验证未跑；当前验证覆盖 Swift build、helper 单元测试、helper TypeScript build 和外部 MCP smoke。

# Seahorse MCP 设计

## 假设
- 第一版 MCP 只面向本机 agents，不支持局域网。
- MCP server 随 Seahorse App 运行，但协议实现拆到 bundled TypeScript/Node.js helper。
- CRUD 范围收敛为 bookmarks 的 create/read/update/search/list，不做 delete。
- tags/categories 第一版只读。

## 计划
- [x] 澄清信任模型、端口、transport、token 和生命周期。
- [x] 澄清 bookmark、tag、category 的第一版工具范围。
- [x] 确认 App/helper/bridge 架构。
- [x] 写入设计文档。

## 审查记录
- 设计文档已写入 docs/superpowers/specs/2026-07-08-seahorse-mcp-design.md。
- 设计采用 Seahorse App + bundled TypeScript/Node.js MCP helper。
- helper 负责 Streamable HTTP MCP 和外部 token 鉴权；真实数据写入必须回到 App 内 `DataStorage`。
- 第一版不做 bookmark delete、tag/category 写操作、image/text MCP、LAN、OAuth、Keychain、多用户权限、stdio 或旧 HTTP+SSE。

# 主搜索输入性能修复

## 假设
- 卡顿发生在主窗口 toolbar 的 `.searchable` 输入，不是 Agent 面板或批量操作弹窗里的搜索框。
- 最小修复优先避免每次 body 重算都扫描全量数据和重复构造搜索字符串，不引入新搜索引擎或索引库。
- 如果现有数据缓存已经覆盖部分场景，只修复真正导致输入期间主线程阻塞的共享路径。

## 计划
- [x] 量化搜索输入时 `filteredItems` 和搜索字符串构造的耗时。
- [x] 定位每次按键触发的昂贵 SwiftUI 计算/视图重建路径。
- [x] 做最小修复：复用已有缓存或增加局部缓存，避免输入过程中重复全量过滤。
- [x] 运行构建、空白检查和最小性能回归检查。

## 审查记录
- 根因定位在主窗口搜索过滤：每次搜索都会为每个 item 重新 lowercased 字段，并用 `dataStorage.tags.filter` 对全量 tag 做线性扫描。
- 合成微基准：20,000 items / 2,000 tags 下旧路径约 8564.9 ms；使用 tag cache 和 searchable text cache 后首次约 61.3 ms，缓存命中约 34.1 ms。
- `ContentView` 现在按 item id 缓存拼好的小写搜索文本，并复用 `DataStorage.tags(for:)` 的 O(1) tag 查询。
- items 数量、items version、tags 或 `DataStorageItemsUpdated` 变化时会清理搜索文本缓存，避免 stale search。
- `git diff --check` 通过。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；保留了已有 asset symbol 重名 warning。

# Chrome 原生书签同步

## 假设
- 不再使用 Chrome 扩展、popup、background service worker、localhost HTTP server 或 Native Messaging host。
- Seahorse 直接写入 Chrome 本地书签文件：`~/Library/Application Support/Google/Chrome/<Profile>/Bookmarks`。
- 最小可靠版本只同步到默认 Chrome profile；如果存在多个 profile，优先 `Default`，没有则使用第一个含 `Bookmarks` 的 profile。
- 为避免 Chrome 运行中覆盖文件，同步前检测 Chrome 是否运行；运行中则提示用户先退出 Chrome。
- 每次写入前备份原 `Bookmarks` 文件。

## 计划
- [x] 删除 Chrome extension 目录和 HTTP server。
- [x] 将 `ChromeBookmarkSyncService` 改成原生 JSON 文件同步。
- [x] 保留现有 toolbar 同步入口，文案改成真实结果。
- [x] 构建验证。

## 审查记录
- 已删除 Chrome extension 目录、Native Messaging host 脚本和 HTTP server。
- `ChromeBookmarkSyncService` 现在直接写入 Chrome 默认 profile 的 `Bookmarks` 文件。
- 同步会在写入前备份原文件，并在 Chrome 正在运行时拒绝写入。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。
- 截图里的平铺结构来自旧扩展同步：当前 Chrome 默认 profile 的 `Seahorse` 文件夹仍有 258 个根级 URL、9 个子文件夹、8 个空文件夹；Chrome 当前正在运行，原生同步不能覆盖该文件。
- 修复 toast 不显示：`GlobalToastManager` 原本只更新状态，主窗口没有挂 `.toast(...)` 渲染器。

# Liquid Glass UI 修复

## 假设
- 截图红框中的主要问题来自自绘 toolbar/search 背景与系统 Liquid Glass toolbar 叠加。
- 最小修复优先使用 SwiftUI/macOS 原生 toolbar 和 searchable，不重新设计卡片或 sidebar。

## 计划
- [x] 移除 toolbar 内自绘搜索框，改用 `.searchable`。
- [x] 移除 toolbar 内自绘背景块，让系统 glass 接管。
- [x] 清理 toolbar 分隔符和密度。
- [x] 构建验证。

## 审查记录
- `ContentView` 删除了 toolbar 内手写搜索框，改用 `NavigationSplitView.searchable`。
- `ContentView` 删除了 toolbar 内的自绘 `controlBackgroundColor` 按钮背景，交给系统 Liquid Glass toolbar。
- `ContentView` 删除了 toolbar 内部自绘分隔符，减少 glass surface 里的硬切线。
- `SortMenuButton` 删除了 popover 自绘 window 背景。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# List Mode 修复

## 假设
- 截图中的超高行来自 `StandardListItemView` 没有固定高度，且标题未限制行数。
- favicon 不需要新建自定义缓存层；项目已使用 Kingfisher，应该启用其磁盘缓存并减少重复加载态。

## 计划
- [x] 固定 list row 高度。
- [x] 限制标题和副标题为单行尾部截断。
- [x] 为 bookmark favicon 启用 Kingfisher 磁盘缓存策略。
- [x] 构建验证。

## 审查记录
- `StandardListItemView` 现在固定为 64pt 高度，移除垂直 padding 导致的内容驱动高度。
- `StandardListItemView` 的标题和副标题均限制为单行，并使用尾部截断。
- `BookmarkIconView` 的远程 favicon 使用 Kingfisher downsampling、磁盘缓存和同步磁盘读取，降低列表重建时重复 loading 的概率。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Grid Poster 缓存和标准菜单

## 假设
- 主 grid poster 已使用 Kingfisher 磁盘缓存；长时间 loading 主要发生在首次下载、远程图片慢/失效，或缓存命中后仍异步读取导致闪 placeholder。
- Toolbar 中不自然的菜单主要是自定义 sort popover；Kind/Add 已经是 SwiftUI `Menu`，只需要让内容更标准。

## 计划
- [x] 给 grid poster 图片启用同步磁盘缓存读取。
- [x] 用标准 SwiftUI `Menu` 替换自定义 sort popover。
- [x] 清理 Kind menu 的手写选中布局。
- [x] 构建验证。

## 审查记录
- 主 grid poster 原本已经使用 Kingfisher 磁盘缓存；这次加了 `.loadDiskFileSynchronously()`，让已有缓存优先从磁盘同步显示，减少 placeholder 闪烁。
- `SortMenuButton` 由自定义 `Button + popover + custom rows` 改为标准 SwiftUI `Menu + Picker`。
- Kind filter 的 menu 内容改为标准 `Picker`，交给系统菜单处理选中态。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Detail Window 打开性能日志

## 假设
- 当前单击打开详情至少有一个人为 100ms 延迟，因为代码在等待双击判定。
- 剩余慢点可能在 SwiftUI window 创建、detail item 查找、detail view 构建，或 bookmark WebView 初始化。

## 计划
- [x] 移除 cell 单击打开详情的 100ms 人为延迟。
- [x] 为 grid/list cell 点击、`showItem`、`openWindow` 返回、detail window appear、detail view appear、`loadItemData` 添加耗时日志。
- [x] detail window 用已有 `dataStorage.item(for:)` 缓存查找 item。
- [x] 构建验证。

## 审查记录
- `StandardCardView` 和 `StandardListItemView` 的单击打开详情不再等待 100ms 双击判定。
- 新增 `performance` OSLog 分类，detail 打开链路统一输出 `detail_open ... elapsed_ms=...`。
- `ItemDetailWindowView` 改用 `dataStorage.item(for:)` O(1) 缓存查找 item。
- `ItemDetailView`、`BookmarkDetailContentView`、`ControllableWebView` 增加 appear、load data、WebView 创建和网页加载日志。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Bookmark WebView 延迟加载

## 假设
- 详情窗口打开慢主要来自 bookmark detail 立即创建 `WKWebView`。
- 最小修复是默认不创建 WebView，用户点击预览后再加载。

## 计划
- [x] 默认显示本地 web preview placeholder，不创建 `WKWebView`。
- [x] 添加打开 Web Preview 的按钮。
- [x] WebView 加载时显示 `ProgressView`。
- [x] 构建验证。

## 审查记录
- `BookmarkDetailContentView` 默认只显示 URL 和 `Open Web Preview` 按钮，不再打开详情时立即创建 `WKWebView`。
- 点击 `Open Web Preview` 后才创建并加载 `ControllableWebView`。
- `isLoading` 时覆盖系统 `ProgressView`，显示网页加载中状态。
- Web preview 未打开时，刷新和截图按钮禁用。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# WebView Loading Bar

## 假设
- 中央 loading spinner 会遮挡网页内容，不符合当前设计预期。
- 更轻量的处理是在顶部 toolbar 下方放一条细进度条。

## 计划
- [x] 移除 WebView 中央 `ProgressView`。
- [x] 在 toolbar 下方添加细 loading bar。
- [x] 构建验证。

## 审查记录
- `BookmarkDetailContentView` 不再在 WebView 中央覆盖 loading spinner。
- Web preview 打开并加载时，在顶部 toolbar 下方显示 2pt 高的线性进度条；未加载时保留 2pt 空白，避免布局跳动。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Toolbar System Menu

## 假设
- 当前难看的部分主要来自 toolbar 中三枚彩色独立按钮和手写 badge。
- 最小修复是把低频工具操作合并进一个标准 SwiftUI `Menu`。

## 计划
- [x] 用系统 `Menu` 替换批量解析、诊断、封面生成三个独立 toolbar 按钮。
- [x] 删除这些按钮上的自定义 tint、pulse 和 badge overlay。
- [x] 构建验证。

## 审查记录
- `ContentView` toolbar 中的 Batch Operation、Diagnostics、Cover Generation 已合并到一个标准 SwiftUI `Menu`。
- 移除了这三个 toolbar action 的彩色 icon、pulse 动效和手写 badge overlay；数量状态改为菜单项文字。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Toolbar System Grouping

## 假设
- 单个 `Menu`/`Button` 直接放进 toolbar 会被系统渲染成一串独立圆形按钮。
- Seahorse 更接近系统截图的做法是把相关操作放进 `ControlGroup`，共享一个系统外框。

## 计划
- [x] 把 Kind、Sync、Sort、Tools 合并进一个系统 `ControlGroup`。
- [x] 去掉 toolbar 控件上的手动 `.controlSize(.small)`。
- [x] 构建验证。

## 审查记录
- `ContentView` 的 Kind、Sync、Sort、Tools 现在共用一个系统 `ControlGroup`，由系统渲染共享外框和 hover 区域。
- `ContentView` 的 view mode 和 Add menu 不再强制 `.controlSize(.small)`。
- `SortMenuButton` 不再内部强制 `.controlSize(.small)`。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Toolbar Menu Highlight

## 假设
- `Menu` 放在 `ControlGroup` 内会产生嵌套 button，导致 hover 只高亮内层而不是整个 toolbar item。
- 最小修复是移除外层 `ControlGroup`，让系统 toolbar 直接渲染 `Menu`。

## 计划
- [x] 移除 Kind、Sync、Sort、Tools 外层 `ControlGroup`。
- [x] 构建验证。

## 审查记录
- `ContentView` 移除了包在 Kind、Sync、Sort、Tools 外面的 `ControlGroup`，避免 `Menu` 形成外层玻璃和内层 button 的嵌套高亮。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Crop Interaction

## 假设
- 固定比例先使用常见的 16:9；以后确实需要再做比例输入。
- 已创建选框后，拖动选框本体应该移动它；拖动空白区域创建新选框；单击空白区域清除选框。

## 计划
- [x] 给 snapshot overlay 增加 `Lock 16:9` 配置。
- [x] 背景拖拽创建固定比例或自由比例选框。
- [x] 选框本体拖拽移动，并限制在 WebView 范围内。
- [x] 空白单击清除选框。
- [x] 构建验证。

## 审查记录
- `SnapshotSelectionOverlay` 新增持久化的 `Lock 16:9` 开关。
- 空白区域拖拽创建选框；开启比例锁时按 16:9 创建。
- 已有选框可通过拖动选框本体移动，并限制在 WebView 范围内。
- 单击空白区域会清除当前选框。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Drag Cursor

## 假设
- 只有已有选框本体是可拖动区域，空白区域用于创建/清除选框。

## 计划
- [x] 鼠标悬停在选框本体时显示 open hand 光标。
- [x] 拖动选框时显示 closed hand 光标。
- [x] 构建验证。

## 审查记录
- `SnapshotSelectionOverlay` 的选框本体 hover 时设置 `NSCursor.openHand`。
- 拖动选框时设置 `NSCursor.closedHand`，拖动结束恢复 open hand。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Resize Handles

## 假设
- 先提供四角缩放；边缘缩放和任意比例菜单以后需要再加。
- `Lock 16:9` 打开时，拖动角点缩放也保持 16:9。

## 计划
- [x] 给选框添加四个角点 resize handle。
- [x] 拖动角点缩放选框，并限制在 WebView 范围内。
- [x] 固定比例模式下 resize 保持 16:9。
- [x] 构建验证。

## 审查记录
- `SnapshotSelectionOverlay` 给选框添加了四个角点 resize handle。
- 拖动角点会以对角点为锚点缩放选框。
- `Lock 16:9` 开启时，角点缩放继续保持 16:9。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Bookmark Poster Stable Cache

## 假设
- GitHub 等站点的 OpenGraph 图片 URL 可能随项目状态变化，按 URL 缓存会导致下次启动重新加载。
- 先用 bookmark id 作为封面缓存 key，让同一条 bookmark 下次启动优先显示上次成功缓存的图片。
- 不强制每次启动刷新远程封面，避免继续拖慢列表首屏。

## 计划
- [x] 给 bookmark 网格封面远程图片添加稳定 Kingfisher cache key。
- [x] 保持本地截图/本地图片路径按原路径加载。
- [x] 构建验证。

## 审查记录
- `StandardCardView` 的 bookmark 远程封面现在使用 `bookmark-preview-{bookmark.id}` 作为 Kingfisher cache key。
- 本地截图、本地图片路径、image item 的加载逻辑保持原样。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Selection Hit Testing

## 假设
- 空白背景负责新建/清除选框。
- 已有选框本体只负责拖动和拦截事件。
- 只有四角 handle 能 resize。

## 计划
- [x] 让选框本体高优先级处理拖动，避免背景 drag 抢事件。
- [x] 让选框本体拦截点击，空白点击才清除。
- [x] 让四角 handle 独占 resize。
- [x] 构建验证。

## 审查记录
- `SnapshotSelectionOverlay` 的选框本体现在使用高优先级拖动手势，并拦截点击。
- 背景仍只负责空白区域的新建/清除选框。
- 四角 resize handle 提升到选框上层，并扩大 hit area。
- 底部保存/取消面板保持最高交互层级。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Poster Refresh

## 假设
- 现有日志没有 snapshot save 的应用级事件，无法直接从日志看到保存路径。
- `DataStorage.updateBookmark` 更新了 `items`，但没有更新 `_itemCache`。
- 卡片通过 `dataStorage.item(for:)` 读取 `_itemCache`，所以 save 后仍渲染旧 bookmark。

## 计划
- [x] 让 `DataStorage` 在 item 增删改时同步 `_itemCache`。
- [x] 给 snapshot preview 更新成功/失败添加精简日志。
- [x] 构建验证。

## 审查记录
- `/Users/caishilin/.venom/logs/Seahorse.log` 里没有 snapshot save / poster update 的应用级日志，只有 WebKit/CFNetwork 噪声，无法直接从日志判断保存是否成功。
- 根因在 `DataStorage.item(for:)` 的 `_itemCache` 没有随 `updateBookmark` 更新，卡片刷新后仍读到旧 bookmark。
- `DataStorage` 现在会在 item/bookmark 增删改时同步 `_itemCache`。
- snapshot preview 保存成功/失败现在会写 `snapshot_preview_updated` / `snapshot_preview_update_failed` 日志。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Poster Ratio

## 假设
- 网格 poster 默认比例是 `4:3`。
- 最小修复是把 snapshot crop 的固定比例从 `16:9` 改成默认开启的 `4:3`。
- 先不做自定义比例编辑器。

## 计划
- [x] 把 snapshot ratio lock 默认值改为开启。
- [x] 把固定比例从 `16:9` 改为 `4:3`。
- [x] 构建验证。

## 审查记录
- snapshot crop 固定比例现在默认开启，并使用 `4:3`。
- UI 文案从 `Lock 16:9` 改成 `Lock 4:3`。
- 使用新的 `snapshotLockPosterAspectRatio` 存储 key，避免旧 `16:9` 偏好影响新默认。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Ratio Options

## 假设
- 用户需要直接在 snapshot 面板里选择多个比例。
- 最小实现提供常用比例，不做自定义输入。
- 默认比例使用 `16:9`。

## 计划
- [x] 增加 Free、4:3、16:9、1:1、3:2 ratio 选项。
- [x] 将选框创建和 resize 都改为使用当前 ratio。
- [x] 构建验证。

## 审查记录
- snapshot 面板里的单一 `Lock 4:3` 已替换为系统 `Picker` 菜单。
- 当前可选比例为 `Free`、`4:3`、`16:9`、`1:1`、`3:2`，默认是 `16:9`。
- 创建选框和拖动四角 resize 都会使用当前选择的比例。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Snapshot Default Ratio

## 假设
- 用户明确要求默认比例为 `16:9`。
- 旧的 `4:3` 默认不应该继续从本地偏好里继承。

## 计划
- [x] 把 snapshot ratio 默认值改为 `16:9`。
- [x] 构建验证。

## 审查记录
- snapshot ratio 的 `AppStorage` 默认值现在是 `16:9`。
- 使用新的 `snapshotAspectRatioV2` key，避免旧 `4:3` 本地默认值继续生效。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。

# Agent Panel Spec

## 假设
- 采用右侧 inspector-style 第三列。
- Agent 搜索结果只显示在 Agent 面板内，不影响主列表过滤。
- 先复用现有 AI provider，不做 embedding 或向量库。

## 计划
- [x] 确认布局方案。
- [x] 确认搜索结果作用范围。
- [x] 写设计文档。
- [ ] 等用户 review spec 后再写实现计划。

## 审查记录
- 设计文档写入 `docs/superpowers/specs/2026-06-22-agent-panel-design.md`。
- `.superpowers/` 已加入 `.gitignore`，避免 visual companion 临时文件进入提交。

# Thin AgentService Chat Panel

## 假设
- 不引入第三方 Agent 框架。
- 先实现书签搜索工具，不做多工具编排和长期记忆。
- 搜索结果只显示在右侧 Agent 面板，不影响主列表过滤状态。

## 计划
- [x] 给 `AIManager` 暴露通用 chat completion 方法。
- [x] 新增 `AgentService`，包含本地候选预筛、AI JSON 结果解析和 bookmark 映射。
- [x] 新增 `AgentPanelView`，包含消息、输入框、loading、结果卡片。
- [x] 在 `ContentView` toolbar 加 Agent 按钮，并展开右侧第三列。
- [x] 构建验证。

## 审查记录
- `AIManager.complete(prompt:temperature:)` 复用现有 OpenAI-compatible provider。
- `AgentService` 实现书签搜索工具：本地预筛候选、请求 AI 返回 JSON、映射回 bookmark。
- `AgentPanelView` 在右侧 320pt 第三列显示聊天和结果，点击结果打开现有详情窗口。
- `ContentView` 使用系统 toolbar button 展开/收起 Agent 面板，不改主列表过滤状态。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warning。

# Agent Result Count

## 假设
- 用户说 question 太多，指 Agent 面板一次返回的搜索结果太多。
- 最小修复是限制 AI 只选最重要的 5 个书签结果。

## 计划
- [x] 将 Agent 结果数量限制从最多 8 个改为 5 个。
- [x] 构建验证。

## 审查记录
- Agent prompt 现在要求 AI 只选择最相关的 5 个书签。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warning。

# Startup Crash Diagnosis

## 假设
- 启动崩溃发生在 SwiftUI 构建主 `Window` 阶段，不是 Agent 请求阶段。
- crash stack 指向 `ContentView.init(batchParsingService:)` 里的 `@StateObject` 初始化/销毁路径。
- 最小修复是去掉 `ContentView.init` 内手动创建 `StateObject` 的闭包。

## 计划
- [x] 检查 `/Users/caishilin/.venom/logs/Seahorse.log`。
- [x] 检查最新 DiagnosticReports crash report。
- [x] 复现当前 Debug app 启动 crash。
- [x] 简化 `ContentView` 的 `@StateObject` 初始化。
- [x] 构建验证。
- [x] 启动验证。

## 审查记录
- Seahorse log 尾部没有 Swift fatal/error，主要是大量 `CFURLResolveBookmarkData` 和 TCC/XPC 记录。
- 最新 crash report 是 `Seahorse-2026-06-23-112722.ips`，异常为 `EXC_BAD_ACCESS / SIGBUS`，崩溃线程在 `SeahorseApp.body` 创建主 `Window` 时销毁 `ContentView.environmentObject(...)` 链。
- `ContentView` 现在不再在 `init(batchParsingService:)` 里手动构造 `DiagnosticService` 和 `PasteHandler` 的 `StateObject`，改为属性默认初始化。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过。
- 直接启动 Debug app 后运行超过 5 秒，没有生成新的 Seahorse crash report。

# Agent Panel Layout Fix

## 假设
- 截图中的错误来自 `HSplitView` 给 Agent split item 分配了超过 320pt 的宽度。
- 最小修复是让 Agent 面板作为固定宽度 inspector 列，不参与 split 宽度分配。

## 计划
- [x] 将 detail 区域的 Agent 容器从 `HSplitView` 改为 `HStack`。
- [x] 让主内容占剩余宽度，Agent 保持固定 320pt。
- [x] 构建验证。

## 审查记录
- Agent 面板现在跟随右侧边缘显示，不再留下右侧空白 split 区域。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warning。

# Commit And Release

## 假设
- 用户要求先提交当前全部改动，再发布一个新版本。
- 当前版本是 `1.5.1`，需要用户确认目标版本号后再修改版本、打 tag 或发布产物。
- 不执行远端 push 或公开发布，除非用户明确确认。

## 计划
- [x] 检查工作区和版本信息。
- [x] 提交当前改动。
- [x] 确认目标版本号。
- [x] bump 版本并构建验证。
- [x] 生成发布产物并记录结果。
- [x] 创建 release commit/tag。

## 审查记录
- 当前版本是 `1.5.1`，build number 是 `4`。
- 现有 tag 使用 `v` 前缀，最新 tag 是 `v1.5.1`。
- 当前改动的 Debug 构建通过；仅有既有 AppIntents metadata warning。
- 当前功能改动已提交，提交标题为 `Add agent bookmark panel`。
- 用户已确认发布 `1.6.0`，build number 使用 `5`。
- `MARKETING_VERSION` 已更新到 `1.6.0`，`CURRENT_PROJECT_VERSION` 已更新到 `5`。
- Debug 构建通过。
- Release 构建通过；`scripts/create-dmg.sh` 的 `create-dmg` 分支没有生成最终目标 DMG，已使用 `hdiutil` 从同一 Release app 产物手动生成。
- 发布产物：`dist/Seahorse-1.6.0_20260624_213028/Seahorse-1.6.0.dmg`。
- SHA-256：`3e524b5d7527890064b879677f4b37f9a589d3325967b2270a925e41ac40a886`。
- `hdiutil verify` 通过，app 内部版本为 `1.6.0` / `5`。
- release commit 标题为 `Bump version to 1.6.0`，本地 tag 为 `v1.6.0`。

# Build And Install DMG

## 假设
- 当前 HEAD 已经是目标版本 `v1.6.0`，不需要再次 bump 版本号。
- 用户需要一个新的时间戳 DMG，并把同一 Release app 安装到 `/Applications`。
- 使用 `hdiutil` 直接生成 DMG，避免复用已知会在 `create-dmg` 分支失败的脚本路径。

## 计划
- [x] 验证当前版本和工作区状态。
- [x] 执行 Release clean build。
- [x] 生成新的 DMG 和 SHA-256。
- [x] 安装 `Seahorse.app` 到 `/Applications`。
- [x] 验证安装后的 app 版本和签名。

## 审查记录
- 当前 HEAD 是 `v1.6.0`，commit 是 `9297d2f`。
- 当前版本字段是 `MARKETING_VERSION = 1.6.0`，`CURRENT_PROJECT_VERSION = 5`。
- 开始前工作区没有未提交代码改动。
- Release clean build 通过；仅有既有 warnings。
- 新 DMG：`dist/Seahorse-1.6.0_20260625_101255/Seahorse-1.6.0.dmg`。
- SHA-256：`8b6081c75656c62368f7b96f31893561a0854f2777221fac76f6fda3edfd5cc8`。
- `hdiutil verify` 通过，DMG 内 app 版本为 `1.6.0` / `5`。
- 已安装到 `/Applications/Seahorse.app`。
- 安装后的 app 版本为 `1.6.0` / `5`，`codesign --verify --deep --strict` 通过。

# Detail WebView Clears Old Page

## 假设
- 详情窗口继续复用同一个窗口实例。
- 问题来自 bookmark URL 切换时 `WKWebView` 直接复用，旧页面会显示到新页面首帧完成。
- 最小修复是在 bookmark URL 变化时重置 WebView 状态，并让 SwiftUI 为新 URL 创建新的 `WKWebView`。

## 计划
- [x] 定位详情窗口和 WebView 复用路径。
- [x] 修改 WebView URL 切换行为，避免旧页面残留。
- [x] 更新 lessons，记录复用窗口里的 WebView identity 规则。
- [x] 构建验证。

## 审查记录
- 根因：`BookmarkDetailContentView` 保留 `showWebPreview` 状态，`ControllableWebView.updateNSView` 对新 URL 直接 `load`，旧页面会留在同一个 `WKWebView` 中直到新页面渲染。
- `ControllableWebView` 现在使用 `url.absoluteString` 作为 SwiftUI identity，bookmark URL 变化会创建新的 `WKWebView`。
- URL 变化时会清空旧 `webView` 引用、导航按钮状态、loading 状态和 snapshot 状态。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warnings。

# Detail WebView Loads By Default

## 假设
- 用户希望 bookmark 详情页打开后立即加载网页，不需要点击 preview 按钮。
- 旧的 placeholder 和 `showWebPreview` 状态已经不再需要。

## 计划
- [x] 移除 preview placeholder 状态和按钮。
- [x] 让 bookmark 详情页默认直接渲染 WebView。
- [x] 构建验证。

## 审查记录
- `BookmarkDetailContentView` 现在始终显示 `webPreview`。
- 删除了 `showWebPreview` 状态和 `Open Web Preview` placeholder。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warnings。

# Cover Generation Empty Image Fix

## 假设
- UI 的 `Failed to decode image` 来自 image API 返回了空 image data，而不是 NSImage 解码器本身坏了。
- GPT image models 不需要、也不应该发送 `response_format`；DALL-E 仍可请求 `b64_json`。
- 需要兼容返回 URL 的 OpenAI-compatible provider。

## 计划
- [x] 检查日志和 cover generation 调用链。
- [x] 复现空 base64 会变成 0 bytes 的 Swift 行为。
- [x] 修复 image API 请求参数和响应解析。
- [x] 更新 lessons，记录空 base64 和 GPT image response_format 规则。
- [x] 构建验证。

## 审查记录
- 日志显示 `Failed to create NSImage from data (0 bytes)`。
- `Data(base64Encoded: "")` 会返回 0-byte `Data`，现有代码没有拒绝空 base64。
- OpenAI 官方 Images API 文档说明 `response_format` 不支持 GPT image models；GPT image models 总是返回 base64。
- `gpt-image-*` 请求现在不再发送 `response_format`；DALL-E/兼容模型仍请求 `b64_json`。
- image API 响应解析现在拒绝空 `b64_json`，并兼容 provider 返回 URL 的情况。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warnings。

# Bookmark Sync Options

## 假设
- 同步 toolbar 入口需要变成菜单，包含 Chrome 和 Safari 两个选项。
- Chrome 继续使用现有原生 JSON 文件写入逻辑。
- Safari 不直接改 `Bookmarks.plist`，而是导出标准 bookmarks HTML，并打开 Safari 的 HTML 书签导入面板。
- Safari 导入面板需要通过 AppleScript/System Events 触发；如果系统权限阻止，则保留已导出的 HTML 文件并提示用户。

## 计划
- [x] 新增 Safari bookmarks HTML 导出和导入面板打开服务。
- [x] 将 toolbar sync 按钮改为 Chrome/Safari 菜单。
- [x] 增加成功/失败 toast。
- [x] 更新 lessons。
- [x] 构建验证。

## 审查记录
- 新增 `SafariBookmarkSyncService`，导出标准 Netscape bookmarks HTML 到 Downloads。
- Safari 同步会尝试激活 Safari，并通过 System Events 扫描 Safari 菜单里的 HTML 书签导入项。
- toolbar sync 入口从单个按钮改为菜单，包含 `Sync to Chrome` 和 `Export for Safari Import`。
- Chrome 同步继续复用现有 `ChromeBookmarkSyncService`。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warnings。

# Disable Browser Bookmark Sync

## 假设
- 用户点击 sync 后无效果，当前外部浏览器同步不应继续暴露。
- 需要隐藏 sync button，并从主界面注释/断开 Chrome/Safari 同步逻辑。
- DataStorage 内部保存通知不是浏览器同步，不能关闭。

## 计划
- [x] 隐藏 toolbar sync 入口。
- [x] 从 `ContentView` 移除手动 Chrome/Safari 同步 action 和动画状态。
- [x] 移除刚新增的 Safari 同步服务文件。
- [x] 禁用旧的 Chrome 同步服务实现。
- [x] 更新 lessons。
- [ ] 构建验证。

## 审查记录
- toolbar 里原 sync menu 已替换成注释：外部浏览器书签同步暂时禁用。
- `ContentView` 不再引用 `ChromeBookmarkSyncService` 或 `SafariBookmarkSyncService`。
- `SafariBookmarkSyncService.swift` 已移除。
- `ChromeBookmarkSyncService.swift` 通过 `#if false` 整体禁用，避免外部浏览器同步逻辑被编译进 app。

# Delete Browser Bookmark Sync Code

## 假设
- 用户明确要求删除所有 Chrome/Safari 同步代码，不只是隐藏或禁用。
- Seahorse 内部数据保存通知不是浏览器同步，不属于本次删除范围。

## 计划
- [x] 删除 `ChromeBookmarkSyncService.swift`。
- [x] 确认 `SafariBookmarkSyncService.swift` 不存在。
- [x] 清理 `ContentView` 里的 sync UI 残留注释。
- [x] 更新 lessons，记录不要用 `#if false` 替代删除。
- [x] 构建验证。

## 审查记录
- Chrome/Safari 浏览器书签同步代码已从 Seahorse 源码移除。
- `rg` 确认 `ChromeBookmarkSyncService`、`SafariBookmarkSyncService`、sync action 和 sync toolbar 文案在 `Seahorse` 源码中没有残留。
- 宽泛搜索只剩 HTML 书签导入说明和网络请求 User-Agent 中的浏览器名称，不属于浏览器同步逻辑。
- `xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug` 通过；仅有既有 warnings。

# Cloudflare D1 Bookmark Sync Design

## 假设
- Seahorse 负责把本地书签发布到远端数据库，远端 navigation website 只读取这些公开数据。
- 不把 Cloudflare account API token 直接写进 app；优先通过用户自部署 Worker API 写入 D1。
- 第一版只同步 bookmarks/categories/tags/metadata，不同步本地图片文件。
- 用户不需要自己实现 Worker；本任务应包含一个可部署的 Cloudflare Worker + D1 schema。
- 用户希望先创建 bookmark navigation website，再接 Cloudflare/D1 部署和同步。
- 用户真实需求是用 iPhone/其他设备访问自己的 Seahorse 书签，不一定需要公开网站或 Cloudflare。
- 更轻的方案是在 iCloud/备份目录里生成一个自包含 `index.html`，手机直接打开访问。

## 计划
- [x] 检查 Seahorse 当前书签数据模型和存储入口。
- [x] 检查 Cloudflare D1 当前接入方式。
- [ ] 确认 Worker 项目放置位置。
- [ ] 确认远端写入架构。
- [ ] 确认 bookmark website 技术形态和首版数据源。
- [x] 创建单页 HTML 风格选择稿。
- [x] 将选择稿重做为漂亮 gallery card 风格。
- [x] 设计 iCloud backup self-contained bookmark HTML 方案。
- [x] 在 backup/export 目录生成移动端 `index.html`。
- [x] 增加手动同步移动书签页菜单。
- [ ] 提出 2-3 个实现方案并选择推荐方案。
- [ ] 写设计文档并等待 review。

## 审查记录
- `Bookmark` 包含 title、url、icon、categoryId、isFavorite、addedDate、modifiedDate、notes、tagIds、isParsed 和 `WebMetadata`。
- `DataStorage` 已有 bookmarks/categories/tags 的集中访问点，适合构建发布 payload。
- Cloudflare D1 支持 Worker binding 和 REST API；桌面 app 更适合调用自有 Worker API，Worker 再通过 binding 写 D1。
- bookmark website 先做单页 HTML 风格选择稿，不依赖 Cloudflare/D1。
- 已创建 `website/style-selection.html`，包含 Workbench Dense、Gallery Nav、Command Library 三个单页风格。
- `node --check` 验证内联 JS 通过，Chrome headless 已成功渲染首屏截图。
- 根据用户反馈，默认方案已从 Workbench Dense 改为 Native Mac Grid，视觉贴近 Seahorse 当前 macOS 原生 grid view。
- 用户不满意当前视觉，希望参考漂亮的 gallery/card UI library 风格重做。
- `website/style-selection.html` 已重做为 Bento Gallery、Editorial Cards、Resource Pro 三套卡片风格。
- `node --check`、`git diff --check` 通过，Chrome headless 已成功渲染 Bento Gallery 首屏。
- 现有 `ExportImportManager` 已在备份/导出目录写入 `Data/items.json`、`Data/categories.json`、`Data/tags.json`；可在导出目录根部额外生成自包含 `index.html`。
- gallery website 方向已废弃，未保留 `website/style-selection.html`。
- `ExportImportManager` 现在会在 `backupToDataFolder` 和 `exportData` 成功导出 JSON 后，在导出目录根部写入自包含 `index.html`。
- `index.html` 内嵌轻量 bookmark payload，不通过 `fetch` 读取 `Data/*.json`，适合从 iCloud Drive/Files 直接打开。
- 移动 HTML 支持搜索、分类筛选、Favorites 筛选、favicon、标题、域名、描述、分类和标签展示。
- `git diff --check` 通过；HTML 内嵌 JS 抽取后 `node --check` 通过；Debug build 通过，仅有既有 warnings。
- 手动同步菜单应写入稳定路径 `Seahorse_Bookmarks/index.html`，不要每次创建新的时间戳备份目录。
- 主窗口 Tools 菜单已新增 `Sync Mobile Bookmark Page`，点击后更新备份目录下的 `Seahorse_Bookmarks/index.html` 并打开 Finder。
- 新增同步状态 `isSyncingBookmarkIndex`，同步中禁用菜单项并显示 `Syncing Mobile Bookmark Page`。
- `git diff --check` 通过；HTML 内嵌 JS 抽取后 `node --check` 通过；Debug build 通过，仅有既有 warnings。
