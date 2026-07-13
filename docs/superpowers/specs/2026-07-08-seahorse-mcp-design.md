# Seahorse MCP 第一版设计

## 背景

Seahorse 是 macOS 素材收藏工具，当前 bookmark 数据由 App 内 `DataStorage` 管理，并通过 JSON 文件持久化。外部 agent 需要在 Seahorse 运行时访问 bookmarks，并执行搜索、创建、读取和更新。

第一版 MCP 的目标是让本机 agent 通过标准 MCP 接口访问 Seahorse bookmarks，同时保持数据写入仍经过 App 内部数据层，避免外部进程直接修改 JSON 文件造成缓存、校验和 UI 状态不一致。

## 已确认边界

- Seahorse App 运行时才提供 MCP 能力。
- MCP server 默认关闭，必须由用户在 Settings 显式开启。
- MCP server 只监听 `127.0.0.1`。
- MCP endpoint 使用固定端口：`http://127.0.0.1:17373/mcp`。
- 第一版只支持 Streamable HTTP，不支持 stdio，不支持旧 HTTP+SSE。
- 外部 agent 必须使用 Bearer token。
- token 第一版存储在 `UserDefaults`。
- 第一版只管理 bookmarks。
- bookmarks 支持 create、read、update、search、list。
- bookmarks 不支持 delete。
- tags/categories 第一版只读，只支持 list/search。
- bookmark 引用的 `categoryId` 和 `tagIds` 必须已存在；不存在时返回 validation error。
- `create_bookmark` 成功后异步触发 metadata 抓取，不阻塞 MCP response。

## 架构

第一版由两个进程组成：

1. Seahorse App 主进程。
2. 随 App 打包的 TypeScript/Node.js MCP helper。

Seahorse App 负责：

- Settings 中的 MCP 开关、状态、URL、token 展示和 token 重生成。
- 启动、停止和监控 MCP helper。
- 提供内部 bridge 给 helper 调用。
- 通过 `DataStorage` 执行真实数据读写。

MCP helper 负责：

- 监听 `127.0.0.1:17373/mcp`。
- 实现 Streamable HTTP MCP。
- 校验外部 Bearer token。
- 暴露 MCP tools 和 tool schema。
- 将通过鉴权的请求转发给 Seahorse App bridge。

helper 不直接读写 `items.json`，也不持久化 bookmark 数据。所有真实数据读写必须回到 Seahorse App 主进程，并通过 `DataStorage` 执行。

## 内部 Bridge

Seahorse App 提供只给 helper 使用的本机 HTTP bridge：

`http://127.0.0.1:17374/...`

bridge 只监听 `127.0.0.1`，使用独立内部 token。内部 token 第一版也存储在 `UserDefaults`。bridge 不作为用户公开 API，不在 Settings 主 UI 中展示。

数据流：

1. agent 请求 MCP helper。
2. helper 校验外部 Bearer token。
3. helper 将请求转发到 Seahorse App bridge。
4. bridge 在 App 主进程中执行校验和 `DataStorage` 操作。
5. bridge 返回结果给 helper。
6. helper 返回 MCP response。

如果 Seahorse App 不可用，helper 返回 `Seahorse app unavailable`。

## MCP Tools

第一版 tools 固定为：

- `search_bookmarks`
- `get_bookmark`
- `create_bookmark`
- `update_bookmark`
- `list_tags`
- `search_tags`
- `list_categories`
- `search_categories`

不提供：

- `delete_bookmark`
- `create_tag`
- `update_tag`
- `delete_tag`
- `create_category`
- `update_category`
- `delete_category`
- image/text item CRUD

### search_bookmarks

输入：

- `query: String`
- `limit: Int?`
- `categoryId: String?`
- `tagIds: [String]?`
- `favoriteOnly: Bool?`

默认 `limit` 为 20，最大 100。

返回摘要字段：

- `id`
- `title`
- `url`
- `notesPreview`
- `category`
- `tags`
- `isFavorite`
- `addedDate`
- `modifiedDate`

搜索结果不默认返回完整 metadata 或大段 notes。完整详情通过 `get_bookmark` 获取。

### get_bookmark

输入：

- `id: String`

返回完整 bookmark 详情，包括：

- `id`
- `title`
- `url`
- `notes`
- `category`
- `tags`
- `isFavorite`
- `addedDate`
- `modifiedDate`
- 已存在的 `metadata`

不返回 App 内部实现细节。

### create_bookmark

输入：

- `url: String`
- `title: String?`
- `notes: String?`
- `categoryId: String?`
- `tagIds: [String]?`
- `isFavorite: Bool?`

行为：

