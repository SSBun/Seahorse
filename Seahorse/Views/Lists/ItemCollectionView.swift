//
//  ItemCollectionView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import SwiftUI

struct ItemCollectionView: View {
    let items: [AnyCollectionItem]
    let viewMode: ViewMode
    
    @EnvironmentObject var dataStorage: DataStorage
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        ScrollView {
            if viewMode == .grid {
                waterfallView
            } else {
                listView
            }
        }
    }
    
    private var waterfallView: some View {
        ScrollView {
            switch appearanceManager.cardStyle {
            case .standard:
                standardGridView
            case .compact:
                compactGridView
            }
        }
    }
    
    private var standardGridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 240), spacing: 20)
        ], spacing: 20) {
            ForEach(items) { item in
                StandardCardView(item: item)
            }
        }
        .padding(20)
    }
    
    private var compactGridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 200), spacing: 16)
        ], spacing: 16) {
            ForEach(items) { item in
                if let bookmark = item.asBookmark {
                    CompactBookmarkCardView(bookmark: bookmark)
                } else {
                    // Fallback for non-bookmarks
                    StandardCardView(item: item)
                }
            }
        }
        .padding(16)
    }
    
    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(items) { item in
                StandardListItemView(item: item)
            }
        }
        .padding(16)
    }
}

#Preview("Grid View") {
    let bookmark = Bookmark(
        title: "Apple Developer",
        url: "https://developer.apple.com",
        icon: "hammer.fill",
        categoryId: UUID(),
        isFavorite: true,
        notes: "Resources for building apps."
    )
    
    let imageItem = ImageItem(
        imagePath: "https://picsum.photos/id/12/200/300",
        categoryId: UUID(),
        isFavorite: false,
        notes: "A nice blue background."
    )
    
    let textItem = TextItem(
        content: "Meeting Notes:\n- Discuss project timeline\n- Review designs\n- Assign tasks",
        categoryId: UUID(),
        isFavorite: true
    )
    
    let items = [
        AnyCollectionItem(bookmark),
        AnyCollectionItem(imageItem),
        AnyCollectionItem(textItem),
        AnyCollectionItem(Bookmark(title: "GitHub", url: "https://github.com", categoryId: UUID())),
        AnyCollectionItem(TextItem(content: "Short note", categoryId: UUID()))
    ]
    
    return ItemCollectionView(items: items, viewMode: .grid)
        .environmentObject(DataStorage.shared)
        .frame(width: 800, height: 600)
}

#Preview("List View") {
    let bookmark = Bookmark(
        title: "Apple Developer",
        url: "https://developer.apple.com",
        icon: "hammer.fill",
        categoryId: UUID(),
        isFavorite: true,
        notes: "Resources for building apps."
    )
    
    let imageItem = ImageItem(
        imagePath: "https://picsum.photos/id/12/200/300",
        categoryId: UUID(),
        isFavorite: false,
        notes: "A nice blue background."
    )
    
    let textItem = TextItem(
        content: "Meeting Notes:\n- Discuss project timeline\n- Review designs\n- Assign tasks",
        categoryId: UUID(),
        isFavorite: true
    )
    
    let items = [
        AnyCollectionItem(bookmark),
        AnyCollectionItem(imageItem),
        AnyCollectionItem(textItem)
    ]
    
    return ItemCollectionView(items: items, viewMode: .list)
        .environmentObject(DataStorage.shared)
        .frame(width: 800, height: 600)
}
