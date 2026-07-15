# 构建与部署分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 构建系统

| Aspect | Detail |
|--------|--------|
| Build tool | 主应用使用 Xcode / `xcodebuild` 与 Swift Package Manager；MCP Helper 使用 npm + TypeScript (`tsc`)；文档站使用 Bundler + Jekyll；DMG 使用仓库脚本串联 `xcodebuild`、`create-dmg`/`hdiutil` 和 `codesign` |
| Language version | Swift 5.0；TypeScript 5.9、输出 ES2022/NodeNext；Node 运行依赖最低为 18；Vitest 4 测试要求 Node 20、22 或 24+；文档 CI 使用 Ruby 3.3 |
| Build config | `Seahorse.xcodeproj/project.pbxproj`、`Seahorse.xcodeproj/xcshareddata/xcschemes/Seahorse.xcscheme`、`Seahorse.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`、`MCPHelper/package.json`、`MCPHelper/package-lock.json`、`MCPHelper/tsconfig.json`、`docs/Gemfile`、`docs/_config.yml` |
| Build targets | Seahorse App：Debug、Release、Archive、Analyze；`SeahorseTests`：Debug/Release 测试；MCP Helper：`dev`、`build`、`test`；发布：带 Helper 的 `.app`、DMG、SHA256；文档：Jekyll `_site` |

主 App 是一个同时声明 `macosx`、`iphoneos` 和 `iphonesimulator` 的多平台 target，当前版本为 `1.9.0 (8)`。共享 scheme 的默认运行目标是 App，测试动作包含 `SeahorseTests`，归档使用 Release 配置。Swift 依赖由 Xcode 的 `Package.resolved` 固定，包括 OpenAI、Kingfisher、Highlightr 和 ZipArchive 及其传递依赖。

当前工作区存在未纳入版本控制或 Xcode 工程依赖图的本地 `Pods/` 内容，但项目没有 `Podfile` 或 `Podfile.lock`，因此 CocoaPods 不是可复现构建链的一部分，不应作为环境前置条件。

## 构建步骤

### 本地开发构建

1. 在 `MCPHelper/` 安装 lockfile 依赖并运行 `npm run build`，生成 `MCPHelper/dist/index.js`。主 App 的普通 Xcode 构建不会自行执行这一步；开发态 `MCPHelperManager` 会回退查找仓库里的该文件。
2. 打开 `Seahorse.xcodeproj`，让 Xcode 按 `Package.resolved` 解析 Swift Package Manager 依赖。
3. 使用共享 `Seahorse` scheme 构建或运行 Debug App；macOS 为默认桌面开发路径，iOS 由同一个跨平台 target 条件编译。
4. 使用 scheme 的 Test action 运行 `SeahorseTests`；Helper 测试独立通过 `npm test` 运行。

### Release App 与 DMG

1. `scripts/create-dmg.sh <version>` 首先调用 `scripts/build-mcp-helper.sh`；后者当前执行 `npm install` 和 `npm run build`。
2. 脚本以 `xcodebuild -scheme Seahorse -configuration Release -destination 'platform=macOS' -derivedDataPath build clean build` 构建 App；`NO_SIGN=1` 时显式关闭签名。
3. 脚本把 Helper 的 `package.json`、`package-lock.json`、`dist/` 和通过 `npm ci --omit=dev --ignore-scripts` 安装的生产依赖写入 `Seahorse.app/Contents/Resources/MCPHelper/`。
4. 非 `NO_SIGN=1` 路径从刚构建的 App 读取现有签名身份，在修改 bundle 后重新签名 App，并执行 `codesign --verify --deep --strict`。
5. App 被复制到 `dist/Seahorse-<version>_<timestamp>/`；脚本优先使用可选的 `create-dmg`，否则回退到 macOS 自带的 `hdiutil`。
6. 最终产物为上述目录内的 `Seahorse-<version>.dmg` 与同目录 SHA256 文件。

### 文档站

1. 在 `docs/` 使用 Bundler 安装 Jekyll 4.4。
2. 执行 `bundle exec jekyll build`，生成 `docs/_site`。
3. GitHub Pages workflow 上传 `_site` 并部署到 `https://ssbun.github.io/Seahorse` 对应的 Pages 环境。

## 环境要求

