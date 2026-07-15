# 核心流程分析（业务逻辑）

> 项目：Seahorse
> 生成日期：2026-07-15

## 概览

Seahorse 的主业务是把网页链接、图片和文本快速收进一个本地资料库，再通过分类、标签、收藏、搜索、详情预览和 AI 整理帮助用户找回它们。macOS 是完整工作台：支持窗口内粘贴/拖放、全局双击复制采集、手工表单、批量 AI、链接健康检查、备份和本机 MCP。iOS 分支当前主要用于导入并浏览一份数据副本，不是持续双向同步客户端。

完整用户链路可概括为：

```text
采集 → 类型识别 → 初始保存 → 元数据/AI 增强 → 分类与检索 → 预览/复制/打开 → 更新或永久删除
```

## 核心流程

### 1. 采集并保存资料

1. **触发采集**
   - 触发：用户在主窗口粘贴或拖放，连续两次复制相同内容，或打开新增书签/图片/文本表单。
   - 动作：窗口入口把 `NSItemProvider` 交给 `PasteHandler`；全局双击复制由 `CopyMonitor` 的 CGEvent tap 监听 Cmd+C，等待 0.1 秒后读取系统剪贴板，再复用 `PasteHandler`。
   - 决策点：双击复制需要两次内容相同且间隔小于 0.2—5 秒的配置窗口；缺少辅助功能权限时停用监听并请求授权。
   - 错误处理：无法读取 provider、剪贴板为空或类型不支持时只记录日志，不生成条目。

2. **识别内容类型**
   - 触发：收到一个或多个 provider。
   - 动作：优先拒绝 Seahorse 内部拖拽 UUID，然后依次检查 URL、纯文本、图片。HTTP(S) 普通 URL 识别为 Bookmark，常见图片扩展名识别为 ImageItem；file URL/本地路径仅在扩展名和文件存在性符合时作为图片；其余内容作为 TextItem。
   - 决策点：远程图片只保存 URL；本地图片和剪贴板位图通过 `ImageFileService` 复制/转码到内部 `Images/`。
   - 错误处理：图片复制或 PNG 转换失败时不创建条目；provider 同时暴露纯文本和图片时，纯文本优先。

3. **写入初始条目**
   - 触发：类型识别成功。
   - 动作：普通 URL 先创建标题为 `Loading...` 的 Bookmark；Github 域名进入 `Github` 分类，其余进入 `None`。图片和文本也默认进入 `None`。`DataStorage` 调用 `JSONStorage`，更新内存数组、UUID/搜索缓存和 `itemsVersion`，再异步合并写入 JSON。
   - 决策点：Bookmark URL 先归一化并检查全库唯一；双击复制还会提前检查完全相同的文本或 URL。
   - 错误处理：重复 URL/文本通常被跳过；持久化异常记录日志。通用 `addItem` 不把失败继续抛给 UI，因此用户反馈并不统一。

4. **补全网页元数据**
   - 触发：占位 Bookmark 写入成功，或 MCP 创建书签成功。
   - 动作：`OpenGraphService` 通过共享 `NetworkManager` 拉取标题、描述、封面、站点名和 favicon，随后更新同一 UUID 的 Bookmark。
   - 决策点：成功时使用元数据标题和描述；失败时至少使用 host/URL 作为标题并保留书签。
   - 错误处理：网络、解析或更新失败不回滚已保存的占位条目；粘贴流程会写入基础 fallback。

5. **触发后续反馈与自动处理**
   - 触发：新条目保存后发出 `SeahorseItemAdded`。
   - 动作：状态栏图标可提供摇动反馈，通知服务可发系统通知；启用自动 AI 解析时，`AutoParsingService` 选择最新的未解析 Bookmark 开始处理。
   - 决策点：只有 Bookmark 进入 AI 解析；服务正在处理时会忽略新的 item-added 事件。
   - 错误处理：通知权限或 AI 配置失败不影响原始条目保存。

### 2. 整理、搜索与使用资料

1. **选择范围和筛选条件**
   - 触发：用户选择分类或标签、内容类型、排序方式，或输入搜索词。
   - 动作：macOS 主界面在 300ms debounce 后构造 `CollectionSearch.Criteria`；支持单分类或单标签范围、收藏、四种内容类型以及名称/时间/站点排序。
   - 决策点：`Favorites` 和 `All Bookmarks` 通过分类英文名称解释为特殊范围；多标签条件在共享搜索器中是“命中任意标签”。
   - 错误处理：没有选择分类/标签时返回空列表；无匹配项显示空状态。

2. **执行本地搜索**
   - 触发：筛选条件或 `itemsVersion` 变化。
   - 动作：`DataStorage` 提供已预计算的搜索记录快照，`CollectionSearch` 在 detached task 中扫描。Bookmark 搜索 title/URL/notes，Image 搜索 path/notes，Text 搜索 content/notes，三类都追加标签名。
   - 决策点：结果按所选排序稳定输出；任务被新条件替换时取消旧任务。
   - 错误处理：搜索没有外部依赖；任务取消返回空结果并由更新后的任务覆盖。

