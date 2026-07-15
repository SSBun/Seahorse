# 数据模型分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 概览

| 指标 | 值 |
|---|---|
| 数据库引擎 | 无数据库；本地 JSON 文件 + 图片文件 + `UserDefaults` |
| ORM / 查询构建器 | 无；`DatabaseProtocol` + `JSONStorage` 手工编解码 |
| 主要集合 | 4 个 JSON 集合（items、categories、tags、preferences），外加 Images 二进制目录 |
| 迁移策略 | 无显式 schema version 或迁移框架；依赖 Codable 兼容、加载时路径归一化和导入时合并 |

Seahorse 是单机、文件型数据模型。核心条目以 `AnyCollectionItem` 包装 `Bookmark`、`ImageItem` 或 `TextItem`，整体数组写入 `Data/items.json`；分类、标签和少量偏好分别写入独立 JSON。图片本体存储在 `Images/`，模型只保存文件名、外部路径或远程 URL。大量 UI、AI、MCP 与启动设置不进入上述 JSON，而是单独保存在 `UserDefaults`。

## 实体关系概览

```text
Category (1) ────────< (N) CollectionItem
   id                         categoryId（逻辑引用，无外键）

Tag (N) >────────────< (N) CollectionItem
   id                         tagIds[]（内嵌 UUID 数组，无连接表）

AnyCollectionItem (1) ── exactly one ──> Bookmark
                                          ├─ metadata (0..1) WebMetadata
                                          └─ imageURL/faviconURL → 远程 URL 或 Images 文件
                       ├─ exactly one ──> ImageItem
                       │                  └─ imagePath/thumbnailPath → 远程 URL、外部路径或 Images 文件
                       └─ exactly one ──> TextItem

preferences.json: String → String
UserDefaults: UI / AI / MCP / 存储授权等运行配置
```

`categoryId` 与 `tagIds` 都是应用层逻辑引用，没有数据库外键、级联规则或持久化索引。`DataStorage` 在内存中构建 category、tag、item 与搜索记录字典，从而提供 O(1) 查找；应用退出后这些索引不会保存。

## Schema 详情

### items.json / AnyCollectionItem

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | UUID | 应用层唯一、必填 | 与内嵌具体条目的 ID 相同 |
| `itemType` | `bookmark \| image \| text` | 必填 | 决定解码哪个 payload |
| `bookmark` | Bookmark? | `itemType=bookmark` 时应存在 | 书签 payload |
| `imageItem` | ImageItem? | `itemType=image` 时应存在 | 图片 payload |
| `textItem` | TextItem? | `itemType=text` 时应存在 | 文本 payload |

解码具体 payload 时使用 `try?`，因此损坏或不兼容的嵌套对象可能被吞掉，留下只有 wrapper ID/type、没有实际条目的半有效值。`categoryId` 访问这类值会触发 `fatalError`，而其他访问器可能返回空值或当前时间。

**索引：**

| 名称 | 字段 | 类型 | 目的 |
|---|---|---|---|
| `_itemCache` | `id` | 运行时字典 | 按 UUID 查条目 |
| `_searchRecordCache` | `id` | 运行时字典 | 缓存预计算搜索文本与排序键 |
| 持久化索引 | 无 | 无 | 启动时全量解码并重建 |

**关系：**

- 每个 wrapper 应且只应包含一个与 `itemType` 一致的具体条目。
- 具体条目通过 `categoryId` 逻辑归属一个 Category，通过 `tagIds` 与零到多个 Tag 建立多对多关系。

### CollectionItem 公共字段

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | UUID | 必填、应用层唯一 | 条目标识 |
| `categoryId` | UUID | 必填、无外键检查 | 所属分类 |
| `tagIds` | `[UUID]` | 默认空数组；添加时去重 | 标签逻辑引用 |
| `addedDate` | Date | 必填 | 创建时间 |
| `modifiedDate` | Date? | 可选 | 修改时间，写入并不由底层统一保证 |
| `notes` | String? | 可选 | 备注；书签 AI 摘要也写入该字段 |
| `isFavorite` | Bool | 默认 false | 收藏标记 |
| `isParsed` | Bool | 默认 false | AI 解析状态；当前主要用于书签 |

