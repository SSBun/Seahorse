//
//  AddBookmarkView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct AddBookmarkView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.dismiss) var dismiss
    
    // Editing mode
    let editingBookmark: Bookmark?
    
    @State private var urlString = ""
    @State private var title = ""
    @State private var summary = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var isFavorite = false
    @State private var iconURL: String? = nil
    @State private var webMetadata: WebMetadata? = nil // OGP/Twitter Data
    
    init(editingBookmark: Bookmark? = nil) {
        self.editingBookmark = editingBookmark
    }
    
    @State private var isParsing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasParseCompleted = false
    @State private var wasParsed = false // Track if bookmark was AI-parsed
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    @State private var showingNewItemsDialog = false
    @State private var suggestedNewCategory: String?
    @State private var suggestedNewTags: [String] = []
    @State private var selectedNewCategory = false
    @State private var selectedNewTags: Set<String> = []
    
    private let aiManager = AIManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingBookmark == nil ? "Add Bookmark" : "Edit Bookmark")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // URL Input with Parse Button
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("URL")
                                    .font(.system(size: 13, weight: .semibold))
                                
                                HStack {
                                    TextField("https://example.com", text: $urlString)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button(action: {
                                        Task {
                                            await fetchMetadataOnly()
                                        }
                                    }) {
                                        Label("Fetch Info", systemImage: "link")
                                    }
                                    .disabled(urlString.isEmpty || isParsing)
                                    
                                    Button(action: {
                                        Task {
                                            parseURL()
                                        }
                                    }) {
                                        Label(isParsing ? "Parsing..." : "AI Parse", systemImage: "sparkles")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(urlString.isEmpty || isParsing)
                                }
                            }
                        }
                        
                        Text("Enter the bookmark URL and click Parse to automatically fetch content and suggestions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Icon & Title
                    HStack(alignment: .top, spacing: 16) {
                        // Icon Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.headline)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 80, height: 80)
                                
                                // Fixed icon preview - no loading states
                                Image(systemName: "link")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.system(size: 13, weight: .semibold))
                            
                            TextField("Bookmark title", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                    }
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack(alignment: .topLeading) {
                            if summary.isEmpty {
                                Text("Click Parse to generate an AI summary, or write your own...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $summary)
                                .font(.system(size: 13))
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        }
                    }
                    
                    Divider()
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.system(size: 13, weight: .semibold))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(dataStorage.categories) { category in
                                // Skip "All Bookmarks" and "Favorites"
                                if category.name != "All Bookmarks" && category.name != "Favorites" {
                                    CategorySelectionButton(
                                        category: category,
                                        isSelected: selectedCategoryId == category.id,
                                        onSelect: {
                                            selectedCategoryId = category.id
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .semibold))
                        
                        if dataStorage.tags.isEmpty {
                            Text("No tags available. Create tags in Settings.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(dataStorage.tags) { tag in
                                    TagSelectionButton(
                                        tag: tag,
                                        isSelected: selectedTagIds.contains(tag.id),
                                        onToggle: {
                                            if selectedTagIds.contains(tag.id) {
                                                selectedTagIds.remove(tag.id)
                                            } else {
                                                selectedTagIds.insert(tag.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Favorite Toggle
                    HStack {
                        Toggle(isOn: $isFavorite) {
                            HStack(spacing: 8) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                                Text("Add to Favorites")
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(editingBookmark == nil ? "Add Bookmark" : "Save Changes") {
                    if editingBookmark != nil {
                        updateBookmark()
                    } else {
                        saveBookmark()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty || title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 700)
        .onAppear {
            if editingBookmark != nil {
                populateFieldsIfEditing()
            } else {
                // Set default category to "None" for new bookmarks
                if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                    selectedCategoryId = noneCategory.id
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingNewItemsDialog) {
            NewItemsConfirmationView(
                suggestedNewCategory: suggestedNewCategory,
                suggestedNewTags: suggestedNewTags,
                selectedNewCategory: $selectedNewCategory,
                selectedNewTags: $selectedNewTags,
                onConfirm: {
                    createAndUseNewItems()
                    showingNewItemsDialog = false
                },
                onCancel: {
                    clearNewItemSelections()
                    showingNewItemsDialog = false
                    toastMessage = "✨ Parsing completed successfully!"
                    showingToast = true
                }
            )
        }
        .toast(isPresented: $showingToast, message: toastMessage, icon: "checkmark.circle.fill")
    }
    
    private func parseURL() {
        isParsing = true
        hasParseCompleted = false
        
        Task {
            do {
                // Step 1: Fetch web content
                let (fetchedTitle, content) = try await aiManager.fetchWebContent(url: urlString)
                
                // Fetch favicon in parallel
                async let faviconTask = aiManager.fetchFavicon(url: urlString)
                
                // Fetch OGP/Metadata in parallel
                async let metadataTask = OpenGraphService.shared.fetchMetadata(url: URL(string: urlString)!)
                
                await MainActor.run {
                    title = fetchedTitle
                }
                
                // Step 2: Parse with AI
                let categoryNames = dataStorage.categories
                    .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
                    .map { $0.name }
                
                let tagNames = dataStorage.tags.map { $0.name }
                
                let parsedData = try await aiManager.parseBookmarkContent(
                    title: fetchedTitle,
                    content: content,
                    availableCategories: categoryNames,
                    availableTags: tagNames
                )
                
                // Get favicon result
                let faviconURL = await faviconTask
                
                // Get Metadata result
                let metadata = try? await metadataTask
                
                // Step 3: Process AI suggestions
                await MainActor.run {
                    // Only overwrite title if it's empty or "Untitled"
                    if title.isEmpty || title == "Untitled" {
                        title = parsedData.refinedTitle
                    }
                    
                    // Only overwrite icon if it's nil
                    if iconURL == nil {
                        // Use favicon if available, otherwise use AI-suggested SF Symbol
                        iconURL = faviconURL ?? parsedData.suggestedSFSymbol
                    }
                    
                    // Use Metadata if available
                    if let metadata = metadata {
                        webMetadata = metadata
                        // If AI didn't find a good title and we still need one, use OGP title
                        if title.isEmpty || title == "Untitled" {
                            title = metadata.title ?? title
                        }
                        // If summary is empty, use OGP description (AI summary usually takes precedence if generated)
                        if summary.isEmpty {
                            summary = metadata.description ?? ""
                        }
                    } else {
                        // If no metadata, use AI summary
                         summary = parsedData.summary
                    }
                    
                    // If we have an AI summary, use it (it's usually better than OGP description)
                    if !parsedData.summary.isEmpty {
                        summary = parsedData.summary
                    }
                    
                    // Check for new category
                    var newCategory: String?
                    if let suggestedName = parsedData.suggestedCategoryName {
                        if let existingCategory = dataStorage.categories.first(where: { $0.name.lowercased() == suggestedName.lowercased() }) {
                            selectedCategoryId = existingCategory.id
                        } else {
                            newCategory = suggestedName
                        }
                    }
                    
                    // Check for new tags
                    var newTags: [String] = []
                    selectedTagIds.removeAll()
                    for tagName in parsedData.suggestedTagNames {
                        if let existingTag = dataStorage.tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) {
                            selectedTagIds.insert(existingTag.id)
                        } else {
                            newTags.append(tagName)
                        }
                    }
                    
                    isParsing = false
                    hasParseCompleted = true
                    wasParsed = true
                    
                    // Show dialog if there are new items to create
                    if newCategory != nil || !newTags.isEmpty {
                        suggestedNewCategory = newCategory
                        suggestedNewTags = newTags
                        selectedNewCategory = newCategory != nil
                        selectedNewTags = Set(newTags)
                        showingNewItemsDialog = true
                    } else {
                        // Show success toast
                        toastMessage = "✨ Parsing completed successfully!"
                        showingToast = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isParsing = false
                }
            }
        }
    }
    
    private func fetchMetadataOnly() async {
        guard let url = URL(string: urlString) else { return }
        
        isParsing = true
        defer { isParsing = false }
        
        do {
            let metadata = try await OpenGraphService.shared.fetchMetadata(url: url)
            print("Fetched Metadata: \(metadata)")
            
            await MainActor.run {
                self.webMetadata = metadata
                
                // Overwrite fields with OGP data
                if let ogTitle = metadata.title, !ogTitle.isEmpty {
                    title = ogTitle
                }
                
                if let ogDescription = metadata.description, !ogDescription.isEmpty {
                    summary = ogDescription
                }
                
                if let favicon = metadata.faviconURL {
                    iconURL = favicon
                }
                
                // If we found a site name, maybe use it as a default category or tag?
                // For now, just leaving it in metadata
            }
        } catch {
            print("Failed to fetch metadata: \(error)")
        }
    }
    
    private func clearNewItemSelections() {
        suggestedNewCategory = nil
        suggestedNewTags = []
        selectedNewCategory = false
        selectedNewTags.removeAll()
    }
    
    private func createAndUseNewItems() {
        // Create new category if selected
        if selectedNewCategory, let newCategoryName = suggestedNewCategory {
            let newCategory = Category(
                name: newCategoryName,
                icon: "folder.fill",
                color: .blue
            )
            do {
                try dataStorage.addCategory(newCategory)
                selectedCategoryId = newCategory.id
            } catch {
                print("Failed to create category: \(error)")
            }
        }
        
        // Create new tags if selected
        for newTagName in selectedNewTags {
            let newTag = Tag(
                name: newTagName,
                color: .blue
            )
            do {
                try dataStorage.addTag(newTag)
                selectedTagIds.insert(newTag.id)
            } catch {
                print("Failed to create tag: \(error)")
            }
        }
        
        clearNewItemSelections()
        
        // Show success toast
        toastMessage = "✨ Parsing completed successfully!"
        showingToast = true
    }
    
    private func populateFieldsIfEditing() {
        guard let bookmark = editingBookmark else { return }
        
        urlString = bookmark.url
        title = bookmark.title
        summary = bookmark.notes ?? ""
        selectedCategoryId = bookmark.categoryId
        selectedTagIds = Set(bookmark.tagIds)
        isFavorite = bookmark.isFavorite
        iconURL = bookmark.icon
        webMetadata = bookmark.metadata
        wasParsed = bookmark.isParsed // Preserve parsed status
    }
    
    private func updateBookmark() {
        guard let editingBookmark = editingBookmark else { return }
        guard !urlString.isEmpty, !title.isEmpty else { return }
        
        // Ensure a category is selected
        let categoryId = selectedCategoryId ?? {
            if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                return noneCategory.id
            }
            return dataStorage.categories.first?.id ?? UUID()
        }()
        
        let updatedBookmark = Bookmark(
            id: editingBookmark.id,  // Keep the same ID
            title: title,
            url: urlString,
            icon: iconURL ?? "link.circle.fill",
            categoryId: categoryId,
            isFavorite: isFavorite,
            addedDate: editingBookmark.addedDate,  // Keep the original creation date
            notes: summary.isEmpty ? nil : summary,
            tagIds: Array(selectedTagIds),
            isParsed: wasParsed || editingBookmark.isParsed, // Keep parsed status or update if newly parsed
            metadata: webMetadata
        )
        
        do {
            try dataStorage.updateBookmark(updatedBookmark)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func saveBookmark() {
        guard !urlString.isEmpty, !title.isEmpty else { return }
        
        // Ensure a category is selected
        let categoryId = selectedCategoryId ?? {
            if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                return noneCategory.id
            }
            return dataStorage.categories.first?.id ?? UUID()
        }()
        
        let bookmark = Bookmark(
            title: title,
            url: urlString,
            icon: iconURL ?? "link.circle.fill",
            categoryId: categoryId,
            isFavorite: isFavorite,
            notes: summary.isEmpty ? nil : summary,
            tagIds: Array(selectedTagIds),
            isParsed: wasParsed,
            metadata: webMetadata
        )
        
        do {
            try dataStorage.addBookmark(bookmark)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Views

struct CategorySelectionButton: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagSelectionButton: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(tag.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? tag.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? tag.color : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    AddBookmarkView()
        .environmentObject(DataStorage.shared)
}

