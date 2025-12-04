//
//  ItemDetailView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import CoreGraphics
import ImageIO

struct ItemDetailView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.dismissWindow) var dismissWindow
    
    let item: AnyCollectionItem
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var notes: String = ""
    @State private var isFavorite: Bool = false
    @State private var bookmarkTitle: String = ""
    @State private var tagInputText: String = ""
    @FocusState private var isTagInputFocused: Bool
    @State private var tagToDelete: Tag?
    @State private var showingDeleteConfirmation = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    // Extract specific item types
    private var bookmark: Bookmark? { item.asBookmark }
    private var imageItem: ImageItem? { item.asImageItem }
    private var textItem: TextItem? { item.asTextItem }
    
    var body: some View {
        HSplitView {
            // Left: Content Area
            contentArea
                .frame(minWidth: 300)
            
            // Right: Sidebar
            sidebar
                .frame(width: 300)
        }
        .frame(minWidth: 500, minHeight: 500)
        .frame(idealWidth: 700, idealHeight: 550)
        .onAppear {
            loadItemData()
        }
        .confirmationDialog(
            "Delete Tag",
            isPresented: $showingDeleteConfirmation,
            presenting: tagToDelete
        ) { tag in
            Button("Delete", role: .destructive) {
                deleteTag(tag)
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: { tag in
            Text("Are you sure you want to delete '\(tag.name)'? This tag will be removed from all items.")
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch item.itemType {
            case .bookmark:
                if let bookmark = bookmark {
                    BookmarkDetailContentView(bookmark: bookmark)
                } else {
                    Text("Invalid bookmark")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .image:
                if let imageItem = imageItem {
                    ImageDetailContentView(imageItem: imageItem)
                } else {
                    Text("Invalid image")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .text:
                if let textItem = textItem {
                    TextDetailContentView(textItem: textItem)
                        .environmentObject(dataStorage)
                } else {
                    Text("Invalid text item")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Details")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title editor (for bookmarks only)
                    if bookmark != nil {
                        titleSection
                    }
                    
                    // Category Selection
                    categorySection
                    
                    // Tags
                    tagsSection
                    
                    // Notes
                    notesSection
                    
                    // Metadata
                    metadataSection
                }
                .padding()
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Dismiss editing state when clicking outside text fields and text areas
                        // This will be called even if child views handle the tap
                        isTagInputFocused = false
                        // Make window resign first responder to dismiss TextEditor focus
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
            )
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Sidebar Sections
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Bookmark title", text: $bookmarkTitle)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .onChange(of: bookmarkTitle) { oldValue, newValue in
                    updateBookmarkTitle(newValue)
                }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Picker("Category", selection: $selectedCategoryId) {
                ForEach(dataStorage.categories) { category in
                    Text(category.name).tag(category.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedCategoryId) { oldValue, newValue in
                updateCategory(newValue)
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            // Selected tags
            if !selectedTagIds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(selectedTagIds), id: \.self) { tagId in
                        if let tag = dataStorage.tags.first(where: { $0.id == tagId }) {
                            HStack(spacing: 4) {
                                Text("#\(tag.name)")
                                    .font(.system(size: 11))
                                Button(action: {
                                    selectedTagIds.remove(tagId)
                                    updateTags()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 9))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(.primary)
                            .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Tag input field
            TextField("Type to add tag...", text: $tagInputText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .focused($isTagInputFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isTagInputFocused ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isTagInputFocused ? 2 : 1)
                )
                .onSubmit {
                    handleTagInputSubmit()
                }
            
            // Available tags selection (tag cloud) - Fixed height ScrollView
            let unselectedTags = getUnselectedTags(filteredBy: tagInputText)
            ScrollView {
                if !unselectedTags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(unselectedTags) { tag in
                            Button(action: {
                                selectTag(tag)
                            }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 5, height: 5)
                                    Text("#\(tag.name)")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(tag.color.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(tag.color.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundStyle(tag.color)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    tagToDelete = tag
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete Tag", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(8)
                } else {
                    // Empty state when no tags match
                    Text("No tags available")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                }
            }
            .frame(height: 150) // Fixed height to prevent layout shifts
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
    }
    
    private func getUnselectedTags(filteredBy query: String = "") -> [Tag] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var tags = dataStorage.tags
            .filter { !selectedTagIds.contains($0.id) }
        
        // Filter by query if provided
        if !queryLower.isEmpty {
            tags = tags.filter { $0.name.lowercased().contains(queryLower) }
        }
        
        return tags.sorted { $0.name < $1.name }
    }
    
    private func selectTag(_ tag: Tag) {
        selectedTagIds.insert(tag.id)
        updateTags()
    }
    
    private func handleTagInputSubmit() {
        let trimmedName = tagInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if tag already exists
        if dataStorage.tagExists(name: trimmedName) {
            // Tag exists, add it
            if let existingTag = dataStorage.tags.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                selectTag(existingTag)
                tagInputText = "" // Clear input
                return
            }
        }
        
        // Create new tag with default color
        let newTag = Tag(name: trimmedName, color: AppConfig.shared.defaultTagColor)
        
        do {
            try dataStorage.addTag(newTag)
            selectTag(newTag)
            tagInputText = "" // Clear input
        } catch {
            // Handle error (tag might already exist)
            if let existingTag = dataStorage.tags.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                selectTag(existingTag)
                tagInputText = "" // Clear input
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextEditor(text: $notes)
                .font(.system(size: 12))
                .frame(height: 120)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .scrollContentBackground(.hidden)
                .onChange(of: notes) { oldValue, newValue in
                    updateNotes(newValue)
                }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                metadataRow(label: "Type", value: itemTypeLabel)
                metadataRow(label: "Added", value: formatDate(item.addedDate))
                if let modifiedDate = bookmark?.modifiedDate ?? imageItem?.modifiedDate ?? textItem?.modifiedDate {
                    metadataRow(label: "Modified", value: formatDate(modifiedDate))
                } else {
                    metadataRow(label: "Modified", value: "Never")
                }
                
                // Type-specific metadata
                if let bookmark = bookmark {
                    metadataRow(label: "URL", value: bookmark.url)
                    if let domain = URL(string: bookmark.url)?.host {
                        metadataRow(label: "Domain", value: domain)
                    }
                } else if let imageItem = imageItem {
                    // Image dimensions
                    if let size = imageItem.imageSize {
                        metadataRow(label: "Dimensions", value: "\(Int(size.width)) × \(Int(size.height)) px")
                    } else {
                        // Try to get size from actual image file
                        if let imageSize = getImageSize(imageItem.imagePath) {
                            metadataRow(label: "Dimensions", value: "\(Int(imageSize.width)) × \(Int(imageSize.height)) px")
                        }
                    }
                    // File size
                    if let fileSize = getFileSize(imageItem.imagePath) {
                        metadataRow(label: "File Size", value: fileSize)
                    }
                    // File path (truncated if too long)
                    let pathDisplay = imageItem.imagePath.count > 50 
                        ? "..." + String(imageItem.imagePath.suffix(47))
                        : imageItem.imagePath
                    metadataRow(label: "Path", value: pathDisplay)
                } else if let textItem = textItem {
                    metadataRow(label: "Characters", value: "\(textItem.content.count)")
                    metadataRow(label: "Words", value: "\(textItem.content.split(separator: " ").count)")
                    metadataRow(label: "Lines", value: "\(textItem.content.components(separatedBy: .newlines).count)")
                }
            }
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadItemData() {
        selectedCategoryId = bookmark?.categoryId ?? imageItem?.categoryId ?? textItem?.categoryId
        selectedTagIds = Set(bookmark?.tagIds ?? imageItem?.tagIds ?? textItem?.tagIds ?? [])
        notes = bookmark?.notes ?? imageItem?.notes ?? textItem?.notes ?? ""
        isFavorite = bookmark?.isFavorite ?? imageItem?.isFavorite ?? textItem?.isFavorite ?? false
        if let bookmark = bookmark {
            bookmarkTitle = bookmark.title
        }
    }
    
    private func updateCategory(_ categoryId: UUID?) {
        guard let categoryId = categoryId else { return }
        var updatedItem = item
        
        if var bookmark = bookmark {
            bookmark.categoryId = categoryId
            bookmark.modifiedDate = Date()
            updatedItem = AnyCollectionItem(bookmark)
        } else if var imageItem = imageItem {
            imageItem.categoryId = categoryId
            imageItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(imageItem)
        } else if var textItem = textItem {
            textItem.categoryId = categoryId
            textItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(textItem)
        }
        
        dataStorage.updateItem(updatedItem)
    }
    
    private func updateTags() {
        var updatedItem = item
        
        if var bookmark = bookmark {
            bookmark.tagIds = Array(selectedTagIds)
            bookmark.modifiedDate = Date()
            updatedItem = AnyCollectionItem(bookmark)
        } else if var imageItem = imageItem {
            imageItem.tagIds = Array(selectedTagIds)
            imageItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(imageItem)
        } else if var textItem = textItem {
            textItem.tagIds = Array(selectedTagIds)
            textItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(textItem)
        }
        
        dataStorage.updateItem(updatedItem)
    }
    
    private func updateNotes(_ newNotes: String) {
        var updatedItem = item
        
        if var bookmark = bookmark {
            bookmark.notes = newNotes.isEmpty ? nil : newNotes
            bookmark.modifiedDate = Date()
            updatedItem = AnyCollectionItem(bookmark)
        } else if var imageItem = imageItem {
            imageItem.notes = newNotes.isEmpty ? nil : newNotes
            imageItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(imageItem)
        } else if var textItem = textItem {
            textItem.notes = newNotes.isEmpty ? nil : newNotes
            textItem.modifiedDate = Date()
            updatedItem = AnyCollectionItem(textItem)
        }
        
        dataStorage.updateItem(updatedItem)
    }
    
    private func saveTextContent(_ newContent: String) {
        guard var textItem = textItem else { return }
        textItem.content = newContent
        textItem.modifiedDate = Date()
        dataStorage.updateItem(AnyCollectionItem(textItem))
    }
    
    private func updateBookmarkTitle(_ newTitle: String) {
        guard var bookmark = bookmark else { return }
        bookmark.title = newTitle
        bookmark.modifiedDate = Date()
        dataStorage.updateItem(AnyCollectionItem(bookmark))
    }
    
    private func getImageSize(_ path: String) -> CGSize? {
        // Check if it's a remote URL
        if let url = URL(string: path), (url.scheme == "http" || url.scheme == "https") {
            // For remote images, we can't easily get size without loading
            return nil
        }
        
        // For local images
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = imageProperties[kCGImagePropertyPixelWidth as String] as? CGFloat,
              let height = imageProperties[kCGImagePropertyPixelHeight as String] as? CGFloat else {
            return nil
        }
        
        return CGSize(width: width, height: height)
    }
    
    private var itemTypeLabel: String {
        switch item.itemType {
        case .bookmark: return "Link"
        case .image: return "Image"
        case .text: return "Text"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getFileSize(_ path: String) -> String? {
        // Check if it's a remote URL
        if let url = URL(string: path), (url.scheme == "http" || url.scheme == "https") {
            // Remote URL, can't get file size
            return nil
        }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    private func deleteTag(_ tag: Tag) {
        // Remove tag from all items first
        let itemsWithTag = dataStorage.items.filter { item in
            if let bookmark = item.asBookmark {
                return bookmark.tagIds.contains(tag.id)
            } else if let imageItem = item.asImageItem {
                return imageItem.tagIds.contains(tag.id)
            } else if let textItem = item.asTextItem {
                return textItem.tagIds.contains(tag.id)
            }
            return false
        }
        
        for item in itemsWithTag {
            if var bookmark = item.asBookmark {
                bookmark.removeTag(tag.id)
                bookmark.modifiedDate = Date()
                dataStorage.updateItem(AnyCollectionItem(bookmark))
            } else if var imageItem = item.asImageItem {
                imageItem.removeTag(tag.id)
                imageItem.modifiedDate = Date()
                dataStorage.updateItem(AnyCollectionItem(imageItem))
            } else if var textItem = item.asTextItem {
                textItem.removeTag(tag.id)
                textItem.modifiedDate = Date()
                dataStorage.updateItem(AnyCollectionItem(textItem))
            }
        }
        
        // Also remove from selectedTagIds if it's selected
        selectedTagIds.remove(tag.id)
        
        // Then delete the tag
        do {
            try dataStorage.deleteTag(tag)
            tagToDelete = nil
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
            tagToDelete = nil
        }
    }
}



#Preview {
    ItemDetailView(item: AnyCollectionItem(Bookmark(
        title: "Example",
        url: "https://www.apple.com",
        categoryId: UUID()
    )))
    .environmentObject(DataStorage.shared)
    .frame(width: 1200, height: 800)
}



