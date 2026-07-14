# MCP 强制重启实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户从设置页安全清理 Seahorse 残留 helper 并强制重启 MCP 服务。

**Architecture:** `MCPHelperManager` 异步停止受控进程，并从 `ps` 输出中只匹配命令为 `node <当前 helper 路径>` 的残留进程；全部退出后再启动 bridge 和 helper。Node helper 监测父 PID 变化，避免父 App 消失后继续占用端口。

**Tech Stack:** Swift 5、SwiftUI、Foundation `Process`、Darwin signals、Node.js。

## Global Constraints

- 不终止命令行不匹配当前 helper 脚本的进程。
- 不新增第三方依赖，不改变 MCP URL、端口或工具协议。
- 保留当前未提交的语言选择器左对齐改动。

---

### Task 1: 安全清理 helper 进程

**Files:**
- Modify: `Seahorse/Services/MCP/MCPHelperManager.swift`
- Modify: `Seahorse/Services/MCP/MCPSettings.swift`
- Test: `SeahorseTests/MCPHelperManagerTests.swift`

**Interfaces:**
- Produces: `func forceRestart() async`
- Produces: `static func matchingHelperProcessIDs(in:helperScriptPath:) -> [pid_t]`

- [ ] 先写测试，输入包含当前 helper、其他 Node 脚本和前缀相似路径的 `ps` 输出，只允许返回当前 helper PID。
- [ ] 运行 `xcodebuild test ... -only-testing:SeahorseTests/MCPHelperManagerTests`，确认因匹配函数缺失而失败。
- [ ] 实现精确命令匹配、TERM 等待、超时 KILL，以及旧 termination handler 的实例身份校验。
- [ ] 实现 `forceRestart()`：设置 `Restarting`、停止 bridge、清理 helper、重置重试计数并重新启动。
- [ ] 运行定向测试并确认通过。

### Task 2: UI 与孤儿预防

**Files:**
- Modify: `Seahorse/Views/Settings/MCPSettingsSectionView.swift`
- Modify: `MCPHelper/src/index.ts`
- Modify: `tasks/todo.md`
- Modify: `tasks/context.md`

**Interfaces:**
- Consumes: `MCPHelperManager.forceRestart()`

- [ ] 在设置页增加带 `arrow.clockwise` 的 `Force Restart` 按钮，服务关闭或正在重启时禁用。
- [ ] Node helper 每秒检查父 PID；父进程变化时退出。
- [ ] 运行 MCP helper 测试与 TypeScript build。
- [ ] 运行 macOS 全量测试、Debug build 和 `git diff --check`。
- [ ] 制造孤儿 helper 占用 `17373`，运行新 App 后点击 Force Restart，验证旧 PID 消失、新 PID 监听、状态为 Running。
