//
//  StandardCardView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//  Renamed from BookmarkCardView on 2025/12/01.
//  Redesigned on 2025/12/02 to support all item types.
//

import SwiftUI
import UniformTypeIdentifiers
import Kingfisher

struct StandardCardView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.openWindow) var openWindow
    let item: AnyCollectionItem
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var tapTask: Task<Void, Never>?
    
    // Extract specific item types
    private var bookmark: Bookmark? { item.asBookmark }
    private var imageItem: ImageItem? { item.asImageItem }
    private var textItem: TextItem? { item.asTextItem }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        if let bookmark = bookmark {
            return bookmark.title
        } else if let imageItem = imageItem {
            if let url = URL(string: imageItem.imagePath) {
                return url.lastPathComponent
            }
            return imageItem.imagePath
        } else if let textItem = textItem {
            if let firstLine = textItem.content.components(separatedBy: .newlines).first, !firstLine.isEmpty {
                return firstLine
            }
            return textItem.contentPreview
        }
        return "Untitled"
    }
    
    private var displayDomain: String? {
        if let bookmark = bookmark, let url = URL(string: bookmark.url) {
            return url.host ?? bookmark.url
        }
        return nil
    }
    
    private var categoryId: UUID {
        bookmark?.categoryId ?? imageItem?.categoryId ?? textItem?.categoryId ?? UUID()
    }
    
    private var isParsed: Bool {
        bookmark?.isParsed ?? imageItem?.isParsed ?? textItem?.isParsed ?? false
    }
    
    private var addedDate: Date {
        bookmark?.addedDate ?? imageItem?.addedDate ?? textItem?.addedDate ?? Date()
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: addedDate, relativeTo: Date())
    }
    
    private var isFavorite: Bool {
        bookmark?.isFavorite ?? imageItem?.isFavorite ?? textItem?.isFavorite ?? false
    }
    
    // MARK: - Preview Area
    
    @ViewBuilder
    private var previewArea: some View {
        Group {
            switch item.itemType {
            case .bookmark:
                // Gradient + Icon for bookmarks (or OGP Image)
                if let bookmark = bookmark, let metadata = bookmark.metadata, let previewURL = metadata.imageURL, let url = URL(string: previewURL) {
                    GeometryReader { geo in
                        KFImage.url(url)
                            .placeholder {
                                // Show subtle background while loading
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                            }
                            .onFailure { _ in
                                // On timeout or error, show blank
                            }
                            // Use fixed size for downsampling to avoid re-processing on resize
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 400, height: 300)))
                            .loadDiskFileSynchronously()
                            .cacheMemoryOnly()
                            .fade(duration: 0.25)
                            .onSuccess { _ in
                                // Image loaded successfully
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .frame(height: 160)
                    .onAppear {
                        // Configure timeout
                        KingfisherManager.shared.downloader.downloadTimeout = 10.0
                    }
                } else {
                    // No OGP image - show link icon with blur
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Rectangle()
                                    .fill(Color.gray.opacity(0.05))
                            )
                        
                        if bookmark != nil {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                    }
                    .frame(height: 160)
                }
                
            case .image:
                // Actual image preview (increased height for image items to match other cards)
                // Other cards: 160 (preview) + 46 (title) + 40 (bottomBar) = 246
                // Image cards: 206 (preview) + 40 (bottomBar) = 246 (no title area)
                if let imageItem = imageItem, !imageItem.imagePath.isEmpty {
                    if let url = URL(string: imageItem.imagePath), (url.scheme == "http" || url.scheme == "https") {
                        // Remote Image
                        GeometryReader { geo in
                            KFImage.url(url)
                                .placeholder {
                                    Color.gray.opacity(0.1)
                                }
                                .onFailure { _ in
                                    // Show blank on timeout/error
                                }
                                .setProcessor(DownsamplingImageProcessor(size: geo.size))
                                .loadDiskFileSynchronously()
                                .cacheMemoryOnly()
                                .fade(duration: 0.25)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                        .frame(height: 206)
                        .onAppear {
                            KingfisherManager.shared.downloader.downloadTimeout = 10.0
                        }
                    } else if let nsImage = NSImage(contentsOfFile: imageItem.imagePath) {
                        // Local Image
                        GeometryReader { geo in
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                        .frame(height: 206)
                    } else {
                        // Fallback gradient
                        ZStack {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [Color.green.opacity(0.6), Color.teal.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            Image(systemName: "photo.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 4)
                        }
                        .frame(height: 206)
                    }
                } else {
                    // Fallback gradient (empty path)
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.teal.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.2), radius: 4)
                    }
                    .frame(height: 206)
                }
                
            case .text:
                // Text content preview
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color(nsColor: .textBackgroundColor))
                    
                    if let textItem = textItem {
                        Text(textItem.content)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .lineLimit(8)
                            .padding(12)
                    }
                }
                .frame(height: 160)
            }
        } // Added missing closing brace for Group
        .clipped()
    }
    
    // MARK: - Bottom Container
    
    @ViewBuilder
    private var bottomContainer: some View {
        VStack(spacing: 0) {
            // Title Section (Optional)
            if isTitleVisible {
                Text(displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 34, alignment: .top) // Fixed height for text area
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            
            // Metadata Bar
            HStack(spacing: 6) {
                // Favorite Toggle
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                
                if let category = dataStorage.categories.first(where: { $0.id == categoryId }) {
                    let categoryColor = Color(hex: category.colorHex) ?? .blue
                    Text("#\(category.name.lowercased())")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: itemTypeIcon)
                        .font(.system(size: 9))
                    Text(itemTypeLabel)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(height: bottomBarHeight)
        }
        .background(item.itemType == .image ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(NSColor.controlBackgroundColor)))
    }
    
    // MARK: - Body
    
    private let bottomBarHeight: CGFloat = 40
    private let titleHeight: CGFloat = 46 // 34 + 8 top + 4 bottom
    
    private var isTitleVisible: Bool {
        item.itemType != .image
    }
    
    private var reservedBottomHeight: CGFloat {
        // For image cards: reserve space for bottom bar (40)
        // For other cards: reserve space for title (46) + bottom bar (40) = 86
        item.itemType == .image ? bottomBarHeight : (bottomBarHeight + titleHeight)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Base content view
            VStack(alignment: .leading, spacing: 0) {
                // Preview area with fixed height (no maxHeight to allow fixed height to work)
                previewArea
                
                // Bottom margin spacer
                // For image cards: reserves space for bottom bar
                // For other cards: reserves space for title + bottom bar
                Spacer()
                    .frame(height: reservedBottomHeight)
            }
            
            // Layer 2: Bottom Container (Title + Metadata)
            bottomContainer
                .zIndex(1)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .aspectRatio(4/3, contentMode: .fit) // Fixed 4:3 aspect ratio
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            contextMenuContent
        }
        .onTapGesture {
            // Cancel any pending single tap
            tapTask?.cancel()
            
            // Schedule single tap action with delay to allow double tap detection
            tapTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                if !Task.isCancelled {
                    await MainActor.run {
                        // Open detail window with item ID
                        openWindow(id: "item-detail", value: item.id)
                    }
                }
            }
        }
        .onTapGesture(count: 2) {
            // Cancel single tap task
            tapTask?.cancel()
            // Handle double tap
            handleDoubleTap()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let bookmark = bookmark {
                AddBookmarkView(editingBookmark: bookmark)
            } else if let imageItem = imageItem {
                AddImageView(editingItem: imageItem)
            } else if let textItem = textItem {
                AddTextView(editingItem: textItem)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var itemTypeIcon: String {
        switch item.itemType {
        case .bookmark: return "link"
        case .image: return "photo"
        case .text: return "doc.text"
        }
    }
    
    private var itemTypeLabel: String {
        switch item.itemType {
        case .bookmark: return "Link"
        case .image: return "Image"
        case .text: return "Note"
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuContent: some View {
        // Common Actions
        Button(action: toggleFavorite) {
            Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "star.slash" : "star")
        }
        
        Divider()
        
        switch item.itemType {
        case .bookmark:
            if let bookmark = bookmark {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(action: {
                    if let url = URL(string: bookmark.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Open in Browser", systemImage: "safari")
                }
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bookmark.url, forType: .string)
                }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    try? dataStorage.deleteItem(item)
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
        case .image:
            if let imageItem = imageItem {
                Button(action: {
                    if !imageItem.imagePath.isEmpty {
                        let imageURL = URL(fileURLWithPath: imageItem.imagePath)
                        NSWorkspace.shared.open(imageURL)
                    }
                }) {
                    Label("Open Image", systemImage: "photo")
                }
                
                Button(action: {
                    if !imageItem.imagePath.isEmpty {
                        let imageURL = URL(fileURLWithPath: imageItem.imagePath)
                        NSWorkspace.shared.activateFileViewerSelecting([imageURL])
                    }
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    try? dataStorage.deleteItem(item)
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
        case .text:
            Button(action: {
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            if let textItem = textItem {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textItem.content, forType: .string)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                try? dataStorage.deleteItem(item)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleDoubleTap() {
        switch item.itemType {
        case .bookmark:
            if let bookmark = bookmark, let url = URL(string: bookmark.url) {
                NSWorkspace.shared.open(url)
            }
        case .image:
            if let imageItem = imageItem, !imageItem.imagePath.isEmpty {
                let imageURL = URL(fileURLWithPath: imageItem.imagePath)
                NSWorkspace.shared.open(imageURL)
            }
        case .text:
            showingEditSheet = true
        }
    }
    
    private func toggleFavorite() {
        var newItem = item
        
        if var bookmark = bookmark {
            bookmark.isFavorite.toggle()
            newItem = AnyCollectionItem(bookmark)
        } else if var imageItem = imageItem {
            imageItem.isFavorite.toggle()
            newItem = AnyCollectionItem(imageItem)
        } else if var textItem = textItem {
            textItem.isFavorite.toggle()
            newItem = AnyCollectionItem(textItem)
        }
        
        dataStorage.updateItem(newItem)
    }
}

// MARK: - Preview

#Preview {
    let dataStorage = DataStorage.preview
    let sampleBookmark = Bookmark(
        title: "Apple",
        url: "https://www.apple.com",
        icon: "apple.logo",
        categoryId: dataStorage.categories.first?.id ?? UUID()
    )
    
    StandardCardView(item: AnyCollectionItem(sampleBookmark))
        .environmentObject(dataStorage)
        .frame(width: 280)
        .padding()
}
