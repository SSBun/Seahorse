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
