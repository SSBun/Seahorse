# Adversarial Review: 美化 README 宣传首页

## Summary

- Gate: APPROVED
- Review state: APPROVED
- Stop reason: approved
- Reviewer: `readme_reviewer`
- Current round: RE-REVIEW (2)
- Task: [tasks/todo/beautify-readme.md](../../tasks/todo/beautify-readme.md) — 美化 README 宣传首页
- Updated: 2026-07-20 Asia/Shanghai

## Reviewed scope

- Base or revision: `db59071`
- Artifacts: `README.md`、`readme-hero.jpg`
- Fingerprint: README diff SHA-256 `699efed60a66d0b648b3e58856f979bccec3bec80c0baf3207520591ac9ebea7`；`readme-hero.jpg` SHA-256 `d39d7ad392633fd25361a2a467ece50c916b5e0a0e5c8881b0c930c3cf75b332`
- Non-goals: `README_ZH.md`、官网、应用代码、现有产品图片资产和工具站表单提交

## Outcome

README 宣传区与 slogan 图在 RE-REVIEW (2) 获得批准；R1–R3 已全部解决，批准范围仅限所列 README 与图片指纹。

## Findings

### R1 — BLOCKER: 历史截图被误标为当前 1.11.0

- Location: `README.md` Hero 下方截图说明
- Evidence: `snapshot.png` 唯一提交记录为 2025-12-05 的 `19e5eb9`，早于 2026-07-19 发布的 v1.11.0。
- Risk: 对外宣传把无法证明时效的历史截图标为当前版本，构成不准确断言。
- Root cause: 初稿复用历史截图时把当前 App 版本错误投射为截图版本，没有先核对图片提交时间。
- Editor response: 接受。README 改用新生成的品牌 slogan 图承担 Hero；截图 alt 与 caption 删除 `1.11.0` 和最新含义，仅标为产品截图。
- Resolution: RE-REVIEW (2) 确认已解决。
- Verification: 检查 README 不再把 `snapshot.png` 关联到具体版本；slogan 图文案和视觉已核对。
- Status: RESOLVED

### R2 — QUESTION: README 反链是否满足工具站规则

- Location: `README.md` 页尾与 `tasks/todo/beautify-readme.md` 目标
- Evidence: 工具站要求链接位于提交网站的 homepage 或 footer；用户明确要求美化 README，未要求修改官网或提交表单。
- Risk: 若提交 URL 是 `https://ssbun.github.io/Seahorse`，README 页尾链接不能证明官网满足规则。
- Root cause: 初稿没有固定计划提交的 Tool URL，因而把 README 反链错误泛化为对任意提交 URL 都合规。
- Editor response: 将计划 Tool URL 明确为 GitHub 仓库地址；保留 README 页尾反链，同时明确它只适用于提交仓库 URL，不代表独立官网已合规。
- Resolution: RE-REVIEW (2) 确认已解决。
- Verification: README 保留 `https://twelve.tools`，任务记录明确排除官网合规声明。
- Status: RESOLVED

### R3 — NOTE: 重复加载大尺寸 App 图标

- Location: `README.md` 原独立 App 图标
- Evidence: 原图标文件为 1,442,905 bytes；新 `readme-hero.jpg` 已包含品牌图标且为 249,439 bytes。
- Risk: 独立加载图标重复品牌视觉并增加 README 首屏资源负担。
- Root cause: 新 slogan Hero 加入后仍保留初稿的独立图标，形成重复品牌元素和冗余请求。
- Editor response: 接受。删除 README 的独立图标引用，以 slogan Hero 同时承载图标和品牌信息；删除仓库内中间 `readme-hero.png`。
- Resolution: RE-REVIEW (2) 确认已解决。
- Verification: README 不再引用 `icon_512x512@2x.png`；仓库只保留最终 `readme-hero.jpg`。
- Status: RESOLVED

## Round history

| Round | State | New findings | Resolved | Unresolved |
|---|---|---|---|---|
| INITIAL (1) | CONTINUE | R1–R3 | none | R1–R3 |
| RE-REVIEW (2) | APPROVED | none | R1–R3 | none |

## Verification

- GitHub Markdown API（`gh api markdown`）— 已成功渲染 `readme-hero.jpg`、无版本断言的 `snapshot.png`、产品截图说明和 `twelve.tools` 链接。
- 图片检查 — `readme-hero.jpg` 为 1983×793、249,439 bytes，SHA-256 为 `d39d7ad392633fd25361a2a467ece50c916b5e0a0e5c8881b0c930c3cf75b332`；中间 `readme-hero.png` 已删除。
- HTTP 检查 — README 的 12 个唯一外部地址中 10 个返回 200/206；未提交 Hero 的远端 raw URL 预期为 404；npm 网页对命令行请求返回 403，但 npm registry 返回 200。
- `git diff --check` — 通过。
- Limitations: 未在外部工具站实际提交或预览；若提交独立官网 URL，仍需另行修改官网首页或页脚。

## Unresolved items

None.

## Approval boundary

- Approval covers only the identified revision and scope.
- Reviewed-artifact changes invalidate approval and resume the same numbered history.
- Report and task-summary synchronization are administrative review records.
- External action authorization: not authorized; no tool-directory submission.
