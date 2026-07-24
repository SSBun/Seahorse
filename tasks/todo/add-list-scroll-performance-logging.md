# 增加列表滚动性能监控日志

## 状态

- 已完成（2026-07-22）

## 目标

- 为 macOS 主列表快速滚动卡顿增加低开销、可关联的性能日志。
- 覆盖列表数据重算、布局/可见行生命周期、图片加载与 `DataStorage` 发布等主要热路径。
- 让 Instruments Points of Interest 与 Console 日志能定位卡顿发生在哪一段。

## 边界

- 仅增加诊断能力，不在没有动态证据前实施列表架构或渲染优化。
- 复用现有 `Log.performance` 和 Apple 原生 signpost，不引入依赖或远端遥测。
- 高频逐行事件必须采样或聚合，避免监控本身造成明显滚动开销。
- 日志不得包含书签标题、URL、文件路径或其他用户内容。

## 计划

- [x] 追踪列表重算、行渲染、图片加载和数据发布调用链。
- [x] 实现统一的低开销性能 signpost 与采样日志。
- [x] 增加最小可运行检查并完成 macOS 构建/测试。
- [x] 完成独立对抗式审查。

## Review status

- Gate: APPROVED
- Review cycles: 3
- Resolved: R1–R3
- Unresolved: none
- Report: [列表滚动性能监控日志对抗式审查](../../reports/adversarial-review/add-list-scroll-performance-logging.md)

## 实现结果

- `ListPerformanceMonitor` 记录搜索快照、异步筛选、滚动阶段、超过 100 ms 的滚动回调间隙、cell 类型/可见数、图片成功/失败/取消/cache/慢加载及数据发布。
- 高频 cell 与图片事件分别累计到 0.5 秒 `scroll_summary` 和 `image_summary`；滚动结束后的图片完成仍进入尾随批次，慢图片不逐项写日志，列表书签 favicon 与图片条目均纳入同一汇总。
- 日志只包含固定原因、枚举、计数和耗时，不包含标题、URL、路径或 UUID；Release 二进制保留 OSLog 与 signpost。

## 验证

- `git diff --check` 通过。
- macOS Debug 与 Release 构建通过；Release 二进制可检出 `list_perf` 和 `ListScrollSummary` 字符串。
- macOS 全量 `xcodebuild test` 通过；测试签名仅通过命令行临时统一 Team，没有修改工程签名。
- iOS Simulator Debug 构建通过。
