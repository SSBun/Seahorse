---
created: 2026-07-22
task: fix-system-proxy-and-scroll-image-churn
review_cycles: 4
---

# 系统代理与滚动图片抖动修复审查

Topic: 滚动阶段的图片暂停与恢复是否覆盖全部图片来源

> **E1:** 主列表把滚动阶段传给网格卡片和列表行；滚动中不创建 Kingfisher 或 data URL 图片内容，Kingfisher 图片启用 `cancelOnDisappear(true)`，idle 后恢复加载。性能监控只为实际允许加载的图片登记 pending 状态。
>
> **R1:** 远程和本地 Kingfisher 图片满足要求，但 data URL 解码使用未继承父任务取消的 `Task.detached`，滚动开始后仍可能继续占用 CPU 并回写状态。
>
> **E2:** 保存后台解码 task handle，通过取消处理器显式传播 SwiftUI 任务取消，在 Base64 与 `NSImage` 构造阶段之间检查取消，并禁止取消后写回；保留 idle 后重新加载行为。
>
> **R2:** data URL 的取消传播、协作式退出和 idle 恢复均已满足；完整图片生命周期与监控角色复查无新增问题。
>
> **E3:** 用户验证发现原滚动门控会连同已经加载完成的海报一起移除。网格、列表和 favicon 改为记录成功显示的精确资源：滚动中保留当前已成功资源，只对 pending 与新资源显示占位；滚动过程中的动态截图确认多个既有海报保持可见。
>
> **R3:** 已加载海报的显示问题已关闭，但相同 item 和 role 下资源地址切换时，原 pending key 无法区分新旧资源，旧回调还可能误标记新资源。
>
> **E4:** pending key 与 begin、complete、cancel API 加入实际资源路径；path 变化时取消旧 pending，并仅在允许加载且新资源未成功时登记新 pending。图片成功仅在回调资源仍为当前资源时更新显示状态，favicon 回调直接携带其实际 icon 地址。
>
> **R4:** 资源切换生命周期、新旧回调隔离、滚动显示保留和 data URL 取消均满足验收要求，无剩余问题。

**Conclusion:** 网格、列表和 favicon 在滚动中保留已经成功显示的资源，只暂停 pending 与新资源，并在 idle 后恢复；监控按实际资源隔离生命周期，迟到回调不会污染当前显示或统计。

Topic: 系统代理与 VPN 继承

> **E1:** 删除不完整的 `connectionProxyDictionary`，保留 `URLSessionConfiguration.default` 及原有 timeout、cookie 和连接配置，不增加手动代理设置。
>
> **R1:** 默认 URLSession 配置可继续继承系统代理与 VPN，代码中无残留自定义代理设置或额外代理 UI。

**Conclusion:** Seahorse 的网络请求继续由 macOS/CFNetwork 的系统网络配置接管。

---

**Final decision:** `APPROVED`

**Outcome:** 系统代理继承和滚动图片优化完成；已加载海报在快速滚动时保持显示，pending 与新图片暂停加载，资源切换竞态已关闭。

**Remaining:** none
