---
created: 2026-07-28
task: release-1.14.0
review_cycles: 2
---

# Seahorse 1.14.0 发布审查

Topic: 搜索长期运行修复与版本发布物是否满足发布条件

> **E1:** `CopyMonitor` 只在辅助功能权限真实变化时发布状态；Xcode、npm 与 CHANGELOG 已统一到 `1.14.0 (14)`。80 项 macOS 测试、iOS Simulator Release 构建、npm dry-run、签名 App、DMG、SHA256、挂载读取和临时 Sparkle appcast 生成均通过。
>
> **R1:** 独立复核确认权限从 false 到 true、从 true 到 false 的语义保持正确，版本、产物字节数、摘要、架构、Sparkle/MCP helper、签名及安全发布顺序均一致，没有阻断问题。

**Conclusion:** 修复、版本元数据和最终本地发布物满足进入远程发布阶段的条件；Apple Development 签名与未 notarize 的边界已明确记录。

Topic: 发布提交与工具产物边界

> **E1:** 发布准备差异尚未暂存，`docs/appcast.xml` 有意保持不变，等待 GitHub 最终资产公开并验证后再发布；评审过程生成了未跟踪的 `.pi-subagents/` 工具产物。
>
> **R1:** 要求避免宽泛暂存污染发布提交，并明确发布准备是独立提交还是修订现有修复提交；空的 `[Unreleased]` 区块符合仓库惯例。
>
> **E2:** 采用定向暂存并删除评审工具产物；发布准备使用独立的 `release: prepare 1.14.0` 提交，叠加在 `035dfae` 之上，不 amend；appcast 继续延后，npm 保持最后发布。
>
> **R2:** 复核确认上述边界与连续版本历史一致，所有问题均已解决，批准完整发布准备范围。

**Conclusion:** 发布提交范围、顺序和远程门禁明确，不会提交评审工具文件或提前公开 appcast。

---

**Final decision:** `APPROVED`

**Outcome:** Seahorse `1.14.0 (14)` 的代码修复、版本元数据、签名本地产物与远程发布顺序通过独立审查。

**Remaining:** none
