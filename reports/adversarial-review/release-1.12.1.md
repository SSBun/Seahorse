# Adversarial Review: 发布 Seahorse 1.12.1

## Discussion results

### R1 — appcast 不能早于安装包公开

- Finding: 原计划先推送 `main`，可能让 Pages 先公开 build `12` 的 appcast，而 `v1.12.1` DMG 尚未上传。
- Required outcome: DMG 公开返回 HTTP 200 并完成元数据验证后，才能公开 build `12` appcast；npm 必须最后发布。
- Reviewer position:

  - 先公开 feed 会让运行中的 `1.12.0` 发现一个暂时返回 404 的更新。
  - 应先推 tag、创建 Release 并验证附件，再推 `main` 部署 Pages。

- Editor response:

  - 接受；发布顺序改为 tag-first，不修改产品、产物或发布系统。
  - `.github/workflows/build.yml` 可由 tag 创建 Release，`.github/workflows/jekyll.yml` 仅在 main push 后部署 Pages，现有流程足以保证顺序。

- Resolution: 先发布并验证 DMG/SHA256，再推送 `main` 公开 appcast，最后发布 npm。

## Final decision

- Decision: APPROVED
- Outcome: `1.12.1 (12)` 的空补丁差异、签名 DMG、SHA256、Sparkle appcast、CHANGELOG 与 npm wrapper 元数据一致，并采用避免公开 404 的安全发布顺序。
- Remaining: none
