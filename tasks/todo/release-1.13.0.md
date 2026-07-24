# 发布 Seahorse 1.13.0

Status: Completed (2026-07-24 14:58)

## Scope

- 包含：当前工作区的列表性能监控、系统代理与滚动图片修复、重复书签更新时间功能，以及本地领先 `origin/main` 的两个文档提交。
- 包含：签名 DMG、SHA256、GitHub Release、Sparkle appcast 与 `@ssbun/seahorse` npm wrapper。
- 不包含：notarization、App Store、Homebrew、自动覆盖 `/Applications` 中的现有 App。

## Target

- [x] T1：Xcode、npm 与 CHANGELOG 统一为 `1.13.0`，build number 为 `13`，发布说明覆盖本轮用户可见改动。
- [x] T2：macOS 全量测试、iOS Simulator 构建、Release App、helper、签名 DMG、挂载读取与 SHA256 验证全部通过。
- [x] T3：最终发布差异通过独立对抗式审查，且没有未解决的阻断问题。
- [x] T4：`main` 与 `v1.13.0` 推送到 `origin`，公开 GitHub Release 提供可下载且摘要一致的 DMG 与 SHA256。
- [x] T5：公开 Sparkle appcast 提供 `1.13.0 (13)`，下载 URL、长度和 EdDSA 签名与 GitHub 最终 DMG 一致。
- [x] T6：`@ssbun/seahorse@1.13.0` 发布到 npm，`latest` 与公开 tarball 验证通过。
- [x] T7：发布记录完整，远端分支/tag/Release/npm 状态一致，工作区只保留已明确说明的生成物或无关状态。

## Plan

1. 同步版本、CHANGELOG、npm 元数据和发布说明。
2. 运行全量测试、跨平台构建、npm 演练并生成签名 DMG。
3. 验证最终产物并完成独立发布审查。
4. 提交并推送 `main`，创建与推送 `v1.13.0`，等待并核对远端 Release。
5. 上传正式 DMG/SHA256，验证后发布 appcast，再发布 npm wrapper。
6. 复核所有公网状态并记录发布结果。

## Review

- 独立审查结论：`APPROVED`（4 轮，R1–R4 全部解决，无未解决问题）。
- 审查记录：[release-1.13.0.md](../../reports/adversarial-review/release-1.13.0.md)

## Result

- GitHub Release：[Seahorse 1.13.0](https://github.com/SSBun/Seahorse/releases/tag/v1.13.0)，正式 DMG 与 SHA 附件均返回 HTTP 200，大小与摘要和本地发布物一致。
- Sparkle 2：公网 appcast 首项为 `1.13.0 (13)`，与仓库 feed 逐字节一致，下载 URL、长度及 EdDSA 签名均通过验证。
- npm：`@ssbun/seahorse@1.13.0` 已发布为 `latest`，公开 tarball 仅包含 README、`install.js` 与 `package.json`。
- 已知边界：发布物使用 Apple Development 签名，未进行 notarization；App Store、Homebrew 与自动安装均未执行。
