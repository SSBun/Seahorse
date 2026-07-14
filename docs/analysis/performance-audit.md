# Seahorse 全项目性能审计

> 审计日期：2026-07-13
>
> 范围：macOS/iOS SwiftUI 应用、JSON 存储、图片、导入导出、AI 解析、MCP helper/bridge
>
> 方法：全量静态扫描、热点调用链阅读、本机数据规模核对；未运行 Instruments，因此需动态量化的项目会明确标注。

## 结论

Seahorse 当前的主要瓶颈不是 SwiftUI 布局，而是「主线程上的全量数据处理」和「每次变更都全量重写 JSON」的叠加。最明确的卡顿路径是：

```text
详情页每次按键
  -> DataStorage.updateItem
  -> JSONStorage.queue.sync(barrier)
  -> 等待已排队的全量编码/写盘
  -> 再排队一次整个 items.json 写入
  -> 发布全局 UI 刷新并清空搜索缓存
```

本机当前数据为 287 条，`items.json` 约 438 KB，且存储位置在 iCloud Drive。即使数据量不大，按键级全量写入与 iCloud 文件同步的组合也足以造成明显停顿。

## 优先级摘要

| 优先级 | 问题 | 预期收益 | 证据强度 |
|---|---|---|---|
| P0 | 编辑每个字符都触发全量 JSON 持久化 | 消除编辑卡顿和写放大 | 已由调用链证实 |
| P0 | 启动同步读取后无条件重写全部数据 | 降低首屏时间和 iCloud I/O | 已由代码证实 |
| P1 | macOS/iOS 搜索在主线程全表过滤、构造文本并排序 | 消除搜索输入停顿 | 代码证实，耗时需基准 |
| P1 | 本地图片解码、图标磁盘读取、PNG 编码位于主线程 | 改善滚动、详情和粘贴响应 | 已由代码证实 |
| P1 | MCP 搜索/序列化和导入导出 I/O 继承 `@MainActor` | 避免 Agent/备份操作卡住 App | 已由隔离标注证实 |
| P1 | 批量删标签、导入、AI 批处理缺少批量提交 | 将 N 次全量写降为 1 次 | 已由循环调用链证实 |

## 详细发现

### P0-1 合并编辑事件与持久化

**证据**

- `Seahorse/Views/Previews/ItemDetailView.swift:199-212` 的标题每次 `onChange` 立即更新。
- `Seahorse/Views/Previews/ItemDetailView.swift:409-411` 的备注每次 `onChange` 立即更新。
- `Seahorse/Storage/DataStorage.swift:119-134` 在主线程调用数据库后广播全局更新。
- `Seahorse/Database/JSONStorage.swift:342-357` 先做同步 barrier 变更，然后调用全量 `saveItemsToDisk()`。
- `Seahorse/Database/JSONStorage.swift:191-199` 每次写入都遍历、规范化、pretty-print、sorted-key 编码整个数组。

**最小修复方向**

1. 详情页编辑使用本地 draft，在失焦、提交或 500–800 ms debounce 后更新模型。
2. `JSONStorage` 保留单一 pending save，将短时间内多次变更合并为一个快照写入。
3. 为批量操作增加一次内存更新、一次发布、一次持久化的 API。
4. 普通持久化去掉 `.prettyPrinted` 和 `.sortedKeys`；仅导出给人阅读时保留。

**边界**：debounce 不能牺牲退出时的数据安全；窗口关闭、App 退出和存储路径迁移前必须 flush。

### P0-2 删除启动阶段的冗余同步写入

**证据**

- `Seahorse/Database/JSONStorage.swift:29-50` 在初始化器中同步加载，然后无条件调用 `ensureDataPersistence()`。
- `Seahorse/Database/JSONStorage.swift:114-124` 每次加载 items 后都再次写入，即使路径没有变化。
- `Seahorse/Database/JSONStorage.swift:147-179` 随后又同步重写 items/categories/tags/preferences 四个文件。
- `DataStorage.shared` 是 `@MainActor`，并在 `SeahorseApp` 初始化时立即构造。

**最小修复方向**

