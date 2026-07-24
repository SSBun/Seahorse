# 重复采集书签时更新时间并反馈

Status: Completed (2026-07-24 13:38)

## Scope

- 包含：默认 `Newest` 排序下，刷新添加时间的书签立即成为列表第一项。
- 不包含：覆盖用户明确选择的名称、最旧或按站点排序；这些排序继续遵循自身语义。

## Target

- [x] T1：高级设置提供默认关闭的开关；开启后，用户再次采集已有 URL 时只更新原书签的添加时间，原有内容保持不变。
- [x] T2：手动添加、粘贴/拖放和双拷贝遇到重复书签时提供可见提示；刷新成功与仅检测到重复使用不同文案。
- [x] T3：新建成功、重复未刷新和重复已刷新使用可区分的状态栏反馈音；关闭现有成功反馈时不播放额外反馈音。
- [x] T4：导入与 MCP 创建的重复语义保持不变，并以自动化检查证明重复刷新和关闭开关两条路径。
- [x] T5：重复书签的添加时间刷新后，在默认 `Newest` 列表中位于第一项，成功提示明确说明已移到顶部。

## Plan

1. 在共享书签写入入口实现受设置控制的添加时间刷新，并保留导入与 MCP 的严格新增模式。
2. 连接设置、用户入口的提示通知和三类反馈音。
3. 添加定向回归测试并执行构建、测试和差异检查。
4. 验证刷新后的默认列表位置，并同步成功提示文案。

## Result

- T1：`AdvancedSettingsView` 新增默认关闭的重复书签开关；`DataStorageDuplicateBookmarkTests.testDuplicateBookmarkRefreshesOnlyAddedDateWhenEnabled` 证明开启后保留原 ID、标题与备注，仅推进 `addedDate` 且条目数仍为 1。
- T2：手动新增使用 sheet 内 toast，粘贴/拖放使用已挂载的全局 toast，双拷贝移除提前静默返回后复用粘贴链路；刷新成功通过 `seahorseBookmarkRefreshed` 显示“添加时间已更新”提示。macOS Debug 构建成功。
- T3：`StatusBarManager` 将新建、重复未刷新、重复已刷新分别映射到 `Glass`、`Tink`、`Pop`，三者的额外反馈音继续统一受 `enableCopyFeedback` 控制；系统通知也使用各自标题和正文。macOS Debug 构建成功。
- T4：导入与 MCP 创建显式传入 `updateDuplicateAddedDate: false`；关闭刷新路径的定向测试通过，macOS 全量 80 项测试最终全部通过，iOS Simulator arm64/x86_64 Debug 构建成功。
- T5：`testRefreshedBookmarkIsFirstWhenSortedNewestFirst` 以一个原本更旧的书签证明刷新后默认排序结果首项为该书签；设置说明、toast 与系统通知均明确写为移到顶部。全量测试首次运行触发既有 AutoParsing 时序测试的 2 秒间歇超时，定向复跑两次通过且最终全量 80 项通过，本轮未修改该无关链路。
- Review gate: Skipped — 用户未要求独立审查，变更只复用已有 `addedDate`、`itemsVersion` 与 `Newest` 排序；列表首项已有确定性回归测试，最终全量测试与平台构建通过，不存在核心验证缺口。
