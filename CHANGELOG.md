# 更新日志

本文档记录 Seahorse App 的用户可见变更。

## [Unreleased]

## [1.13.0] - 2026-07-24

### 新增

- Advanced Settings 新增重复书签处理开关；开启后再次采集已有链接会刷新原书签的添加时间，并在默认 Newest 列表中移到第一位。
- 新增低开销的本地列表性能诊断日志，可关联筛选、滚动、图片加载与数据发布，且不记录书签内容。

### 改进

- 快速滚动时保留已经显示的海报、缩略图和 favicon，只暂停尚未开始或仍在等待的图片请求，滚动停止后自动恢复。
- 网络请求直接继承 macOS 的系统代理与 VPN 配置，不再写入不完整的自定义代理字典。

### 修复

- 重复采集书签时不再静默无响应；未刷新与已刷新使用不同的 toast、系统通知和反馈音。

## [1.12.1] - 2026-07-21

### 说明

- 本版本不包含产品功能变更，仅用于验证从 `1.12.0` 通过 Sparkle 检查、下载、验签并安装更新的完整链路。

## [1.12.0] - 2026-07-21

### 新增

- 新增 Sparkle 2 自动更新，支持在 App 内检查、下载、验签、安装并重启到新版本。

### 改进

- Advanced Settings 的更新入口改用 Sparkle 标准流程，并建立 EdDSA 签名的 GitHub Pages appcast feed。

## [1.11.0] - 2026-07-19

### 新增

- Agent 聊天改为独立、可调整尺寸的 macOS 窗口，不再占用主内容区域。

### 改进

- Agent 回复支持系统 Markdown 富文本，消息气泡、输入区和书签结果卡片使用更清晰的原生 macOS 布局。

### 修复

- Codex Agent 遇到临时 429、5xx、网络或流错误时最多重试一次；400、401、额度耗尽和取消保持单次请求，失败尝试不会重复工具调用。

## [1.10.0] - 2026-07-18

### 新增

- 新增内置多 Provider Agent、持久化封面生成工作流，以及 Smart Collections 和回收站管理。
- 新增标准化 AI 书签解析：统一分类与标签规则、逐字段差异确认、真实解析阶段和失败重试。
- 富化问题列表支持打开详情、跳转浏览器，并可经确认将书签移入回收站。
- 新增 `@ssbun/seahorse` npm 安装入口，用于下载并打开对应版本的 GitHub Release DMG。

### 改进

- 书签查看与编辑统一到详情页，卡片和列表的编辑与 AI Parse 入口共用同一流程。
- 链接诊断区分可访问、无法确认与已失效，避免将限流、权限或 TLS 错误误判为死链。
- 自定义分类删除会先把所有类型条目迁移到 None，避免产生悬空引用。

### 修复

- 核心 JSON 损坏时从跨文件一致的 last-good 快照恢复；无法恢复时进入只读，防止覆盖用户数据。
- 修复自定义存储目录解析失败导致已生成封面无法显示或打开的问题。

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

[Unreleased]: https://github.com/SSBun/Seahorse/compare/v1.13.0...HEAD
[1.13.0]: https://github.com/SSBun/Seahorse/compare/v1.12.1...v1.13.0
[1.12.1]: https://github.com/SSBun/Seahorse/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/SSBun/Seahorse/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/SSBun/Seahorse/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/SSBun/Seahorse/compare/v1.7.0...v1.10.0
[1.9.0]: https://github.com/SSBun/Seahorse/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/SSBun/Seahorse/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/SSBun/Seahorse/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/SSBun/Seahorse/releases/tag/v1.6.0
