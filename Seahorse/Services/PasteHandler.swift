//
//  PasteHandler.swift
//  Seahorse
//
//  Created by Antigravity on 2025/12/03.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

extension UTType {
    static let seahorseItemUUID = UTType(exportedAs: "com.csl.cool.Seahorse.item-uuid")
}

@MainActor
class PasteHandler: ObservableObject {
    let dataStorage: DataStorage
    
    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }
    
    func handlePaste(providers: [NSItemProvider]) {
        Log.info("handlePaste called with \(providers.count) providers", category: .paste)
        for provider in providers {
            Log.info("Checking provider: \(provider)", category: .paste)
            // Priority 0: Reject internal Seahorse item UUID drops (prevents duplicate card creation)
            if provider.hasItemConformingToTypeIdentifier(UTType.seahorseItemUUID.identifier) {
                Log.info("Rejected internal Seahorse item drop", category: .paste)
                return
            }
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
        #if os(macOS)
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
        #else
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error = error {
                Log.error("Error loading image object: \(error)", category: .paste)
                return
            }

            guard let self = self, let image = object as? UIImage else {
                Log.error("Object is not a UIImage", category: .paste)
                return
            }
            Log.info("Loaded image object", category: .paste)
            self.createImageItem(from: image)
        }
        #endif
    }
    
    // MARK: - Item Creation
    
    private func createBookmarkFromURL(_ urlString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Canonicalize so URL parsing + metadata fetch work even when user pastes "example.com"
            let canonicalURLString = BookmarkURLNormalizer.normalize(urlString)
            guard !canonicalURLString.isEmpty else { return }
            DLog("Paste: create bookmark placeholder url='\(canonicalURLString)'", category: .paste)

            let defaultCategoryId = self.defaultCategoryID()
            
            // Create initial bookmark with minimal info
            let bookmark = Bookmark(
                title: "Loading...",
                url: canonicalURLString,
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
                DLog("Paste: saved placeholder id=\(bookmark.id.uuidString)", category: .paste)
                Log.info("Created placeholder bookmark and queued enrichment", category: .paste)
            } catch DatabaseError.duplicateBookmarkURL {
                DLog("Paste: skipped duplicate url='\(canonicalURLString)'", category: .paste)
                Log.info("Skipped duplicate bookmark URL: \(urlString)", category: .paste)
            } catch {
                Log.error("Failed to create bookmark: \(error)", category: .paste)
            }
        }
    }
    
    #if os(macOS)
    private func createImageItem(from image: NSImage) {
        let imagesDirectory = StorageManager.shared.getImagesDirectory()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let imagePath = try await ImageFileService.shared.savePNG(image, to: imagesDirectory)
                self.createStoredImageItem(path: imagePath, source: "paste")
            } catch {
                Log.error("Failed to save pasted image", category: .paste)
            }
        }
    }
    #else
    private func createImageItem(from image: UIImage) {
        let imagesDirectory = StorageManager.shared.getImagesDirectory()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let imagePath = try await ImageFileService.shared.savePNG(image, to: imagesDirectory)
                self.createStoredImageItem(path: imagePath, source: "paste")
            } catch {
                Log.error("Failed to save pasted image", category: .paste)
            }
        }
    }
    #endif
    
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
            } catch {
                Log.error("Failed to create image item: \(error)", category: .paste)
            }
        }
    }
    
    private func createImageItemFromLocalPath(_ filePath: String) {
        let imagesDirectory = StorageManager.shared.getImagesDirectory()
        let sourceURL = URL(fileURLWithPath: filePath)
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let copiedPath = try await ImageFileService.shared.copyImage(
                    from: sourceURL,
                    to: imagesDirectory
                )
                self.createStoredImageItem(path: copiedPath, source: filePath)
            } catch {
                Log.error("Failed to copy local image file", category: .paste)
            }
        }
    }

    private func createStoredImageItem(path: String, source: String) {
        let defaultCategoryId = dataStorage.categories.first(where: { $0.name == "None" })?.id
            ?? dataStorage.categories.first?.id
            ?? UUID()
        let imageItem = ImageItem(imagePath: path, categoryId: defaultCategoryId)
        dataStorage.addItem(AnyCollectionItem(imageItem))
        Log.info("Created image item from \(source)", category: .paste)
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
            } catch {
                Log.error("Failed to create text item: \(error)", category: .paste)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func defaultCategoryID() -> UUID {
        return dataStorage.categories.first(where: { $0.name == "None" })?.id
            ?? dataStorage.categories.first?.id
            ?? UUID()
    }
}
