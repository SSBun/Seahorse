//
//  RectangleBookmarkCardView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct RectangleBookmarkCardView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var showingPreview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Icon and Title
            HStack(alignment: .top, spacing: 8) {
                // Icon at top left (fixed size)
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        BookmarkIconView(
                            iconString: bookmark.icon,
                            size: 20
                        )
                        .frame(width: 36, height: 36)
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Parsed badge (doesn't affect layout)
                    if bookmark.isParsed {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                            .offset(x: 2, y: -2)
                    }
                }
                
                // Title and URL at top right (fixed height)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: 32, alignment: .top)
                    
                    Text(bookmark.url)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Favorite button (fixed size)
                Button(action: toggleFavorite) {
                    Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(bookmark.isFavorite ? .yellow : .secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .opacity(isHovered || bookmark.isFavorite ? 1.0 : 0.5)
            }
            
            // Summary at bottom (fixed height to keep consistent size)
            Text(bookmark.notes ?? " ")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 26, alignment: .top)
                .opacity(bookmark.notes != nil && !bookmark.notes!.isEmpty ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 2)
        )
        .aspectRatio(3.0, contentMode: .fill)
        .clipped()
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            // Double-click to open URL
            if let url = URL(string: bookmark.url) {
                NSWorkspace.shared.open(url)
            }
        }
        .contextMenu {
            // Right-click context menu
            Button(action: {
                showingEditSheet = true
            }) {
                Label(L10n.edit, systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label(L10n.openURL, systemImage: "arrow.up.forward.app")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                deleteBookmark()
            }) {
                Label(L10n.delete, systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddBookmarkView(editingBookmark: bookmark)
                .environmentObject(dataStorage)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            showingPreview = true
        }
        .popover(isPresented: $showingPreview, arrowEdge: .trailing) {
            BookmarkPreviewView(bookmark: bookmark)
                .environmentObject(dataStorage)
        }
        .onDrag {
            let provider = NSItemProvider(object: bookmark.id.uuidString as NSString)
            provider.suggestedName = bookmark.title
            return provider
        } preview: {
            // Custom drag preview - small bar
            HStack(spacing: 8) {
                BookmarkIconView(iconString: bookmark.icon, size: 14)
                    .frame(width: 14, height: 14)
                
                Text(bookmark.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .frame(maxWidth: 200)
        }
    }
    
    private func deleteBookmark() {
        do {
            try dataStorage.deleteBookmark(bookmark)
        } catch {
            print("Failed to delete bookmark: \(error)")
        }
    }
    
    private func toggleFavorite() {
        var updatedBookmark = bookmark
        updatedBookmark.isFavorite.toggle()
        do {
            try dataStorage.updateBookmark(updatedBookmark)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RectangleBookmarkCardView(
            bookmark: Bookmark(
                title: "SwiftUI Documentation - Building Modern Apps",
                url: "https://developer.apple.com/documentation/swiftui",
                icon: "swift",
                categoryId: UUID(),
                isFavorite: true,
                notes: "Comprehensive guide to SwiftUI framework for building user interfaces across all Apple platforms with declarative Swift syntax.",
                isParsed: true
            )
        )
        .environmentObject(DataStorage.shared)
        
        RectangleBookmarkCardView(
            bookmark: Bookmark(
                title: "GitHub - Where the world builds software",
                url: "https://github.com",
                icon: "arrow.triangle.branch",
                categoryId: UUID(),
                isFavorite: false,
                notes: "GitHub is where over 100 million developers shape the future of software, together.",
                isParsed: false
            )
        )
        .environmentObject(DataStorage.shared)
    }
    .padding()
    .frame(width: 500, height: 400)
}

