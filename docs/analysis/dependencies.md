# 依赖分析

> 项目：Seahorse
> 生成日期：2026-07-15

## 摘要

项目有三套依赖入口：Xcode 工程中的 Swift Package Manager、`MCPHelper/package.json` 与 `docs/Gemfile`。共声明 11 个一级依赖，其中运行时 6 个、开发/构建时 5 个。锁文件可识别 205 个已解析包记录（Swift 6、Node 199）；再计入未锁定的 Jekyll，共 206 个已知包记录：运行时 99 个，开发/构建时 107 个。Jekyll 的 18 个传递依赖只有版本约束、没有具体解析版本，因此不计入上述总数。

整体健康度中等：`Package.resolved` 和 `package-lock.json` 均存在，`npm audit` 对 Node 依赖报告 0 个漏洞，所有已锁定 Node 包都有许可证字段；但 6 个一级依赖落后于当前版本，`docs/Gemfile` 缺少 `Gemfile.lock`，Swift 与 Ruby 依赖也没有可用的本地漏洞审计工具。以下表格列一级依赖，以及数量较少、会直接进入应用的 Swift 传递依赖；Node 的完整 199 包清单以 `MCPHelper/package-lock.json` 为准。

## 运行时依赖

| 包 | 版本 | 用途 | 最新版本 | 状态 |
|---------|---------|---------|--------|--------|
| OpenAI（Swift，直接） | `>= 0.4.7, < 1.0.0`；锁定 `0.4.7` | OpenAI API 客户端 | `0.5.0` | 过期；当前约束允许更新 |
| Kingfisher（Swift，直接） | `>= 8.6.2, < 9.0.0`；锁定 `8.6.2` | 图片下载、缓存与 SwiftUI 展示 | `8.10.0` | 过期；当前约束允许更新 |
| Highlightr（Swift，直接） | `>= 2.3.0, < 3.0.0`；锁定 `2.3.0` | Markdown 编辑器代码高亮 | `2.3.0` | 最新 |
| ZipArchive（Swift，直接） | `>= 2.6.0, < 3.0.0`；锁定 `2.6.0` | iOS 数据 ZIP 导入 | `2.6.0` | 最新 |
| swift-openapi-runtime（Swift，传递） | 锁定 `1.8.3` | OpenAI 的 OpenAPI 运行时 | `1.12.0` | 过期；由 OpenAI 引入 |
| swift-http-types（Swift，传递） | 锁定 `1.5.1` | OpenAPI 运行时的 HTTP 类型 | `1.6.0` | 过期；由 swift-openapi-runtime 引入 |
| @modelcontextprotocol/sdk（Node，直接） | `^1.29.0`；锁定 `1.29.0` | MCP stdio 服务、协议类型与工具注册 | `1.29.0` | 最新 |
| zod（Node，直接） | `^3.25.76`；锁定 `3.25.76` | MCP 工具输入校验 | `4.4.3` | 大版本过期；当前约束内已最新 |

Node 锁文件另外包含 91 个运行时传递包记录。主要来自 `@modelcontextprotocol/sdk` 的 HTTP、JSON Schema、鉴权与 SSE 支持；其中包含按平台或功能声明、当前安装不需要的 optional dependency。

## 开发依赖

| 包 | 版本 | 用途 | 最新版本 | 状态 |
|---------|---------|---------|--------|--------|
| @types/node | `^24.10.1`；锁定 `24.13.2` | Node.js 类型声明 | `24.13.3`（同主版本）/ `26.1.1`（最新） | 补丁过期；另有大版本可用 |
| tsx | `^4.20.6`；锁定 `4.23.0` | 直接运行 TypeScript 开发入口 | `4.23.1` | 补丁过期 |
| typescript | `^5.9.3`；锁定 `5.9.3` | MCP Helper 编译器 | `7.0.2` | 大版本过期；当前约束内已最新 |
| vitest | `^4.0.14`；锁定 `4.1.10` | MCP Helper 测试 | `4.1.10` | 最新 |
| jekyll | `~> 4.4`；未锁定 | 构建 `docs/` 静态站点 | `4.4.1` | 约束可取最新，但构建不可复现 |

Node 锁文件另有 102 个开发传递包记录，主要来自 Vitest/Vite、tsx/esbuild 和类型声明。Jekyll 4.4.1 声明 18 个运行时传递依赖，但项目没有 `Gemfile.lock`，无法确认实际会解析到的版本、完整许可证或漏洞状态。

