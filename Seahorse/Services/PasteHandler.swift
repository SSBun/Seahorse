//
//  PasteHandler.swift
//  Seahorse
//
//  Created by Antigravity on 2025/12/03.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

class PasteHandler: ObservableObject {
    let dataStorage: DataStorage
    
    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }
    
    func handlePaste(providers: [NSItemProvider]) {
        Log.info("handlePaste called with \(providers.count) providers", category: .paste)
        for provider in providers {
            Log.info("Checking provider: \(provider)", category: .paste)
            // Priority 1: Check for URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                Log.info("Provider has URL type", category: .paste)
                handleURLPaste(provider)
                return
            }
            
            // Priority 2: Check for plain text (might be a URL)
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                Log.info("Provider has Plain Text type", category: .paste)
                handleTextPaste(provider)
                return
            }
            
            // Priority 3: Check for image
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                Log.info("Provider has Image type", category: .paste)
                handleImagePaste(provider)
                return
            }
        }
        Log.warning("No matching type found in providers", category: .paste)
    }
    
    private func handleURLPaste(_ provider: NSItemProvider) {
        Log.info("Handling URL paste", category: .paste)
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }
            
            if let error = error {
                Log.error("Error loading URL item: \(error)", category: .paste)
                return
            }
            
            var urlObject: URL?
            
            if let data = item as? Data {
                urlObject = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                urlObject = url
            }
            
            guard let url = urlObject else { return }
            let urlString = url.absoluteString
            
            // Check if it's a file URL (local image)
            if url.isFileURL {
                let pathExtension = url.pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "tiff"]
                
                if imageExtensions.contains(pathExtension) {
                    self.createImageItemFromLocalPath(url.path)
                    return
                }
            }
            
            // Check if it's a remote image URL
            if let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                let pathExtension = url.pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif"]
                
                if imageExtensions.contains(pathExtension) {
                    self.createImageItemFromURL(urlString)
                    return
                }
                
                // It's a valid web URL -> Bookmark
                self.createBookmarkFromURL(urlString)
                return
            }
            
            // Fallback: Treat as text
            self.createTextItem(from: urlString)
        }
    }
    
    private func handleTextPaste(_ provider: NSItemProvider) {
        Log.info("Handling Text paste", category: .paste)
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }
            
            if let error = error {
                Log.error("Error loading text item: \(error)", category: .paste)
                return
            }
            
            var textContent: String?
            
            if let string = item as? String {
                textContent = string
            } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                textContent = string
            }
            
            guard let text = textContent else {
                Log.error("Item is not a string or valid UTF-8 data: \(String(describing: item))", category: .paste)
                return
            }
            
            Log.info("Loaded text: \(text.prefix(50))...", category: .paste)
            
            // Check if text is a URL
            if let url = URL(string: text) {
                if url.scheme == "http" || url.scheme == "https" {
                    // Check if it's an image URL by extension or create as bookmark
                    let pathExtension = url.pathExtension.lowercased()
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif"]
                    
                    if imageExtensions.contains(pathExtension) {
                        // It's a remote image URL
                        self.createImageItemFromURL(text)
                    } else {
                        // It's a regular URL, create bookmark
                        self.createBookmarkFromURL(text)
                    }
                } else if url.scheme == "file" || url.isFileURL {
                    // Local file path
                    let filePath = url.path
                    let pathExtension = url.pathExtension.lowercased()
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "tiff"]
                    
                    if imageExtensions.contains(pathExtension) {
                        // Local image file - copy to storage
                        self.createImageItemFromLocalPath(filePath)
                    } else {
                        // Not an image file, create as text
                        self.createTextItem(from: text)
                    }
                } else {
                    // Not http/https/file -> Text
                    self.createTextItem(from: text)
                }
            } else if text.hasPrefix("/") || text.hasPrefix("~") {
                // Might be a local file path without file:// scheme
                let expandedPath = NSString(string: text).expandingTildeInPath
                let pathExtension = (expandedPath as NSString).pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "tiff"]
                
                if imageExtensions.contains(pathExtension) && FileManager.default.fileExists(atPath: expandedPath) {
                    self.createImageItemFromLocalPath(expandedPath)
                } else {
                    self.createTextItem(from: text)
                }
            } else {
                self.createTextItem(from: text)
            }
        }
    }
    
    private func handleImagePaste(_ provider: NSItemProvider) {
        Log.info("Handling Image paste", category: .paste)
        provider.loadObject(ofClass: NSImage.self) { [weak self] object, error in
            if let error = error {
                Log.error("Error loading image object: \(error)", category: .paste)
                return
            }
            
            guard let self = self, let image = object as? NSImage else {
                Log.error("Object is not an NSImage", category: .paste)
                return
            }
            Log.info("Loaded image object", category: .paste)
            self.createImageItem(from: image)
        }
    }
    
    // MARK: - Item Creation
    
    private func createBookmarkFromURL(_ urlString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Get default category (None)
            let defaultCategoryId = self.dataStorage.categories.first(where: { $0.name == "None" })?.id 
                ?? self.dataStorage.categories.first?.id 
                ?? UUID()
            
            // Create initial bookmark with minimal info
            let bookmark = Bookmark(
                title: "Loading...",
                url: urlString,
                icon: "link.circle",
                categoryId: defaultCategoryId,
                isFavorite: false,
                notes: nil,
                tagIds: [],
                isParsed: false,
                metadata: nil
            )
            
            do {
                try self.dataStorage.addBookmark(bookmark)
                Log.info("Created placeholder bookmark, fetching metadata...", category: .paste)
                NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
                
                // Fetch metadata asynchronously
                Task {
                    await self.fetchAndUpdateBookmark(bookmark, urlString: urlString)
                }
            } catch {
                Log.error("Failed to create bookmark: \(error)", category: .paste)
            }
        }
    }
    
    private func fetchAndUpdateBookmark(_ bookmark: Bookmark, urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            let metadata = try await OpenGraphService.shared.fetchMetadata(url: url)
            
            await MainActor.run {
                // Update bookmark with fetched metadata
                let updatedBookmark = Bookmark(
                    id: bookmark.id,
                    title: metadata.title ?? url.host ?? "Untitled",
                    url: urlString,
                    icon: metadata.faviconURL ?? "link.circle",
                    categoryId: bookmark.categoryId,
                    isFavorite: bookmark.isFavorite,
                    addedDate: bookmark.addedDate,
                    notes: metadata.description,
                    tagIds: bookmark.tagIds,
                    isParsed: false,
                    metadata: metadata
                )
                
                do {
                    try self.dataStorage.updateBookmark(updatedBookmark)
                    Log.info("Updated bookmark with metadata", category: .paste)
                } catch {
                    Log.error("Failed to update bookmark: \(error)", category: .paste)
                }
            }
        } catch {
            // If metadata fetch fails, update with basic info
            await MainActor.run {
                let fallbackBookmark = Bookmark(
                    id: bookmark.id,
                    title: url.host ?? urlString,
                    url: urlString,
                    icon: "link.circle",
                    categoryId: bookmark.categoryId,
                    isFavorite: bookmark.isFavorite,
                    addedDate: bookmark.addedDate,
                    notes: nil,
                    tagIds: bookmark.tagIds,
                    isParsed: false,
                    metadata: nil
                )
                
                try? self.dataStorage.updateBookmark(fallbackBookmark)
                Log.warning("Failed to fetch metadata, using fallback", category: .paste)
            }
        }
    }
    
    private func createImageItem(from image: NSImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Save image to storage
            guard let imagePath = self.saveImageToStorage(image) else {
                Log.error("Failed to save pasted image", category: .paste)
                return
            }
            
            let defaultCategoryId = self.dataStorage.categories.first(where: { $0.name == "None" })?.id 
                ?? self.dataStorage.categories.first?.id 
                ?? UUID()
            
            let imageItem = ImageItem(
                imagePath: imagePath,
                categoryId: defaultCategoryId,
                isFavorite: false,
                notes: nil,
                tagIds: [],
                isParsed: false,
                thumbnailPath: nil,
                imageSize: nil
            )
            
            do {
                try self.dataStorage.addItem(AnyCollectionItem(imageItem))
                Log.info("Created image item from paste", category: .paste)
                NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
            } catch {
                Log.error("Failed to create image item: \(error)", category: .paste)
            }
        }
    }
    
    private func createImageItemFromURL(_ urlString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let defaultCategoryId = self.dataStorage.categories.first(where: { $0.name == "None" })?.id 
                ?? self.dataStorage.categories.first?.id 
                ?? UUID()
            
            let imageItem = ImageItem(
                imagePath: urlString, // Save remote URL directly
                categoryId: defaultCategoryId,
                isFavorite: false,
                notes: nil,
                tagIds: [],
                isParsed: false,
                thumbnailPath: nil,
                imageSize: nil
            )
            
            do {
                try self.dataStorage.addItem(AnyCollectionItem(imageItem))
                Log.info("Created image item from remote URL: \(urlString)", category: .paste)
                NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
            } catch {
                Log.error("Failed to create image item: \(error)", category: .paste)
            }
        }
    }
    
    private func createImageItemFromLocalPath(_ filePath: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Copy local file to internal storage
            guard let copiedPath = self.copyImageToStorage(from: filePath) else {
                Log.error("Failed to copy local image file", category: .paste)
                return
            }
            
            let defaultCategoryId = self.dataStorage.categories.first(where: { $0.name == "None" })?.id 
                ?? self.dataStorage.categories.first?.id 
                ?? UUID()
            
            let imageItem = ImageItem(
                imagePath: copiedPath,
                categoryId: defaultCategoryId,
                isFavorite: false,
                notes: nil,
                tagIds: [],
                isParsed: false,
                thumbnailPath: nil,
                imageSize: nil
            )
            
            do {
                try self.dataStorage.addItem(AnyCollectionItem(imageItem))
                Log.info("Created image item from local file: \(filePath)", category: .paste)
                NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
            } catch {
                Log.error("Failed to create image item: \(error)", category: .paste)
            }
        }
    }
    
    private func createTextItem(from text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let defaultCategoryId = self.dataStorage.categories.first(where: { $0.name == "None" })?.id 
                ?? self.dataStorage.categories.first?.id 
                ?? UUID()
            
            let textItem = TextItem(
                content: text,
                categoryId: defaultCategoryId,
                isFavorite: false,
                notes: nil,
                tagIds: [],
                isParsed: false
            )
            
            do {
                try self.dataStorage.addItem(AnyCollectionItem(textItem))
                Log.info("Created text item from paste", category: .paste)
                NotificationCenter.default.post(name: NSNotification.Name("SeahorseItemAdded"), object: nil)
            } catch {
                Log.error("Failed to create text item: \(error)", category: .paste)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveImageToStorage(_ image: NSImage) -> String? {
        guard let storageDir = getImagesStorageDirectory() else { return nil }
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        
        let filename = "\(UUID().uuidString).png"
        let fileURL = storageDir.appendingPathComponent(filename)
        
        if let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                return fileURL.path
            } catch {
                Log.error("Failed to save image: \(error)", category: .paste)
                return nil
            }
        }
        
        return nil
    }
    
    private func getImagesStorageDirectory() -> URL? {
        let imagesDir = StorageManager.shared.getImagesDirectory()
        
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true
        )
        
        return imagesDir
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
            return destinationURL.path
        } catch {
            Log.error("Failed to copy image: \(error)", category: .paste)
            return nil
        }
    }
}
