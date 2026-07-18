#if os(macOS)
import AppKit
import SwiftUI

struct EnrichmentIssuesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var dataStorage: DataStorage
    @EnvironmentObject private var itemDetailState: ItemDetailState
    @ObservedObject var autoParsingService: AutoParsingService

    @State private var showingBulkRetryConfirmation = false
    @State private var bookmarkToDelete: Bookmark?
    @State private var showingDeleteConfirmation = false
    @State private var deleteErrorMessage = ""
    @State private var showingDeleteError = false

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
        .confirmationDialog(
            "Move Bookmark to Trash?",
            isPresented: $showingDeleteConfirmation,
            presenting: bookmarkToDelete
        ) { bookmark in
            Button("Move to Trash", role: .destructive) {
                moveToTrash(bookmark)
            }
            Button("Cancel", role: .cancel) {
                bookmarkToDelete = nil
            }
        } message: { bookmark in
            Text("Enrichment failure does not prove “\(bookmark.title)” is invalid. Move it to Trash only after checking the link. You can restore it later.")
        }
        .alert("Unable to Move Bookmark", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
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

            Menu {
                Button("Open Details") {
                    itemDetailState.showItem(bookmark.id, source: "enrichment-issues")
                    openWindow(id: "item-detail")
                }

                Button("Open in Browser") {
                    if let url = URL(string: bookmark.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(URL(string: bookmark.url) == nil)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            .menuStyle(.button)

            Button("Retry") {
                autoParsingService.retryBookmark(id: bookmark.id)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                bookmarkToDelete = bookmark
                showingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .help("Move to Trash")
            .accessibilityLabel("Move \(bookmark.title) to Trash")
        }
        .padding(.vertical, 4)
    }

    private func moveToTrash(_ bookmark: Bookmark) {
        do {
            try dataStorage.deleteBookmark(bookmark)
            bookmarkToDelete = nil
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
        }
    }
}
#endif
