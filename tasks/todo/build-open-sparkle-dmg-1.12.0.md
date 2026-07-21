# 构建并打开 Seahorse 1.12.0 DMG

## 状态

- 已并入后续发布验证任务（2026-07-21）

## 目标

- 使用现有打包脚本生成包含 Sparkle 2 的签名 `Seahorse-1.12.0.dmg`。
- 验证 DMG、SHA256、App 版本、build number 与代码签名。
- 打开 DMG，让用户手动拖入 Applications 安装。

## 边界

- 不自动覆盖 `/Applications/Seahorse.app`。
- 不推送、打标签、上传 Release、发布 npm 或更新 Sparkle appcast。

## Review status

- Gate: SUPERSEDED
- Report: [build-open-sparkle-dmg-1.12.0.md](../../reports/adversarial-review/build-open-sparkle-dmg-1.12.0.md)

## 结果与验证

- 已生成 `dist/Seahorse-1.12.0_20260721_170155/Seahorse-1.12.0.dmg`，大小为 84,083,481 bytes。
- SHA256 为 `718350351294e2f031c5a8ae7bb6c0d71f44a19ee59d3884bb354c676585b51f`，与 `.sha256` 文件一致。
- `hdiutil verify` 通过；只读挂载后包含 `Seahorse.app` 与 Applications 链接。
- DMG 内外 App 均为 `1.12.0 (11)`，包含 `Sparkle.framework`，并通过 `codesign --verify --deep --strict`。
- App 使用 Apple Development 身份签名，没有 notarization ticket；本任务不声称已公证。
- DMG 已构建并验证，但在打开前任务被新的双版本发布验证任务取代；尚未自动覆盖 `/Applications`，尚未执行远端发布动作。
