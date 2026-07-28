# 发布 Seahorse 1.14.0

- Status: In Progress (2026-07-28 13:38)

## Scope

- 包含：提交 `035dfae` 的搜索长期运行性能修复，以及版本、CHANGELOG 与发布记录。
- 包含：Apple Development 签名 DMG、SHA256、GitHub Release、Sparkle appcast 与 `@ssbun/seahorse` npm wrapper。
- 不包含：notarization、App Store、Homebrew、自动覆盖 `/Applications` 中的现有 App。

## Target

- [x] T1：Xcode、npm 与 CHANGELOG 统一为 `1.14.0`，build number 为 `14`，发布说明准确描述本轮用户可见修复。
- [x] T2：macOS 全量测试、iOS Simulator 构建、Release App、helper、签名 DMG、挂载读取与 SHA256 验证全部通过。
- [x] T3：最终发布差异通过独立对抗式审查，且没有未解决的阻断问题。
- [ ] T4：`main` 与 `v1.14.0` 推送到 `origin`，公开 GitHub Release 提供可下载且摘要一致的 DMG 与 SHA256。
- [ ] T5：公开 Sparkle appcast 提供 `1.14.0 (14)`，下载 URL、长度和 EdDSA 签名与 GitHub 最终 DMG 一致。
- [ ] T6：`@ssbun/seahorse@1.14.0` 发布到 npm，`latest` 与公开 tarball 验证通过。
- [ ] T7：发布记录完整，远端分支、tag、Release、appcast 与 npm 状态一致。

## Plan

1. 同步版本、CHANGELOG、npm 元数据和发布说明。
2. 运行全量测试、跨平台构建、npm 演练并生成签名 DMG。
3. 验证最终产物并完成独立发布审查。
4. 列出最终远程动作、产物与命令，取得用户确认。
5. 推送 `main` 与 `v1.14.0`，创建 GitHub Release 并上传正式附件。
6. 验证远端资产后发布 appcast，再发布 npm wrapper。
7. 复核全部公网状态并记录发布结果。

## Result

- T1：Xcode Debug/Release 均为 `1.14.0 (14)`，npm manifest 与 lockfile 为 `1.14.0`；CHANGELOG 新增长期运行搜索性能修复并更新 compare 链。registry 的 `latest` 仍为 `1.13.0`，目标版本尚未占用。
- T2：macOS 80 项测试全部通过，iOS Simulator Release 构建通过；npm pack/publish dry-run 通过且 tarball 仅含 README、`install.js` 和 `package.json`。正式 DMG 为 `84,151,488` bytes，SHA256 `f3e2b32abc9301e4f26d5dfebb9cee619920e8fb943bcddac21b0a119ddf14c0`；DMG、挂载 App、`1.14.0 (14)`、arm64 App/Node、Sparkle、MCP helper 与 deep strict codesign 均验证通过。
- T3：独立 Reviewer 在 2 轮后 `APPROVED`；[审查记录](../../reports/adversarial-review/release-1.14.0.md)。
- Review gate: Required — `APPROVED`，报告见上述链接。
