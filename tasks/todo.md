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