3. **查看和修改**
   - 触发：用户从卡片、列表或 Agent 结果打开条目。
   - 动作：单一详情窗口显示网页、图片或 Markdown 文本；用户可编辑内容、分类、标签、收藏和书签元数据，或复制/打开原始内容。修改经 `DataStorage` 更新 JSON 与搜索缓存。
   - 决策点：拖到分类可改变 category；标签可多选；Bookmark 可刷新元数据或生成封面。
   - 错误处理：部分更新入口使用 `try?` 或只记日志，失败提示不一致。

4. **删除**
   - 触发：卡片、列表、详情、诊断结果或 MCP `delete_item`。
   - 动作：条目立即从 JSON 和内存集合移除；内部图片条目还会删除位于受控 `Images/` 目录内的物理文件。
   - 决策点：外部文件、远程 URL 和可能逃逸内部目录的符号链接不会被删。
   - 错误处理：当前没有回收站或撤销；诊断界面明确提示操作不可恢复。

### 3. AI 整理与自然语言查找

1. **解析单个 Bookmark**
   - 触发：自动解析开关、详情/卡片手工命令或批量任务。
   - 动作：先抓网页 HTML 并清洗为最多 4,000 字符，再调用用户配置的 OpenAI 兼容 endpoint 生成精炼标题、摘要、分类、标签和 SF Symbol，并尝试获取 favicon。
   - 决策点：已有分类/标签优先复用；自动服务是否新建分类/标签由设置决定；Github URL 强制进入 Github 分类。
   - 错误处理：网页或 AI 调用失败时保留 `isParsed=false` 并记录错误；不会丢失原始 Bookmark。

2. **批量解析**
   - 触发：用户选择全部未解析或指定 Bookmark。
   - 动作：最多 5 个并发任务抓取和调用 AI，成功结果先在内存收集，任务组结束后通过一次 `updateItems` 提交仍存在的条目。
   - 决策点：失败项不进入批量提交；暂停会取消任务组。
   - 错误处理：单项错误只计为失败并继续；最终批量持久化失败会让所有成功解析结果无法落盘。

3. **Agent 搜索**
   - 触发：用户在右侧 Agent 面板输入自然语言。
   - 动作：本地 token 匹配先从 Bookmark 中选最多 40 个候选，再由 AI 返回最多 5 个 UUID 与理由；点击结果打开详情。
   - 决策点：若本地 token 无命中，则用最新 40 个 Bookmark 作为候选；Image/Text 不参与。
   - 错误处理：AI JSON 解析失败时显示原始回答但无可点击结果；API 异常显示错误消息。

## 次要流程

### 链接健康检查

1. 用户选择全部或部分 Bookmark，`DiagnosticService` 以最多 10 个并发 HEAD 请求扫描。
2. 2xx/3xx 视为可访问，4xx/5xx、无效协议、超时、SSL/DNS/网络异常按原因归类。
3. 用户可筛选并批量永久删除检测结果；状态不写入 Bookmark，因此下次需重新扫描。

### 导入、导出与备份

1. macOS 可从浏览器 HTML 导入 Bookmark，也可把完整 items/categories/tags 与图片导出到带时间戳的文件夹，并生成移动端只读 HTML 索引。
2. 完整导入按分类/标签名称、条目 UUID 和归一化 URL 去重后追加；同名实体的 UUID 引用当前不会重映射。
3. Settings 可在当前存储目录的父目录创建/扫描备份并恢复；界面文案说“替换”，实现路径实际复用合并导入。
4. iOS 仅支持从 ZIP/文件夹导入，再本地浏览、筛选和查看；没有持续 CloudKit/文件变化监听或冲突解决。

### 本机 MCP

1. 用户启用 MCP 后，App 在 127.0.0.1:17374 启动内部 bridge，并启动 Node helper 在 127.0.0.1:17373 暴露 Streamable HTTP MCP。
2. 外部客户端使用独立 bearer token 调用 helper；helper 以内部 token 把动作转发给 App。
3. 工具覆盖 Bookmark 搜索/读取/创建/更新、任意条目删除、Tag 列出/搜索/删除、Category 列出/搜索；真实数据操作仍由 `DataStorage` 完成。
4. helper 启动失败、端口占用或残留进程会映射到状态页；Force Restart 会尝试终止旧实例后重启。

### 图片封面生成

用户对 Bookmark 发起生成任务，AI 图片 endpoint 返回图片后写入内部 Images，再把文件名设为 `metadata.imageURL`。任务有运行/完成/失败状态，应用前会确认对应 Bookmark 仍存在。

### 更新与发布发现

App 通过 GitHub Releases API 比较最新 tag，发现新版本后引导用户打开发布页；不包含 Sparkle 式增量下载或自动安装。

## 后台进程

