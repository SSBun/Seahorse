# API 接口面分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 概览

| 指标 | 值 |
|---|---|
| 接口总量 | 15 个可调用操作：11 个 MCP tools、`/mcp` 的 3 个 method/path 组合、`/bridge` 的 1 个内部 method/path 组合 |
| 协议 | MCP Streamable HTTP（JSON-RPC）、内部 JSON over HTTP、macOS/iOS 系统输入事件 |
| 鉴权方式 | 两个独立的固定 Bearer token：外部 MCP token 与内部 bridge token |
| API 版本 | 无 URL/schema 版本；MCP SDK 协议协商，helper 固定宣告 server version `0.1.0` |

Seahorse 不是 Web 后端，也没有 REST 资源 API、GraphQL schema、gRPC、WebSocket 或公开 Swift library。唯一面向外部自动化客户端的集成面，是用户显式启用后监听 `127.0.0.1:17373` 的 MCP server；它通过只监听 `127.0.0.1:17374` 的私有 bridge 操作 App 内 `DataStorage`。源码证据集中在 `MCPHelper/src/index.ts:10-65`、`MCPHelper/src/tools.ts:52-83`、`Seahorse/Services/MCP/MCPBridgeServer.swift:17-29` 和 `Seahorse/Services/MCP/MCPBookmarkBridgeService.swift:191-218`。

### 接口边界分类

| 边界 | 分类 | 说明 |
|---|---|---|
| `http://127.0.0.1:17373/mcp` | **对外但仅本机** | 本机 agent 可持外部 token 接入；不监听 LAN，也不是互联网公开 API。 |
| 11 个 MCP tools | **对外但仅本机** | 当前真正给 agent 使用的功能契约。 |
| `http://127.0.0.1:17374/bridge` | **私有内部接口** | 只供 App 启动的 Node helper 调用；使用不同 token，不应作为第三方集成面。 |
| `MCPBookmarkBridgeService`、`DataStorage` 等 Swift 类型 | **App 内部 API** | 工程没有 library/framework target，且 Swift 声明未标记 `public`；不是可发布的 SDK。 |
| GitHub、AI provider、网页、图片请求 | **出站 API 消费** | Seahorse 是调用方，不是这些 endpoint 的提供者。 |
| 剪贴板、拖放、文件面板、状态栏、键盘命令 | **系统/UI 输入** | 是用户输入边界，不是网络 API。 |
| `NotificationCenter` 事件名 | **进程内事件** | 只在 App 内部发布/订阅，不是跨进程通知协议。 |

## 身份验证与授权

### 外部 MCP token

- `MCPSettings` 首次初始化时生成 32 个随机字节并 Base64 编码；若 `SecRandomCopyBytes` 失败，则回退为两个 UUID 拼接。源码：`Seahorse/Services/MCP/MCPSettings.swift:46-72`。
- token 以 `seahorse.mcp.externalToken` 明文保存在 `UserDefaults`，设置页允许复制 header 或重新生成。重新生成会重启 helper，使新 token 生效。源码：`MCPSettings.swift:26-27,42-55`、`MCPSettingsSectionView.swift:45-61`。
- App 启动 helper 时通过 `SEAHORSE_MCP_TOKEN` 环境变量注入；helper 对进入 `/mcp` 的每个请求执行精确的 `Authorization: Bearer <token>` 比较。源码：`MCPHelperManager.swift:192-199`、`MCPHelper/src/index.ts:10,28-37`。
- 初始化成功后，SDK 生成随机 MCP session ID；后续 GET/DELETE 必须带 `mcp-session-id`，已有 session 的 POST 也按该 header 路由。session ID 只标识 transport 会话，不替代 Bearer 鉴权。源码：`MCPHelper/src/index.ts:44-55,76-109`。
- token 没有过期时间、refresh、设备绑定或撤销列表；生命周期是“持久化直到用户重新生成”。

### 内部 bridge token

- `MCPSettings` 单独生成并持久化 `internalToken`，以 `SEAHORSE_BRIDGE_TOKEN` 注入 helper。外部 token 与内部 token 不复用。源码：`MCPSettings.swift:30-31,43-60`、`MCPHelperManager.swift:195-197`。
- `BridgeClient` 对每个 `/bridge` POST 带内部 Bearer token；Swift bridge 在解码 body 前执行精确匹配。源码：`MCPHelper/src/bridgeClient.ts:26-34`、`MCPBridgeServer.swift:172-185`。

