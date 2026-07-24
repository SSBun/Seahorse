---
created: 2026-07-24
task: release-1.13.0
review_cycles: 2
---

# Seahorse 1.13.0 发布审查

Topic: 发布附件的 SHA256 可移植性

> **E1:** 最终 DMG 的摘要、签名、版本、挂载与包内组件均已验证，但最初的摘要文件保留了仓库相对路径。
>
> **R1:** 指出用户下载 DMG 与摘要文件后，无法在相邻目录直接用标准 `shasum -c` 校验，因此发布完整性附件不可直接使用。
>
> **E2:** 将打包脚本改为在输出目录内对 DMG basename 生成摘要，并重生成当前摘要文件；DMG 本身未改变，同目录校验返回 `Seahorse-1.13.0.dmg: OK`。
>
> **R2:** 确认摘要文件只引用 basename，DMG 摘要保持不变，该问题已解决。

**Conclusion:** 正式摘要文件可与 GitHub Release 中相邻下载的 DMG 直接配合标准工具验证。

Topic: 本地与远端版本事实一致性

> **E1:** Xcode、npm manifest、lockfile 与 CHANGELOG 均已升级到 `1.13.0 (13)`，但持久上下文仍残留旧的本地 npm manifest 版本。
>
> **R1:** 要求发布前准确区分本地 manifest `1.13.0` 与尚未发布的 registry `latest` `1.12.1`。
>
> **E2:** 仅修正该上下文条目，并验证 package 与 lockfile 的版本均为 `1.13.0`。
>
> **R2:** 确认本地与远端状态表达一致，该问题已解决。

**Conclusion:** 发布前版本记录内部一致，并保留了 npm 尚未发布这一真实远端状态。

Topic: MCP Helper 依赖审计告警

> **E1:** 依赖审计包含一个间接高危和五个中危告警；当前 helper 仅在 macOS 本机监听、使用 bearer token，工具 schema 为本地静态注册。
>
> **R1:** 确认 Hono 告警仅影响 Windows，`fast-uri` 告警在当前实现中没有不可信动态 schema 解析路径，因此记录为非阻断风险。
>
> **E2:** 确认不扩大本次发布范围；若未来引入动态不可信 schema 或扩大监听面，再重新评估。
>
> **R2:** 接受该风险边界，没有遗留阻断项。

**Conclusion:** 当前发布路径未发现可观察的适用攻击面，依赖告警不阻断本次 Apple Silicon macOS 发布。

---

**Final decision:** `APPROVED`

**Outcome:** 版本 `1.13.0 (13)` 的完整发布差异与最终本地产物通过独立审查，两个阻断问题均已用最小改动修复并验证。

**Remaining:** none
