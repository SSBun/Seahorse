# 美化 README 宣传首页

## 状态

- 已完成（2026-07-20）

## 目标

- 用品牌 slogan 图、简洁文案和清晰下载入口建立 README 顶部宣传区。
- 继续展示真实产品截图，但不把历史截图宣称为当前版本或最新截图。
- 在 README 页尾加入 `twelve.tools` 反向链接；当工具站提交 URL 使用 GitHub 仓库地址时，该链接可被仓库首页直接展示。

## 边界

- 只修改英文 `README.md` 并新增不描绘产品 UI 的 `readme-hero.jpg`；不改中文 README、官网、应用代码或现有产品截图。
- slogan 图复用 App 品牌图标和准确文案；继续复用 `snapshot.png`，但不对其版本或时效作无证据断言。
- README 反向链接不代表 `ssbun.github.io` 官网已满足工具站规则；若提交官网 URL，需另行在官网首页或页脚添加链接。
- 本任务不代用户向工具站提交表单。

## 计划

- [x] 确认现有截图时效并生成品牌 slogan 图。
- [x] 改造 README Hero、截图说明与推广链接。
- [x] 验证 Markdown、外部资源链接和内容准确性。
- [x] 完成独立对抗式审查并处理全部问题。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: `readme_reviewer`
- Round: RE-REVIEW (2)
- Scope: `README.md`、`readme-hero.jpg` 的最终内容与相对 `db59071` 的差异
- Summary: README 宣传区、slogan 图、截图表述与反向链接边界已通过独立审查。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/beautify-readme.md)

## 结果与验证

- GitHub Markdown API 通过已认证请求成功渲染品牌 slogan 图、产品截图和 `twelve.tools` 链接。
- slogan 图为 1983×793、249,439 bytes；产品截图不再标注具体版本或“最新”。
- README 的 12 个外部地址中 10 个返回 HTTP 200/206；新增 Hero 的远端 raw URL 在提交前预期为 404，npm 网页拒绝命令行请求为 403，但对应 registry 返回 200。
- `git diff --check` 通过；未修改应用代码、官网或现有产品截图。