### 授权模型

- 没有用户、角色、scope 或逐工具权限。持有外部 token 即可调用全部 11 个工具，包括 `delete_item`、`delete_tag` 和可读取本地文件的 `update_bookmark.posterImagePath`。
- `destructiveHint: true` 只标记 `delete_item` 与 `delete_tag`，用于告知 MCP client 其破坏性；它不是服务端授权或确认机制。源码：`MCPHelper/src/tools.ts:58,61`。
- 没有速率限制。当前 loopback 绑定降低了远程攻击面，但 token 泄露给本机其他进程后没有权限降级手段。
- AI API token 是另一套出站凭据，由用户配置并明文保存在 `UserDefaults`；它不参与 Seahorse MCP 鉴权。源码：`Seahorse/Models/AISettings.swift:15-30,63-78,105-114`。

## 接口清单

### 本机 MCP transport：`127.0.0.1:17373/mcp`

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/mcp` | 外部 Bearer token；已有会话还需 `mcp-session-id` | 创建 MCP 会话，或向既有会话发送 JSON-RPC 请求。没有 session 时只接受 initialize request。 |
| GET | `/mcp` | 外部 Bearer token + `mcp-session-id` | 交给 MCP Streamable HTTP transport 处理既有会话的服务端消息流。 |
| DELETE | `/mcp` | 外部 Bearer token + `mcp-session-id` | 交给 transport 关闭既有 MCP 会话。 |

其他 path 返回 404，其他 method 返回 405。helper 固定绑定 `127.0.0.1`，默认端口 `17373`；端口可由 App 注入的 `SEAHORSE_MCP_PORT` 覆盖，但当前 UI 和 App 设置使用固定值。源码：`MCPHelper/src/index.ts:12-14,28-65`、`MCPSettings.swift:16-17,34-36`。

### MCP tools：书签与条目

| 方法 | 路径/工具名 | 鉴权 | 说明 |
|---|---|---|---|
| MCP tool | `search_bookmarks` | MCP 会话鉴权 | 搜索 bookmark；支持 `query`、`categoryId`、`tagIds`、`favoriteOnly`，以 `offset` + `limit` 分页。`limit` 为 1...100，bridge 默认 20；结果按最新优先返回摘要。 |
| MCP tool | `get_bookmark` | MCP 会话鉴权 | 按 UUID 返回单个 bookmark 详情；不存在或不是 bookmark 时返回 `not_found`。 |
| MCP tool | `get_bookmarks` | MCP 会话鉴权 | 接受 1...100 个 UUID 并批量返回详情；当前实现会静默省略不存在或非 bookmark 的 ID。 |
| MCP tool | `create_bookmark` | MCP 会话鉴权 | 创建 bookmark；必填 `url`，可选 title、notes、categoryId、tagIds、isFavorite。先返回保存结果，再异步抓取网页 metadata。 |
| MCP tool | `update_bookmark` | MCP 会话鉴权 | 更新 title、url、notes、categoryId、tagIds、favorite；也可设置远程 `posterImageURL`，或从本地 `posterImagePath` 复制图片到 Seahorse Images 存储。 |
| MCP tool | `delete_item` | MCP 会话鉴权；标注 destructive | 按 UUID 删除任意 collection item，不限 bookmark，也可删除 image 或 text。 |

工具 schema 由 Zod 在 helper 层校验，业务存在性和关联约束再由 Swift bridge 校验。源码：`MCPHelper/src/tools.ts:6-46`、`MCPBookmarkBridgeService.swift:222-444`。

### MCP tools：标签与分类

| 方法 | 路径/工具名 | 鉴权 | 说明 |
|---|---|---|---|
| MCP tool | `list_tags` | MCP 会话鉴权 | 返回全部 tag。 |
| MCP tool | `search_tags` | MCP 会话鉴权 | 按不区分大小写的 substring 搜索 tag name；空 query 返回全部。 |
| MCP tool | `delete_tag` | MCP 会话鉴权；标注 destructive | 按 UUID 删除 tag；底层 `DataStorage.deleteTag` 先清除三类 item 的 tag 关联。 |
| MCP tool | `list_categories` | MCP 会话鉴权 | 返回全部 category。 |
| MCP tool | `search_categories` | MCP 会话鉴权 | 按不区分大小写的 substring 搜索 category name；空 query 返回全部。 |

当前没有创建/更新 tag 的工具，也没有任何 category 写工具。工具注册证据：`MCPHelper/src/tools.ts:52-63`；bridge action 分派证据：`MCPBookmarkBridgeService.swift:191-218`。

### App 内部 bridge：`127.0.0.1:17374/bridge`

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/bridge` | 内部 Bearer token | 接收 `{action, payload}`，将与 11 个 MCP tool 同名的 action 分派给 `MCPBookmarkBridgeService`，并返回 `{ok, result, error}`。 |

