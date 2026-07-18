#if os(macOS)
import SwiftUI

struct BookmarkParsingProgressView: View {
    @ObservedObject var session: BookmarkParsingSession

    var body: some View {
        if session.hasStarted {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AI Parsing")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if session.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(BookmarkParsingStep.allCases) { step in
                        stepRow(step)
                    }
                }

                if let resolution = session.resolution {
                    Divider()
                    suggestionSummary(resolution)
                }
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.18))
            }
        }
    }

    private func stepRow(_ step: BookmarkParsingStep) -> some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon(for: session.status(for: step))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 11, weight: .medium))
                if let detail = detail(for: session.status(for: step)) {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: BookmarkParsingStepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func detail(for status: BookmarkParsingStepStatus) -> String? {
        switch status {
        case .completed(let detail): return detail
        case .failed(let message): return message
        case .pending, .running: return nil
        }
    }

    private func suggestionSummary(_ resolution: BookmarkParsingResolution) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Suggestions received")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.purple)

            suggestionRow(label: "Title", value: resolution.refinedTitle)
            suggestionRow(label: "Summary", value: resolution.summary, lineLimit: 3)
            suggestionRow(
                label: "Category",
                value: resolution.category?.name
                    ?? resolution.suggestedNewCategoryName
                    ?? "Unclassified"
            )
            suggestionRow(
                label: "Tags",
                value: resolution.suggestedTagNames.isEmpty
                    ? "None"
                    : resolution.suggestedTagNames.joined(separator: ", ")
            )
        }
    }

    private func suggestionRow(
        label: String,
        value: String,
        lineLimit: Int = 2
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "No suggestion" : value)
                .font(.system(size: 10))
                .lineLimit(lineLimit)
        }
    }
}
#endif
