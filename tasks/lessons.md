# Lessons

- 使用 `GlobalToastManager.shared.show(...)` 之前，必须确认顶层窗口有订阅该 manager 并挂载 `.toast(...)` 渲染器；只更新 ObservableObject 状态不会自动显示 UI。
- 列表行展示外部抓取内容时，标题、摘要、URL 等文本必须设置行数限制和截断，并给 row 固定高度；不能让网页描述长度决定列表布局。
- Liquid Glass toolbar 必须优先使用系统 SwiftUI/AppKit 组件和默认样式；不要把 `Menu` 嵌进自定义 glass 或 `ControlGroup` 里，否则 hover/按下高亮会只作用在内层控件，和系统外框不一致。
- 做 SwiftUI overlay 选区交互时，必须先明确 hit-test 层级：背景只处理空白，选区本体拦截并拖动，resize handle 独占缩放，不能让背景手势穿透到选区。
- 维护 O(1) lookup cache 时，任何 source-of-truth 数组增删改都必须同步更新 cache；否则 SwiftUI 刷新后仍会从 stale cache 读旧模型。
- 当用户指出“在这里加更多选项”时，应优先把当前控件扩展为同位置的系统选项菜单，而不是继续用单一开关或硬编码默认值。
- 调整默认偏好值时，如果旧默认已经通过 `AppStorage` 落盘，必须换 key 或迁移；只改 initializer 不会影响已有本地值。