bridge 使用手写的最小 HTTP/1.1 解析器，只接受 POST 与精确路径 `/bridge`，最大累计 buffer 为 1 MiB；每个请求处理后关闭连接。非 POST、错误 path、错误 token 和过大请求分别返回 405、404、401、413。源码：`Seahorse/Services/MCP/MCPBridgeServer.swift:104-209`。

该 route 是 helper 与 App 之间的实现细节，不应被第三方直接调用：端口、action envelope、错误码和 token 生命周期都没有公开兼容承诺。

### 系统输入入口（非网络 API）

| 输入 | 平台/权限 | 接受内容 | 行为 |
|---|---|---|---|
| 全局双击复制监控 | macOS；Accessibility/Input Monitoring | `Cmd+C` 后的 URL、文本、图片 | `CGEventTap` 监听全局按键，在 0.2...5 秒窗口内检测相同内容二次复制，交给 `PasteHandler` 保存。源码：`CopyMonitor.swift:95-152,173-261`。 |
| App 内 Paste | macOS SwiftUI paste command | URL、图片、纯文本 | 根据 URL scheme/扩展名创建 bookmark、image 或 text。源码：`ContentView.swift:348-350`、`PasteHandler.swift:26-214`。 |
| 主界面 Drop | macOS drag and drop | URL、image、plain text、file URL、内部 item UUID | 外部内容走 `PasteHandler`；内部 UUID 用于 item 操作。源码：`ContentView.swift:143-145,395-399`。 |
| 侧边栏分类 Drop | macOS drag and drop | App 内 item UUID | 将 bookmark/image/text 改到目标 category；这是 App 内拖放协议，不是外部导入格式。源码：`SidebarView.swift:44-59,136-169`。 |
| 详情预览图 Drop | macOS drag and drop | image data 或本地 file URL | 将图片保存/复制到 Images 目录并设为 bookmark preview。源码：`ItemDetailView.swift:573,645-710`。 |
| 书签文件导入 | macOS `NSOpenPanel` | JSON、HTML、HTM | 解析浏览器/Seahorse bookmark 文件并导入。源码：`ImportBookmarksView.swift:191-216`。 |
| 完整数据导入 | macOS `NSOpenPanel` | Seahorse export folder | 加载 items/categories/tags 和图片并合并；UI 文案提到 JSON file，但实现只接受目录。源码：`ExportImportManager.swift:265-310`。 |
| 数据/存储目录选择 | macOS `NSOpenPanel` + security-scoped bookmark | 用户选择的目录 | 作为导出目标或迁移后的存储位置。源码：`ExportImportManager.swift:212-263`、`StoragePathManager.swift:94-168`。 |
| 完整数据导入 | iOS `fileImporter` | ZIP 或 folder | 获取 security-scoped access 后解压或从目录导入。源码：`iOSSettingsView.swift:60-90`。 |
| 状态栏与键盘命令 | macOS UI | 菜单点击、`Cmd+Shift+I` 等 | 打开 App、添加条目、导入、设置、批量解析或退出；事件通过 UI/`NotificationCenter` 传递。源码：`SeahorseApp.swift:69-80`、`StatusBarManager.swift:103-209`。 |

源码未定义 URL scheme、Universal Link、`onOpenURL`、App Intent 或命令行参数入口。系统通知点击回调当前只调用 completion，不执行导航或数据动作；因此这些也不构成隐藏的外部 API。源码：`NotificationService.swift:168-175`。

## 请求/响应格式

### MCP transport 与 tool 格式

