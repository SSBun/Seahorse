//
//  BookmarkPreviewView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//
//  Preview view shown on long press of bookmark cards

import SwiftUI

struct BookmarkPreviewView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    
    var category: Category? {
        dataStorage.categories.first { $0.id == bookmark.categoryId }
    }
    
    var tags: [Tag] {
        bookmark.tagIds.compactMap { tagId in
            dataStorage.tags.first { $0.id == tagId }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    BookmarkIconView(
                        iconString: bookmark.icon,
                        size: 32
                    )
                    .frame(width: 56, height: 56)
                }
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Title and favorite
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bookmark.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                        
                        if bookmark.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    if bookmark.isParsed {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                            Text(L10n.aiParsed)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // URL
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.url)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text(bookmark.url)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            
            // Summary
            if let notes = bookmark.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.summary)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
            
            // Category
            if let category = category {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text(category.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            // Tags - separate section showing all tags
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tags)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    // Flow layout for all tags
                    FlowLayout(spacing: 6) {
                        ForEach(tags) { tag in
                            Text(tag.name)
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(tag.color.opacity(0.2))
                                )
                                .foregroundStyle(tag.color)
                        }
                    }
                }
            }
            
            // Added date
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.added)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text(bookmark.addedDate, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: bookmark.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                        Text(L10n.openInBrowser)
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(L10n.openInBrowser)
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bookmark.url, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text(L10n.copyURL)
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.copyURL)
            }
        }
        .padding(20)
        .frame(minWidth: 360, maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
    }
}

#Preview {
    BookmarkPreviewView(bookmark: Bookmark(
        title: "SwiftUI Documentation",
        url: "https://developer.apple.com/documentation/swiftui",
        icon: "book.fill",
        categoryId: UUID(),
        isFavorite: true,
        addedDate: Date(),
        notes: "Official SwiftUI documentation from Apple. Contains comprehensive guides, tutorials, and API references for building apps with SwiftUI.",
        tagIds: [],
        isParsed: true
    ))
    .environmentObject(DataStorage.shared)
}

