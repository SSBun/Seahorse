#if os(macOS)
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
    @State private var isScrolling = false

    var body: some View {
        ScrollView {
            if viewMode == .grid {
                standardGridView
            } else {
                listView
            }
        }
        .onAppear {
            ListPerformanceMonitor.shared.recordCollectionAppeared(
                itemCount: items.count,
                mode: performanceMode
            )
        }
        .onChange(of: items.count) { oldCount, newCount in
            ListPerformanceMonitor.shared.recordCollectionChanged(
                oldCount: oldCount,
                newCount: newCount,
                mode: performanceMode
            )
        }
        .onChange(of: viewMode) { oldMode, newMode in
            ListPerformanceMonitor.shared.recordViewModeChanged(
                oldMode: performanceName(for: oldMode),
                newMode: performanceName(for: newMode),
                itemCount: items.count
            )
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            isScrolling = newPhase.isScrolling
            ListPerformanceMonitor.shared.recordScrollPhase(
                previous: String(describing: oldPhase),
                current: String(describing: newPhase),
                isScrolling: newPhase.isScrolling,
                mode: performanceMode,
                itemCount: items.count
            )
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { oldOffset, newOffset in
            ListPerformanceMonitor.shared.recordScrollOffset(
                previous: Double(oldOffset),
                current: Double(newOffset)
            )
        }
        .onDisappear {
            isScrolling = false
            ListPerformanceMonitor.shared.recordScrollPhase(
                previous: "unknown",
                current: "collection_disappear",
                isScrolling: false,
                mode: performanceMode,
                itemCount: items.count
            )
        }
    }

    private var performanceMode: String {
        performanceName(for: viewMode)
    }

    private func performanceName(for mode: ViewMode) -> String {
        switch mode {
        case .grid: "grid"
        case .list: "list"
        }
    }

    private var gridColumns: [GridItem] {
        if appearanceManager.isAutoColumnCount {
            return [GridItem(.adaptive(minimum: appearanceManager.cardMinWidth), spacing: appearanceManager.cardPadding)]
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: appearanceManager.gridColumnCount)
        }
    }

    private var standardGridView: some View {
        LazyVGrid(columns: gridColumns, spacing: appearanceManager.isAutoColumnCount ? appearanceManager.cardPadding : 16) {
            ForEach(items) { item in
                StandardCardView(
                    item: item,
                    allowsImageLoading: !isScrolling
                )
                    .padding(.horizontal, appearanceManager.isAutoColumnCount ? appearanceManager.cardPadding / 2 : 10)
                    .padding(.vertical, appearanceManager.isAutoColumnCount ? appearanceManager.cardPadding / 2 : 10)
            }
        }
        .padding(appearanceManager.isAutoColumnCount ? appearanceManager.cardPadding : 16)
    }


    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(items) { item in
                StandardListItemView(
                    item: item,
                    allowsImageLoading: !isScrolling
                )
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

#endif