- `/mcp` 使用 MCP SDK 的 Streamable HTTP/JSON-RPC 格式；initialize 后以 `mcp-session-id` 关联会话。
- 工具输入由 `z.object(...)` 校验。UUID、数组长度、整数范围等在 helper 层拒绝，随后 bridge 再校验 category/tag 是否存在及数据写入结果。
- 每个工具把 bridge `result` 再 `JSON.stringify`，作为单个 MCP `text` content 返回；当前没有 `structuredContent` 或 `outputSchema`。源码：`MCPHelper/src/tools.ts:66-83`。
- `search_bookmarks` 返回裸数组分页，没有 `total`、`hasMore` 或 next cursor；日期为 ISO 8601，ID 为 UUID string。

### 成功响应

MCP tool 的逻辑结果被编码为文本内容；以下仅展示无真实数据的结构：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"id\":\"<uuid>\",\"title\":\"<title>\"}"
    }
  ]
}
```

内部 bridge 的成功 envelope：

```json
{
  "ok": true,
  "result": {},
  "error": null
}
```

### 错误响应

bridge 业务错误使用稳定 code + message，并统一以 HTTP 400 返回：

```json
{
  "ok": false,
  "result": null,
  "error": {
    "code": "validation_error",
    "message": "<safe message>"
  }
}
```

已出现的业务 code 包括 `validation_error`、`not_found`、`delete_failed` 和 `unknown_action`。但 `BridgeClient` 只把 message 转成抛出的 JavaScript `Error`，没有把 code 传递到最终 MCP tool result；外部客户端不能稳定地按错误类型分支。源码：`MCPHelper/src/bridgeClient.ts:36-41`。

path、method、token、session 或 body 解析失败时，HTTP 层返回简单 `{ "error": "..." }`，不使用上述 bridge envelope。helper 的 `readJSON` 会把完整 request body 读入内存，当前没有显式 body size 上限；只有内部 Swift bridge 有 1 MiB buffer 限制。

## 中间件栈

项目未使用 Express/Hono 等 Web middleware 框架；请求处理顺序直接写在两个 server 中。

| 顺序 | 中间件/处理阶段 | 目的 |
|---:|---|---|
| 1 | loopback listener | 两个 server 只绑定 `127.0.0.1`，拒绝 LAN 直接连接。 |
| 2 | `/mcp` path 精确匹配 | 非 `/mcp` 请求立即返回 404。 |
| 3 | 外部 Bearer token 比较 | 在 method、session 和 body 处理前拒绝未授权 MCP 请求。 |
| 4 | HTTP method + session 检查 | POST 进入 body 处理；GET/DELETE 必须引用已知 session；其他 method 返回 405。 |
| 5 | JSON body 读取 | POST 聚合 body 并 `JSON.parse`；没有显式 size limit。 |
| 6 | MCP transport/session | 只允许 initialize 创建 session，或把请求路由到现有 Streamable HTTP transport。 |
| 7 | Zod tool input schema | 校验 UUID、数组长度、分页范围及可选字段。 |
| 8 | `BridgeClient` | 将 tool name 和 args 转换为内部 `/bridge` POST，并带内部 token。 |
| 9 | bridge method/path/token/size | Swift server 验证 POST、`/bridge`、内部 Bearer token 和 1 MiB 上限。 |
| 10 | bridge JSON decode + action dispatch | 解码 `{action,payload}`，执行业务校验和 `DataStorage` 操作，编码响应。 |

未实现请求日志中间件、CORS、压缩、CSRF、rate limit、审计日志或 tool 级授权。对当前 loopback-only 服务，CORS/CSRF 并非首要缺口；若未来监听局域网，则 TLS、速率限制与权限模型必须在扩大监听范围前完成。

## 外部 API 消费

| 服务 | 用途 | 协议 | 鉴权 |
|---|---|---|---|
| GitHub Releases API | 检查 `SSBun/Seahorse` 最新 release | HTTPS GET `/repos/SSBun/Seahorse/releases/latest`；GitHub API version `2022-11-28` | 无 token；User-Agent + Accept header。源码：`UpdateManager.swift:71-112`。 |
| OpenAI-compatible Chat API | 测试连接、网页摘要、标题优化、分类/标签/图标建议、Agent 搜索 | 用户可配置 base URL，默认 `https://api.openai.com/v1`；OpenAI Swift SDK chat completion | 用户 API token 交给 SDK；仓库不手写 Authorization header。源码：`AISettings.swift:105-113`、`AIManager.swift:76-135,271-367,517-539`。 |
| OpenAI-compatible Image API | 生成 bookmark cover | 用户可配置 image base URL/model；OpenAI Swift SDK image generation | 共享或独立的用户 API token。源码：`AIManager.swift:369-458`。 |
| 用户收藏的网页 | OpenGraph metadata 与 AI 网页内容抓取 | 对用户提供 URL 发 HTTPS/HTTP GET，浏览器式 User-Agent，10/15 秒业务超时 | 无显式 header；`NetworkManager` 启用系统 cookie/credential store 与系统代理。源码：`OpenGraphService.swift:15-40`、`AIManager.swift:138-186`、`NetworkManager.swift:15-53`。 |
| 网站 favicon | 探测 `/favicon.ico`、`.png`、Apple touch icon | 对收藏网站发 GET | 无显式鉴权。源码：`AIManager.swift:235-269`。 |
| Bookmark 健康检查 | 判断失效链接 | 对每个 bookmark URL 发 HEAD | 无显式鉴权。源码：`DiagnosticService.swift:176-248`。 |
| 远程图片 URL | 添加/预览 image、bookmark poster、下载 AI 生成图 | URLSession、SwiftUI `AsyncImage`、Kingfisher 发 GET | 通常无显式鉴权；URL 由用户数据或 AI 响应提供。源码：`AddImageView.swift:289-317`、`ItemDetailView.swift:589-623`、`AIManager.swift:496-515`。 |
| Bookmark 网页预览 | 在详情页加载真实网页 | `WKWebView` GET 及网页自身后续请求 | WebKit 自身 cookie/session；Seahorse 不注入 API token。源码：`ControllableWebView.swift:19-51`、`iOSWebView.swift:13-22`。 |
| Google favicon service | 导出的移动 bookmark HTML 缺失 favicon 时使用 | 最终用户浏览器访问 `https://www.google.com/s2/favicons` | 无鉴权；不是 Seahorse App 进程直接请求。源码：`ExportImportManager.swift:801`。 |

