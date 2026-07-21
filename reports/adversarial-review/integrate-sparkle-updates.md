# 对抗式审查：集成 Sparkle 2 自动更新

## 讨论结果

### R1 — 发布脚本无法定位常规 DerivedData 中的 Sparkle 工具

- Finding: 发布文档的生成命令默认只查找 `build/SourcePackages/...`，但文档中的普通 Xcode 构建使用默认 DerivedData，干净环境会报找不到 Sparkle 工具。
- Required outcome: 完成文档前置步骤后，appcast 生成命令可以直接成功，或提供明确、可复现的工具定位方式。
- Reviewer position:

  - 发布 feed 是自动更新链路的一部分，文档命令不可执行会导致未来版本无法被客户端发现。
  - 可从常规 DerivedData 定位工具，或补充明确的准备步骤。

- Editor response:

  - 接受问题，但将修复收窄到脚本的工具定位，不扩大到 CI 或改变发布架构。
  - 脚本保留显式 `SPARKLE_BIN` 与 `build/...` 快路径；缺失时从 Xcode 的实际 `BUILD_DIR` 推导对应 DerivedData，并已用文档命令生成、验签测试 appcast。

- Resolution: 已解决；默认路径缺失且未设置覆盖变量时，文档命令仍能生成带有效 EdDSA 签名的 feed。

## 最终决定

- Decision: APPROVED
- Outcome: Sparkle 客户端、签名 feed、可重复发布流程与 macOS-only package product 过滤满足要求，最终差异获准交付。
- Remaining: none