| 进程 | 计划/触发 | 功能 | 实现 |
|---|---|---|---|
| 剪贴板键盘监听 | App 启动；每次 Cmd+C | 检测双击复制并采集 | `CopyMonitor.startMonitoring/handleCopyEvent` |
| 辅助功能权限检查 | 每 2 秒 | 检测用户从系统设置返回后是否授权 | `CopyMonitor.startPermissionMonitoring` |
| 元数据补全 | 新 Bookmark 保存后 | 异步抓取 OpenGraph/favicons 并更新占位项 | `PasteHandler.fetchAndUpdateBookmark`、MCP bridge |
| 自动 AI 解析 | `SeahorseItemAdded` 通知 | 解析最新未处理 Bookmark | `AutoParsingService.handleItemAdded` |
| JSON 合并写盘 | item 修改后约 250ms | 合并连续 item 写入并原子替换文件 | `JSONStorage.saveItemsToDisk` |
| 系统通知 | 条目新增 | 可选发送本地通知 | `NotificationService` |
| MCP helper/bridge | App 启动且设置启用 | 为本机 agent 暴露工具 | `MCPHelperManager`、`MCPBridgeServer` |
| 退出前强制保存 | App 退出 | 停 helper 并同步落盘全部 JSON | `AppDelegate.applicationShouldTerminate` |

项目没有服务端 cron、消息队列或常驻云 worker。

## 状态机 / 流程转换

```text
条目生命周期
[输入]
  ├─ 无效/重复 ───────────────> [不创建]
  └─ 有效 ─> [已保存, isParsed=false]
                 ├─ 元数据成功 ─> [已丰富, isParsed=false]
                 ├─ 元数据失败 ─> [基础 fallback, isParsed=false]
                 └─ AI 成功 ───> [已整理, isParsed=true]
                                      ├─ 编辑/收藏/换分类 ─> [已更新]
                                      └─ 删除 ───────────> [永久移除]

MCP 生命周期
[Stopped] ─启用/启动─> [Running]
    ├─ 端口占用 ─────> [Port unavailable]
    ├─ 启动异常 ─────> [Failed]
    └─ Force Restart > [Restarting] ─成功/失败─> [Running]/[Failed]
```

## 业务规则

| 规则 | 强制位置 | 说明 |
|---|---|---|
| Bookmark URL 全库唯一 | `DataStorage`、`JSONStorage` | 归一化后比较，新增/更新/批量/导入都检查 |
| 分类与标签名不区分大小写唯一 | `DataStorage`、`JSONStorage` | UI 预检，底层再次验证 |
| 默认分类不可在管理 UI 编辑/删除 | `CategoryManagementView` | 通过四个英文名称识别系统分类 |
| Github 自动分类 | `PasteHandler`、`AutoParsingService` | github.com 及子域进入 Github |
| 双击复制窗口限制 | `CopyMonitor.timeWindow` | 设置值限制为 0.2—5 秒 |
| 本地 MCP 仅 loopback + token | `MCPSettings`、helper/bridge | 固定 127.0.0.1 与两个独立 token |
| MCP 搜索分页上限 | MCP bridge | limit 1—100，offset 非负 |
| 批量读取上限 | MCP bridge | 一次 1—100 个 Bookmark UUID |
| 物理图片删除限制 | `DataStorage.deleteImageFile` | 只删除解析后处于内部 Images 目录的文件 |
| 搜索标签条件 | `CollectionSearch` | 多个 tag UUID 当前是 OR，而不是全部命中 |

## 边界情况与错误流

- 连续复制两张不同图片时，`ClipboardContent` 仍把“图片与图片”视为相等，可能误触发保存第二张。
- 自动 AI 解析正在运行时，新条目的通知会被忽略；任务结束后没有循环清空所有未解析 Bookmark，可能留下等待项。
- 网络元数据失败有 fallback，但 AI Agent、封面生成和部分手工更新的失败提示不统一。
- items JSON 结构性解码失败会导致空库日志；缺少面向用户的恢复入口。异步写盘失败也可能造成 UI 已更新而磁盘未更新。
- 删除没有回收站，来自 UI、批量诊断和 MCP 的误操作不可逆；内部图片还会立即清理物理文件。
- 删除自定义分类只搬移 Bookmark，不搬移 ImageItem/TextItem；导入同名分类/标签也不会重映射 UUID，均可能留下悬空关系。
- 链接诊断只使用 HEAD；拒绝 HEAD 但允许 GET 的站点可能被误判，结果也不持久化。
- iOS 与 macOS 使用相同模型但没有实时同步与冲突策略，README 中“companion/sync”容易让用户形成高于实现的预期。
- MCP helper 随包带 JS 和依赖但不带 Node runtime；终端环境与 Finder PATH 差异可让安装后的 MCP 无法启动。

## 建议

1. 下一版本优先增加“智能集合/保存筛选”，复用现有 `CollectionSearch.Criteria`，把采集后的资料真正变成可持续使用的视图。
2. 所有删除入口统一改为可恢复回收站，再由永久删除清理图片；这是继续开放批量操作和 destructive MCP 的必要护栏。
3. 把粘贴、双击复制、手工新增与 MCP 创建收敛到一个可测试的条目创建流程，统一类型识别、重复处理、反馈和元数据策略。
4. 将自动 AI 解析从“忙时丢事件”改为串行 drain 未解析队列；不需要新增消息队列系统。
5. 在承诺 Share Extension、OCR 或真正跨设备同步前，先加入 schema version/迁移与明确的数据冲突规则。
