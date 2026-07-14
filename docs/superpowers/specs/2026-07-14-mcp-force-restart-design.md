# MCP 强制重启设计

## 问题

MCP helper 可能在 Seahorse 退出后成为孤儿 Node 进程，继续占用固定端口 `17373`。当前 manager 只保存本次启动的 `Process`，无法停止旧实例；同时 `restart()` 在发送 terminate 后立即启动，存在端口尚未释放的竞争。

## 方案

- 设置页增加 `Force Restart` 按钮，并显示 `Restarting` 状态。
- 强制重启先停止当前受控 helper，等待退出；超时后强制终止。
- 仅查找命令行精确匹配当前 `MCPHelper/dist/index.js` 路径的 Node 进程，清理匹配的残留 helper；不终止仅仅占用 `17373` 的其他进程。
- 旧 helper 全部退出后重启 bridge 和 helper。
- helper 定时检查父进程；父 Seahorse 消失并被系统进程接管后，helper 主动退出，避免再次成为孤儿。
- termination handler 必须校验退出进程仍是 manager 当前持有的实例，避免旧进程的延迟回调清空新进程引用。

## 失败处理

- helper 脚本缺失或清理后仍无法启动时，状态回到 `Failed`。
- 非 Seahorse 进程占用固定端口时不强杀，保留失败状态供用户处理端口冲突。
- App 正常退出仍沿用现有 stop 流程。

## 验证

- Swift 构建和 MCP helper 测试、构建通过。
- 人工制造孤儿 helper 占用 `17373`，点击 `Force Restart` 后确认旧 PID 退出、新 helper 监听端口、状态变为 `Running`。
- 验证关闭父 Seahorse 后 helper 不再残留。
