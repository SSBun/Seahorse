//
//  BookmarkCardView.swift
//  Seahorse
//
//  Legacy shim: preserved file name for Xcode project references.
//

import SwiftUI

/// Legacy wrapper to keep existing project references compiling.
/// Routes old `BookmarkCardView` usages to the new `StandardCardView`.
struct BookmarkCardView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    
    var body: some View {
        StandardCardView(item: AnyCollectionItem(bookmark))
            .environmentObject(dataStorage)
    }
}

#Preview {
    let storage = DataStorage.preview
    let sample = storage.bookmarks.first ?? Bookmark(
        title: "Example",
        url: "https://example.com",
        categoryId: storage.categories.first?.id ?? UUID()
    )
    return BookmarkCardView(bookmark: sample)
        .environmentObject(storage)
        .frame(width: 280)
        .padding()
}

