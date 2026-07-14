# 当前版本变更日志面板设计

## 目标

在 Advanced Settings 的 `Updates` 标题右侧增加图标按钮。点击后打开原生 sheet，只显示当前 App 版本在 `CHANGELOG.md` 中的内容。

## 交互

- 使用系统 `info.circle` 图标，保持无文字的紧凑按钮，并提供 `Show Changelog` tooltip 和无障碍标签。
- sheet 尺寸约为 `520 × 420`，标题为 `What’s New in <version>`。
- 内容按 CHANGELOG 中已有的小节顺序展示，每个条目使用项目现有字体和系统列表样式。
- 右上角使用系统关闭图标；用户也可以按 Escape 关闭 sheet。

## 数据

- 根目录 `CHANGELOG.md` 是唯一内容源，并作为 App resource 打包。
- 使用 `UpdateManager.currentVersion` 定位 `## [<version>]`，读取到下一个同级版本标题为止。
- 支持 `###` 小节和 `-` 列表项；不实现通用 Markdown 渲染器。
- 资源缺失、版本不存在或内容为空时显示 `Changelog is unavailable for this version.`。

## 代码边界

- `AdvancedSettingsView` 只维护 sheet 展示状态和入口按钮。
- 新视图负责读取、解析和展示当前版本内容。
- 不请求网络，不新增依赖，不改变更新检查逻辑。

## 验证

- 单元测试覆盖当前版本提取、停止于下一版本、缺失版本和空内容。
- macOS 构建验证资源已进入 App bundle。
- 手工检查图标位置、tooltip、sheet 尺寸、滚动和关闭行为。
