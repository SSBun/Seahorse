# 修复系统代理配置与滚动图片抖动

## 状态

- 已完成（2026-07-22）

## 目标

- 让 Seahorse 直接继承 macOS 的系统代理与 VPN 配置，删除不完整的自定义代理字典。
- 主列表快速滚动时保留已经成功显示的图片，只暂停 pending 与新图片请求，滚动停止后再恢复加载。
- 保持性能监控数据准确，不把尚未启动的图片加载误记为取消。

## 边界

- 不增加手动代理设置页；VPN 与代理继续由 macOS/CFNetwork 管理。
- 不新增图片加载框架、失败 URL 缓存或预取系统。
- 只修改主列表图片生命周期和现有 `NetworkManager` 配置。

## 计划

- [x] 删除自定义代理字典并保留默认 URLSession 配置。
- [x] 滚动中保留已经显示的海报，只对 pending 与新图片显示占位内容。
- [x] 同步调整图片性能监控生命周期。
- [x] 重新完成构建、测试与独立对抗式审查。

## Review status

- Gate: APPROVED
- Reviewer: `/root/sparkle_reviewer`
- Review cycles: 4
- Resolved: R1、C1、R2
- Unresolved: none
- Report: [系统代理与滚动图片抖动修复审查](../../reports/adversarial-review/fix-system-proxy-and-scroll-image-churn.md)

## 实现结果

- `NetworkManager` 不再写入自定义代理字典，默认 URLSession 继续继承 macOS/iOS 系统代理与 VPN。
- 主网格和列表在滚动阶段保留已经成功显示的远程、本地、favicon 与 data URL 图片，只让 pending 与新资源显示占位，idle 后恢复加载。
- Kingfisher 图片在 View 消失时真实取消；data URL 后台解码显式传播取消并阻止取消后回写。
- 图片性能监控以 item、角色和实际资源路径共同识别 pending；资源切换会取消旧记录，迟到回调不能完成或标记新资源。

## 验证

- `git diff --check` 通过。
- macOS Debug 全量 `xcodebuild test` 通过。
- macOS Release `xcodebuild build` 通过。
- iOS Simulator Debug `xcodebuild build` 通过。
- 通过正在滚动时的界面截图确认已显示海报保持可见，新资源继续显示占位。
- 独立对抗式审查在四轮后 `APPROVED`。
