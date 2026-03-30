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
                standardGridView
            } else {
                listView
            }
        }
    }

    private var standardGridView: some View {
        GeometryReader { geometry in
            gridContent(containerWidth: geometry.size.width)
        }
    }

    @ViewBuilder
    private func gridContent(containerWidth: CGFloat) -> some View {
        let columnCount = calculateColumnCount(containerWidth: containerWidth)
        // Use fixed column count with flexible items, spacing adapts automatically
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount)

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(items) { item in
                StandardCardView(item: item)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 10)
    }

    private func calculateColumnCount(containerWidth: CGFloat) -> Int {
        if appearanceManager.isAutoColumnCount {
            // Calculate optimal column count based on container width and minimum card width
            let padding: CGFloat = 20  // .padding(.horizontal, 10) on each side
            let availableWidth = containerWidth - padding
            let calculatedCount = Int(availableWidth / appearanceManager.cardMinWidth)
            return max(2, min(6, calculatedCount))
        } else {
            return appearanceManager.gridColumnCount
        }
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
