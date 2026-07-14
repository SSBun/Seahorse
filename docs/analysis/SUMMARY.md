# Seahorse 性能审计摘要

> 生成日期：2026-07-13
>
> 深度：全项目静态审计
>
> 路径：`/Users/caishilin/Desktop/personal/Seahorse`

## 总体判断

Seahorse 是 SwiftUI + AppKit 客户端，使用 `DataStorage` 作为 `@MainActor` 单一数据入口，并用 JSON 全文件持久化。列表 lazy 容器、缩略图下采样和 ID cache 已经存在；当前性能风险主要来自主线程的全量数据处理和全量 JSON 写放大。

## 前三项发现

1. **编辑卡顿根因**：标题/备注每个字符都立即进入同步数据库 barrier，并排队重写整个 `items.json`。本机当前文件约 438 KB、287 条，位于 iCloud Drive。
2. **搜索与 MCP 占用主线程**：macOS/iOS/MCP 都有全表过滤和排序；缓存失效过粗，iOS 还会在一次 body 重复计算。
3. **图片和文件 I/O actor 错位**：多处 View body 同步解码本地图片，列表图标显式同步读磁盘，粘贴/截图/导入导出/MCP 文件复制都可在主 actor 执行。

## 建议顺序

1. 先做编辑 draft/debounce、写入合并和可等待 flush。
2. 删除启动时的无条件全量重写。
3. 抽出 macOS/iOS/MCP 共享搜索核心，增加增量索引、取消和后台计算。
4. 将图片解码/编码、MCP CPU/I/O 和导入导出移出主 actor。
5. 增加批量事务后，再按 Instruments 数据处理排序键、动画和长文本等中优先级项。

## 报告索引

- `docs/analysis/performance-audit.md`：完整证据、优先级、最小修复方向、基准与失败模式。
- `docs/analysis/repo-map.md`：性能审计使用的组件边界、数据流和热路径地图。
