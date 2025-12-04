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
    @StateObject private var batchParsingService: BatchParsingService
    @StateObject private var diagnosticService: DiagnosticService
    @StateObject private var sortPreferenceManager = SortPreferenceManager.shared
    @StateObject private var pasteHandler: PasteHandler
    
    init() {
        let dataStorage = DataStorage.shared
        _batchParsingService = StateObject(wrappedValue: BatchParsingService(dataStorage: dataStorage))
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
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                if let bookmark = item.asBookmark {
                    return bookmark.title.localizedCaseInsensitiveContains(searchText) ||
                           bookmark.url.localizedCaseInsensitiveContains(searchText) ||
                           (bookmark.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                } else if let imageItem = item.asImageItem {
                    return imageItem.imagePath.localizedCaseInsensitiveContains(searchText) ||
                           (imageItem.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                } else if let textItem = item.asTextItem {
                    return textItem.content.localizedCaseInsensitiveContains(searchText) ||
                           (textItem.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
                return false
            }
        }
        
        // Apply sorting to all items uniformly
        return sortPreferenceManager.sortOption.sort(items)
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
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        ItemCollectionView(
                            items: filteredItems,
                            viewMode: viewMode
                        )
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
}

#Preview {
    ContentView()
        .environmentObject(DataStorage.shared)
        .frame(width: 1200, height: 800)
}
