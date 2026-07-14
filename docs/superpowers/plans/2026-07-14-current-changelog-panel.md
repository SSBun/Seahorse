# Current Changelog Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Advanced Settings 中增加图标入口，打开只展示当前 App 版本内容的 changelog sheet。

**Architecture:** 根目录 `CHANGELOG.md` 作为唯一内容源并打包到 App。纯 `ChangelogParser` 从 Markdown 中提取当前版本的三级标题和列表项，SwiftUI sheet 只负责加载 Bundle resource 与展示解析结果。

**Tech Stack:** Swift 5、SwiftUI、Foundation、XCTest、Xcode macOS resources。

## Global Constraints

- 不新增第三方依赖，不实现通用 Markdown 渲染器。
- 只显示 `UpdateManager.currentVersion` 对应章节。
- 资源缺失、版本不存在或内容为空时显示 fallback。
- 图标按钮必须有 tooltip 和无障碍标签。
- sheet 约为 `520 × 420`，内容可滚动并支持 Escape 关闭。

---

### Task 1: 当前版本 CHANGELOG 解析器

**Files:**
- Create: `Seahorse/Utilities/ChangelogParser.swift`
- Create: `SeahorseTests/ChangelogParserTests.swift`

**Interfaces:**
- Produces: `ChangelogSection(title: String, items: [String])`
- Produces: `ChangelogParser.sections(for version: String, in markdown: String) -> [ChangelogSection]`

- [ ] **Step 1: 写失败测试**

覆盖目标版本提取、在下一版本停止、缺失版本和无列表内容：

```swift
import XCTest
@testable import Seahorse

final class ChangelogParserTests: XCTestCase {
    func testExtractsOnlyRequestedVersionSections() {
        let markdown = """
        ## [Unreleased]
        - ignored
        ## [1.8.0] - 2026-07-14
        ### Added
        - First
        ### Fixed
        - Second
        ## [1.7.0] - 2026-07-09
        ### Added
        - Old
        """

        XCTAssertEqual(
            ChangelogParser.sections(for: "1.8.0", in: markdown),
            [
                ChangelogSection(title: "Added", items: ["First"]),
                ChangelogSection(title: "Fixed", items: ["Second"]),
            ]
        )
    }

    func testReturnsEmptyForMissingOrEmptyVersion() {
        XCTAssertTrue(ChangelogParser.sections(for: "2.0.0", in: "## [1.8.0]").isEmpty)
        XCTAssertTrue(ChangelogParser.sections(for: "1.8.0", in: "## [1.8.0]").isEmpty)
    }
}
```

- [ ] **Step 2: 运行测试确认红灯**

Run:

```bash
xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' -only-testing:SeahorseTests/ChangelogParserTests CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL，因为 `ChangelogParser` 尚不存在。

- [ ] **Step 3: 实现最小解析器**

```swift
import Foundation

struct ChangelogSection: Equatable {
    let title: String
    var items: [String]
}

enum ChangelogParser {
    static func sections(for version: String, in markdown: String) -> [ChangelogSection] {
        let targetPrefix = "## [\(version)]"
        var isInTargetVersion = false
        var sections: [ChangelogSection] = []

        for substring in markdown.split(whereSeparator: \.isNewline) {
            let line = String(substring)

            if line.hasPrefix("## ") {
                if isInTargetVersion { break }
                isInTargetVersion = line.hasPrefix(targetPrefix)
                continue
            }
            guard isInTargetVersion else { continue }

            if line.hasPrefix("### ") {
                sections.append(ChangelogSection(title: String(line.dropFirst(4)), items: []))
            } else if line.hasPrefix("- "), !sections.isEmpty {
                sections[sections.count - 1].items.append(String(line.dropFirst(2)))
            }
        }

        return sections.filter { !$0.items.isEmpty }
    }
}
```

- [ ] **Step 4: 运行测试确认绿灯**

Run: Task 1 Step 2 的同一命令。

Expected: `ChangelogParserTests` PASS。

---

### Task 2: Bundle resource 与 changelog sheet

**Files:**
- Modify: `Seahorse.xcodeproj/project.pbxproj`
- Modify: `Seahorse/Views/Settings/AdvancedSettingsView.swift`
- Create: `Seahorse/Views/Settings/ChangelogPanelView.swift`
- Modify: `tasks/context.md`
- Modify: `tasks/todo.md`

**Interfaces:**
- Consumes: `ChangelogParser.sections(for:in:)`
- Produces: `ChangelogPanelView(version: String)`

- [ ] **Step 1: 将根 CHANGELOG 加入 App resources**

在 `project.pbxproj` 中为根目录 `CHANGELOG.md` 增加 file reference、build file，并加入 Seahorse target 的 Resources build phase。构建后必须存在：

```text
Seahorse.app/Contents/Resources/CHANGELOG.md
```

- [ ] **Step 2: 创建原生 sheet**

```swift
import SwiftUI

struct ChangelogPanelView: View {
    @Environment(\.dismiss) private var dismiss

    let version: String
    private let sections: [ChangelogSection]

    init(version: String, bundle: Bundle = .main) {
        self.version = version
        let markdown = bundle.url(forResource: "CHANGELOG", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        sections = markdown.map { ChangelogParser.sections(for: version, in: $0) } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("What’s New in \(version)")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help("Close")
                    .accessibilityLabel("Close")
            }
            .padding(20)

            Divider()

            ScrollView {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "Changelog Unavailable",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Changelog is unavailable for this version.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title).font(.headline)
                                ForEach(section.items, id: \.self) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("•")
                                        Text(item).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
        }
        .frame(width: 520, height: 420)
        .onExitCommand { dismiss() }
    }
}
```

- [ ] **Step 3: 接入 Updates 标题入口**

在 `AdvancedSettingsView` 增加 `@State private var showingChangelog = false`，把标题改为带图标的 `HStack`，并挂载 sheet：

```swift
HStack(spacing: 8) {
    Text("Updates")
        .font(.system(size: 16, weight: .semibold))

    Button {
        showingChangelog = true
    } label: {
        Image(systemName: "info.circle")
    }
    .buttonStyle(.plain)
    .help("Show Changelog")
    .accessibilityLabel("Show Changelog")
}
.sheet(isPresented: $showingChangelog) {
    ChangelogPanelView(version: updateManager.currentVersion)
}
```

- [ ] **Step 4: 运行完整验证**

Run:

```bash
xcodebuild test -project Seahorse.xcodeproj -scheme Seahorse -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Seahorse.xcodeproj -scheme Seahorse -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
test -f ~/Library/Developer/Xcode/DerivedData/Seahorse-*/Build/Products/Debug/Seahorse.app/Contents/Resources/CHANGELOG.md
git diff --check
```

Expected: 解析测试和全量测试通过，构建成功，CHANGELOG resource 存在，空白检查无输出。

- [ ] **Step 5: 更新任务与上下文记录**

在 `tasks/context.md` 记录 changelog 数据源和入口，在 `tasks/todo.md` 勾选计划并写入测试、构建、资源及视觉验证结果。

