# Seahorse 项目分析

> 生成日期：2026-07-15
>
> 深度：standard
>
> 路径：`/Users/caishilin/Desktop/personal/Seahorse`

## 执行摘要

Seahorse 是一款本地优先的 macOS/iOS 素材收藏工具，支持 Bookmark、Image 和 Text 三类条目，并通过粘贴/拖放、全局双击复制、AI 整理、链接诊断、导入导出及本机 MCP 完成采集与管理。主体采用 SwiftUI + AppKit/UIKit、`DataStorage` 集中式 Observable Store 和 JSON 文件持久化；macOS 另带一个 TypeScript/Node MCP sidecar。

项目整体健康度为**中等**：约 23K 行 Swift 的单 target 架构仍能清晰交付功能，三端共享搜索和统一数据门面是明显优势，近期也已有搜索、JSON、图片与 MCP 测试。但“内存已接受”与“磁盘已落盘”的成功语义不一致，跨 JSON/Images 操作无事务且没有 schema migration；发布 CI 又存在产物路径、签名/notarization、隐式 Node runtime 和最低系统版本承诺冲突。这些问题在继续增加 destructive 自动化或同步之前必须收敛。

### 三项主要风险

1. **数据完整性与恢复能力不足。** JSON 只有单文件原子写，写盘失败只记日志；分类/标签导入与删除会产生悬空引用，结构解码失败缺少恢复流程，条目删除也没有回收站。
2. **发布链不能证明可交付。** workflow 的 artifact glob 与实际 `dist/` 产物不匹配，Release 不运行测试/smoke，DMG 未做 Developer ID 签名和 notarization，MCP 还隐式依赖用户机器 Node。
3. **对外能力扩大快于安全边界。** 单一 MCP token 同时拥有读写、删除和本地图片路径能力，AI/MCP token 明文保存在 UserDefaults；自动 OGP 与 AI 解析还可能竞态覆盖或漏处理新增项。

### 三项主要优势

1. **真实数据所有权清楚。** UI、AI、导入和 MCP 最终都经 `DataStorage`/`DatabaseProtocol`，Node helper 保持为薄协议适配层，不直接触碰 JSON。
2. **核心能力有效复用。** macOS、iOS 与 MCP 共用 `CollectionSearch`，URL 唯一性最终由 JSONStorage 校验，图片文件删除有内部目录和符号链接边界保护。
3. **当前架构足以继续演进。** 单 target、JSON 和少量 actor 在当前规模合理；已有可注入 MockDatabase、writeData、BridgeClient，以及搜索/性能/图片/MCP 测试，不需要先做框架化或更换数据库。

## 项目快照

| 维度 | 值 |
|---|---|
| 语言 | Swift 5.0、TypeScript 5.9、HTML/CSS/JavaScript、Shell、Ruby/Jekyll |
| 框架 | SwiftUI、AppKit/UIKit、Foundation、OpenAI、Kingfisher、Highlightr、ZipArchive、MCP SDK、Zod |
| 主要数据存储 | 本地 Codable JSON + Images 文件目录 + UserDefaults；无数据库/ORM |
| 构建系统 | Xcode/xcodebuild + SwiftPM；npm/tsc；Bundler/Jekyll；shell DMG 脚本 |
| CI/CD | GitHub Actions：tag/手工 DMG、GitHub Pages；Release 流水线目前不闭合 |
| 贡献者 | 85 个 HEAD 提交；CSL 61、Silas 23、GitButler 1；bus factor 约 2 |
| 最新版本 | 源码/CHANGELOG 为 1.9.0（build 8）；最新 Git tag 仍为 `v1.7.0` |
| 许可证 | 仓库未发现项目级 LICENSE/COPYING；第三方依赖以 MIT 等宽松许可证为主 |

## 分析索引

| 主题 | 关键发现 | 详细报告 |
|---|---|---|
| 项目结构 | 101 个 Swift 文件/22,906 行；分层模块化单体 + Node sidecar，12 个 Swift 文件 ≥500 行 | [project-structure.md](project-structure.md) |
| 依赖 | 11 个一级依赖；Node audit 0 告警，6 个一级依赖有更新，Jekyll 缺锁文件 | [dependencies.md](dependencies.md) |
| 开发历史 | 85 个提交、19 个标签、两位主要贡献者；当前 tag 落后 1.9.0 源码 | [development-history.md](development-history.md) |
| 构建与部署 | artifact 路径不匹配；未签名/notarize；MCP runtime 与系统版本承诺不闭合 | [build-and-deploy.md](build-and-deploy.md) |
| 架构 | 集中式 Store/MVVM 风格清晰，但 DataStorage 过宽、写入成功语义与路径职责分散 | [architecture.md](architecture.md) |
| 数据流 | OGP/AI 有竞态与漏任务；导入缺少 ID 重映射/回滚；普通/Agent 搜索字段不一致 | [data-flow.md](data-flow.md) |
| 核心流程 | 采集—富化—检索链完整，但删除不可恢复，iOS 只是导入浏览而非实时同步 | [process-analysis.md](process-analysis.md) |
| API 接口面 | 11 个本机 MCP tool + 私有 bridge；单 token 全权限且错误/输出契约偏弱 | [api-surface.md](api-surface.md) |
| 数据模型 | 4 个 JSON 集合，无 schema version/外键；导入和分类删除可能留下悬空 UUID | [data-model.md](data-model.md) |
| 安全 | standard 深度未单独分析；API/架构报告已记录 token、日志与 MCP 权限边界 | 未分析 |
| 质量 | standard 深度未单独分析；已有 9 个 Swift 测试文件和 2 个 Helper 测试文件 | 未分析 |
| 下一版本功能 | 建议 1.10.0 只交付智能集合与回收站，Share Extension/OCR 后置 | [next-version-features.md](next-version-features.md) |

既有补充报告：[performance-audit.md](performance-audit.md) 记录 2026-07-13 性能审计；[repo-map.md](repo-map.md) 是该审计使用的仓库地图。

## 建议

1. **以“智能集合 + 回收站”作为 1.10.0 的完整产品范围。** 前者复用现有搜索核心解决资料增长后的找回问题，后者统一 UI、批量诊断和 MCP 删除的安全语义；不要把 Share Extension、OCR、同步和更多 MCP 写工具同时塞入。
2. **先建立轻量 schema migration 和统一 mutation 结果。** 对外成功必须可确认落盘；分类/标签引用、导入 ID 重映射、图片清理和破损 JSON 恢复应有一个一致提交边界，无需因此迁移 SQLite。
3. **修复发布链并证明安装包可用。** 对齐 `dist/` artifact、运行 Swift/Helper/DMG/MCP 验证，完成 Developer ID 签名和 notarization，解决 Node runtime 与 macOS 13/15.2 宣称冲突。
4. **收紧联网与自动化边界。** AI/MCP token 迁入 Keychain，MCP 提供最小只读模式，logger 默认保护 URL/路径/token；同时把 OGP + AI 收敛成按 item ID 串行、可重试的富化流程。
5. **后续按依赖关系推进能力。** 本地模型稳定后先做系统 Share Extension，再做 Vision OCR；“重新发现”先用原型验证；真正跨设备同步必须作为包含冲突与 tombstone 设计的独立大版本。
