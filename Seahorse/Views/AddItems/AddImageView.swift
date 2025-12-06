//
//  AddImageView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import SwiftUI
import OSLog

struct AddImageView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.dismiss) var dismiss
    
    // Editing mode
    let editingItem: ImageItem?
    
    @State private var imagePath = ""
    @State private var notes = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var isFavorite = false
    @State private var pastedImage: NSImage? = nil
    @State private var loadedImage: NSImage? = nil // Image loaded from path
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(editingItem: ImageItem? = nil) {
        self.editingItem = editingItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingItem == nil ? "Add Image" : "Edit Image")
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
                    // Image Preview and Paste Area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack {
                            // Preview area
                            if let image = pastedImage ?? loadedImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            } else if !imagePath.isEmpty {
                                // Loading indicator while image loads
                                ZStack {
                                    Rectangle()
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                    
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            } else {
                                // Empty state
                                ZStack {
                                    Rectangle()
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.tertiary)
                                        Text("Paste image here (⌘V)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .onPasteCommand(of: [.tiff, .png]) { providers in
                            handlePaste(providers: providers)
                        }
                        
                        Text("Paste an image or enter a file path/URL below")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Image Path Input (alternative)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or enter path/URL")
                            .font(.system(size: 13, weight: .semibold))
                        
                        TextField("file:///path/to/image.jpg or https://...", text: $imagePath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13))
                            .disabled(pastedImage != nil)
                            .onChange(of: imagePath) { newValue in
                                loadImageFromPath(newValue)
                            }
                    }
                    
                    Divider()
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add notes or description...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $notes)
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
                
                Button(editingItem == nil ? "Add Image" : "Save Changes") {
                    saveImage()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled((imagePath.isEmpty && pastedImage == nil))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 650)
        .onAppear {
            if let item = editingItem {
                populateFields(from: item)
            } else {
                // Set default category
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
    }
    
    private func handlePaste(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadDataRepresentation(forTypeIdentifier: "public.tiff") { data, error in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.pastedImage = image
                    self.imagePath = "" // Clear path when image is pasted
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to paste image: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func loadImageFromPath(_ path: String) {
        guard !path.isEmpty else {
            loadedImage = nil
            return
        }
        
        // Check if it's a remote URL
        if let url = URL(string: path),
           (url.scheme == "http" || url.scheme == "https") {
            // Load remote image asynchronously
            Task {
                do {
                    let (data, _) = try await NetworkManager.shared.data(from: url)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            self.loadedImage = image
                        }
                    } else {
                        await MainActor.run {
                            self.loadedImage = nil
                        }
                    }
                } catch {
                    Log.error("Failed to load remote image: \(error)", category: .ui)
                    await MainActor.run {
                        self.loadedImage = nil
                    }
                }
            }
        } else {
            // Handle local file path
            let localPath = StorageManager.shared.resolveImagePath(path)
            
            // Load local image from file system
            if let image = NSImage(contentsOfFile: localPath) {
                self.loadedImage = image
            } else {
                self.loadedImage = nil
            }
        }
    }
    
    private func getImagesStorageDirectory() -> URL? {
        let imagesDir = StorageManager.shared.getImagesDirectory()
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true
        )
        
        return imagesDir
    }
    
    private func saveImageToStorage(_ image: NSImage) -> String? {
        guard let storageDir = getImagesStorageDirectory() else { return nil }
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).png"
        let fileURL = storageDir.appendingPathComponent(filename)
        
        // Save as PNG
        if let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                return filename // store filename for portability
            } catch {
                Log.error("Failed to save image: \(error)", category: .ui)
                return nil
            }
        }
        
        return nil
    }
    
    private func copyImageToStorage(from sourcePath: String) -> String? {
        guard let storageDir = getImagesStorageDirectory() else { return nil }
        
        let sourceURL = URL(fileURLWithPath: sourcePath)
        
        // Get original file extension
        let fileExtension = sourceURL.pathExtension.lowercased()
        
        // Only copy if it's an image file
        let validExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp"]
        guard validExtensions.contains(fileExtension) else { return nil }
        
        // Generate unique filename with original extension
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = storageDir.appendingPathComponent(filename)
        
        do {
            // Copy file directly to preserve format and metadata
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return filename // store filename for portability
        } catch {
            Log.error("Failed to copy image: \(error)", category: .ui)
            return nil
        }
    }
    
    private func populateFields(from item: ImageItem) {
        imagePath = item.imagePath
        notes = item.notes ?? ""
        selectedCategoryId = item.categoryId
        selectedTagIds = Set(item.tagIds)
        isFavorite = item.isFavorite
        loadImageFromPath(item.imagePath)
    }
    
    private func saveImage() {
        let categoryId = selectedCategoryId ?? {
            if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                return noneCategory.id
            }
            return dataStorage.categories.first?.id ?? UUID()
        }()
        
        var finalImagePath: String?
        
        // Handle pasted image
        if let image = pastedImage {
            // Save pasted image to internal storage
            finalImagePath = saveImageToStorage(image)
            
            if finalImagePath == nil {
                errorMessage = "Failed to save pasted image"
                showingError = true
                return
            }
        } else if !imagePath.isEmpty {
            // Check if it's a remote URL
            if let url = URL(string: imagePath),
               (url.scheme == "http" || url.scheme == "https") {
                // Remote URL - save directly without downloading
                finalImagePath = imagePath
                Log.info("✅ Remote image URL detected, saving directly: \(imagePath)", category: .ui)
            } else {
                // Local file path - copy to internal storage
                let sourcePath: String
                if imagePath.hasPrefix("file://") {
                    sourcePath = imagePath.replacingOccurrences(of: "file://", with: "")
                } else {
                    sourcePath = imagePath
                }
                
                finalImagePath = copyImageToStorage(from: sourcePath)
                
                if finalImagePath == nil {
                    errorMessage = "Failed to copy image to storage"
                    showingError = true
                    return
                }
            }
        }
        
        guard let imagePath = finalImagePath else {
            errorMessage = "Please provide an image"
            showingError = true
            return
        }
        
        // Add or Update
        if let editingItem = editingItem {
            let updatedItem = ImageItem(
                id: editingItem.id,
                imagePath: imagePath,
                categoryId: categoryId,
                isFavorite: isFavorite,
                addedDate: editingItem.addedDate,
                notes: notes.isEmpty ? nil : notes,
                tagIds: Array(selectedTagIds),
                isParsed: editingItem.isParsed,
                thumbnailPath: editingItem.thumbnailPath,
                imageSize: editingItem.imageSize
            )
            
            do {
                try dataStorage.updateItem(AnyCollectionItem(updatedItem))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        } else {
            let imageItem = ImageItem(
                imagePath: imagePath,
                categoryId: categoryId,
                isFavorite: isFavorite,
                notes: notes.isEmpty ? nil : notes,
                tagIds: Array(selectedTagIds)
            )
            
            // Add to dataStorage
            dataStorage.addItem(AnyCollectionItem(imageItem))
            dismiss()
        }
    }
}

#Preview {
    AddImageView()
        .environmentObject(DataStorage.shared)
}
