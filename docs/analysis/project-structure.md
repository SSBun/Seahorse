# 项目结构分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 概览

Seahorse 是一个单仓库、多运行时项目：主体是由一个 Xcode App target 构建的 SwiftUI 应用，按 Models、Views、Services、Database、Storage、Utilities 分层；仓库内另有一个独立的 TypeScript/Node.js MCP helper，并通过本机 HTTP bridge 与 App 交互。整体属于“分层式模块化单体 + 随 App 打包的辅助进程”，不是多 package 的 monorepo；App target 同时声明 macOS、iPhone 和 iPhone Simulator 平台支持，但现有测试 target 仅支持 macOS。

本次测量得到 `Seahorse/` 内共有 126 个文件，其中 101 个是 Swift 源文件，共 22,906 行；`SeahorseTests/` 有 9 个 Swift 测试文件。`MCPHelper/` 的自有实现和测试只有 5 个 TypeScript 文件，`node_modules/`、`build/`、`dist/`、`Pods/` 等本地生成或依赖目录不计入自有源码规模。

## 目录树

```text
Seahorse/
├── Seahorse.xcodeproj/                    # Xcode 工程；Seahorse、SeahorseTests 两个 target
│   ├── project.pbxproj                    # target、构建设置和 Swift Package 依赖
│   ├── project.xcworkspace/
│   │   └── xcshareddata/swiftpm/          # Package.resolved 依赖锁定文件
│   └── xcshareddata/xcschemes/            # 共享 Seahorse scheme
├── Seahorse/                              # App target：126 个文件、101 个 Swift 文件
│   ├── SeahorseApp.swift                  # macOS/iOS 条件编译的 @main 入口
│   ├── ContentView.swift                  # macOS 主窗口根视图
│   ├── Models/                            # 12 个领域与 UI 状态模型
│   ├── Views/                             # 46 个 SwiftUI/AppKit 视图
│   │   ├── AddItems/                      # 书签、图片、文本与导入入口
│   │   ├── Cards/                         # 卡片呈现
│   │   ├── Components/                    # 通用 UI 组件
│   │   ├── Lists/                         # 集合与列表行
│   │   ├── Management/                    # 侧边栏、分类、标签、图片生成
│   │   ├── Previews/                      # 条目详情、网页和图片预览
│   │   ├── Settings/                      # 基础、AI、MCP、高级设置
│   │   └── iOS/                           # 8 个 iOS 专用视图
│   ├── Services/                          # 25 个服务文件，其中 MCP/ 4 个
│   │   └── MCP/                           # App 内 bridge、helper 生命周期及设置
│   ├── Database/                          # 存储协议、JSON 实现和 Mock（3 个文件）
│   ├── Storage/                           # 响应式数据门面与存储路径（2 个文件）
│   ├── Utilities/                         # 11 个通用辅助文件
│   ├── Assets.xcassets/                   # 20 个 asset 文件
│   ├── Localizable.xcstrings              # String Catalog 本地化资源
│   ├── Info.plist                         # App Info 配置
│   └── Seahorse.entitlements              # 沙箱、文件、网络和输入监听权限
├── SeahorseTests/                         # 9 个 macOS XCTest 文件
├── MCPHelper/                             # TypeScript MCP 辅助进程
│   ├── src/                               # 3 个实现文件：入口、bridge client、工具注册
│   ├── tests/                             # 2 个 Vitest 文件
│   ├── dist/                              # 3 个本地编译产物，未跟踪
│   ├── node_modules/                      # 4,358 个本地依赖文件，未跟踪
│   ├── package.json                       # npm 元数据、脚本和依赖
│   └── tsconfig.json                      # TypeScript 编译设置
├── scripts/                               # MCP 构建、DMG 打包、MCP 冒烟脚本（3 个）
├── docs/                                  # Jekyll 站点、分析、规格和实施计划
│   ├── analysis/                          # 项目分析报告
│   ├── superpowers/                       # 功能规格与实施计划
│   ├── _layouts/                          # Jekyll 页面布局
│   ├── index.html                         # 文档站入口
│   ├── Gemfile                            # Jekyll Ruby 依赖
│   └── _config.yml                        # GitHub Pages/Jekyll 配置
├── .github/workflows/                     # DMG 发布与 Pages 部署工作流（2 个）
├── tasks/                                 # 工作区事实、任务历史和复用教训
├── build/                                 # 7,404 个本地 Xcode 构建文件，未跟踪
├── dist/                                  # 5,686 个本地发布制品文件，未跟踪
├── Pods/                                  # 47 个本地依赖残留文件，未跟踪
├── generate_app_icon.py                   # App 图标生成工具
├── install_latest.sh                      # 本地安装最新 DMG 的运维脚本
└── README*.md、CHANGELOG.md、RELEASE.md    # 用户、变更和发布文档
```

