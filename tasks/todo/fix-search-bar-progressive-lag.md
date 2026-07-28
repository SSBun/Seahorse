# 修复搜索随应用运行时间增长的性能退化

- Status: Completed (2026-07-28 12:50)

## Target

- [x] T1：确认一个会随同一 App 进程运行时间或搜索次数累积、并与搜索延迟同步增长的根因指标。
- [x] T2：修复后，同一进程重复搜索不会持续变慢，启动时的搜索语义、筛选、排序与取消行为保持不变。
- [x] T3：现有搜索测试、完整 macOS 测试与 macOS 构建通过，改动不引入新的编译错误。

## Plan

1. 撤回只针对逐键视图失效的错误修复，比较长时间运行实例与隔离的新实例。
2. 跟踪每次搜索创建和保留的任务、日志 interval、视图状态、缓存及结果资源，找出随时间增长的对象或工作量。
3. 在累积源头做最小修复，并重复搜索验证延迟和资源数量保持稳定。
4. 运行定向测试、完整测试、构建和差异检查。

## Result

- T1：运行 21 小时的 1.13.0 进程已累积约 73,679 个 Observation registrar 与 18,333 个 `ViewMode` tag projection；313 条记录的一次筛选耗时 611 ms。隔离启动的未修复实例在 20 秒内 registrar 从 104 增至 148、tag projection 从 5 增至 16，增长频率与 `CopyMonitor` 的 2 秒权限轮询一致。根因是轮询每次都给 `@Published hasAccessibilityPermission` 赋值，即使权限没有变化，也会让持有该 `@StateObject` 的 App 根场景反复失效。
- T2：`CopyMonitor` 现在只在辅助功能权限真实变化时发布。相同的 20 秒验证中，修复实例的 registrar 保持 77、tag projection 保持 2，没有继续增长；搜索、筛选和排序代码未改动，上一轮错误的 `ContentView` 改动已撤回。
- T3：80 项 macOS 测试全部通过；macOS arm64 Debug 构建、`swiftc -parse Seahorse/Services/CopyMonitor.swift` 与 `git diff --check` 通过。构建仅报告既有警告。
- Review gate: Skipped — 用户未要求独立审查；虽然涉及 App 根观察与周期状态，但对象计数增长有可重复的修复前后验证，核心结果不存在验证缺口，也不属于关键风险。