### Bookmark

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| 公共字段 | 见上 | 见上 | `CollectionItem` 字段 |
| `title` | String | 必填 | 展示与搜索标题 |
| `url` | String | 归一化后应用层唯一 | 原始网页地址 |
| `icon` | String | 必填，默认 `link.circle.fill` | SF Symbol、favicon URL 等图标来源 |
| `metadata` | WebMetadata? | 可选 | OpenGraph / Twitter Card 元数据 |

URL 唯一性通过 `BookmarkURLNormalizer` 在 `DataStorage` 与 `JSONStorage` 两层检查；它是全库约束，但不是文件格式本身的约束。

### WebMetadata

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `title` | String? | 可选 | 页面元数据标题 |
| `description` | String? | 可选 | 页面描述 |
| `imageURL` | String? | 可选 | 远程图片 URL 或 Seahorse 内部图片文件名 |
| `siteName` | String? | 可选 | 站点名称 |
| `url` | String? | 可选 | 元数据规范 URL |
| `faviconURL` | String? | 可选 | favicon URL |

### ImageItem

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| 公共字段 | 见上 | 见上 | `CollectionItem` 字段 |
| `imagePath` | String | 必填 | 内部文件名、外部绝对路径、file URL 或 HTTP(S) URL |
| `thumbnailPath` | String? | 可选 | 缩略图路径 |
| `imageSize` | CGSize? | 可选 | 像素/点尺寸 |

加载与写入会尝试把内部图片路径归一化为文件名，远程 URL 保持不变。删除图片条目时，只允许清理解析后仍位于内部 `Images/` 目录且未通过符号链接逃逸的文件。

### TextItem

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| 公共字段 | 见上 | 见上 | `CollectionItem` 字段 |
| `content` | String | 必填 | 文本或 Markdown 正文 |

`firstLine` 与 `contentPreview` 是运行时派生值，不持久化。

### categories.json / Category

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | UUID | 应用层唯一、必填 | 分类标识 |
| `name` | String | 不区分大小写唯一 | 分类名称 |
| `icon` | String | 必填 | SF Symbol 名称 |
| `colorHex` | String | 必填；非法值展示时回退蓝色 | 颜色十六进制值 |

**索引：** `_categoryCache[id]` 仅存在于运行时。

**关系：** Category 与 CollectionItem 是 1:N 逻辑关系。四个默认分类通过英文名称识别，而不是稳定的系统类型字段：`All Bookmarks`、`Favorites`、`Github`、`None`。

### tags.json / Tag

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | UUID | 应用层唯一、必填 | 标签标识 |
| `name` | String | 不区分大小写唯一 | 标签名称 |
| `colorHex` | String | 必填；非法值展示时回退蓝色 | 颜色十六进制值 |

**索引：** `_tagCache[id]` 仅存在于运行时。

**关系：** Tag 与 CollectionItem 为 N:M；关联直接存放在每个条目的 `tagIds` 数组中。通过 `DataStorage.deleteTag` 删除标签时会批量移除三类条目上的引用；直接调用数据库层删除方法则不会级联。

### preferences.json

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| key | String | 字典 key 唯一 | 偏好名称 |
| value | String | 仅支持字符串 | 偏好值 |

目前可确认 `AppearanceManager` 会把外观模式和强调色同时写入 `UserDefaults` 与该文件。完整导出会创建一个空的 `preferences.json`，因此该文件不是设置备份的可靠来源。

### UserDefaults 与文件授权

