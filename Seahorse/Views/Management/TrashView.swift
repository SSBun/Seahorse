#if os(macOS)
import SwiftUI

struct TrashView: View {
    @EnvironmentObject private var dataStorage: DataStorage
    let searchText: String
    let selectedKind: ItemKind

    @State private var selectedIDs = Set<UUID>()
    @State private var pendingPermanentDeletionIDs = Set<UUID>()
    @State private var showingEmptyTrashConfirmation = false

    private var filteredItems: [AnyCollectionItem] {
        let records = CollectionSearch.makeRecords(
            items: dataStorage.trashItems,
            tagsByID: Dictionary(uniqueKeysWithValues: dataStorage.tags.map { ($0.id, $0) })
        )
        return CollectionSearch.items(
            in: records,
            matching: CollectionSearch.Criteria(query: searchText, kind: searchKind)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Items stay here until you permanently delete them.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restore Selected") {
                    restoreSelected()
                }
                .disabled(selectedIDs.isEmpty)
                Button("Delete Selected", role: .destructive) {
                    pendingPermanentDeletionIDs = selectedIDs
                }
                .disabled(selectedIDs.isEmpty)
                Button("Empty Trash", role: .destructive) {
                    showingEmptyTrashConfirmation = true
                }
                .disabled(dataStorage.trashItems.isEmpty)
            }
            .padding()

            Divider()

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Trash Is Empty" : "No Results",
                    systemImage: searchText.isEmpty ? "trash" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Deleted items will appear here."
                        : "No deleted items match your search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems, selection: $selectedIDs) { item in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: item))
                            .frame(width: 24)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title(for: item))
                                .lineLimit(1)
                            if let deletedAt = item.deletedAt {
                                Text("Deleted \(deletedAt, format: .relative(presentation: .named))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Restore") {
                            restore(item)
                        }
                        .accessibilityLabel("Restore \(title(for: item))")

                        Button("Delete Permanently", role: .destructive) {
                            pendingPermanentDeletionIDs = [item.id]
                        }
                        .accessibilityLabel("Permanently delete \(title(for: item))")
                    }
                    .padding(.vertical, 4)
                    .tag(item.id)
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Delete Item Permanently?",
            isPresented: Binding(
                get: { !pendingPermanentDeletionIDs.isEmpty },
                set: { if !$0 { pendingPermanentDeletionIDs.removeAll() } }
            )
        ) {
            Button("Delete Permanently", role: .destructive) {
                permanentlyDeletePendingItem()
            }
        } message: {
            Text("\(pendingPermanentDeletionIDs.count) item(s) will be deleted. This cannot be undone.")
        }
        .confirmationDialog("Empty Trash?", isPresented: $showingEmptyTrashConfirmation) {
            Button("Empty Trash", role: .destructive, action: emptyTrash)
        } message: {
            Text("All items in Trash will be permanently deleted. This cannot be undone.")
        }
    }

    private var searchKind: CollectionSearch.Kind {
        switch selectedKind {
        case .all: .all
        case .bookmark: .bookmark
        case .image: .image
        case .note: .text
        }
    }

    private func restore(_ item: AnyCollectionItem) {
        do {
            let result = try dataStorage.restoreItem(item)
            var message = "Item restored"
            if result.categoryWasReset || result.removedTagCount > 0 {
                message += " with missing organization removed"
            }
            GlobalToastManager.shared.show(message: message, icon: "arrow.uturn.backward.circle.fill")
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
    }

    private func restoreSelected() {
        do {
            let results = try dataStorage.restoreItems(ids: Array(selectedIDs))
            let resetCount = results.filter(\.categoryWasReset).count
            let removedTagCount = results.reduce(0) { $0 + $1.removedTagCount }
            var message = "\(results.count) item(s) restored"
            if resetCount > 0 || removedTagCount > 0 {
                message += "; repaired missing organization"
            }
            selectedIDs.removeAll()
            GlobalToastManager.shared.show(message: message, icon: "arrow.uturn.backward.circle.fill")
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
    }

    private func permanentlyDeletePendingItem() {
        guard !pendingPermanentDeletionIDs.isEmpty else { return }
        do {
            try dataStorage.permanentlyDeleteItems(ids: Array(pendingPermanentDeletionIDs))
            selectedIDs.subtract(pendingPermanentDeletionIDs)
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
        pendingPermanentDeletionIDs.removeAll()
    }

    private func emptyTrash() {
        do {
            try dataStorage.emptyTrash()
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
    }

    private func title(for item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark { return bookmark.title }
        if let image = item.asImageItem { return image.notes ?? image.imagePath }
        if let text = item.asTextItem { return text.notes ?? String(text.firstLine) }
        return "Item"
    }

    private func icon(for item: AnyCollectionItem) -> String {
        switch item.itemType {
        case .bookmark: "link"
        case .image: "photo"
        case .text: "doc.text"
        }
    }
}
#endif
