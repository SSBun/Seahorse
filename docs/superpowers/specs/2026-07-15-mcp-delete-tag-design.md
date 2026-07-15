# MCP 删除 Tag 设计

## 目标

为 Seahorse MCP 新增 `delete_tag(id)`，允许 agent 删除 Tag。书签继续使用现有 `delete_item(id)`，不增加重复的 `delete_bookmark`。

## 方案

采用独立 `delete_tag` 工具，并把级联清理收敛到 `DataStorage.deleteTag`。相比在 MCP bridge 中单独清理，这能让设置界面、详情界面和 MCP 使用同一删除语义；相比新增通用资源删除工具，改动更小且不会扩大现有 MCP 契约。

未采用以下方案：

- 新增 `delete_bookmark`：与 `delete_item` 功能重复。
- 新增 `delete_resource(type, id)`：当前只有 Tag 缺少删除能力，通用化没有实际收益。

## 数据流

1. MCP helper 校验 `id` 为 UUID，并以 `destructiveHint: true` 注册 `delete_tag`。
2. Swift bridge 按 ID 查找 Tag；无效 ID 返回 `validation_error`，不存在返回 `not_found`。
3. `DataStorage.deleteTag` 收集所有引用该 Tag 的 bookmark、image 和 text，移除 Tag ID，并通过现有 `updateItems` 批量持久化。
4. 仅在条目更新成功后删除 Tag，并刷新 Tag cache 与搜索版本。
5. 成功响应返回被删除 Tag 的 `id` 和 `name`。

## 失败语义

- 关联条目批量更新失败时，不执行 Tag 删除。
- Tag 删除失败时返回 `delete_failed`；此前已移除的引用保持有效数据状态，不会产生悬空 Tag ID。
- 删除操作不影响 category，也不改变 `delete_item` 的 bookmark/image/text 行为。

## 验证

- MCP 测试确认 `delete_tag` 注册、UUID schema 和 destructive annotation。
- Swift 测试确认三种 item 的 Tag 引用均被清除，Tag 从存储中消失。
- 运行 Node 全量测试与构建、macOS 全量测试、Debug build 和 `git diff --check`。
