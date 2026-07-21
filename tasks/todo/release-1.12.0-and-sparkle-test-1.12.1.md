# 发布 1.12.0 并用 1.12.1 验证 Sparkle 更新

## 状态

- 进行中（2026-07-21）

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

- [ ] 完成 `1.12.0` 发布准备、独立审查与远端发布。
- [ ] 安装并启动 `1.12.0` 基线。
- [ ] 将版本升级到 `1.12.1 (12)`，完成构建、测试和签名 DMG。
- [ ] 发布 `1.12.1`，更新 appcast 并验证公开资源。
- [ ] 从 `1.12.0` 通过 Sparkle 更新到 `1.12.1`，记录验证结果。

## Review status

- Overall gate: PENDING
- `1.12.0` 发布准备：APPROVED
- Report: [release-1.12.0.md](../../reports/adversarial-review/release-1.12.0.md)

## 1.12.0 发布准备

- GitHub 登录账号为 `SSBun`，npm 登录账号为 `ssbun`；远端与 registry 均未存在 `1.12.0`。
- 签名 DMG 位于 `dist/Seahorse-1.12.0_20260721_170155/Seahorse-1.12.0.dmg`，版本为 `1.12.0 (11)`，包含 Sparkle，`hdiutil verify` 与严格代码签名验证通过。
- SHA256 为 `718350351294e2f031c5a8ae7bb6c0d71f44a19ee59d3884bb354c676585b51f`；App 未公证。
- `docs/appcast.xml` 已用 Keychain 中的私钥生成 `1.12.0` EdDSA 签名项，URL 指向待发布的同一 DMG。
- `npm pack --dry-run` 与 `npm publish --dry-run --access public` 通过，仅包含 `README.md`、`install.js`、`package.json`。
- 远端动作待独立审查通过后执行：提交并推送 `main`、创建并推送 `v1.12.0`、创建 GitHub Release 并上传 DMG/SHA256、发布 `@ssbun/seahorse@1.12.0`。
- SSH 22 端口在当前网络不可用；已验证 GitHub HTTPS credential 通道的 push dry-run 成功，正式 push 使用该通道。
