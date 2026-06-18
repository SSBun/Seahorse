# Lessons

- 使用 `GlobalToastManager.shared.show(...)` 之前，必须确认顶层窗口有订阅该 manager 并挂载 `.toast(...)` 渲染器；只更新 ObservableObject 状态不会自动显示 UI。
- 列表行展示外部抓取内容时，标题、摘要、URL 等文本必须设置行数限制和截断，并给 row 固定高度；不能让网页描述长度决定列表布局。
- Liquid Glass toolbar 必须优先使用系统 SwiftUI/AppKit 组件和默认样式；不要把 `Menu` 嵌进自定义 glass 或 `ControlGroup` 里，否则 hover/按下高亮会只作用在内层控件，和系统外框不一致。
