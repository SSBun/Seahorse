# Workspace Context

## Components
- `MCPHelper/` 是 Seahorse 的 TypeScript/Node.js MCP 协议层，负责工具 schema、Streamable HTTP 和外部 token 鉴权。
- `Seahorse/Services/MCP/` 是 App 内 bridge，负责把 MCP action 转换为 `DataStorage` 操作。
- `Seahorse/Storage/DataStorage.swift` 是 bookmark、image、text 条目的统一内存与持久化入口。

## Relationships
- 外部 agent 调用 `MCPHelper` 工具后，由 helper 调用 App 内 HTTP bridge；真实数据读写只通过 `DataStorage` 完成。
- `AnyCollectionItem` 统一封装 `Bookmark`、`ImageItem` 和 `TextItem`，其 UUID 在 `DataStorage.items` 中用于定位条目。

## Domain
- Seahorse collection item 包含 `bookmark`、`image`、`text` 三种类型。
- tag 和 category 的 MCP 能力当前只读。

## Decisions and Conventions
- MCP server 仅监听本机固定端口，并使用 bearer token 鉴权。
- MCP helper 不直接读写 Seahorse JSON 存储。
- MCP 使用通用 `delete_item(id)` 删除 bookmark、image 或 text；tag 和 category 不提供写操作。
- 图片删除只允许作用于解析符号链接后仍位于 Seahorse `Images/` 目录内的文件。
