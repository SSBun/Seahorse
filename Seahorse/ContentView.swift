#if os(macOS)
//
//  ContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers

enum ItemKind: String, CaseIterable {
    case all = "All"
    case bookmark = "Bookmark"
    case image = "Image"
    case note = "Note"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .bookmark: return "link"
        case .image: return "photo"
        case .note: return "doc.text"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @EnvironmentObject var itemDetailState: ItemDetailState
    @EnvironmentObject var autoParsingService: AutoParsingService

    // UI State
    @State private var sidebarSelection: SidebarSelection?
    @State private var viewMode: ViewMode = .grid
    @AppStorage("selectedItemKind") private var selectedKind: ItemKind = .all
    @State private var searchText = ""
    @State private var debouncedSearchText = ""  // Debounced search for performance
    @State private var showingAddBookmark = false
    @State private var showingAddImage = false
    @State private var showingAddText = false
    @State private var showingImportDialog = false
    @State private var showingDiagnosticResults = false
    @State private var showingBatchOperation = false
    @ObservedObject var batchParsingService: BatchParsingService
    @StateObject private var diagnosticService = DiagnosticService(dataStorage: .shared)
    @StateObject private var sortPreferenceManager = SortPreferenceManager.shared
    @StateObject private var toastManager = GlobalToastManager.shared
    @StateObject private var exportImportManager = ExportImportManager.shared
    @EnvironmentObject var imageGenerationService: ImageGenerationService
    @StateObject private var pasteHandler = PasteHandler(dataStorage: .shared)
    @State private var isAgentPanelVisible = false

    @State private var cachedItems: [AnyCollectionItem] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?

    @State private var windowDelegate = MainWindowDelegate()
    
    init(batchParsingService: BatchParsingService) {
        self.batchParsingService = batchParsingService
    }
    
    var filteredItems: [AnyCollectionItem] {
        cachedItems
    }

    var navigationTitle: String {
        guard let sidebarSelection else { return "Bookmarks" }
        switch sidebarSelection {
        case .category(let id):
            return dataStorage.category(for: id)?.name ?? "Bookmarks"
        case .tag(let id):
            return dataStorage.tag(for: id)?.name ?? "Bookmarks"
        case .smartCollection(let id):
            return dataStorage.smartCollections.first(where: { $0.id == id })?.name ?? "Smart Collection"
        case .recent:
            return "Recent"
        case .unorganized:
            return "Unorganized"
        case .trash:
            return "Trash"
        }
    }

    private func recalculateFilteredItems() {
        filterTask?.cancel()
        guard let sidebarSelection else {
            cachedItems = []
            return
        }

        var criteria: CollectionSearch.Criteria
        switch sidebarSelection {
        case .category(let id):
            guard let category = dataStorage.category(for: id) else {
                cachedItems = []
                return
            }
            criteria = CollectionSearch.Criteria(
                query: debouncedSearchText,
                kind: collectionSearchKind,
                order: collectionSearchOrder
            )
            if category.name == "Favorites" {
                criteria.favoriteOnly = true
            } else if category.name != "All Bookmarks" {
                criteria.categoryID = category.id
            }
        case .tag(let id):
            criteria = CollectionSearch.Criteria(
                query: debouncedSearchText,
                kind: collectionSearchKind,
                tagIDs: [id],
                order: collectionSearchOrder
            )
        case .smartCollection(let id):
            guard let smartCollection = dataStorage.smartCollections.first(where: { $0.id == id }) else {
                cachedItems = []
                return
            }
            criteria = CollectionSearch.criteria(
                for: smartCollection,
                availableCategoryIDs: Set(dataStorage.categories.map(\.id)),
                availableTagIDs: Set(dataStorage.tags.map(\.id))
            )
            criteria.additionalQuery = debouncedSearchText
            applyKindFilter(to: &criteria)
        case .recent:
            let startOfToday = Calendar.current.startOfDay(for: Date())
            criteria = CollectionSearch.Criteria(
                query: debouncedSearchText,
                kind: collectionSearchKind,
                addedOnOrAfter: Calendar.current.date(byAdding: .day, value: -6, to: startOfToday),
                addedBefore: Calendar.current.date(byAdding: .day, value: 1, to: startOfToday),
                order: collectionSearchOrder
            )
        case .unorganized:
            criteria = CollectionSearch.Criteria(
                query: debouncedSearchText,
                kind: collectionSearchKind,
                unorganizedOnly: true,
                unorganizedCategoryID: dataStorage.categories.first(where: { $0.name == "None" })?.id,
                order: collectionSearchOrder
            )
        case .trash:
            cachedItems = []
            return
        }

        let records = dataStorage.searchRecordsSnapshot()
        filterTask = Task { @MainActor in
            let results = await CollectionSearch.itemsAsync(in: records, matching: criteria)
            guard !Task.isCancelled else { return }
            cachedItems = results
        }
    }

    private var collectionSearchKind: CollectionSearch.Kind {
        switch selectedKind {
        case .all: .all
        case .bookmark: .bookmark
        case .image: .image
        case .note: .text
        }
    }

