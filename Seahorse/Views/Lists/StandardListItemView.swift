#if os(macOS)
//
//  StandardListItemView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/02.
//

import SwiftUI
import UniformTypeIdentifiers
import Kingfisher

struct StandardListItemView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @EnvironmentObject var itemDetailState: ItemDetailState
    @Environment(\.openWindow) var openWindow
    let item: AnyCollectionItem
    @State private var isHovered = false
    @State private var showingEditSheet = false
    private let rowHeight: CGFloat = 64

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
            let firstLine = textItem.firstLine
            if !firstLine.isEmpty {
                return String(firstLine)
            }
            return textItem.contentPreview
        }
        return "Untitled"
    }
    
    private var displaySubtitle: String? {
        if let bookmark = bookmark {
            return bookmark.url
        } else if let textItem = textItem {
            return textItem.contentPreview
        }
        return nil
    }
    
    private var addedDate: Date {
        bookmark?.addedDate ?? imageItem?.addedDate ?? textItem?.addedDate ?? Date()
    }
    
    private var isFavorite: Bool {
        bookmark?.isFavorite ?? imageItem?.isFavorite ?? textItem?.isFavorite ?? false
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon / Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                if let bookmark = bookmark {
                    BookmarkIconView(iconString: bookmark.icon, size: 20)
                        .frame(width: 30, height: 30)
                } else if let imageItem = imageItem,
                          !imageItem.imagePath.isEmpty {
                    let resolvedPath = StorageManager.shared.resolveImagePath(imageItem.imagePath)
                    if let url = URL(string: imageItem.imagePath), (url.scheme == "http" || url.scheme == "https") {
                        // Optimized: Use downsampling for remote images
                        KFImage(url)
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 40, height: 40)))
                            .cacheMemoryOnly()
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                    } else {
                        let fileURL = URL(fileURLWithPath: resolvedPath)
                        KFImage.url(fileURL)
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80)))
                            .scaleFactor(NSScreen.main?.backingScaleFactor ?? 2.0)
                            .cacheMemoryOnly()
                            .placeholder {
                                Image(systemName: "photo")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                    }
                } else {
                    Image(systemName: itemTypeIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.system(size: 13))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 0)
                }
                
                if let subtitle = displaySubtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            
            // Type Badge
            Text(itemTypeLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            // Favorite button
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isFavorite ? 1.0 : 0.5)
            
            // Date
            Text(addedDate, style: .date)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        .onTapGesture {
            openDetailWindow()
        }
        .contextMenu {
            Button(role: .destructive, action: {
                do { try dataStorage.deleteItem(item) } catch { Log.error("Failed to delete item: (error)", category: .ui) }
            }) {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var gradientColors: [Color] {
        switch item.itemType {
        case .bookmark: return [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]
        case .image: return [Color.green.opacity(0.6), Color.teal.opacity(0.6)]
        case .text: return [Color.orange.opacity(0.6), Color.pink.opacity(0.6)]
        }
    }
    
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
    
    // MARK: - Actions

    private func openDetailWindow() {
        let startedAt = ProcessInfo.processInfo.systemUptime
        Log.info("detail_open cell_tap source=list item_type=\(item.itemType.rawValue)", category: .performance)
        itemDetailState.showItem(item.id, source: "list", requestedAt: startedAt)
        openWindow(id: "item-detail")
        Log.info("detail_open openWindow_return source=list elapsed_ms=\(itemDetailState.elapsedSinceOpenRequestMs())", category: .performance)
    }
    
    private func toggleFavorite() {
        // TODO: Implement generic favorite toggle
        // For now only bookmarks support favorite in UI properly
        if var bookmark = bookmark {
            bookmark.isFavorite.toggle()
            try? dataStorage.updateBookmark(bookmark)
        }
    }
    
    private func handleDoubleTap() {
        switch item.itemType {
        case .bookmark:
            if let bookmark = bookmark, let url = URL(string: bookmark.url) {
                NSWorkspace.shared.open(url)
            }
        case .image:
            if let imageItem = imageItem, !imageItem.imagePath.isEmpty {
                if let remoteURL = URL(string: imageItem.imagePath),
                   let scheme = remoteURL.scheme,
                   (scheme == "http" || scheme == "https") {
                    NSWorkspace.shared.open(remoteURL)
                } else {
                    let absolutePath = StorageManager.shared.resolveImagePath(imageItem.imagePath)
                    let imageURL = URL(fileURLWithPath: absolutePath)
                    NSWorkspace.shared.open(imageURL)
                }
            }
        case .text:
            // TODO: Edit text
            break
        }
    }
}

#endif
