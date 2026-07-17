# 书签富化与链接健康修复方案

> 状态：已确认（2026-07-17）

## 结论

当前界面中的大量警告不是大量死链，而是“富化失败”。最主要的确定性故障是分类、标签名称的查找与唯一性规则不一致；真正的死链检查又把无法确认的网络结果误判为失效链接。

建议拆成两个小修复：

1. 先统一分类与标签的名称解析，修复自动解析和批量解析两个入口，并把工具栏文案明确为“富化问题”。
2. 再把链接检查改成“可访问 / 无法确认 / 已失效”三类，避免把访问限制、限流或临时网络故障放进可批量删除的结果。

不建议新增工作流引擎、数据库迁移器或复杂自动重试系统。

## 已确认的本地证据

实际数据中有 286 个书签，其中 64 个持久化为富化失败：

| 错误 | 数量 |
|---|---:|
| `Item already exists` | 33 |
| 请求超时 | 18 |
| HTTP 429 | 5 |
| TLS 错误 | 3 |
| `NSURLErrorDomain -1011` | 2 |
| HTTP 403 | 2 |
| HTTP 404 | 1 |

其中 62 个失败书签已经保存网页元数据，说明链接和 OGP 抓取大多已经成功；工具栏只是读取 `failedBookmarkIDs` 并显示 `Enrichment Failed`，不是死链列表。

## 根因

### 1. 名称语义不一致

`AutoParsingService` 用大小写敏感的 `name == suggestedName` 查找分类与标签；`DataStorage` 和 `JSONStorage` 却用 `lowercased()` 判断名称唯一性。

例如已有标签 `AI`，模型返回 `ai`：

1. 富化服务认为标签不存在。
2. 服务尝试创建 `ai`。
3. 存储层认为 `AI` 与 `ai` 重复，抛出 `duplicateEntry`。
4. 整个书签被标记为 `.failed`，本地化错误为 `Item already exists`。

这能直接解释现有 33 个确定性失败。

### 2. 批量解析存在同源数据完整性问题

`BatchParsingService` 也进行大小写敏感查找。更严重的是，它用 `try?` 吞掉 `addTag` 的失败，却仍把新建但未持久化的 Tag UUID 加进书签，可能产生悬空引用。

因此只修 `AutoParsingService` 不够；两个入口必须复用同一套大小写不敏感查找语义。批量并发下，“查找后创建”还必须在同一个 `MainActor` 同步闭包内完成，避免两个任务同时认为标签不存在。

### 3. 部分成功被压成整体失败

当前流程依次执行 OGP、网页正文抓取、AI 解析、分类/标签写入；任一后续步骤抛错都会显示统一的 `.failed`。OGP 已经成功保存，但 UI 没有向用户说明书签仍可正常使用。

现有 `metadata`、`isParsed` 和 `enrichmentError` 已足够支撑首轮修复，不需要立即增加一组持久化阶段状态：

- `metadata != nil`：OGP 已成功。
- `isParsed == true`：AI 内容解析已成功。
- `.failed`：仅代表辅助富化未全部完成，不代表 URL 失效。

## HTTP 标准约束

