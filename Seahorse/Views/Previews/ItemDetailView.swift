//
//  ItemDetailView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

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
    @State private var isPreviewDropTarget = false
    
    // Extract specific item types
    private var bookmark: Bookmark? {
        dataStorage.bookmarks.first(where: { $0.id == item.id }) ?? item.asBookmark
    }
    private var imageItem: ImageItem? {
        dataStorage.items.first(where: { $0.id == item.id })?.asImageItem ?? item.asImageItem
    }
    private var textItem: TextItem? {
        dataStorage.items.first(where: { $0.id == item.id })?.asTextItem ?? item.asTextItem
    }
    
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
                    
                    // Preview image / OGP
                    if bookmark != nil {
                        ogpSection
                    }
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
                    let resolvedPath = StorageManager.shared.resolveImagePath(imageItem.imagePath)
                    let pathDisplay = resolvedPath.count > 50 
                        ? "..." + String(resolvedPath.suffix(47))
                        : resolvedPath
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
    

    
    private var ogpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview Image")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            previewDropArea
            
            if let metadata = bookmark?.metadata {
                VStack(alignment: .leading, spacing: 12) {
                    // Fields
                    Group {
                        if let title = metadata.title {
                            ogpRow(label: "Title", value: title)
                        }
                        
                        if let siteName = metadata.siteName {
                            ogpRow(label: "Site Name", value: siteName)
                        }
                        
                        if let description = metadata.description {
                            ogpRow(label: "Description", value: description)
                        }
                        
                        if let url = metadata.url {
                            ogpRow(label: "URL", value: url)
                        }
                    }
                }
                .textSelection(.enabled) // Make text copyable
            } else {
                Text("No metadata yet. Add a snapshot or drop an image to set a preview.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func ogpRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Preview Image Helpers
    
    private var previewImagePath: String? {
        bookmark?.metadata?.imageURL
    }
    
    private var previewDropArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPreviewDropTarget ? Color.accentColor : Color(NSColor.separatorColor),
                            style: StrokeStyle(lineWidth: 1, dash: [6]))
                
                previewImageView(for: previewImagePath)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 160)
            .onDrop(of: [UTType.image, .fileURL], isTargeted: $isPreviewDropTarget) { providers in
                handlePreviewDrop(providers)
            }
            .animation(.easeInOut(duration: 0.15), value: isPreviewDropTarget)
            
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 12))
                Text("Drop an image here or capture a snapshot to set the preview.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func previewImageView(for path: String?) -> some View {
        if let path = path, !path.isEmpty {
            if let remoteURL = URL(string: path),
               let scheme = remoteURL.scheme,
               scheme == "http" || scheme == "https" {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.textBackgroundColor))
                    case .failure:
                        placeholderPreview
                    @unknown default:
                        placeholderPreview
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let resolvedPath = StorageManager.shared.resolveImagePath(path)
                if let image = NSImage(contentsOfFile: resolvedPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                } else {
                    placeholderPreview
                }
            }
        } else {
            placeholderPreview
        }
    }
    
    private var placeholderPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No preview image")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Drop an image or capture a snapshot to fill this area.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
    
    private func handlePreviewDrop(_ providers: [NSItemProvider]) -> Bool {
        if let imageProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data = data, let image = NSImage(data: data) else { return }
                persistPreviewImage(image)
            }
            return true
        }
        
        if let fileProvider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            fileProvider.loadObject(ofClass: URL.self) { object, _ in
                guard let url = object, url.isFileURL else { return }
                if let image = NSImage(contentsOf: url) {
                    persistPreviewImage(image)
                }
            }
            return true
        }
        
        return false
    }
    
    private func persistPreviewImage(_ image: NSImage) {
        DispatchQueue.main.async {
            guard let path = savePreviewImage(image) else { return }
            applyPreviewImagePath(path)
        }
    }
    
    private func savePreviewImage(_ image: NSImage) -> String? {
        let imagesDir = StorageManager.shared.getImagesDirectory()
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            alertMessage = "Failed to prepare image directory."
            showingAlert = true
            return nil
        }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            alertMessage = "Unable to read dropped image."
            showingAlert = true
            return nil
        }
        
        let filename = "preview-\(UUID().uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            return filename // store filename for portability
        } catch {
            alertMessage = "Failed to save preview image."
            showingAlert = true
            return nil
        }
    }
    
    private func applyPreviewImagePath(_ path: String) {
        guard var updated = bookmark else { return }
        if updated.metadata != nil {
            updated.metadata?.imageURL = path
        } else {
            updated.metadata = WebMetadata(imageURL: path, url: updated.url)
        }
        
        do {
            try dataStorage.updateBookmark(updated)
        } catch {
            alertMessage = "Failed to attach preview image to bookmark."
            showingAlert = true
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
        
        let resolvedPath = StorageManager.shared.resolveImagePath(path)
        
        // For local images
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: resolvedPath) as CFURL, nil),
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
        
        let resolvedPath = StorageManager.shared.resolveImagePath(path)
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolvedPath),
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



