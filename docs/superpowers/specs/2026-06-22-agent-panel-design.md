# Agent Panel 设计

## 目标

在主窗口右侧增加一个可展开的 Agent 第三列。用户点击顶部右侧 toolbar 的 Agent 图标后展开面板，在面板内通过聊天方式让 AI 搜索书签。

搜索结果只显示在 Agent 面板内，不改变主列表的分类、标签、搜索文本或排序状态。

## 范围

本次实现包含：

- 主窗口 toolbar 右侧增加 Agent 图标按钮。
- 点击按钮展开或收起右侧第三列。
- 第三列显示聊天界面：消息列表、输入框、发送按钮、加载状态。
- Agent 使用现有 `AISettings` 和 `AIManager` 的 OpenAI-compatible provider。
- Agent 返回的书签结果显示在面板内。
- 点击结果复用现有详情窗口打开对应 item。

本次不做：

- 向量数据库。
- embedding 索引。
- 跨启动持久化聊天历史。
- 把 Agent 结果应用到主列表过滤。
- 多 Agent 或工具调用系统。

## 布局

采用 inspector-style 右侧第三列：

- 左列保持现有 `SidebarView`。
- 中间保持现有 `ItemCollectionView`。
- 右侧新增 `AgentPanelView`，宽度约 320pt。
- 面板收起时完全不占宽度。

实现上优先复用当前 `ContentView` 的 `NavigationSplitView` 外层结构，在 detail 区域内部用水平布局组合主内容和 Agent 面板，避免重写现有 sidebar 逻辑。

## Agent 搜索流程

1. 用户输入自然语言查询。
2. 面板先把用户消息追加到 chat transcript。
3. 本地对 bookmark 做轻量预筛：
   - title
   - url
   - notes
   - tag names
   - metadata description
4. 取前一小批候选传给 AI。
5. AI 返回最相关的书签 id 列表和简短原因。
6. 面板渲染结果卡片。

预筛是为了避免把所有书签一次性塞给模型，也降低 token 和延迟。

## AI 输出格式

让 AI 返回 JSON：

```json
{
  "answer": "简短回复",
  "results": [
    {
      "id": "bookmark uuid",
      "reason": "匹配原因"
    }
  ]
}
```

如果解析失败，面板显示 AI 的文本回复，并给出“未能解析结构化结果”的轻量错误提示。

## 状态

`AgentPanelView` 持有本地状态：

- messages
- inputText
- isSearching
- lastResults
- errorMessage

不新增全局 store。聊天历史只在当前窗口生命周期内存在。

## 错误处理

- 未配置 API key：显示设置提示，不发送请求。
- AI 请求失败：显示错误消息，保留用户输入和历史。
- AI 返回不存在的 bookmark id：忽略该结果。
- 无候选或无结果：显示空结果回复。

## 验证

- 构建通过：`xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug`
- 手动验证：
  - Agent 按钮能展开/收起第三列。
  - 主列表筛选状态不受 Agent 搜索影响。
  - 可发送消息并看到 loading。
  - 结果只出现在 Agent 面板。
  - 点击结果打开现有详情窗口。

