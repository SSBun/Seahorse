#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var dataStorage: DataStorage
    @Binding var selection: SidebarSelection?

    @State private var dropTargetCategory: UUID?
    @State private var editingSmartCollection: SmartCollection?
    @State private var showingSmartCollectionEditor = false
    @State private var smartCollectionPendingDeletion: SmartCollection?

    private var sortedTags: [Tag] {
        dataStorage.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(selection: $selection) {
            Section("LIBRARY") {
                Label("Recent", systemImage: "clock")
                    .tag(SidebarSelection.recent)
                Label("Unorganized", systemImage: "tray")
                    .tag(SidebarSelection.unorganized)
                Label("Trash", systemImage: "trash")
                    .tag(SidebarSelection.trash)
            }

            Section("CATEGORIES") {
                ForEach(dataStorage.categories) { category in
                    categoryRow(category)
                        .tag(SidebarSelection.category(category.id))
                }
            }

            Section {
                ForEach(dataStorage.smartCollections) { smartCollection in
                    smartCollectionRow(smartCollection)
                        .tag(SidebarSelection.smartCollection(smartCollection.id))
                        .contextMenu {
                            Button("Edit") {
                                editingSmartCollection = smartCollection
                                showingSmartCollectionEditor = true
                            }
                            Button("Move Up") {
                                moveSmartCollection(smartCollection, offset: -1)
                            }
                            .disabled(dataStorage.smartCollections.first?.id == smartCollection.id)
                            Button("Move Down") {
                                moveSmartCollection(smartCollection, offset: 1)
                            }
                            .disabled(dataStorage.smartCollections.last?.id == smartCollection.id)
                            Button("Delete", role: .destructive) {
                                smartCollectionPendingDeletion = smartCollection
                            }
                        }
                }
                .onMove(perform: dataStorage.reorderSmartCollections)
            } header: {
                HStack {
                    Text("SMART COLLECTIONS")
                    Spacer()
                    Button {
                        editingSmartCollection = nil
                        showingSmartCollectionEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("New Smart Collection")
                    .help("New Smart Collection")
                }
            }

            Section("TAGS") {
                ForEach(sortedTags) { tag in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 10, height: 10)
                        Text(tag.name)
                    }
                    .tag(SidebarSelection.tag(tag.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Bookmarks")
        .frame(minWidth: 200, idealWidth: 220)
        .sheet(isPresented: $showingSmartCollectionEditor) {
            SmartCollectionEditorView(smartCollection: editingSmartCollection)
                .environmentObject(dataStorage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EditSmartCollection"))) { notification in
            guard let id = notification.object as? UUID,
                  let smartCollection = dataStorage.smartCollections.first(where: { $0.id == id }) else {
                return
            }
            editingSmartCollection = smartCollection
            showingSmartCollectionEditor = true
        }
        .confirmationDialog(
            "Delete Smart Collection?",
            isPresented: Binding(
                get: { smartCollectionPendingDeletion != nil },
                set: { if !$0 { smartCollectionPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                deletePendingSmartCollection()
            }
        } message: {
            Text("The saved filter will be deleted. Its items will not be affected.")
        }
    }

    private func smartCollectionRow(_ smartCollection: SmartCollection) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.purple)
            Text(smartCollection.name)
            Spacer()
            Text("\(resultCount(for: smartCollection))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if hasInvalidReference(smartCollection) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Missing category or tag")
                    .help("This smart collection references a missing category or tag.")
            }
        }
    }

    private func hasInvalidReference(_ smartCollection: SmartCollection) -> Bool {
        let categoryIDs = Set(dataStorage.categories.map(\.id))
        let tagIDs = Set(dataStorage.tags.map(\.id))
        return !(smartCollection.categoryId.map(categoryIDs.contains) ?? true)
            || !Set(smartCollection.tagIds).isSubset(of: tagIDs)
    }

    private func resultCount(for smartCollection: SmartCollection) -> Int {
        let criteria = CollectionSearch.criteria(
            for: smartCollection,
            availableCategoryIDs: Set(dataStorage.categories.map(\.id)),
            availableTagIDs: Set(dataStorage.tags.map(\.id))
        )
        return CollectionSearch.items(
            in: dataStorage.searchRecordsSnapshot(),
            matching: criteria
        ).count
    }

    private func moveSmartCollection(_ smartCollection: SmartCollection, offset: Int) {
        guard let source = dataStorage.smartCollections.firstIndex(where: { $0.id == smartCollection.id }) else {
            return
        }
        let target = source + offset
        guard dataStorage.smartCollections.indices.contains(target) else { return }
        let destination = offset < 0 ? target : target + 1
        dataStorage.reorderSmartCollections(
            fromOffsets: IndexSet(integer: source),
            toOffset: destination
        )
    }

    private func categoryRow(_ category: Category) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onDrop(of: [.seahorseItemUUID], isTargeted: Binding(
                    get: { dropTargetCategory == category.id },
                    set: { isTargeted in
                        dropTargetCategory = isTargeted ? category.id : nil
                        Log.info("item_drag target_changed active=\(isTargeted)", category: .ui)
                    }
                )) { providers in
                    handleDrop(providers: providers, category: category)
                }

            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 16, height: 16)
                Text(category.name)
                Spacer()
            }
        }
        .listRowBackground(
            dropTargetCategory == category.id
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.25))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                : nil
        )
    }

    private func deletePendingSmartCollection() {
        guard let smartCollectionPendingDeletion else { return }
        do {
            try dataStorage.deleteSmartCollection(smartCollectionPendingDeletion)
            if selection == .smartCollection(smartCollectionPendingDeletion.id) {
                selection = dataStorage.categories.first.map { .category($0.id) }
            }
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
        self.smartCollectionPendingDeletion = nil
    }

    private func handleDrop(providers: [NSItemProvider], category: Category) -> Bool {
        Log.info("item_drag drop_received provider_count=\(providers.count)", category: .ui)
        guard let provider = providers.first else {
            Log.warning("item_drag drop_rejected reason=no_provider", category: .ui)
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.seahorseItemUUID.identifier) { data, error in
            if let error {
                Log.error("item_drag payload_load_failed error_type=\(String(describing: type(of: error)))", category: .ui)
                return
            }
            guard let data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let itemId = UUID(uuidString: uuidString) else {
                Log.warning("item_drag payload_invalid", category: .ui)
                return
            }

            DispatchQueue.main.async {
                guard var item = dataStorage.item(for: itemId) else {
                    Log.warning("item_drag item_not_found", category: .ui)
                    return
                }
                guard item.categoryId != category.id else {
                    Log.info("item_drag update_skipped reason=same_category item_type=\(item.itemType.rawValue)", category: .ui)
                    return
                }

                if var bookmark = item.asBookmark {
                    bookmark.categoryId = category.id
                    bookmark.modifiedDate = Date()
                    item = AnyCollectionItem(bookmark)
                } else if var imageItem = item.asImageItem {
                    imageItem.categoryId = category.id
                    imageItem.modifiedDate = Date()
                    item = AnyCollectionItem(imageItem)
                } else if var textItem = item.asTextItem {
                    textItem.categoryId = category.id
                    textItem.modifiedDate = Date()
                    item = AnyCollectionItem(textItem)
                } else {
                    Log.error("item_drag update_failed reason=unsupported_item", category: .ui)
                    return
                }

                dataStorage.updateItem(item)
                if dataStorage.item(for: itemId)?.categoryId == category.id {
                    Log.info("item_drag update_succeeded item_type=\(item.itemType.rawValue)", category: .ui)
                } else {
                    Log.error("item_drag update_failed reason=persistence item_type=\(item.itemType.rawValue)", category: .ui)
                }
            }
        }
        return true
    }
}

#Preview {
    NavigationSplitView {
        SidebarView(selection: .constant(.recent))
            .environmentObject(DataStorage.preview)
    } detail: {
        Text("Detail View")
    }
}
#endif
