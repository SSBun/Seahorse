//
//  BookmarkActionPopover.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct BookmarkActionPopover: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmarkId: UUID
    let onDelete: () -> Void
    @Binding var isPresented: Bool
    
    @State private var selectedCategoryId: UUID
    
    private var bookmark: Bookmark? {
        dataStorage.bookmarks.first(where: { $0.id == bookmarkId })
    }
    
    init(bookmark: Bookmark, onDelete: @escaping () -> Void, isPresented: Binding<Bool>) {
        self.bookmarkId = bookmark.id
        self.onDelete = onDelete
        self._isPresented = isPresented
        self._selectedCategoryId = State(initialValue: bookmark.categoryId)
    }
    
    var body: some View {
        Group {
            if let bookmark = bookmark {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: bookmark.icon)
                            .foregroundStyle(.blue)
                        Text(bookmark.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    Divider()
                    
                    // Category Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(dataStorage.categories.filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }) { category in
                                    CategorySelectionRow(
                                        category: category,
                                        isSelected: bookmark.categoryId == category.id,
                                        onSelect: {
                                            selectCategory(category)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                    
                    Divider()
                    
                    // Tags Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        if dataStorage.tags.isEmpty {
                            Text("No tags available")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(dataStorage.tags) { tag in
                                        TagSelectionRow(
                                            tag: tag,
                                            isSelected: bookmark.hasTag(tag.id),
                                            onToggle: {
                                                toggleTag(tag)
                                            }
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                }
                .padding(16)
                .frame(width: 300)
            } else {
                Text("Bookmark not found")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
    
    private func selectCategory(_ category: Category) {
        guard let currentBookmark = bookmark else { return }
        
        // Only allow selection, not deselection
        if currentBookmark.categoryId != category.id {
            var updated = currentBookmark
            updated.categoryId = category.id
            do {
                try dataStorage.updateBookmark(updated)
            } catch {
                print("Failed to update bookmark category: \(error)")
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        guard let currentBookmark = bookmark else { return }
        
        do {
            try dataStorage.toggleBookmarkTag(bookmark: currentBookmark, tagId: tag.id)
        } catch {
            print("Failed to toggle tag: \(error)")
        }
    }
}

struct CategorySelectionRow: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 16, height: 16)
                
                Text(category.name)
                    .font(.system(size: 12))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

struct TagSelectionRow: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .fill(tag.color)
                    .frame(width: 10, height: 10)
                
                Text(tag.name)
                    .font(.system(size: 12))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    BookmarkActionPopover(
        bookmark: Bookmark(
            title: "GitHub",
            url: "https://github.com",
            categoryId: UUID()
        ),
        onDelete: {},
        isPresented: .constant(true)
    )
    .environmentObject(DataStorage.shared)
}