## 入口点

| 入口点 | 路径 | 说明 |
|---|---|---|
| Seahorse App | `Seahorse/SeahorseApp.swift` | 唯一 App 源入口；文件内用 `#if os(macOS)` / `#elseif os(iOS)` 定义两个互斥的 `@main`。macOS 建立主窗口、详情窗口和 Settings，iOS 建立 `WindowGroup`。 |
| macOS 根界面 | `Seahorse/ContentView.swift` | `SeahorseApp` 主窗口加载的 macOS UI 根节点。 |
| iOS 根界面 | `Seahorse/Views/iOS/iOSContentView.swift` | iOS 分支 `WindowGroup` 加载的 UI 根节点。 |
| MCP helper | `MCPHelper/src/index.ts` | 带 Node shebang 的可执行入口；启动仅监听 `127.0.0.1` 的 Streamable HTTP MCP server，并转发到 App bridge。 |
| 文档站 | `docs/index.html` | Jekyll/GitHub Pages 网站入口。 |
| MCP 构建 | `scripts/build-mcp-helper.sh` | 安装生产依赖并编译 TypeScript helper。 |
| DMG 打包 | `scripts/create-dmg.sh` | Release 构建、嵌入 MCP helper 并生成 DMG 的发布入口。 |
| MCP 冒烟验证 | `scripts/smoke-mcp.sh` | 对本地 MCP 服务执行初始化和基础工具验证。 |
| 本地安装 | `install_latest.sh` | 查找并安装最新本地 DMG。 |
| App 图标生成 | `generate_app_icon.py` | 从源图片生成 AppIcon 尺寸资源。 |
| Release CI | `.github/workflows/build.yml` | tag 或手动触发，构建 DMG、上传 artifact，并在 tag 场景创建 GitHub Release。 |
| Pages CI | `.github/workflows/jekyll.yml` | `main` 分支或手动触发，构建并部署 `docs/` Jekyll 站点。 |

## 模块边界

App 主体采用按技术层分区、在 View 层再按功能分组的混合策略：

- `Models/` 定义 Bookmark、ImageItem、TextItem、Category、Tag、统一条目封装及设置状态，是领域数据边界。
- `Database/` 定义 `DatabaseProtocol`、JSON 持久化实现和测试用 Mock；`Storage/` 的 `DataStorage` 则是面向 UI/服务的 `@MainActor ObservableObject` 数据门面，`StorageManager` 管理数据、图片和备份目录。
- `Services/` 承担抓取、AI、剪贴板、解析、导入导出、图片文件、通知、启动、排序等业务与系统集成；MCP 相关能力进一步放入 `Services/MCP/`。
- `Views/` 以展示职责分为 AddItems、Cards、Components、Lists、Management、Previews、Settings，并以 `Views/iOS/` 隔离 iOS 专用界面；macOS 视图与共享视图没有对应的显式平台目录。
- `Utilities/` 放置日志、本地化、窗口桥接、URL 归一化、更新、SF Symbols 等横切辅助能力。
- `MCPHelper/` 是清晰的进程边界：TypeScript helper 不直接访问 JSON 数据，真实 CRUD 经 App 内 `Services/MCP/` 和 `DataStorage` 完成。
- `SeahorseTests/` 是单一、扁平的 macOS 测试 target，覆盖搜索、JSON、图片、MCP helper 管理和性能基线；没有独立 iOS 测试 target。