- 只在首次创建文件或实际发生路径规范化时写入。
- 删除无条件 `ensureDataPersistence()`，将缺失文件创建放在各自的首次保存路径。
- 若启动基准仍超标，再将文件读取/解码移到非主 actor，最后一次性发布状态。

### P1-1 统一并移出主线程的搜索管线

**macOS 证据**

- `Seahorse/ContentView.swift:88-158` 依次做多轮 `filter`、搜索文本匹配和全量排序，全部在主 actor。
- `Seahorse/ContentView.swift:161-190` 首次查询需为候选集合构造并小写化完整文本。
- `Seahorse/ContentView.swift:376-391` 任何 item/tag 变更都清空全部搜索缓存。
- `Seahorse/ContentView.swift:57,77-85` 的 `lastFilterHash`/`filterHash` 没有实际参与计算，应删除而不是继续叠加缓存。

**iOS 证据**

- `Seahorse/Views/iOS/iOSHomePageView.swift:46-60` 在 computed property 中每次 body 刷新都全量过滤和排序。
- 同一 body 在 `List` 和 empty overlay 中读取两次 `filteredItems`，一次刷新可重复计算。
- iOS 搜索没有 debounce，每次按键还会重复 lowercasing 大段文本。

**最小修复方向**

1. 将每个 item 的 searchable text 变成与数据层同步的派生索引，只更新变化的 item 和受影响 tag。
2. 搜索输入保留 debounce/cancellation，对不可变快照在后台过滤排序，仅将最新结果回传主 actor。
3. 过滤条件合并到单轮遍历；过滤后再排序。
4. iOS 与 macOS 共用纯搜索核心，避免两套索引和失效规则分叉。

**验证目标**：300/3,000/10,000 条 fixture 下记录首次搜索、连续输入和 tag 修改的 p50/p95；主线程单次工作应小于一帧预算，且旧查询结果不得覆盖新查询。

### P1-2 将图片解码、编码和文件复制移出主线程

**证据**

- `Seahorse/Views/Previews/ImageViewer.swift:24-48` 在 body 内同步 `NSImage(contentsOfFile:)`，缩放/拖拽状态更新可重新解码大图。
- `Seahorse/Views/iOS/iOSImageView.swift:46-53` 在 body 内同步 `UIImage(contentsOfFile:)`。
- `Seahorse/Views/Previews/ItemDetailView.swift:577-608` 预览区同样在渲染路径同步加载本地图片。
- `Seahorse/Views/Components/BookmarkIconView.swift:23-44` 对远程图标显式启用 `.loadDiskFileSynchronously()`，data URL 也在 body 内重复解码。
- `Seahorse/Services/PasteHandler.swift:318-350,415-446,475-550` 在主 actor 做 TIFF→PNG 编码、写盘和文件复制。
- `Seahorse/Views/Previews/ItemDetailView.swift:663-698`、`BookmarkDetailContentView.swift:287-337` 和 `ContentView.swift:491-513` 在主线程转 PNG 并写入。

**最小修复方向**

- 本地文件 URL 也使用 Kingfisher 或 ImageIO 异步管线，按实际显示尺寸与 backing scale 下采样。
- 移除 `.loadDiskFileSynchronously()`，将 data URL 解码结果缓存到与 `iconString` 关联的状态/管理器。
- PNG 编码和文件 I/O 在非主 actor 完成，主 actor 只更新进度、错误和模型。
- 图片查看器需要缩放，不应无条件只保留低分辨率；先加载视口尺寸图，放大到阈值后再切换更高分辨率。

### P1-3 MCP 与导入导出不应占用主 actor

**MCP 证据**

- `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:94-166` 整个 bridge service 是 `@MainActor`，搜索会全表过滤、构造文本、排序和 JSON 映射。
- `Seahorse/Services/MCP/MCPBridgeServer.swift:185-190` 在 `Task { @MainActor in }` 中解码请求、执行处理并编码响应。
- `MCPBookmarkBridgeService.swift:314-340` 的 poster 文件复制同样在主 actor。
- 分页每页都从头执行全量搜索与排序，Agent 遍历全量 bookmark 时会重复付费。

**导入导出证据**

