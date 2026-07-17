#if os(macOS)
import SwiftUI

struct EnrichmentIssuesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStorage: DataStorage
    @ObservedObject var autoParsingService: AutoParsingService

    @State private var showingBulkRetryConfirmation = false

    /// Returns failed bookmarks ordered for display.
    /// - Complexity: O(n log n).
    private var issues: [Bookmark] {
        let failedIDs = Set(autoParsingService.failedBookmarkIDs)
        return dataStorage.bookmarks
            .filter { failedIDs.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Returns failures caused by the corrected duplicate-name mismatch.
    /// - Complexity: O(n).
    private var recoverableIDs: [UUID] {
        issues.compactMap { bookmark in
            autoParsingService.failureMessage(for: bookmark.id) == DatabaseError.duplicateEntry.localizedDescription
                ? bookmark.id
                : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if issues.isEmpty {
                ContentUnavailableView(
                    "No Enrichment Issues",
                    systemImage: "checkmark.circle",
                    description: Text("All bookmark enrichment tasks are complete.")
                )
            } else {
                List(issues) { bookmark in
                    issueRow(for: bookmark)
                }
            }

            Divider()
            footer
        }
        .frame(width: 680, height: 520)
        .confirmationDialog(
            "Retry recoverable enrichment issues?",
            isPresented: $showingBulkRetryConfirmation
        ) {
            Button("Retry (recoverableIDs.count) Bookmarks") {
                for id in recoverableIDs {
                    autoParsingService.retryBookmark(id: id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This reruns AI enrichment and may use API credits or update titles, summaries, and tags.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enrichment Issues")
                    .font(.title2.weight(.semibold))
                Text("These bookmarks are usable; only optional enrichment is incomplete.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            Text("\(issues.count) issue(s)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if !recoverableIDs.isEmpty {
                Button("Retry Recoverable (\(recoverableIDs.count))") {
                    showingBulkRetryConfirmation = true
                }
            }
        }
        .padding(16)
    }

    private func issueRow(for bookmark: Bookmark) -> some View {
        HStack(spacing: 12) {
            BookmarkIconView(iconString: bookmark.icon, size: 20)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(bookmark.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(autoParsingService.failureMessage(for: bookmark.id) ?? "Unknown enrichment error")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Spacer()

            Button("Retry") {
                autoParsingService.retryBookmark(id: bookmark.id)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
#endif