## 关键目录

以下数字由 `find` 测量；生成目录单独注明，自有源码统计不包含依赖目录。

| 目录 | 用途 | 大小（文件） |
|---|---|---:|
| `Seahorse/` | App target 源码与资源 | 126（101 个 Swift） |
| `Seahorse/Models/` | 领域模型、排序及设置模型 | 12 |
| `Seahorse/Views/` | macOS、共享及 iOS UI | 46 |
| `Seahorse/Services/` | 业务逻辑与系统集成 | 25（含 `MCP/` 4 个） |
| `Seahorse/Database/` | 持久化接口、JSON 实现、Mock | 3 |
| `Seahorse/Storage/` | 数据状态门面与存储路径 | 2 |
| `Seahorse/Utilities/` | 横切辅助能力 | 11 |
| `Seahorse/Assets.xcassets/` | App 图标、Accent Color 与图片资源 | 20 |
| `SeahorseTests/` | macOS XCTest | 9 |
| `MCPHelper/src/` | MCP helper 实现 | 3 |
| `MCPHelper/tests/` | MCP helper Vitest | 2 |
| `scripts/` | 构建、打包、冒烟验证 | 3 |
| `docs/` | 文档站、分析、规格与计划 | 19 个分析开始时已跟踪文件（不含 Jekyll 缓存/站点产物） |
| `.github/` | GitHub Actions | 2 |
| `MCPHelper/node_modules/` | 本地 Node 依赖，未跟踪 | 4,358 |
| `build/` | 本地 Xcode 构建产物，未跟踪 | 7,404 |
| `dist/` | 本地 DMG 与 App 发布产物，未跟踪 | 5,686 |
| `Pods/` | 本地未跟踪依赖目录 | 47 |

## 配置文件