`UserDefaults` 保存 AI endpoint/token/model/prompt、MCP 开关与两个 bearer token、剪贴板监控设置、语言、排序、外观、卡片布局、通知、开机启动、最近图标、选择的内容类型等。自定义存储目录的 security-scoped bookmark 也保存在这里。它们没有统一 schema，也不会随完整数据导出；这有利于避免把 API/MCP token 意外带入备份，但也意味着“恢复数据”与“恢复应用配置”是两件不同的事。

## 迁移

仓库没有 migration 文件、schema 版本号或按版本执行的迁移器。

| 迁移/兼容路径 | 时间 | 变更 |
|---|---|---|
| 首次启动初始化 | 运行时 | 缺少 categories 文件时创建四个默认分类；缺少其他文件时使用空集合 |
| 图片路径归一化 | 每次加载/写入 | 内部绝对路径或 file URL 尽量缩减为 `Images/` 下的文件名；HTTP(S) URL 保持原样 |
| 自定义存储目录迁移 | 用户触发 | 先强制写盘，再复制已知数据文件并要求重启；当前旧管理器与新 `Data/` 目录布局存在需要统一验证的路径差异 |
| 完整数据导入 | 用户触发 | 按分类/标签名称、条目 ID 和归一化 bookmark URL 去重后追加，不覆盖现有数据 |

新增可选字段通常能借助 Codable 保持向后兼容；新增必填字段、枚举 case、改变 wrapper payload 或目录结构则可能使整个数组解码失败。当前失败时只记录日志：items/tags 可能变为空，categories 还会回退到默认数据，用户没有明确的恢复引导。

## 数据验证

- `JSONStorage` 在 barrier 区域内检查 item/category/tag UUID 唯一，以及分类/标签名称的不区分大小写唯一。
- bookmark URL 通过统一 normalizer 后检查全库唯一；批量更新与导入也会验证候选全集。
- `CollectionItem` 的标签添加方法会阻止同一 UUID 重复，但直接构造或导入的数据没有同等数组级校验。
- `AnyCollectionItem` 的 wrapper ID、payload ID、`itemType` 三者没有显式一致性校验。
- category/tag 关系没有外键检查；导入时若同名分类或标签已存在但 UUID 不同，现有逻辑会跳过实体，却不会重映射新条目的引用。
- UI 删除自定义分类时只把 bookmark 移到 `None`；image/text 仍可能引用已删除分类。数据库层也不阻止删除仍被引用的分类。
- JSON 写入使用原子文件替换，items 的连续写入按 generation 合并；错误只写日志，不回传到已修改的 UI 状态。
- AI token 与 MCP token 以明文 `UserDefaults` 保存，不属于导出 JSON，但也未使用 Keychain。

## 种子数据 / Fixtures

生产首次启动会创建四个默认分类：`All Bookmarks`、`Favorites`、`Github`、`None`，不创建默认标签或条目。`MockDatabase` 为 SwiftUI preview 和单元测试提供内存实现；`SeahorseTests` 另有搜索、JSON、图片及 MCP 测试夹具。没有开发/生产分离的 seed 工具。

## 建议

1. **在下一次扩展持久化模型前加入轻量 schema version 与显式迁移。** 智能集合、回收站、OCR 文本等候选功能都会新增模型或字段；先定义版本、解码校验和失败回滚，避免靠整个数组一次性 Codable 解码承担升级风险。
2. **把逻辑引用完整性收敛到数据层。** 统一处理分类删除对 bookmark/image/text 的重分配，导入时重映射同名 category/tag UUID，并拒绝 payload 缺失或 wrapper/payload ID 不一致的数据。
3. **明确设置备份边界。** 保持 AI/MCP token 不导出，但让非敏感偏好是否跟随备份成为清晰、可验证的产品规则；不要继续生成看似完整但实际为空的 preferences 文件。
4. **为破损 JSON 提供可恢复加载路径。** 保留上一份有效原子快照、向用户报告具体文件错误，并支持从自动备份恢复；不要在解码失败后静默展示空库或默认分类。