出站 AI base URL、bookmark URL、poster/image URL 大多来自用户输入；`Info.plist` 还设置了 `NSAllowsArbitraryLoads = true`。因此这些 URL 是实际 trust boundary，不能视作内部常量。

## 建议

1. **先修正公开契约与产品文案。** MCP 设置页仍显示“bookmark-only、does not expose delete tools”，但实际已有通用 `delete_item` 和 `delete_tag`；应立即让 UI/README 与真实工具集一致，并明确 `posterImagePath` 会读取本地文件。源码偏差：`MCPSettingsSectionView.swift:71-73` 对比 `MCPHelper/src/tools.ts:58-61`。
2. **把 token 移到 Keychain。** AI token、外部 MCP token、内部 bridge token 当前都明文存于 `UserDefaults`。迁移时保留一次性兼容读取并删除旧值；不要把 token 纳入数据导出。
3. **提供最小的只读 MCP 模式。** 当前一个 token 同时获得搜索、写入、删除和本地图片路径能力。无需设计完整 RBAC；增加 read-only 开关或单独只读 token，并在服务端拒绝 write/destructive tools，即可覆盖大多数 agent 使用场景。
4. **收紧 MCP 入站和出站校验。** 给 `/mcp` body 增加与 bridge 一致的大小上限；`create_bookmark.url`、`update_bookmark.url` 至少限制为 HTTP/HTTPS，对由 MCP 自动触发的 metadata fetch 明确 localhost/private-network 策略；`posterImagePath` 应保留现有复制语义，但在 tool 描述中声明本地文件权限边界。
5. **让 tool 输出机器可读。** 为 11 个 tools 补 description、`outputSchema`/`structuredContent`，保留稳定错误 code，不要只返回 JSON 字符串或丢弃 bridge error code；同时让 `get_bookmarks` 明确返回 missing IDs，分页返回 `hasMore` 或 next offset。
6. **把 server version 与 App 契约同步。** helper 固定报告 `0.1.0`，App 已是 `1.9.0`。最小做法是构建时注入 App/MCP contract version 并记录兼容变更；在真正出现破坏性变更前，无需新增 `/v1` route。
7. **暂不为 loopback 服务增加 CORS、复杂限流或角色系统。** 当前监听范围不需要这些复杂度；但任何 LAN/远程访问功能都必须先加 TLS、速率限制、token scope/撤销和安全审计，不能只把 host 从 `127.0.0.1` 改为 `0.0.0.0`。
