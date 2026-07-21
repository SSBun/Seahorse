# 编写 Sparkle 2 集成 SOP

## 状态

- 已完成（2026-07-21）

## 目标

- 将 Seahorse 已验证成功的 Sparkle 2 集成与发布流程整理为跨项目可复用的用户 SOP。
- 覆盖 Swift Package Manager 集成、EdDSA 密钥、appcast 发布顺序和基线升级验收。
- 提交当前仓库全部本地变更。

## 边界

- SOP 写入用户级 `~/.csl-agent-kit/sops/`，不复制 Sparkle 源码或新增项目依赖。
- 以普通 macOS App 的 DMG/ZIP 更新为主；沙盒 App、PKG 更新和 App Store 发布仅作分流提示。
- 私钥不得写入仓库、命令行参数、日志或 SOP 示例。

## 计划

- [x] 核对 Seahorse 的实际实现与 1.12.0 → 1.12.1 成功升级证据。
- [x] 创建并验证用户级 Sparkle 2 集成 SOP。
- [x] 完成独立对抗式审查。
- [x] 提交仓库全部本地变更。

## Review status

- Gate: APPROVED
- Report: [create-sparkle2-integration-sop.md](../../reports/adversarial-review/create-sparkle2-integration-sop.md)

## 结果与验证

- 用户级 SOP 已写入 `~/.csl-agent-kit/sops/integrate-sparkle2-macos.md`，`sop-summaries.sh` 能按 `when_to_use` 和 globs 正确发现。
- SOP 覆盖 SPM/macOS 平台过滤、EdDSA Keychain 密钥、标准 updater、签名归档、资产先于 feed 的发布顺序及两个连续版本的端到端验证。
- 官方事实以 Sparkle 官方 documentation、publishing、sandboxing、ATS 和 upgrading 文档为依据。
- `/Applications/Seahorse.app` 已从 `1.12.0 (11)` 更新到 `1.12.1 (12)`，严格代码签名验证通过。
- 已审查范围提交为 `ba3977f`。
