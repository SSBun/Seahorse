# 发布下一个次版本

Status: In Progress (2026-08-27 11:51)
Kind: Task

## Scope

- 包含当前 `main` 上尚未推送的拖拽分类功能，以及 `1.15.0 (15)` 的版本元数据、CHANGELOG、GitHub Release、Sparkle appcast 与 `@ssbun/seahorse` npm wrapper。
- 不包含额外功能、App Store、Homebrew 或自动覆盖 `/Applications` 中的现有 App。

## Target
- [ ] T1: `1.15.0 (15)` 通过 GitHub Release 与 npm 发布，版本号、`v1.15.0` 标签和可安装 macOS DMG 一致。
- [ ] T2: 公开 Sparkle appcast 包含 `1.15.0 (15)`，且 URL、长度、EdDSA 签名和远端 DMG 校验一致。
- [ ] T3: 发布所需变更、`main` 与 `v1.15.0` 已推送，最终本地工作区无未提交变更。

## Plan

1. 同步 Xcode、npm 与 CHANGELOG 的 `1.15.0 (15)` 发布元数据。
2. 构建并验证最终 Release App、DMG、checksum、Sparkle appcast 与 npm dry-run。
3. 列出签名限制、测试项和全部远程命令，取得明确确认。
4. 按标签、GitHub Release、远端资产验证、`main`/appcast、npm 的安全顺序发布。
5. 复核公网版本与仓库状态并完成发布记录。

## Decisions

- Xcode target 的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 是 App 版本 source of truth；npm manifest、lockfile 与 CHANGELOG 同步更新。
- 本机没有 Developer ID Application identity；远程发布前必须明确说明 Apple Development 签名与未 notarize 限制并取得接受。
- 单元测试与项目测试套件只有在用户明确授权具体命令后运行；Release build、artifact 与 dry-run 验证仍按 SOP 执行。
- 用户已明确授权运行完整 macOS `xcodebuild test`，并接受本次继续使用 Apple Development、`get-task-allow=true`、未 notarize、现有编译警告及 MCP Helper 的 2 个 High/2 个 Moderate 间接依赖漏洞。
