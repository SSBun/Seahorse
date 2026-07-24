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
    @Environment(\.openWindow) private var openWindow

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
    @State private var showingEnrichmentIssues = false
    @ObservedObject var batchParsingService: BatchParsingService
    @StateObject private var diagnosticService = DiagnosticService(dataStorage: .shared)
    @StateObject private var sortPreferenceManager = SortPreferenceManager.shared
    @StateObject private var toastManager = GlobalToastManager.shared
    @StateObject private var exportImportManager = ExportImportManager.shared
    @EnvironmentObject var imageGenerationService: ImageGenerationService
    @StateObject private var pasteHandler = PasteHandler(dataStorage: .shared)
    @State private var cachedItems: [AnyCollectionItem] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var filterTask: Task<Void, Never>?
    @State private var filterRequestID = 0

    @State private var windowDelegate = MainWindowDelegate()
    
    init(batchParsingService: BatchParsingService) {
        self.batchParsingService = batchParsingService
    }
    
    var filteredItems: [AnyCollectionItem] {
        cachedItems
    }

    private var diagnosticIssueCount: Int {
        diagnosticService.brokenBookmarks.count + diagnosticService.unverifiedBookmarks.count
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

    private func recalculateFilteredItems(reason: String) {
        filterTask?.cancel()
        guard let sidebarSelection else {
            cachedItems = []
            Log.info("list_perf filter_skip reason=\(reason) cause=no_selection", category: .performance)
            return
        }

        var criteria: CollectionSearch.Criteria
        switch sidebarSelection {
        case .category(let id):
            guard let category = dataStorage.category(for: id) else {
                cachedItems = []
                Log.info("list_perf filter_skip reason=\(reason) cause=missing_category", category: .performance)
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
                Log.info("list_perf filter_skip reason=\(reason) cause=missing_smart_collection", category: .performance)
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
            Log.info("list_perf filter_skip reason=\(reason) cause=trash_view", category: .performance)
            return
        }

        filterRequestID += 1
        let requestID = filterRequestID
        let snapshotInterval = ListPerformanceMonitor.shared.beginSnapshot(
            itemCount: dataStorage.items.count,
            reason: reason
        )
        let records = dataStorage.searchRecordsSnapshot()
        ListPerformanceMonitor.shared.endSnapshot(
            snapshotInterval,
            recordCount: records.count,
            reason: reason
        )
        let filterInterval = ListPerformanceMonitor.shared.beginFilter(
            requestID: requestID,
            reason: reason,
            recordCount: records.count,
            queryLength: criteria.query.count + criteria.additionalQuery.count,
            selection: performanceSelectionName,
            kind: String(describing: criteria.kind),
            order: String(describing: criteria.order)
        )
        filterTask = Task { @MainActor in
            let results = await CollectionSearch.itemsAsync(in: records, matching: criteria)
            guard !Task.isCancelled else {
                ListPerformanceMonitor.shared.endFilter(
                    filterInterval,
                    requestID: requestID,
                    resultCount: 0,
                    applyMs: 0,
                    cancelled: true
                )
                return
            }
            let applyStartedAt = ProcessInfo.processInfo.systemUptime
            cachedItems = results
            let applyMs = max(
                Int((ProcessInfo.processInfo.systemUptime - applyStartedAt) * 1_000),
                0
            )
            ListPerformanceMonitor.shared.endFilter(
                filterInterval,
                requestID: requestID,
                resultCount: results.count,
                applyMs: applyMs,
                cancelled: false
            )
        }
    }

    private var performanceSelectionName: String {
        switch sidebarSelection {
        case .category: "category"
        case .tag: "tag"
        case .smartCollection: "smart_collection"
        case .recent: "recent"
        case .unorganized: "unorganized"
        case .trash: "trash"
        case .none: "none"
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
            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 420)
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
                                diagnosticIssueCount == 0 ? "Check Bookmark Links" : "Link Issues (\(diagnosticIssueCount))",
                                systemImage: diagnosticService.isRunning ? "stethoscope.fill" : "stethoscope"
                            )
                        }

                        Button(action: {
                            imageGenerationService.clearPreparedBookmark()
                            openWindow(id: "image-generation")
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

                    if !autoParsingService.failedBookmarkIDs.isEmpty {
                        Button {
                            showingEnrichmentIssues = true
                        } label: {
                            Label(
                                "Enrichment Issues (\(autoParsingService.failedBookmarkIDs.count))",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                        .help("View bookmark enrichment issues")
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
                        openWindow(id: "agent-chat")
                    } label: {
                        Label("Agent", systemImage: "sparkles")
                    }
                    .help("Open Agent")
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
            recalculateFilteredItems(reason: "initial_appear")
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
            recalculateFilteredItems(reason: "sidebar_selection")
        }
        .onChange(of: selectedKind) { _, _ in
            recalculateFilteredItems(reason: "item_kind")
        }
        .onChange(of: debouncedSearchText) { _, _ in
            recalculateFilteredItems(reason: "search")
        }
        .onChange(of: sortPreferenceManager.sortOption) { _, _ in
            recalculateFilteredItems(reason: "sort")
        }
        // Watch for data changes (items added/deleted or updated in-place)
        .onChange(of: dataStorage.itemsVersion) { _, _ in
            recalculateFilteredItems(reason: "items_version")
        }
        .onChange(of: dataStorage.smartCollections) { _, _ in
            recalculateFilteredItems(reason: "smart_collections")
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
        .sheet(isPresented: $showingEnrichmentIssues) {
            EnrichmentIssuesView(autoParsingService: autoParsingService)
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
        .onReceive(NotificationCenter.default.publisher(for: .seahorseBookmarkRefreshed)) { _ in
            GlobalToastManager.shared.show(
                message: "Bookmark moved to the top",
                icon: "arrow.up.circle.fill"
            )
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

}

#Preview {
    ContentView(batchParsingService: BatchParsingService(dataStorage: DataStorage.shared))
        .environmentObject(DataStorage.shared)
        .frame(width: 1200, height: 800)
}

#endif