- `Seahorse/Services/ExportImportManager.swift:13` 将整个 manager 标记为 `@MainActor`。
- `ExportImportManager.swift:108-180,183-220,270-348,400-488` 内部的 `Task {}` 继承 actor，因此 JSON 编解码、HTML 生成、目录扫描和批量图片复制仍在主线程。

**最小修复方向**

- 主 actor 上一次性快照化所需值类型，在独立 actor/非隔离工作器中搜索、编解码和 I/O，最后回主 actor 发布。
- MCP 搜索复用与 UI 相同的纯搜索核心，但不共享 SwiftUI `@State` 缓存。
- 若 Agent 需要稳定遍历全量，缓存「数据版本 + 筛选条件」对应的有序 ID 结果，后续 offset 分页仅切片。
- `get_bookmark(s)` 直接复用 `DataStorage.item(for:)` 的 O(1) cache，不必每次扫描或临时构造整张字典。

### P1-4 为批量变更提供事务式提交

**证据**

- `Seahorse/Views/Previews/ItemDetailView.swift:856-890` 删除标签时对每个关联 item 单独 `updateItem`，每次都全量写 JSON 并发布 UI 通知。
- `Seahorse/Services/ExportImportManager.swift:491-510` 导入合并对 category/tag/item 逐个查重、插入和写盘，查重本身也是线性扫描。
- `Seahorse/Services/BatchParsingService.swift:123-158` 每个 AI 结果单独保存并发布进度。

**最小修复方向**

- 新增有明确边界的 `performBatchUpdates`：内存中一次替换、一次更新 cache、一次持久化、一次发布。
- 导入前预先构造 ID/name `Set`，将查重从 O(imported × existing) 降为近似 O(imported + existing)。
- 批处理要保留错误语义：要么整批成功，要么返回明确的部分失败结果，不能因减少写盘而静默丢数据。

### P2 中优先级优化

#### 1. 预计算排序键

`Seahorse/Models/SortOption.swift:24-54` 在 sort comparator 中反复提取名称/站点键；`groupBySite` 还反复解析 URL，文本项会反复分割全文。先生成 `(item, sortKey, secondaryKey)` 再排序，使键提取从 O(n log n) 降为 O(n)。

#### 2. 缓存详情页元数据

`Seahorse/Views/Previews/ItemDetailView.swift:415-459,804-853` 在渲染期间读取图片头、文件属性，并反复创建 `DateFormatter`。在 item/path 变化时异步计算一次，日期格式器使用稳定实例或 Swift 格式化 API。

#### 3. 减少长文本在列表渲染中的全量遍历

- `StandardCardView.swift:38-51` 和 `StandardListItemView.swift:34-47` 用 `components(separatedBy:)` 为获取首行创建全部行数组。
- `Seahorse/Models/TextItem.swift:23-29` 先 `content.count` 遍历整个 Swift String，再截取 200 字符。

改用首个 newline index 和 `prefix(200)`/受限 index；对大文本可在模型更新时生成 preview，但不需要为短文本引入新索引层。

#### 4. 拆分 cache 重建范围

`Seahorse/Storage/DataStorage.swift:54-59,267-323` 在 category 或 tag 增删改时都同时重建 item/category/tag 三张字典。分为 `rebuildCategoryCache`/`rebuildTagCache`/`rebuildItemCache`，只重建被改变的表。

#### 5. 降低每张 AI 解析卡片的主线程动画成本

`Seahorse/Views/Cards/ParsingFireEffect.swift:42-48,129-131,185-220` 为每张正在解析的卡片创建 33 Hz 主线程 Timer，每 tick 变更 40 个粒子，循环内多次读取 `Date()`。将 elapsed 每帧计算一次，限制刷新率/同时动画数，并尊重 Reduce Motion。是否需共享 Timeline 应由 Core Animation/Time Profiler 决定。

#### 6. 缓存 SF Symbol 可用性检查

`Seahorse/Views/Components/IconPickerSheet.swift:180-207` 每次打开都对全部 symbol 创建 `NSImage` 检查，又在分类中重复一遍。以 OS 版本为边界在 manager 中缓存可用集合，分类只从该 Set 过滤。

### P3 长期扩展性，不建议立即重构

