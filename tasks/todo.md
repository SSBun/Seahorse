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
