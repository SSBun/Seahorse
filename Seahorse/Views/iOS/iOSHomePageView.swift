#if os(iOS)
//
//  iOSHomePageView.swift
//  Seahorse
//

import SwiftUI

enum iOSItemKind: String, CaseIterable {
    case all = "All"
    case bookmark = "Bookmarks"
    case image = "Images"
    case text = "Notes"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .bookmark: return "link"
        case .image: return "photo"
        case .text: return "doc.text"
        }
    }
}

enum iOSSortOrder: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"

    var icon: String {
        switch self {
        case .newestFirst: return "arrow.down.to.line"
        case .oldestFirst: return "arrow.up.to.line"
        }
    }
}

struct iOSHomePageView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @State private var searchText = ""
    @State private var selectedKind: iOSItemKind = .all
    @State private var selectedCategory: Category?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var sortOrder: iOSSortOrder = .newestFirst
    @State private var showingFilter = false

    private var filteredItems: [AnyCollectionItem] {
        let items = dataStorage.items.filter { item in
            let matchesKind = kindMatches(item)
            let matchesSearch = searchText.isEmpty || itemMatchesSearch(item, searchText)
            let matchesCategory = selectedCategory == nil || item.categoryId == selectedCategory?.id
            let matchesTags = selectedTagIds.isEmpty || !item.tagIds.filter { selectedTagIds.contains($0) }.isEmpty
            return matchesKind && matchesSearch && matchesCategory && matchesTags
        }
        return items.sorted { a, b in
            switch sortOrder {
            case .newestFirst: return a.addedDate > b.addedDate
            case .oldestFirst: return a.addedDate < b.addedDate
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                NavigationLink {
                    iOSItemDetailView(item: item)
                } label: {
                    iOSItemListRow(
                        item: item,
                        category: dataStorage.category(for: item.categoryId)
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Seahorse")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if filteredItems.isEmpty {
                    emptyState
                }
            }
            .sheet(isPresented: $showingFilter) {
                iOSFilterView(
                    selectedKind: $selectedKind,
                    selectedCategory: $selectedCategory,
                    selectedTagIds: $selectedTagIds,
                    sortOrder: $sortOrder
                )
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedKind != .all || selectedCategory != nil || !selectedTagIds.isEmpty
    }

    private func kindMatches(_ item: AnyCollectionItem) -> Bool {
        switch selectedKind {
        case .all: return true
        case .bookmark: return item.itemType == .bookmark
        case .image: return item.itemType == .image
        case .text: return item.itemType == .text
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Items")
                .font(.headline)
            Text("Your collection is empty or no items match your filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemMatchesSearch(_ item: AnyCollectionItem, _ query: String) -> Bool {
        let lowerQuery = query.lowercased()
        switch item.itemType {
        case .bookmark:
            guard let bookmark = item.asBookmark else { return false }
            return bookmark.title.lowercased().contains(lowerQuery)
                || bookmark.url.lowercased().contains(lowerQuery)
        case .image:
            return "image".contains(lowerQuery)
        case .text:
            guard let textItem = item.asTextItem else { return false }
            return textItem.content.lowercased().contains(lowerQuery)
                || (textItem.notes?.lowercased().contains(lowerQuery) ?? false)
        }
    }
}

// MARK: - Filter View

struct iOSFilterView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Binding var selectedKind: iOSItemKind
    @Binding var selectedCategory: Category?
    @Binding var selectedTagIds: Set<UUID>
    @Binding var sortOrder: iOSSortOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Sort
                Section("Sort") {
                    ForEach(iOSSortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Image(systemName: order.icon)
                                    .frame(width: 24)
                                Text(order.rawValue)
                                Spacer()
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Kind
                Section("Kind") {
                    ForEach(iOSItemKind.allCases, id: \.self) { kind in
                        Button {
                            selectedKind = kind
                        } label: {
                            HStack {
                                Image(systemName: kind.icon)
                                    .frame(width: 24)
                                Text(kind.rawValue)
                                Spacer()
                                if selectedKind == kind {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Category
                Section("Category") {
                    Button {
                        selectedCategory = nil
                    } label: {
                        HStack {
                            Text("All Categories")
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(dataStorage.categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                    .frame(width: 24)
                                Text(category.name)
                                Spacer()
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // Tags (multi-select)
                if !dataStorage.tags.isEmpty {
                    Section("Tags") {
                        ForEach(dataStorage.tags) { tag in
                            Button {
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds.insert(tag.id)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                    Spacer()
                                    if selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedKind = .all
                        selectedCategory = nil
                        selectedTagIds.removeAll()
                        sortOrder = .newestFirst
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#endif
