# 集成 Sparkle 2 自动更新

## 状态

- 已完成（2026-07-21）

## 目标

- 通过现有 Swift Package Manager 为 macOS 集成 Sparkle 2.9.4，不影响共用 target 的 iOS 构建。
- 设置页的更新按钮使用 Sparkle 标准流程检查、下载、验签、退出替换并重启 App。
- 使用 GitHub Pages `appcast.xml` 和 EdDSA 签名建立可验证的更新 feed。

## 边界

- 不保留自制 App 替换逻辑，不新增第二套依赖管理器。
- 仅 Sparkle 使用 macOS 平台过滤；iOS 不链接或导入 Sparkle。
- 本任务不升级 Seahorse 版本，不创建 tag、GitHub Release，也不执行 npm publish。
- Developer ID 与 notarization 仍是正式可信分发的独立发布要求，本任务不伪称已完成。

## 计划

- [x] 确认当前更新行为、依赖管理和多平台 target 约束。
- [x] 添加 macOS-only Sparkle SPM 依赖与更新控制器。
- [x] 接入设置页标准更新流程。
- [x] 生成 EdDSA 公钥并建立 appcast feed。
- [x] 运行 macOS/iOS 构建、测试与 feed 验证。
- [x] 完成独立对抗式审查并处理全部问题。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: `sparkle_reviewer`
- Round: RE-REVIEW (4)
- Scope: Sparkle SPM 集成、macOS 更新控制器、设置页入口、Info.plist、签名 appcast、发布脚本与文档、iOS 平台过滤及 1.12.0 最终差异
- Summary: 修正 package product 的 iOS 平台过滤后，新鲜双平台构建与最终完整差异获 Reviewer 批准。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/integrate-sparkle-updates.md)

## 结果与验证

- Sparkle 2.9.4 已通过 SPM 锁定；macOS App 包含 Sparkle framework、feed URL 与 EdDSA 公钥，iOS App 不包含也不链接 Sparkle。
- 设置页按钮调用 Sparkle 标准流程；Updater 在 App 初始化时启动，因此定时检查不依赖打开设置页。
- 本机 Keychain 的 `Seahorse` account 保存私钥；`docs/appcast.xml` 对 1.11.0 DMG 的 EdDSA 签名已通过 `sign_update --verify`，公开 DMG URL 返回 HTTP 200。
- `scripts/generate-appcast.sh` 已用新的 Apple-signed App 打包成测试 DMG，成功生成带 `sparkle:edSignature` 的 feed 并通过验签。
- 发布脚本在默认快路径缺失时会从 Xcode 实际 `BUILD_DIR` 推导 Sparkle 工具路径；未设置 `SPARKLE_BIN` 的文档命令已通过复验。
- Jekyll 在隔离副本中成功构建，输出站点包含可通过 `xmllint` 的 `appcast.xml`。
- macOS Debug、iOS Simulator Debug 构建通过；macOS 测试 77/77 通过；`plutil`、`xmllint` 与 `git diff --check` 通过。现有 Swift 6 与 asset warning 未由本任务引入。
- 首个带 Sparkle 的版本仍需手动安装一次；正式自动更新 DMG 必须使用 Developer ID 签名并完成 notarization，现有 CI 的 `NO_SIGN=1` 产物不能作为自动更新包。
- 新鲜 iOS Simulator 构建验证 `platformFilters = (macos)` 会完整排除 Sparkle product；旧的单数 `platformFilter` 仅阻止嵌入，仍会错误解析 macOS-only XCFramework。