    private var collectionSearchOrder: CollectionSearch.Order {
        switch sortPreferenceManager.sortOption {
        case .none: .none
        case .nameAscending: .nameAscending
        case .newestFirst: .newestFirst
        case .oldestFirst: .oldestFirst
        case .groupBySite: .groupBySite
        }
    }

    private func applyKindFilter(to criteria: inout CollectionSearch.Criteria) {
        guard collectionSearchKind != .all else { return }
        if criteria.kind == .all {
            criteria.kind = collectionSearchKind
        } else if criteria.kind != collectionSearchKind {
            criteria.matchesNothing = true
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection
            )
            .environmentObject(dataStorage)
        } detail: {
            HStack(spacing: 0) {
                mainContentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 420)

                if isAgentPanelVisible {
                    Divider()
                    AgentPanelView()
                        .environmentObject(dataStorage)
                        .environmentObject(itemDetailState)
                }
            }
            .navigationTitle(navigationTitle)
            .onDrop(of: [.url, .image, .plainText, .fileURL, .seahorseItemUUID], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Kind filter dropdown
                    Menu {
                        Picker("Kind", selection: $selectedKind) {
                            ForEach(ItemKind.allCases, id: \.self) { kind in
                                Label(kind.rawValue, systemImage: kind.icon)
                                    .tag(kind)
                            }
                        }
                    } label: {
                        Label(selectedKind.rawValue, systemImage: selectedKind.icon)
                    }

                    // Sort menu
                    SortMenuButton(sortPreferenceManager: sortPreferenceManager)

                    Menu {
                        Button(action: {
                            showingBatchOperation = true
                        }) {
                            Label(
                                batchParsingService.isRunning ? "Batch Operation Running" : "Batch Operation",
                                systemImage: batchParsingService.isRunning ? "pause.fill" : "play.fill"
                            )
                        }

                        Button(action: {
                            showingDiagnosticResults = true
                        }) {
                            Label(
                                diagnosticService.brokenBookmarks.isEmpty ? "Check Broken Bookmarks" : "Broken Bookmarks (\(diagnosticService.brokenBookmarks.count))",
                                systemImage: diagnosticService.isRunning ? "stethoscope.fill" : "stethoscope"
                            )
                        }

                        Button(action: {
                            imageGenerationService.showingPanel.toggle()
                        }) {
                            Label(
                                imageGenerationService.activeCount > 0 ? "Cover Generation (\(imageGenerationService.activeCount))" : "Cover Generation",
                                systemImage: imageGenerationService.isRunning ? "photo.fill" : "photo"
                            )
                        }

                        Divider()

                        Button(action: syncMobileBookmarkPage) {
                            Label(
                                exportImportManager.isSyncingBookmarkIndex ? "Syncing Mobile Bookmark Page" : "Sync Mobile Bookmark Page",
                                systemImage: exportImportManager.isSyncingBookmarkIndex ? "arrow.triangle.2.circlepath" : "iphone"
                            )
                        }
                        .disabled(exportImportManager.isSyncingBookmarkIndex)
                    } label: {
                        Label("Tools", systemImage: "ellipsis.circle")
                    }
                    .help("Tools")
                    .popover(isPresented: $imageGenerationService.showingPanel) {
                        ImageGenerationPanelView(service: imageGenerationService) { taskId, image in
                            applyGeneratedCover(taskId: taskId, image: image)
                        }
                    }

                    if !autoParsingService.failedBookmarkIDs.isEmpty {
                        Menu {
                            ForEach(autoParsingService.failedBookmarkIDs, id: \.self) { id in
                                Button {
                                    autoParsingService.retryBookmark(id: id)
                                } label: {
                                    Label(
                                        dataStorage.item(for: id)?.asBookmark?.title ?? "Bookmark",
                                        systemImage: "arrow.clockwise"
                                    )
                                }
                            }
                        } label: {
                            Label(
                                "Enrichment Failed (\(autoParsingService.failedBookmarkIDs.count))",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                        .help("Retry failed bookmark enrichment")
                    }
                }

                ToolbarItemGroup(placement: .automatic) {
                    // View mode toggle
                    Picker("View Mode", selection: $viewMode) {
                        Label("Grid", systemImage: "square.grid.2x2")
                            .tag(ViewMode.grid)
                        Label("List", systemImage: "list.bullet")
                            .tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()

                    // Add button with dropdown menu
                    Menu {
                        Button(action: {
                            showingAddBookmark = true
                        }) {
                            Label("Bookmark", systemImage: "link")
                        }
                        
                        Button(action: {
                            showingAddImage = true
                        }) {
                            Label("Image", systemImage: "photo")
                        }
                        
                        Button(action: {
                            showingAddText = true
                        }) {
                            Label("Text Note", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .help("Add Item")

                    Button {
                        isAgentPanelVisible.toggle()
                    } label: {
                        Label("Agent", systemImage: "sparkles")
                    }
                    .help(isAgentPanelVisible ? "Hide Agent" : "Show Agent")
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .background(WindowAccessor { window in
            if let window = window {
                window.delegate = windowDelegate
            }
        })
        .onAppear {
            // Set initial selection
            if let firstCategory = dataStorage.categories.first {
                sidebarSelection = .category(firstCategory.id)
            }
            // Initial calculation
            recalculateFilteredItems()
        }
        // Debounce search text changes (300ms delay) - always applies final value
        .onChange(of: searchText) { _, newValue in
            // Cancel previous debounce task
            searchDebounceTask?.cancel()

            // Start new debounce task
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                if !Task.isCancelled {
                    await MainActor.run {
                        self.debouncedSearchText = newValue
                    }
                }
            }
        }
        .onChange(of: sidebarSelection) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: selectedKind) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: debouncedSearchText) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: sortPreferenceManager.sortOption) { _, _ in
            recalculateFilteredItems()
        }
        // Watch for data changes (items added/deleted or updated in-place)
        .onChange(of: dataStorage.itemsVersion) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: dataStorage.smartCollections) { _, _ in
            recalculateFilteredItems()
        }
        .onDisappear {
            searchDebounceTask?.cancel()
            filterTask?.cancel()
        }
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkView()
                .environmentObject(dataStorage)
        }
        .sheet(isPresented: $showingAddImage) {
            AddImageView()
                .environmentObject(dataStorage)
        }
        .sheet(isPresented: $showingAddText) {
            AddTextView()
                .environmentObject(dataStorage)
        }
        .sheet(isPresented: $showingImportDialog) {
            ImportBookmarksView()
                .environmentObject(dataStorage)
        }
        .sheet(isPresented: $showingDiagnosticResults) {
            DiagnosticResultsView(diagnosticService: diagnosticService)
                .environmentObject(dataStorage)
        }
        .sheet(isPresented: $showingBatchOperation) {
            BatchOperationView(batchParsingService: batchParsingService)
                .environmentObject(dataStorage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowImportDialog"))) { _ in
            showingImportDialog = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddBookmark"))) { _ in
            showingAddBookmark = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddImage"))) { _ in
            showingAddImage = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddText"))) { _ in
            showingAddText = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowToast"))) { notification in
            let message = notification.userInfo?["message"] as? String ?? ""
            let icon = notification.userInfo?["icon"] as? String ?? "checkmark.circle.fill"
            GlobalToastManager.shared.show(message: message, icon: icon)
        }
        .onPasteCommand(of: [.url, .image, .plainText]) { providers in
            pasteHandler.handlePaste(providers: providers)
        }
        .toast(isPresented: $toastManager.isPresented, message: toastManager.message, icon: toastManager.icon, duration: 3.0)
    }

    @ViewBuilder
    private var mainContentArea: some View {
        if sidebarSelection == .trash {
            TrashView(searchText: debouncedSearchText, selectedKind: selectedKind)
                .environmentObject(dataStorage)
        } else if sidebarSelection != nil {
            ItemCollectionView(
                items: filteredItems,
                viewMode: viewMode
            )
            .overlay {
                if filteredItems.isEmpty {
                    emptyStateView
                        .background(Color(NSColor.windowBackgroundColor))
                }
            }
        } else {
            Text("Select a category")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedKind == .note ? "doc.text" : "bookmark.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(selectedKind == .note ? "No Notes" : "No Bookmarks")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                (selectedKind == .note ? "Add your first note to get started" : "Add your first bookmark to get started") :
                (selectedKind == .note ? "No notes match your search" : "No bookmarks match your search")
            )
            .font(.body)
            .foregroundStyle(.secondary)

            if case .smartCollection(let id) = sidebarSelection {
                Button("Edit Conditions") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("EditSmartCollection"),
                        object: id
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Use PasteHandler to process dropped items
        pasteHandler.handlePaste(providers: providers)
        return true
    }

    private func syncMobileBookmarkPage() {
        exportImportManager.syncBookmarkIndexToBackupFolder(dataStorage: dataStorage) { _, _ in }
    }

    private func applyGeneratedCover(taskId: UUID, image: NSImage) {
        guard let _ = imageGenerationService.applyImage(taskId: taskId) else { return }
        guard let task = imageGenerationService.tasks.first(where: { $0.id == taskId }) else { return }
        let imagesDir = StorageManager.shared.getImagesDirectory()
        Task { @MainActor in
            guard let filename = try? await ImageFileService.shared.savePNG(
                image,
                to: imagesDir,
                prefix: "preview"
            ), let bookmark = dataStorage.item(for: task.bookmarkId)?.asBookmark else {
                Log.error("Failed to write preview image to disk", category: .ai)
                return
            }
            var updated = bookmark
            if updated.metadata != nil {
                updated.metadata?.imageURL = filename
            } else {
                updated.metadata = WebMetadata(imageURL: filename, url: updated.url)
            }
            try? dataStorage.updateBookmark(updated)
            Log.info("Applied generated cover to bookmark: \"\(bookmark.title)\"", category: .ai)
        }
    }
}

#Preview {
    ContentView(batchParsingService: BatchParsingService(dataStorage: DataStorage.shared))
        .environmentObject(DataStorage.shared)
        .frame(width: 1200, height: 800)
}

#endif
