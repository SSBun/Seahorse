# 发布 1.12.0 并用 1.12.1 验证 Sparkle 更新

## 状态

- 已完成（2026-07-21）

## 目标

- 发布当前 `1.12.0 (11)`，作为首个集成 Sparkle 2 的可安装基线。
- 安装并启动 `1.12.0`。
- 只递增版本到 `1.12.1 (12)`，不增加产品功能，构建并发布签名 DMG。
- 更新 Sparkle appcast 后，从 `1.12.0` 检查、下载并安装 `1.12.1`，验证更新链路。

## 边界

- 复用现有 DMG、GitHub Release、npm wrapper 与 appcast 流程，不新增发布系统。
- 两个版本都不声称已 notarized；签名身份为 Apple Development。
- `1.12.1` 仅用于 Sparkle 端到端验证，CHANGELOG 明确记录其用途。

## 计划

- [x] 完成 `1.12.0` 发布准备、独立审查与远端发布。
- [x] 安装并启动 `1.12.0` 基线。
- [x] 将版本升级到 `1.12.1 (12)`，完成构建、测试和签名 DMG。
- [x] 发布 `1.12.1`，更新 appcast 并验证公开资源。
- [x] 从 `1.12.0` 通过 Sparkle 更新到 `1.12.1`，记录验证结果。

## Review status

- Overall gate: APPROVED
- Final report: [create-sparkle2-integration-sop.md](../../reports/adversarial-review/create-sparkle2-integration-sop.md)
- `1.12.0` 发布准备：APPROVED
- Report: [release-1.12.0.md](../../reports/adversarial-review/release-1.12.0.md)
- `1.12.1` 发布准备：APPROVED
- Report: [release-1.12.1.md](../../reports/adversarial-review/release-1.12.1.md)

## 1.12.0 发布准备

- GitHub 登录账号为 `SSBun`，npm 登录账号为 `ssbun`；远端与 registry 均未存在 `1.12.0`。
- 签名 DMG 位于 `dist/Seahorse-1.12.0_20260721_170155/Seahorse-1.12.0.dmg`，版本为 `1.12.0 (11)`，包含 Sparkle，`hdiutil verify` 与严格代码签名验证通过。
- SHA256 为 `718350351294e2f031c5a8ae7bb6c0d71f44a19ee59d3884bb354c676585b51f`；App 未公证。
- `docs/appcast.xml` 已用 Keychain 中的私钥生成 `1.12.0` EdDSA 签名项，URL 指向待发布的同一 DMG。
- `npm pack --dry-run` 与 `npm publish --dry-run --access public` 通过，仅包含 `README.md`、`install.js`、`package.json`。
- 远端动作待独立审查通过后执行：提交并推送 `main`、创建并推送 `v1.12.0`、创建 GitHub Release 并上传 DMG/SHA256、发布 `@ssbun/seahorse@1.12.0`。
- SSH 22 端口在当前网络不可用；已验证 GitHub HTTPS credential 通道的 push dry-run 成功，正式 push 使用该通道。

## 1.12.0 发布结果

- 提交 `56070f9`、tag `v1.12.0` 与 `main` 已推送；GitHub Actions run `29817357675` 成功创建 Release。
- 本地签名 DMG 与 SHA256 已上传；DMG 为 84,083,481 bytes，GitHub digest 与本地 SHA256 一致，两个公开 URL 均返回 HTTP 200。
- GitHub Pages appcast 已公开 `1.12.0` / build `11` 的 EdDSA 签名项。
- `@ssbun/seahorse@1.12.0` 已发布，registry `latest` 为 `1.12.0`。
- `/Applications/Seahorse.app` 已安装并运行 `1.12.0 (11)`，包含 Sparkle 且严格代码签名验证通过。

## 1.12.1 发布准备

- 仅修改 Xcode marketing/build version、npm manifest/lockfile、CHANGELOG、appcast 与任务上下文；没有产品代码变更。
- macOS 77 项测试全部通过；全新 iOS Simulator build 通过，产物为 `1.12.1 (12)` 且不包含 Sparkle framework。
- 签名 DMG 位于 `dist/Seahorse-1.12.1_20260721_172624/Seahorse-1.12.1.dmg`，大小为 84,083,614 bytes，SHA256 为 `3cc74fe096b46391fedffa142f77f8fd26c18c4630f783700eb891325e48c9a6`。
- `hdiutil verify`、SHA256、版本 `1.12.1 (12)`、Sparkle framework 存在性与严格代码签名验证通过；App 未公证。
- `docs/appcast.xml` 已用 Keychain 私钥生成 build `12` 的 EdDSA 签名项，URL 指向待发布的同一 DMG。
- `npm pack --dry-run` 与 `npm publish --dry-run --access public` 通过，仅包含预期的 3 个文件；npm 尚不存在 `1.12.1`。
- 远端动作待独立审查通过后执行：先本地提交并推送 `v1.12.1`，创建 GitHub Release、上传并验证 DMG/SHA256；确认附件 HTTP 200 后才推送 `main` 公开 build `12` appcast，最后发布 `@ssbun/seahorse@1.12.1`。

## 1.12.1 发布结果

- 发布准备提交 `984ab91`、tag `v1.12.1` 与 `main` 已推送；GitHub Actions release run `29818749900` 和 Pages run `29819236355` 均成功。
- 本地签名 DMG 与 SHA256 已上传；DMG 为 84,083,614 bytes，GitHub digest 与本地 SHA256 `3cc74fe096b46391fedffa142f77f8fd26c18c4630f783700eb891325e48c9a6` 一致，两个公开 URL 均返回 HTTP 200。
- GitHub Pages appcast 已公开 `1.12.1` / build `12` 的正确下载 URL、文件长度和 EdDSA 签名项。
- `@ssbun/seahorse@1.12.1` 已发布，registry `latest` 为 `1.12.1`。
- `/Applications/Seahorse.app` 的 `1.12.0 (11)` 已通过 Sparkle 检测到 `1.12.1`，并成功完成下载、EdDSA 验签、替换和重启。
- 更新后的 `/Applications/Seahorse.app` 为 `1.12.1 (12)`；`codesign --verify --deep --strict` 通过，确认端到端更新链路成功。