RFC 9110 说明 `HEAD` 可用于测试超链接且不传输正文，但 `405` 只表示目标不支持当前方法，所以 `HEAD 405` 必须用 `GET` 复查，不能直接判为死链。[RFC 9110：HEAD](https://datatracker.ietf.org/doc/html/rfc9110#section-9.3.2)、[RFC 9110：405](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.6)

状态码应按以下语义处理：

| 结果 | 建议分类 | 依据 |
|---|---|---|
| 2xx、3xx | 可访问 | 请求已成功或资源可重定向 |
| 401、403 | 无法确认：访问受限 | 401 缺少有效凭据；403 是服务器理解但拒绝请求，并不证明资源不存在。[401](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.2)、[403](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.4) |
| 404 | 无法确认：当前未找到 | 标准明确说 404 不表示临时还是永久，也可能用于隐藏资源是否存在。[404](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.5) |
| 405、501 | 改用 GET 复查 | 表示方法不受支持，而不是资源失效。[405](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.6)、[5xx](https://datatracker.ietf.org/doc/html/rfc9110#section-15.6) |
| 410 | 已失效 | 表示资源不再可用且情况很可能是永久的。[410](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.11) |
| 429 | 无法确认：限流 | 429 表示请求过多，并可能携带 `Retry-After`。[RFC 6585：429](https://datatracker.ietf.org/doc/html/rfc6585#section-4) |
| 5xx | 无法确认：服务端临时故障 | 例如 503 明确可能是临时过载或维护。[RFC 9110：5xx](https://datatracker.ietf.org/doc/html/rfc9110#section-15.6) |
| timeout、DNS、断网、TLS | 无法确认：传输或安全错误 | `URLSession` 的传输失败只说明本次请求未完成，不能证明资源不存在。[Apple：URLSession.data(for:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data%28for%3Adelegate%3A%29)、[Apple：URLError](https://developer.apple.com/documentation/foundation/urlerror) |

TLS 或证书错误不能通过关闭验证来修复；HTTPS 客户端仍必须验证服务端身份。[RFC 9110：HTTPS 证书验证](https://datatracker.ietf.org/doc/html/rfc9110#section-4.3.4)

## 被否决的方案

| 方案 | 否决原因 |
|---|---|
| 有 OGP 就清除失败状态 | 会掩盖真实的 AI 或分类写入失败，且无法正确重试。 |
| 对全部失败无限重试 | 33 个重复名称错误会永久循环；429 会因重试风暴变得更严重。 |
| 只把查找改成大小写不敏感 | 必要但不充分；批量路径仍会吞写入错误并产生悬空 UUID。 |
| 只修自动解析队列 | 同源的批量解析路径仍然破坏数据引用。 |
| 把所有 4xx、5xx 和网络异常判为死链 | 与 HTTP 标准冲突，而且 UI 支持批量删除，误判有数据损失风险。 |
| 新增完整工作流引擎和数据库迁移 | 当前已有字段足以表达首轮产品语义，复杂状态机没有必要。 |

## 最小落地方案

### 修复 A：富化一致性

1. 在 `DataStorage` 增加大小写不敏感的 `category(named:)` 与 `tag(named:)` 查询，匹配现有存储唯一性规则。
2. `AutoParsingService` 和 `BatchParsingService` 都通过这两个查询复用已有对象。
3. 批量解析把“查询、必要时创建、返回真实 ID”放进同一个 `MainActor` 同步闭包；不再使用 `try?`，只有创建成功后才能写入 ID。
4. 保留已有富化状态模型；将工具栏改称“富化问题”，行内展示错误原因和重试操作，明确它不是死链列表。
5. 部署后只批量重试现有 33 个 `Item already exists`；其余网络失败保留为手动重试，避免一次性再次触发限流。

### 修复 B：链接健康检查

1. `BookmarkStatus` 增加“无法确认”状态，只有确定失效结果进入 `brokenBookmarks`。
2. 先发 `HEAD`；遇到 405 或 501 时用 `GET` 复查。GET 只需确认响应，不需要长期保存正文。
3. 401/403、404、429、5xx、timeout、DNS、网络和 TLS 错误进入“无法确认”；410 进入“已失效”。
4. 批量删除只允许选择“已失效”，不能默认包含“无法确认”。

两个修复应分别提交：富化修复解决截图中的大量警告；链接健康修复解决真正检查工具的误判与误删风险。

## 验收标准

- 已有 `AI` 标签且模型返回 `ai` 时，复用同一个 UUID，不新增标签，自动富化成功。
- 批量解析遇到同一大小写变体时，不吞错误、不写入不存在的 Tag UUID。
- 多个并发书签建议同一个新标签时，最终只有一个标签，全部书签引用真实 UUID。
- OGP 成功、AI 超时时，网页元数据继续保留，UI 显示“富化问题”而不是死链。
- 修复后重试现有 33 个重复名称失败，不重新抓取已经存在的 OGP 元数据。
- `HEAD 405 + GET 200` 判为可访问。
- 401、403、429、5xx、timeout 和 TLS 错误判为无法确认，不能进入批量删除集合。
- 410 判为已失效；404 显示当前未找到，但不声称永久失效。

## 已确认的产品决策

- AI 与分类/标签富化不是书签可用性的必要条件。只要 URL 已保存，书签就是可用记录；富化失败只能作为可重试的辅助问题，不影响书签健康或删除资格。
- HTTP 404 显示为“当前未找到”，但不进入可批量删除的失效链接集合；HTTP 410 才自动归为已失效。
- timeout、HTTP 429 和 5xx 等临时富化失败首版只允许手动重试，不增加后台自动重试；未来若增加自动重试，必须限制次数、退避并遵守 `Retry-After`。
- 修复发布后不自动重跑现有 `Item already exists` 记录；只提供用户主动触发的批量恢复，避免意外消耗 AI 请求额度或修改标题、摘要和标签。
- HTTP 401/403、429、5xx、timeout、DNS 和 TLS 错误统一归入独立的“无法确认”分组，并完全排除批量删除。
- 工具栏只显示富化问题数量并打开独立问题列表；列表展示错误原因、单条重试和用户主动触发的批量恢复，不再直接展开全部失败记录。
- 富化一致性与问题列表作为第一个独立提交；HTTP 三态链接健康检查作为第二个独立提交，分别测试和回滚。
