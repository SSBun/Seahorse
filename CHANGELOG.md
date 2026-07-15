# 更新日志

本文档记录 Seahorse App 的用户可见变更。

## [Unreleased]

## [1.9.0] - 2026-07-15

### 新增

- Advanced Settings 的 Updates 区域新增当前版本更新日志面板。
- 新增 destructive MCP `delete_tag`，支持按 UUID 删除 Tag。
- MCP Settings 新增 `Force Restart`，可安全清理残留 helper 并恢复本地服务。

### 改进

- App 异常退出后，MCP helper 会检测父进程并自行退出，避免孤儿进程长期占用端口。
- 删除 Tag 时统一清理 bookmark、image、text 三类条目中的关联。

### 修复

- 修复 Basic Settings 中语言选择菜单未左对齐的问题。
- 修复 DMG 未包含 MCP helper 生产运行文件、安装后只能依赖源码目录回退的问题。

## [1.8.0] - 2026-07-14

### 新增

- 新增 MCP `get_bookmarks`，支持按 UUID 批量读取 bookmark。
- 新增 MCP `delete_item`，支持按 UUID 删除 bookmark、image 或 text 条目。
- `update_bookmark` 支持使用远程 URL 或本地图片文件更新 poster image。

### 改进

- `search_bookmarks` 新增 `offset`，agent 可配合 `limit` 分页获取全部 bookmark。
- MCP 图片删除只会清理 Seahorse 内部 `Images` 目录中的文件，并拒绝相邻目录或符号链接逃逸路径。
- 优化搜索、JSON 持久化、图片处理、导入导出和批量操作性能。
- 侧边栏 tags 按本地化字母顺序展示。

### 修复

- 修复 MCP SDK 工具注册参数歧义导致的 `typedHandler is not a function`。

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

[Unreleased]: https://github.com/SSBun/Seahorse/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/SSBun/Seahorse/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/SSBun/Seahorse/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/SSBun/Seahorse/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/SSBun/Seahorse/releases/tag/v1.6.0