- URL 重复时返回 validation error。
- `categoryId` 不存在时返回 validation error。
- 任一 `tagIds` 不存在时返回 validation error。
- 成功后立即返回创建的 bookmark。
- 成功后异步触发现有 metadata 解析流程。
- MCP response 不等待 OpenGraph/metadata 网络抓取。

### update_bookmark

输入：

- `id: String`
- `title: String?`
- `url: String?`
- `notes: String?`
- `categoryId: String?`
- `tagIds: [String]?`
- `isFavorite: Bool?`

只允许更新：

- `title`
- `url`
- `notes`
- `categoryId`
- `tagIds`
- `isFavorite`

不允许更新：

- `id`
- `addedDate`
- `modifiedDate`
- `isParsed`
- `metadata`
- `icon`

传入不存在的 bookmark id、重复 URL、不存在的 category/tag id 或不允许字段时，返回 validation error。

### tags/categories

`list_tags` 和 `search_tags` 只读。`list_categories` 和 `search_categories` 只读。

搜索返回 `id`、`name`、颜色等展示所需字段。第一版不允许 agent 创建、更新或删除 tags/categories。

## 后续扩展

后续版本在不改变 App/helper/bridge 边界的前提下新增：

- `get_bookmarks`：按 UUID 批量读取 bookmark。
- `delete_item`：按全局 UUID 永久删除 bookmark、image 或 text，成功返回被删除条目的 `id` 和 `type`。
- `search_bookmarks.offset`：与 `limit` 配合分页。
- `update_bookmark.posterImageURL` 和 `posterImagePath`：更新 bookmark poster image；本地文件复制到 Seahorse `Images` 目录。

`delete_item` 标记为 destructive MCP tool；tag 和 category 继续只读。

## Settings UX

Settings 新增 MCP 区域：

- `Enable MCP Server`
- Status：`Stopped` / `Running` / `Failed` / `Port unavailable`
- MCP URL：`http://127.0.0.1:17373/mcp`
- Token：可复制
- `Regenerate Token`
- 示例 header：`Authorization: Bearer <token>`

`Regenerate Token` 会让旧 token 立即失效，并重启 helper 或通知 helper 刷新配置。

## 生命周期

- App launch 时，如果 MCP enabled，则启动 helper。
- Toggle off 时停止 helper。
- App quit 时停止 helper。
- helper crash 后 App 自动重启一次。
- helper 第二次失败时，Settings 显示 `Failed`。
- 固定端口 `17373` 被占用时，不自动换端口，Settings 显示 `Port unavailable`。

第一版不要求用户机器预装 Node.js。Node/helper runtime 随 Seahorse App 打包。

## 安全模型

第一版安全模型是本机单用户：

- 只监听 `127.0.0.1`。
- 不支持局域网访问。
- 不做 OAuth。
- 不做多用户权限模型。
- 不提供 dangerous delete 权限。
- token 存 `UserDefaults` 是有意识的简化。

如果未来支持局域网访问、多用户或更高风险操作，应重新评估 token 存储和授权模型，优先迁移到 Keychain 或系统级授权。

## 错误处理

- 外部 token 错误：unauthorized。
- bridge 不可达：`Seahorse app unavailable`。
- 端口占用：`Port unavailable`。
- duplicate URL：validation error。
- category/tag id 不存在：validation error。
- bookmark id 不存在：not found。
- update 不允许字段：validation error。
- helper crash：自动重启一次，再失败显示 `Failed`。

## 测试要求

### App lifecycle

- Settings toggle on 会启动 helper。
- toggle off / App quit 会停止 helper。
- 端口 `17373` 被占用时显示 `Port unavailable`。
- helper crash 后自动重启一次，重复失败显示 `Failed`。

### MCP protocol smoke test

- 未带 token 调用 tools 返回 unauthorized。
- 带 token 能列出固定 tools。
- 只支持 `/mcp` Streamable HTTP endpoint。
- 不支持 stdio、旧 HTTP+SSE。

### Bookmark behavior

- `create_bookmark` 成功后 App UI 能看到新 bookmark。
- duplicate URL 返回 validation error。
- `update_bookmark` 只能改允许字段。
- 引用不存在的 category/tag 返回 validation error。
- `search_bookmarks` 返回摘要。
- `get_bookmark` 返回详情。
- create 后 metadata 异步解析，不阻塞 MCP response。

### Read-only taxonomy

- `list_tags` / `search_tags` 可用。
- `list_categories` / `search_categories` 可用。
- 没有 tag/category create/update/delete tools。
- 没有 bookmark delete tool。

## 第一版不做

- delete bookmark。
- tags/categories 写操作。
- image/text item MCP。
- helper 长期缓存或持久化索引。
- 直接读写 Seahorse JSON。
- LAN 访问。
- OAuth。
- Keychain token。
- 多用户权限模型。
- stdio transport。
- 旧 HTTP+SSE transport。