## 依赖图

```text
Seahorse app target
├── OpenAI 0.4.7
│   └── swift-openapi-runtime 1.8.3
│       └── swift-http-types 1.5.1
├── Kingfisher 8.6.2
├── Highlightr 2.3.0
└── ZipArchive 2.6.0
    ├── libz（系统库）
    ├── iconv（系统库）
    └── Security.framework（系统框架）

SeahorseTests target
└── Seahorse app target（无直接第三方包）

MCPHelper
├── @modelcontextprotocol/sdk 1.29.0
│   ├── Hono / Express HTTP 栈
│   ├── AJV / JSON Schema 栈
│   ├── eventsource / raw-body
│   ├── jose / pkce-challenge
│   └── zod 3.25.76（去重到直接依赖）
├── zod 3.25.76
├── @types/node 24.13.2
│   └── undici-types 7.18.2
├── tsx 4.23.0
│   └── esbuild 0.28.1 + fsevents 2.3.3
├── typescript 5.9.3
└── vitest 4.1.10
    └── @vitest/* + Vite 8.1.3 + Rolldown 1.1.4

docs site
└── jekyll ~> 4.4
    └── 18 个未锁定的直接运行时依赖约束
```

`npm ls --all` 成功完成，Swift 的已解析关系也是单向 DAG，未发现循环依赖。Jekyll 因缺少锁文件，无法验证最终依赖图是否存在循环或冲突。`npm ls` 显示的未满足项目均为 SDK、Vitest 或 Vite 的可选功能/平台包，不是当前 MCP Helper 的安装错误。

## 许可证审计

| 许可证 | 数量 | 包 |
|---------|-------|----------|
| MIT | 175 | Node 锁文件中的 170 个包；OpenAI、Kingfisher、Highlightr、ZipArchive；Jekyll |
| MPL-2.0 | 12 | lightningcss 及其 11 个平台绑定包 |
| ISC | 9 | inherits、isexe、once、picocolors、setprototypeof、siginfo、which、wrappy、zod-to-json-schema |
| Apache-2.0 | 5 | TypeScript、detect-libc、expect-type、swift-openapi-runtime、swift-http-types |
| BSD-3-Clause | 3 | fast-uri、qs、source-map-js |
| BSD-2-Clause | 1 | json-schema-typed |
| 0BSD | 1 | tslib |

以上 206 个已知包记录均为允许商业分发的宽松许可证或弱 copyleft 许可证；MPL-2.0 的文件级修改需要继续以 MPL-2.0 提供源代码。另有两个不能只看包级许可证的内嵌组件：Highlightr 打包的 highlight.js 使用 BSD-3-Clause，ZipArchive 打包的 minizip-ng 使用 Zlib License。发布物应保留这些许可证声明。Jekyll 未锁定的传递依赖不在计数内，完整分发审计仍不闭合。

## 安全告警

- `npm audit --json`（2026-07-15）覆盖 `MCPHelper/package-lock.json`：0 个 info、low、moderate、high 或 critical 漏洞。
- Swift 漏洞审计：Tool not available。`Package.resolved` 固定了版本与提交，但本机没有 `osv-scanner` 或等价工具，因此不能据此断言 Swift 包没有已知漏洞。
- Ruby 漏洞审计：Tool not available。`bundler-audit` 未安装，且项目缺少 `Gemfile.lock`，无法对 Jekyll 的最终传递依赖做可复现审计。
- 未发现凭据或令牌进入依赖清单；报告未记录环境变量或本机配置值。

## 建议

1. 为 `docs/Gemfile` 生成并提交 `Gemfile.lock`，然后在 CI 使用现有 Bundler 做锁定安装；只有确实需要持续 Ruby 漏洞扫描时再引入 `bundler-audit`。这是当前依赖可复现性的唯一明显缺口。
2. 在下一次维护提交中只更新现有约束允许的版本：重新解析 OpenAI、Kingfisher 及其 Swift 传递依赖，并锁定 @types/node `24.13.3`、tsx `4.23.1`；随后运行 Xcode 与 MCP Helper 测试。无需新增依赖管理层。
3. 将 zod 4、TypeScript 7 与 @types/node 26 视为独立迁移，不与功能版本混发；发布前同时生成或维护第三方许可证清单，至少覆盖 Highlightr 的 BSD-3-Clause 资源和 ZipArchive 的 Zlib 组件。