| Requirement | Value | Required? |
|------------|-------|----------|
| 主机系统 | macOS；DMG 打包依赖 `xcodebuild`、`codesign`、`hdiutil` 等 macOS 工具 | 是 |
| App 最低系统 | 工程实际 `MACOSX_DEPLOYMENT_TARGET = 15.2`；README、RELEASE 和官网仍宣称 macOS 13.0+，两者冲突 | 是 |
| iOS 最低系统 | `IPHONEOS_DEPLOYMENT_TARGET = 16.0` | 仅 iOS 构建 |
| Xcode | 工程格式 `objectVersion = 77`，scheme 标记 `LastUpgradeVersion = 2620`；仓库未固定本地 Xcode 版本，CI 使用 `latest-stable` | 是 |
| Swift | `SWIFT_VERSION = 5.0` | 是 |
| Node.js | Helper 运行依赖 Node 18+；完整开发/测试建议 Node 20、22 或 24+，因为 Vitest 4 不支持 Node 18 | Helper 必需 |
| npm | lockfile v3；负责 Helper 构建、测试和生产依赖裁剪 | Helper 必需 |
| Ruby / Bundler | CI 固定 Ruby 3.3，Jekyll `~> 4.4`；仓库没有 `Gemfile.lock` | 仅文档构建 |
| `create-dmg` | 可选；缺失时脚本使用 `hdiutil`，Homebrew 安装命令仅用于获得定制 DMG 布局 | 否 |
| Apple 签名资产 | 工程采用 Automatic Signing、Team `2795FFTPWT` 和 Hardened Runtime；公开分发还需要 Developer ID Application 证书及 notarization 凭据 | 本地无签名构建否；可信分发是 |
| AI API 配置 | 无构建期环境变量；API endpoint/token 由用户在 App 内配置 | 否 |
| MCP 环境变量 | `SEAHORSE_MCP_TOKEN`、`SEAHORSE_BRIDGE_TOKEN` 由 App 启动 Helper 时注入；bridge URL 和端口亦由 App 设置 | 运行 MCP 时由 App 自动提供 |

仓库没有 `.env.example`，构建不依赖手工配置的环境文件，也未在所检查配置中发现硬编码发布秘密。GitHub Release 使用平台注入的 `GITHUB_TOKEN`。

### MCP Helper 的分发边界

DMG 脚本会打包编译后的 Helper 和 production-only npm 依赖，但不会打包 Node 可执行文件。App 通过 `/usr/bin/env node <bundled-index.js>` 启动 Helper，因此最终用户机器仍须安装兼容 Node，且从 Finder 启动 App 时继承的 `PATH` 必须能找到它。README 和安装脚本当前均未声明这一要求；这会让“App 安装成功但 MCP 无法启动”成为静默环境差异。

Helper 不接受用户手工维护的 `.env`：App 在运行时生成外部/内部 token，将它们和 `127.0.0.1:17373/17374` 配置注入子进程。服务只监听 loopback，`scripts/smoke-mcp.sh` 需要显式传入外部 token 才能执行协议冒烟检查。

## CI/CD 流水线

当前检测到两条 GitHub Actions 流水线。

| Stage | Trigger | Actions |
|-------|---------|---------|
| macOS Build and Release | push `v*` tag，或带 `version` 输入的手工 `workflow_dispatch` | `macos-14` runner；选择 `latest-stable` Xcode；安装 `create-dmg`；以 `NO_SIGN=1` 调用 DMG 脚本；计划上传 DMG/SHA256；tag 构建计划创建 GitHub Release |
| Jekyll Build | push `main`，或手工触发 | Ubuntu runner；Ruby 3.3；安装 Gem；构建 `docs/_site`；上传 Pages artifact |
| GitHub Pages Deploy | Jekyll Build 成功后 | 部署到受保护的 `github-pages` environment，暴露 Pages URL |

现有 CI/CD 有以下静态可证实的缺口：

1. `scripts/create-dmg.sh` 把 DMG 和校验文件写入 `dist/Seahorse-<version>_<timestamp>/`，但 `.github/workflows/build.yml` 的 artifact 和 Release 步骤只匹配仓库根目录的 `Seahorse-*.dmg` / `Seahorse-*.dmg.sha256`。当前 glob 无法命中脚本产物，因此自动 artifact 和 tag Release 附件链路不闭合。
2. Release workflow 没有运行 `SeahorseTests`、Helper 的 `npm test`、DMG 挂载验证、App 启动检查或 MCP 冒烟测试；“构建成功”是发布的唯一质量门禁。
3. CI 使用 `NO_SIGN=1`，没有 Developer ID 签名、DMG 签名、`notarytool` notarization 或 staple。即使修复上传路径，产物也不是可直接通过 Gatekeeper 的可信公开分发包。
4. workflow 没有固定 Node 版本，Helper 自身也未声明 `engines`；`scripts/build-mcp-helper.sh` 使用 `npm install` 而非 lockfile 严格安装，降低了发布构建的可重复性。
5. App target 支持 iOS，但没有 iOS 构建、测试、Archive 或 App Store/TestFlight 部署流水线。
6. `RELEASE.md` 描述手工 GitHub Release，而 workflow 描述 tag 自动发布；发布流程存在双重事实来源。

## 部署

