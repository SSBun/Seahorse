#if os(macOS)
import SwiftUI

struct BookmarkParsingSelection {
    let appliesTitle: Bool
    let appliesSummary: Bool
    let appliesCategory: Bool
    let appliesTags: Bool
}

struct BookmarkParsingDiffView: View {
    let diff: BookmarkParsingDiff
    let onApply: (BookmarkParsingSelection) -> Void
    let onCancel: () -> Void

    @State private var appliesTitle: Bool
    @State private var appliesSummary: Bool
    @State private var appliesCategory: Bool
    @State private var appliesTags: Bool

    init(
        diff: BookmarkParsingDiff,
        onApply: @escaping (BookmarkParsingSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.diff = diff
        self.onApply = onApply
        self.onCancel = onCancel
        _appliesTitle = State(initialValue: diff.title?.isSelectedByDefault ?? false)
        _appliesSummary = State(initialValue: diff.summary?.isSelectedByDefault ?? false)
        _appliesCategory = State(initialValue: diff.category?.isSelectedByDefault ?? false)
        _appliesTags = State(initialValue: diff.tags?.isSelectedByDefault ?? false)
    }

    var body: some View {
        VStack(spacing: 18) {
            Label("Review AI Changes", systemImage: "sparkles")
                .font(.system(size: 18, weight: .semibold))

            Text("Select the AI suggestions you want to apply. Existing content is never replaced unless you choose it here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let change = diff.title {
                        textChange(
                            title: "Title",
                            change: change,
                            isSelected: $appliesTitle
                        )
                    }
                    if let change = diff.summary {
                        textChange(
                            title: "Summary",
                            change: change,
                            isSelected: $appliesSummary
                        )
                    }
                    if let change = diff.category {
                        valueChange(
                            title: "Category",
                            change: change,
                            isSelected: $appliesCategory
                        )
                    }
                    if let change = diff.tags {
                        tagChange(change, isSelected: $appliesTags)
                    }
                }
            }
            .frame(maxHeight: 430)

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply Selected Changes") {
                    onApply(
                        BookmarkParsingSelection(
                            appliesTitle: appliesTitle,
                            appliesSummary: appliesSummary,
                            appliesCategory: appliesCategory,
                            appliesTags: appliesTags
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!appliesTitle && !appliesSummary && !appliesCategory && !appliesTags)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    @ViewBuilder
    private func textChange(
        title: String,
        change: BookmarkParsingChange<String>,
        isSelected: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isSelected) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                comparedText("Current", value: change.currentValue, color: .secondary)
                comparedText("Suggested", value: change.suggestedValue, color: .accentColor)
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder
    private func valueChange(
        title: String,
        change: BookmarkParsingChange<String>,
        isSelected: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isSelected) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    Text(change.currentValue)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                    Text(change.suggestedValue)
                        .foregroundStyle(.tint)
                }
                .font(.system(size: 12))
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder
    private func tagChange(
        _ change: BookmarkParsingChange<[String]>,
        isSelected: Binding<Bool>
    ) -> some View {
        let currentKeys = Set(change.currentValue.map { $0.lowercased() })
        let suggestedKeys = Set(change.suggestedValue.map { $0.lowercased() })

        Toggle(isOn: isSelected) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.system(size: 12, weight: .semibold))
                tagRow(
                    "Keep",
                    names: change.suggestedValue.filter { currentKeys.contains($0.lowercased()) },
                    color: .secondary
                )
                tagRow(
                    "Add",
                    names: change.suggestedValue.filter { !currentKeys.contains($0.lowercased()) },
                    color: .green
                )
                tagRow(
                    "Remove",
                    names: change.currentValue.filter { !suggestedKeys.contains($0.lowercased()) },
                    color: .red
                )
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder
    private func comparedText(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func tagRow(_ label: String, names: [String], color: Color) -> some View {
        if !names.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
                Text(names.map { "#\($0)" }.joined(separator: "  "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
        }
    }
}
#endif
