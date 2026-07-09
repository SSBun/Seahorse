# 更新日志

本文档记录 Seahorse App 的用户可见变更。

## [Unreleased]

- 暂无。

## [1.7.0] - 2026-07-09

### 新增

- 新增本机 MCP Server，可让本机 agent 通过 `http://127.0.0.1:17373/mcp` 访问 Seahorse。
- 新增 MCP Settings，可启用/停用 MCP Server、查看连接 URL、复制 token、重新生成 token。
- 新增 MCP bookmark 工具：`search_bookmarks`、`get_bookmark`、`create_bookmark`、`update_bookmark`。
- 新增只读 tag/category MCP 工具：`list_tags`、`search_tags`、`list_categories`、`search_categories`。
- 新增 MCP helper 构建脚本和 smoke test 脚本。

### 改进

- 优化主窗口搜索性能，避免编辑搜索文本时反复全量构造搜索字符串和线性扫描 tag。

### 说明

- 第一版 MCP 仅绑定本机地址，不支持局域网访问。
- 第一版 MCP 不提供 bookmark delete，也不提供 tag/category 写操作。

## [1.6.0] - 2026-07-08

### 新增

- 新增移动端 bookmark 页面同步相关能力。

### 移除

- 移除旧的浏览器书签同步实现。

[Unreleased]: https://github.com/SSBun/Seahorse/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/SSBun/Seahorse/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/SSBun/Seahorse/releases/tag/v1.6.0
