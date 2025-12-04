//
//  CompactBookmarkCardView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct CompactBookmarkCardView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var showingPreview = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon with parsed badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: isHovered ?
                                [Color.blue.opacity(0.8), Color.purple.opacity(0.8)] :
                                [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    BookmarkIconView(
                        iconString: bookmark.icon,
                        size: isHovered ? 18 : 16
                    )
                    .frame(width: isHovered ? 32 : 30, height: isHovered ? 32 : 30)
                }
                .frame(width: isHovered ? 42 : 40, height: isHovered ? 42 : 40)
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 4 : 2, x: 0, y: isHovered ? 2 : 1)
                
                // Parsed badge
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
            
            // Title, URL, and Summary
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let notes = bookmark.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                } else {
                    Text(bookmark.url)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer(minLength: 4)
            
            // Favorite button
            Button(action: toggleFavorite) {
                Image(systemName: bookmark.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(bookmark.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered || bookmark.isFavorite ? 1.0 : 0.5)
        }
        .frame(width: 140, height: 64)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ?
                    Color(NSColor.controlBackgroundColor).opacity(0.8) :
                    Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0.05), radius: isHovered ? 8 : 3, x: 0, y: isHovered ? 3 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: isHovered ? 2 : 1)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
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
    HStack(spacing: 12) {
        CompactBookmarkCardView(
            bookmark: Bookmark(
                title: "GitHub",
                url: "https://github.com",
                icon: "arrow.triangle.branch",
                categoryId: UUID(),
                isFavorite: true
            )
        )
        .environmentObject(DataStorage.shared)
        
        CompactBookmarkCardView(
            bookmark: Bookmark(
                title: "SwiftUI Documentation",
                url: "https://developer.apple.com/documentation/swiftui",
                icon: "swift",
                categoryId: UUID(),
                isFavorite: false
            )
        )
        .environmentObject(DataStorage.shared)
    }
    .padding()
    .frame(width: 350, height: 150)
}