| 文件 | 用途 |
|---|---|
| `Seahorse.xcodeproj/project.pbxproj` | 定义 Seahorse 与 SeahorseTests target、Debug/Release 设置、版本号、支持平台及 OpenAI、Kingfisher、Highlightr、ZipArchive 四个直接 Swift Package 依赖。 |
| `Seahorse.xcodeproj/xcshareddata/xcschemes/Seahorse.xcscheme` | 共享 build、test、run、profile、archive 流程。 |
| `Seahorse.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | 锁定直接和传递 Swift Package 版本。 |
| `Seahorse/Info.plist` | 声明 App Transport Security 与启动屏配置。 |
| `Seahorse/Seahorse.entitlements` | 声明输入监听、security-scoped bookmark、用户文件访问及网络 client/server 权限。 |
| `Seahorse/Localizable.xcstrings` | Xcode String Catalog，本地化字符串的 source of truth。 |
| `Seahorse/Assets.xcassets/**/Contents.json` | Xcode asset catalog 清单。 |
| `MCPHelper/package.json` | 声明私有 Node package、bin 入口、build/test/dev 脚本及 MCP SDK、Zod 等依赖。 |
| `MCPHelper/package-lock.json` | 锁定 Node 依赖树。 |
| `MCPHelper/tsconfig.json` | 启用 strict、NodeNext、ES2022，并将 `src/` 编译到 `dist/`。 |
| `.github/workflows/build.yml` | tag/手动发布 DMG 的 CI 配置。 |
| `.github/workflows/jekyll.yml` | GitHub Pages 构建与部署配置。 |
| `docs/Gemfile` | 锁定 Jekyll `~> 4.4` 文档站依赖范围。 |
| `docs/_config.yml` | Jekyll 站点标题、URL、baseurl、Markdown 引擎和排除项。 |
| `.gitignore` | 排除 Xcode、SwiftPM、Node、DMG、构建和发布产物。 |
| `AGENTS.md` | 仓库内代理工程规则和项目开发约定，不参与 App 运行。 |
| `.claude/settings.local.json` | 本机代理工具设置，不参与 App 运行。 |

## 显著模式

- **单 App target**：101 个 Swift 源文件全部归入 Seahorse target，没有内部 Swift Package 或 framework；模块边界主要依赖目录和类型可见性维持。
- **MVVM 风格的集中式数据流**：视图通过共享的 `DataStorage` 观察数据；数据库协议与 JSON 实现位于底层，服务在其上组合业务流程。
- **双平台条件编译**：同一个 `SeahorseApp.swift` 为 macOS/iOS 提供互斥入口；iOS UI 有专属目录，共享模型和服务继续复用同一 target。
- **辅助进程 sidecar**：MCP helper 拥有独立 Node 工具链、测试与 HTTP 入口，但不形成独立发布物，而是在 DMG 流程中嵌入 App bundle。
- **混合依赖管理**：App 使用 Swift Package Manager，helper 使用 npm，文档站使用 Bundler；本地存在 `Pods/`，但当前 Xcode 工程没有 Pods 引用，仓库也没有 Podfile。
- **测试按 target 平铺**：Swift 测试集中在 `SeahorseTests/`，TypeScript 测试集中在 `MCPHelper/tests/`；当前没有按 App 目录镜像测试结构。
- **文档与代码同仓**：产品文档、发布文档、分析、规格、实施计划和 Jekyll 网站均在仓库中维护。

## 潜在问题

1. **大文件形成明显维护热点。** 101 个 Swift 文件中有 12 个达到或超过 500 行，共 9,357 行；最大的是 `Utilities/SFSymbolManager.swift`（1,871 行），其次是 `Views/Previews/ItemDetailView.swift`（943 行）、`Services/ExportImportManager.swift`（917 行）和 `Views/AddItems/AddBookmarkView.swift`（915 行）。这不自动意味着需要拆分，但下一版本若继续修改这些文件，应先确认能否沿现有职责拆出真实边界，避免仅按行数机械拆文件。

2. **`Services/` 顶层职责较宽。** 25 个文件中有 21 个直接放在 `Services/` 根目录，覆盖 AI、剪贴板、解析、网络、导入导出、图片、通知、启动和状态栏；只有 MCP 被分出子目录。新增功能若同时跨多个服务，定位和依赖方向会继续变模糊，届时应优先按已经稳定的功能域移动，而不是预先搭建抽象层。

3. **持久化命名边界需要额外理解。** `Database/` 负责协议和 JSON 实现，`Storage/` 同时包含响应式数据门面与文件目录管理；两个目录名称语义接近。当前调用链可辨认，但新存储能力容易被放错层，建议以“Database = 数据读写实现、Storage = App 状态门面和路径”作为明确约定。

4. **平台目录不对称。** iOS 专用界面集中在 `Views/iOS/`，macOS 与共享界面则混在 `Views/` 各功能目录；同时测试 target 仅支持 macOS。下一版本若增加 iOS 功能，必须验证哪些 Services/Utilities 真正跨平台，并补足 iOS 构建或测试证据，不能以 macOS 测试通过代替双平台验证。

5. **部分 View 文件未遵循现有子目录边界。** `Views/BookmarkCardView.swift` 位于根目录，但同层已有 `Views/Cards/`；`Views/AgentPanelView.swift` 也位于根目录。它们可能有合理的组合层职责，但会让“根视图、功能页还是可复用组件”的放置规则不清晰。只有在相关文件再次发生功能性修改时再顺手归位，单独重排没有产品收益。

6. **本地残留和仓库根文件会干扰扫描。** 本地有未跟踪的 `build/`、`dist/`、`MCPHelper/node_modules/`、`Pods/` 等 17,495 个文件；`.gitignore` 已覆盖主要生成目录，但 `Pods/` 没有 Podfile，也没有 Xcode 工程引用。仓库还跟踪了 `build.log` 和 `build_verify.log` 两个历史构建日志。它们不影响当前构建，却容易让工具和维护者误判依赖或项目状态；无需为下一功能专门处理，但可在后续仓库卫生任务中确认后清理。

7. **单 target 的编译边界较弱。** 当前所有 App 源码共享同一 target，目录并不会强制依赖方向。以 22,906 行规模仍可工作；只有当增量构建、多人并行修改或循环依赖出现可测问题时，才值得考虑内部 Swift Package/framework，当前不应为“可能扩展”提前模块化。
