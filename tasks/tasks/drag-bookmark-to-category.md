# 支持拖拽条目到分类

Status: Completed (2026-08-27 11:41)
Kind: Task

## Scope

- 包含 Bookmark、Image 与 Text 三类单个条目拖到现有分类。
- 不包含多选批量拖拽或通过拖放新建分类。

## Target
- [x] T1: 用户将 Bookmark、Image 或 Text 条目拖到目标分类后，条目分类更新为该目标分类并持久化，界面同步反映移动结果。
- [x] T2: 在实际 macOS App 中从网格或列表拖动 Bookmark、Image 或 Text 到不同分类时，侧边栏分类确实接收拖放并完成持久化移动。
- [x] T3: 拖拽开始、目标识别、载荷解析、条目查找与更新结果写入 `/Users/caishilin/.venom/logs/Seahorse.log`，足以定位未生效阶段且不记录用户内容。

## Plan

1. 在网格、列表和侧边栏拖放边界加入有界诊断日志。
2. 重新构建并启动 App，通过真实拖放和指定日志定位首个未触发阶段。
3. 在该阶段实施最小根因修复，再验证分类持久化与界面刷新。

## Decisions

- 继续优先使用 SwiftUI 拖放能力，不新增依赖；只有日志证明标准 API 无法覆盖时才考虑最小 AppKit bridge。
- 日志使用现有 `Log` 与 `.ui` category，只记录阶段、条目类型、计数和结果，不记录标题、URL、文本或分类名称。
- 运行日志明确报告 `com.csl.cool.Seahorse.item-uuid` 未在 App Info.plist 导出；先补齐该 UTType 声明与 `public.data` conformance，不在证据出现前扩大到 AppKit bridge。
- 导出 UTType 后真实拖放已进入 drop callback，但日志停在 `payload_invalid`；统一改为显式 `registerDataRepresentation` 与 `loadDataRepresentation`，避免 NSString 在拖放边界被系统转换为文件表示。

## Result

- T1: 网格与列表的 Bookmark、Image、Text 条目均生成 seahorseItemUUID 载荷；分类行按同一 UTType 解码 UUID、更新对应模型并通过 DataStorage.updateItem 持久化，Debug 构建成功。
- T2: 用户在最终 Debug App 中完成实际拖放并确认列表已刷新；自定义存储中的 items.json 于 11:28:10 写入，最新 Bookmark 的 modifiedDate 同为 11:28:10，目标 categoryId 存在。
- T3: 指定 Seahorse.log 先后捕获未导出 UTI 与 item_drag payload_invalid，精确定位两个失败阶段；最终阶段日志覆盖源、目标、载荷、查找与更新分支且不含标题、URL、文本或分类名。
- Review gate: Skipped — 用户未要求独立 Reviewer、双 Agent Reviewer–Editor 或对抗审查。

## Verification

- Passed: 最终 Debug xcodebuild 显示 BUILD SUCCEEDED；Info.plist lint 通过且构建产物含导出 UTI；真实拖放后的持久化时间、modifiedDate、有效目标分类与用户确认一致；git diff --check 通过。
