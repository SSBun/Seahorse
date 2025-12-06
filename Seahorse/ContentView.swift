//
//  ContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStorage: DataStorage
    
    // UI State
    @State private var selectedCategory: Category?
    @State private var selectedTag: Tag?
    @State private var viewMode: ViewMode = .grid
    @State private var searchText = ""
    @State private var showingAddBookmark = false
    @State private var showingAddImage = false
    @State private var showingAddText = false
    @State private var showingImportDialog = false
    @State private var showingDiagnosticResults = false
    @ObservedObject var batchParsingService: BatchParsingService
    @StateObject private var diagnosticService: DiagnosticService
    @StateObject private var sortPreferenceManager = SortPreferenceManager.shared
    @StateObject private var pasteHandler: PasteHandler
    @FocusState private var isSearchFocused: Bool
    @State private var isSyncing = false
    @State private var syncRotation: Double = 0
    @State private var syncStartTime: Date?
    
    @State private var windowDelegate = MainWindowDelegate()
    
    init(batchParsingService: BatchParsingService) {
        let dataStorage = DataStorage.shared
        self.batchParsingService = batchParsingService
        _diagnosticService = StateObject(wrappedValue: DiagnosticService(dataStorage: dataStorage))
        _pasteHandler = StateObject(wrappedValue: PasteHandler(dataStorage: dataStorage))
    }
    
    var filteredItems: [AnyCollectionItem] {
        var items = dataStorage.items
        
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
            return []
        }
        
        // Filter by search text (title/url/notes + tags)
        let searchQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchQuery.isEmpty {
            let queryLower = searchQuery.lowercased()
            items = items.filter { item in
                let searchable = searchableStrings(for: item)
                return searchable.contains { $0.contains(queryLower) }
            }
        }
        
        // Apply sorting to all items uniformly
        return sortPreferenceManager.sortOption.sort(items)
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
            .navigationTitle(selectedCategory?.name ?? "Bookmarks")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Search field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($isSearchFocused)
                            .frame(width: 180)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    
                    // Sync button
                    Button(action: performManualSync) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(syncRotation))
                            .animation(isSyncing
                                       ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                                       : .default,
                                       value: isSyncing)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                    .help("Sync")
                }
                
                ToolbarItemGroup(placement: .automatic) {
                    // Sort menu (Finder-style)
                    Menu {
                        ForEach(SortOption.allCases) { option in
                            Button(action: {
                                sortPreferenceManager.sortOption = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    Spacer()
                                    if sortPreferenceManager.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help("Sort bookmarks")
                    
                    // Batch parsing button
                    Button(action: {
                        if batchParsingService.isRunning {
                            batchParsingService.pause()
                        } else {
                            batchParsingService.start()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: batchParsingService.isRunning ? "pause.fill" : "play.fill")
                                .foregroundStyle(batchParsingService.isRunning ? .orange : .blue)
                            
                            if batchParsingService.isRunning {
                                Text("\(batchParsingService.completedCount)/\(batchParsingService.totalCount)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .help(batchParsingService.isRunning ? "Pause Batch Parsing" : "Start Batch Parsing")
                    
                    // Parsing progress indicator
                    if batchParsingService.isRunning, let current = batchParsingService.currentBookmark {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            
                            Text("Parsing: \(current.title)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 100)
                        }
                    }
                    
                    // Diagnostic button
                    Button(action: {
                        // Always open the diagnostic view
                        showingDiagnosticResults = true
                        // Start diagnostic if not already running
                        if !diagnosticService.isRunning {
                            diagnosticService.start()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: diagnosticService.isRunning ? "stethoscope.fill" : "stethoscope")
                                .foregroundStyle(diagnosticService.isRunning ? .orange : .green)
                                .symbolEffect(.pulse, isActive: diagnosticService.isRunning)
                            
                            if diagnosticService.isRunning {
                                Text("\(diagnosticService.checkedCount)/\(diagnosticService.totalCount)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            } else if !diagnosticService.brokenBookmarks.isEmpty {
                                Text("\(diagnosticService.brokenBookmarks.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .help(diagnosticService.isRunning ? L10n.viewDiagnosticProgress : L10n.checkBrokenBookmarks)
                    .accessibilityLabel(diagnosticService.isRunning ? L10n.viewDiagnosticProgress : L10n.checkBrokenBookmarks)
                    
                    Divider()
                    
                    // View mode toggle
                    Picker("View Mode", selection: $viewMode) {
                        Label("Grid", systemImage: "square.grid.2x2")
                            .tag(ViewMode.grid)
                        Label("List", systemImage: "list.bullet")
                            .tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    
                    Divider()
                    
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
        .onReceive(NotificationCenter.default.publisher(for: .autoSyncStarted)) { _ in
            startSyncAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoSyncEnded)) { _ in
            stopSyncAnimation()
        }
        .onPasteCommand(of: [.url, .image, .plainText]) { providers in
            pasteHandler.handlePaste(providers: providers)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Bookmarks")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? 
                "Add your first bookmark to get started" :
                "No bookmarks match your search"
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
            // Force save triggers autoSync notifications; we handle animation stop with minimum duration.
            DataStorage.shared.forceSaveAllData()
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
}

#Preview {
    ContentView(batchParsingService: BatchParsingService(dataStorage: DataStorage.shared))
        .environmentObject(DataStorage.shared)
        .frame(width: 1200, height: 800)
}
