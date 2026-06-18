#if os(macOS)
//
//  ContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

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

    // UI State
    @State private var selectedCategory: Category?
    @State private var selectedTag: Tag?
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
    @StateObject private var diagnosticService: DiagnosticService
    @StateObject private var sortPreferenceManager = SortPreferenceManager.shared
    @StateObject private var toastManager = GlobalToastManager.shared
    @EnvironmentObject var imageGenerationService: ImageGenerationService
    @StateObject private var pasteHandler: PasteHandler
    @State private var isSyncing = false
    @State private var syncRotation: Double = 0
    @State private var syncStartTime: Date?

    // Cached filtered items - only recalculates when filters change
    @State private var cachedItems: [AnyCollectionItem] = []
    @State private var lastFilterHash: Int = 0
    @State private var searchDebounceTask: Task<Void, Never>?

    @State private var windowDelegate = MainWindowDelegate()
    
    init(batchParsingService: BatchParsingService) {
        let dataStorage = DataStorage.shared
        self.batchParsingService = batchParsingService
        _diagnosticService = StateObject(wrappedValue: DiagnosticService(dataStorage: dataStorage))
        _pasteHandler = StateObject(wrappedValue: PasteHandler(dataStorage: dataStorage))
    }
    
    var filteredItems: [AnyCollectionItem] {
        cachedItems
    }

    var navigationTitle: String {
        selectedCategory?.name ?? selectedTag?.name ?? "Bookmarks"
    }

    /// Computes a hash of current filter state to detect changes
    /// Uses debouncedSearchText for filtering to avoid recalculating on every keystroke
    private var filterHash: Int {
        var hasher = Hasher()
        hasher.combine(selectedCategory?.id)
        hasher.combine(selectedTag?.id)
        hasher.combine(selectedKind)
        hasher.combine(debouncedSearchText)  // Use debounced search
        hasher.combine(sortPreferenceManager.sortOption)
        hasher.combine(dataStorage.items.count) // Include item count to detect additions/deletions
        return hasher.finalize()
    }

    private func recalculateFilteredItems() {
        var items = dataStorage.items

        // Filter by kind
        switch selectedKind {
        case .all:
            break // Show all items
        case .bookmark:
            items = items.filter { $0.asBookmark != nil }
        case .image:
            items = items.filter { $0.asImageItem != nil }
        case .note:
            items = items.filter { $0.asTextItem != nil }
        }

        // Filter by category or tag
        if let category = selectedCategory {
            if category.name != "All Bookmarks" {
                if category.name == "Favorites" {
                    items = items.filter { item in
                        if let bookmark = item.asBookmark {
                            return bookmark.isFavorite
                        } else if let imageItem = item.asImageItem {
                            return imageItem.isFavorite
                        } else if let textItem = item.asTextItem {
                            return textItem.isFavorite
                        }
                        return false
                    }
                } else {
                    items = items.filter { item in
                        if let bookmark = item.asBookmark {
                            return bookmark.categoryId == category.id
                        } else if let imageItem = item.asImageItem {
                            return imageItem.categoryId == category.id
                        } else if let textItem = item.asTextItem {
                            return textItem.categoryId == category.id
                        }
                        return false
                    }
                }
            }
        } else if let tag = selectedTag {
            items = items.filter { item in
                if let bookmark = item.asBookmark {
                    return bookmark.tagIds.contains(tag.id)
                } else if let imageItem = item.asImageItem {
                    return imageItem.tagIds.contains(tag.id)
                } else if let textItem = item.asTextItem {
                    return textItem.tagIds.contains(tag.id)
                }
                return false
            }
        } else {
            cachedItems = []
            return
        }

        // Filter by search text (title/url/notes + tags) - uses debounced search
        let searchQuery = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchQuery.isEmpty {
            let queryLower = searchQuery.lowercased()
            items = items.filter { item in
                let searchable = searchableStrings(for: item)
                return searchable.contains { $0.contains(queryLower) }
            }
        }

        // Apply sorting to all items uniformly
        let sorted = sortPreferenceManager.sortOption.sort(items)

        cachedItems = sorted
    }
    
    private func tagNames(for item: AnyCollectionItem) -> [String] {
        let tagIds: [UUID] = item.asBookmark?.tagIds ??
            item.asImageItem?.tagIds ??
            item.asTextItem?.tagIds ??
            []
        
        guard !tagIds.isEmpty else { return [] }
        
        return dataStorage.tags
            .filter { tagIds.contains($0.id) }
            .map { $0.name.lowercased() }
    }
    
    private func searchableStrings(for item: AnyCollectionItem) -> [String] {
        var fields: [String] = []
        
        if let bookmark = item.asBookmark {
            fields.append(bookmark.title.lowercased())
            fields.append(bookmark.url.lowercased())
            if let notes = bookmark.notes {
                fields.append(notes.lowercased())
            }
        } else if let imageItem = item.asImageItem {
            fields.append(imageItem.imagePath.lowercased())
            if let notes = imageItem.notes {
                fields.append(notes.lowercased())
            }
        } else if let textItem = item.asTextItem {
            fields.append(textItem.content.lowercased())
            if let notes = textItem.notes {
                fields.append(notes.lowercased())
            }
        }
        
        fields.append(contentsOf: tagNames(for: item))
        return fields
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                categories: dataStorage.categories,
                tags: dataStorage.tags,
                selectedCategory: $selectedCategory,
                selectedTag: $selectedTag
            )
            .environmentObject(dataStorage)
        } detail: {
            Group {
                // Content area
                if selectedCategory != nil || selectedTag != nil {
                    ItemCollectionView(
                        items: filteredItems,
                        viewMode: viewMode
                    )
                    .overlay {
                        if filteredItems.isEmpty {
                            emptyStateView
                                .background(Color(NSColor.windowBackgroundColor)) // Ensure it covers the content
                        }
                    }
                } else {
                    Text("Select a category")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                    // Sync button
                    Button(action: performManualSync) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(syncRotation))
                            .animation(isSyncing
                                       ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                                       : .default,
                                       value: isSyncing)
                    }
                    .help("Sync")

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
                    } label: {
                        Label("Tools", systemImage: "ellipsis.circle")
                    }
                    .help("Tools")
                    .popover(isPresented: $imageGenerationService.showingPanel) {
                        ImageGenerationPanelView(service: imageGenerationService) { taskId, image in
                            applyGeneratedCover(taskId: taskId, image: image)
                        }
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
                selectedCategory = firstCategory
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
        .onChange(of: selectedCategory) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: selectedTag) { _, _ in
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
        .onChange(of: dataStorage.items.count) { _, _ in
            recalculateFilteredItems()
        }
        .onChange(of: dataStorage.itemsVersion) { _, _ in
            recalculateFilteredItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DataStorageItemsUpdated"))) { _ in
            recalculateFilteredItems()
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
        .onReceive(NotificationCenter.default.publisher(for: .autoSyncStarted)) { _ in
            startSyncAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoSyncEnded)) { _ in
            stopSyncAnimation()
        }
        .onPasteCommand(of: [.url, .image, .plainText]) { providers in
            pasteHandler.handlePaste(providers: providers)
        }
        .toast(isPresented: $toastManager.isPresented, message: toastManager.message, icon: toastManager.icon, duration: 3.0)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func performManualSync() {
        guard !isSyncing else { return }
        startSyncAnimation()

        Task { @MainActor in
            await ChromeBookmarkSyncService.shared.syncToChrome(from: dataStorage)
            if let error = ChromeBookmarkSyncService.shared.lastError {
                GlobalToastManager.shared.show(message: "Chrome sync failed: \(error)", icon: "xmark.circle.fill")
            } else {
                let count = ChromeBookmarkSyncService.shared.lastSyncCount
                let profile = ChromeBookmarkSyncService.shared.lastProfileName ?? "Default"
                GlobalToastManager.shared.show(message: "Synced \(count) bookmarks to Chrome (\(profile))", icon: "checkmark.circle.fill")
            }
            stopSyncAnimation()
        }
    }
    
    private func startSyncAnimation() {
        guard !isSyncing else { return }
        isSyncing = true
        syncRotation = 0
        syncStartTime = Date()
        syncRotation += 360
    }
    
    private func stopSyncAnimation() {
        guard let start = syncStartTime else {
            isSyncing = false
            syncRotation = 0
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let minimumDuration: TimeInterval = 1.0
        if elapsed >= minimumDuration {
            isSyncing = false
            syncRotation = 0
        } else {
            let remaining = minimumDuration - elapsed
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                isSyncing = false
                syncRotation = 0
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Use PasteHandler to process dropped items
        pasteHandler.handlePaste(providers: providers)
        return true
    }

    private func applyGeneratedCover(taskId: UUID, image: NSImage) {
        guard let _ = imageGenerationService.applyImage(taskId: taskId) else { return }

        let imagesDir = StorageManager.shared.getImagesDirectory()
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            Log.error("Failed to create images directory: \(error)", category: .ai)
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let filename = "preview-\(UUID().uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL)
        } catch {
            Log.error("Failed to write preview image to disk: \(error)", category: .ai)
            return
        }

        // Find the bookmark and update its metadata
        if let task = imageGenerationService.tasks.first(where: { $0.id == taskId }),
           let bookmark = dataStorage.bookmarks.first(where: { $0.id == task.bookmarkId }) {
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