1. `DataStorage` 同时维护 `items` 和 `bookmarks` 两份 bookmark 值，并以一个大型 `ObservableObject` 影响大量视图。当 Instruments 证明广播刷新仍是瓶颈时，再收敛为单一数据源并拆分 observation 范围。
2. JSON 全文件存储在数千到数万条、多设备同步冲突或需要增量查询时会成为架构上限。先完成写入合并与基准；只在 3,000/10,000 条基准仍不达标时再评估 SQLite/SwiftData，不建议现在直接迁移。

## 现有优化中的正确部分

以下已经做对，不应在新一轮优化中倒退：

- `ItemCollectionView` 已使用 `LazyVGrid`/`LazyVStack`，不需要再做一套手写视图回收。
- 卡片和列表缩略图已使用 Kingfisher downsampling。
- `DataStorage` 已有 item/category/tag ID 字典，单项查找可达 O(1)。
- Batch parsing/diagnostics 已有有界并发，不应改成无限 task fan-out。
- MCP 单页 limit 100 是有意义的响应体与内存上限，应优化分页重复计算，不应取消上限。

## 需纠正的旧性能建议

`PERFORMANCE_OPTIMIZATION.md` 中有多项建议已过时或缺少量化，不应直接继续执行：

- 不要给 `AnyCollectionItem` 添加「仅比较 ID」的 `Equatable/Hashable`；模型文件已明确记录这会导致 payload 变更被 SwiftUI 忽略。
- `StandardCardView`/`StandardListItemView` 当前的 ID-only `Equatable` 也应做 UI 正确性回归；如果需要 equatable 优化，应比较所有实际渲染字段或使用明确 view state。
- 不要未测量就广泛加 `.drawingGroup()`；它可能增加离屏纹理内存和合成成本。
- 不要继续把缓存塞进 View `@State`；当前更需要的是单一搜索索引、明确失效规则和可测试的纯函数。

## 基准与验收计划

| 场景 | 数据规模 | 指标 | 验收方向 |
|---|---:|---|---|
| 首次搜索/连续输入 | 300/3,000/10,000 items | p50/p95、主线程 hitch | 输入无可感知停顿，旧 task 可取消 |
| 连续编辑 10 秒 | 当前 438 KB 及 10 MB JSON | 写入次数、最长主线程阻塞 | 按键不对应写盘，结束后 1 次合并写 |
| 冷启动 | 本地与 iCloud Drive | time to first responsive frame、读/写字节 | 正常启动为 0 字节写入 |
| 图片列表/详情 | 1–20 MP，本地/远程 | hitch、解码内存、FPS | 无主线程解码，缩略图内存受控 |
| MCP 全量分页 | 3,000/10,000 bookmarks | 每页 latency、App UI hitch | 查询不阻塞 UI，后续页不重复全量排序 |
| 批量删标签/导入 | 1,000 items | JSON 写入次数、总耗时 | 单次事务一次持久化 |

工具：Instruments Time Profiler、Hangs、File Activity、Core Animation、Allocations；结合 `os_signpost` 标记 search/save/decode/import/MCP 边界。项目当前没有 Swift 性能测试，应先增加可重复 fixture 和 XCTest metrics，再做 P2/P3 优化。

## 建议实施顺序

1. 写入合并 + 详情页 draft/debounce + 退出 flush。
2. 删除启动冗余写入，补启动/File Activity 基准。
3. 抽出共享搜索核心，增加增量索引、取消和 macOS/iOS/MCP 基准。
4. 将图片解码/编码、MCP CPU/I/O、导入导出移出主 actor。
5. 增加批量事务，再处理排序键、长文本和动画等 P2 项。

## 最可能失败模式与缓解

1. **写入合并后退出丢数据**：必须实现可等待的 flush，并用强制退出/崩溃恢复测试验证。
2. **后台搜索结果乱序覆盖**：每次查询带 generation ID，只接受最新 generation，并取消旧 task。
3. **索引失效不完整导致搜索过期**：为 title/url/content/notes/tag 的每种变更写回归测试，不依赖视图手动清 cache。
4. **图片下采样导致放大模糊**：区分缩略图和查看器管线，查看器按缩放阈值请求更高分辨率。
5. **移出主 actor 后引入数据竞争**：后台任务只接收不可变值快照，所有可观察状态和 `DataStorage` 变更仍回到主 actor。
