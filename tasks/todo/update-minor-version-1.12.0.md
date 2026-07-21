# 升级并提交 Seahorse 1.12.0

## 状态

- 已完成（2026-07-21）

## 目标

- 将 Seahorse App 从 `1.11.0 (10)` 升级到 minor 版本 `1.12.0 (11)`。
- 同步 CHANGELOG、根 npm wrapper 与持久上下文。
- 验证并提交当前全部 Sparkle 集成与版本更新改动。

## 边界

- 不修改 MCP Helper 自身的独立 `0.1.0` 版本。
- `docs/appcast.xml` 继续描述当前已发布的 1.11.0 DMG；1.12.0 未发布前不写入不存在的附件。
- 本任务只创建本地 commit，不 push、不创建 tag、不发布 GitHub Release 或 npm package。

## 计划

- [x] 更新 Xcode App 版本、build number、CHANGELOG 与 npm wrapper。
- [x] 检查 README、installer、appcast 和 release metadata 的版本语义。
- [x] 运行构建、测试与版本一致性验证。
- [x] 完成独立对抗式审查并提交全部本地改动。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: `sparkle_reviewer`
- Round: RE-REVIEW (4)
- Scope: HEAD 到当前工作树的全部 Sparkle 集成、1.12.0 版本元数据、CHANGELOG、npm wrapper、发布文档与任务记录
- Summary: Reviewer 确认 Sparkle macOS-only 集成与 1.12.0 版本元数据一致，批准最终完整差异。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/update-minor-version-1.12.0.md)

## 结果与验证

- Xcode Debug/Release 的 `MARKETING_VERSION` 为 `1.12.0`，`CURRENT_PROJECT_VERSION` 为 `11`；macOS/iOS 构建产物均读取为 `1.12.0 (11)`。
- 根 npm wrapper 的 manifest 与 lockfile 由 `npm version` 同步为 `1.12.0`；`npm pack --dry-run` 只包含预期的 README、installer 与 manifest。
- `CHANGELOG.md` 新增 1.12.0 用户可见变更与 compare 链接；README/installer 无硬编码旧版本，appcast 按边界保留已发布的 1.11.0 DMG。
- 新鲜 iOS Simulator Debug 构建通过且不包含 Sparkle；macOS 测试 77/77 通过。第一次 macOS 测试因临时目录中 App/Test bundle Team ID 不一致未加载测试，改用 `CODE_SIGNING_ALLOWED=NO` 后完整通过。
- `plutil`、`xmllint`、`bash -n` 与 `git diff --check` 通过；现有 Swift 6 与 asset warning 未由本任务引入。
- npm registry 的 `latest` 与远端最新 tag 仍为 1.11.0；本任务未执行 push、tag 或发布。