| Aspect | Detail |
|--------|--------|
| Platform | macOS App 计划通过 GitHub Releases 的 DMG 分发；官网通过 GitHub Pages；iOS 暂无部署配置 |
| Strategy | 版本 tag 对应不可变 DMG，`install_latest.sh` 和 App 内 `UpdateManager` 均读取 GitHub latest release；没有服务器端滚动、蓝绿或金丝雀部署 |
| Config management | GitHub Actions workflow、`scripts/create-dmg.sh`、Xcode build settings、GitHub Pages environment；App 版本 source of truth 为 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |
| Container image | No containerization detected. 没有 Dockerfile、Compose、Kubernetes、serverless 或 PaaS 配置，桌面 App 与静态站点也不需要容器化 |

当前公开更新机制不是 Sparkle appcast：`UpdateManager` 调用 GitHub Releases API 比较版本并打开 Release 页面，`install_latest.sh` 同样从 GitHub latest release 选择 DMG。仓库中没有 `appcast.xml`、Sparkle feed key 或自动安装更新配置。

签名方面，工程启用了 Hardened Runtime 和 Automatic Signing，但未锁定 Developer ID Application 身份；打包脚本只复用 Xcode 构建产物的现有身份，且设置 `--timestamp=none`。最近一次本地发布记录显示产物为 Apple Development 签名、未 notarize。这适合本地验证，不等同于面向普通用户的发行签名。

## 本地开发设置

1. 安装能够打开当前工程格式的 Xcode，并确保命令行工具可用；使用 Xcode 自动解析已固定的 Swift Package Manager 依赖。
2. 安装 Node 20、22 或 24+ 与 npm；该范围同时覆盖 Helper 运行、TypeScript 编译和 Vitest 4 测试。
3. 在 `MCPHelper/` 按 lockfile 安装依赖，运行 `npm test` 和 `npm run build`。若不使用 MCP，可只构建 App；启用 MCP 前必须存在 `MCPHelper/dist/index.js`。
4. 打开 `Seahorse.xcodeproj`，选择共享 `Seahorse` scheme 和 macOS destination，运行 Debug；使用同一 scheme 的 Test action 验证 `SeahorseTests`。
5. 需要本地 Release DMG 时，从仓库根目录执行 `scripts/create-dmg.sh <version>`。有有效签名身份时使用默认路径；只做本机无签名验证时可设置 `NO_SIGN=1`。产物位于带时间戳的 `dist/` 子目录。
6. 需要预览官网时安装 Ruby/Bundler，在 `docs/` 安装 Jekyll 依赖并运行 Jekyll 本地服务或构建命令。

无需容器、数据库服务或 `.env` 文件。AI 能力需要用户运行后提供自己的 API 配置；MCP token 由 App 管理。

## 建议

1. **P0：先修复现有发布链，不另造发布系统。** 让 workflow 上传 `dist/**/Seahorse-*.dmg*`，或让脚本输出稳定产物路径；在创建 Release 前加入 Helper 测试、Swift 测试、DMG 校验、bundle 内 Helper 依赖检查和最小 MCP 冒烟。这样现有 tag 工作流才真正交付可验证附件。
2. **P0：完成 macOS 可信分发。** 在受保护的 Release job 中使用 Developer ID Application 签名，签名修改后的 App 和 DMG，提交 Apple notarization、staple，并在干净用户环境验证 Gatekeeper。发布凭据只放 GitHub encrypted secrets/environment，不写入仓库。
3. **P0：消除 MCP 的隐式 Node 前置条件。** 下一版本若继续把 MCP 作为正式功能，应随 App 提供受支持的 Node runtime/自包含 Helper；若暂不这样做，至少在启动前检测 Node 版本和可执行路径，并在设置页给出可操作错误与安装说明。仅打包 JS 和 `node_modules` 还不是自包含功能。
4. **P1：统一并固定构建环境。** 明确支持的 Xcode/runner 组合，CI 显式设置 Node 版本，在 Helper `package.json` 声明 `engines`，发布构建改用 `npm ci`；文档站提交 `Gemfile.lock`。不要继续依赖 runner 的偶然预装版本。
5. **P1：解决系统版本声明冲突。** 当前二进制目标是 macOS 15.2，而 README、RELEASE 和官网承诺 13.0+。若产品确实要支持 13，应降低 deployment target 并加入 macOS 13/当前系统验证；否则把所有用户文档统一为 15.2+，避免下载后无法启动。
6. **P1：合并发布事实来源。** 让 `RELEASE.md` 直接描述 tag workflow、版本号、签名/notarization 和产物路径；删除与自动流程冲突的手工步骤。App、安装脚本和官网都依赖 GitHub latest release，发布失败会同时破坏下载和更新检查。
7. **P2：iOS 流水线按真实发布计划再加。** 若下一版本要交付 iOS companion，应增加 iOS build/test/archive 和 TestFlight/App Store 配置；若仍只发布 macOS，则保持现状并不要提前搭建闲置流水线。
