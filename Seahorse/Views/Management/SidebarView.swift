//
//  SidebarView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: Hashable, Identifiable {
    case category(Category)
    case tag(Tag)
    
    var id: UUID {
        switch self {
        case .category(let category):
            return category.id
        case .tag(let tag):
            return tag.id
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let categories: [Category]
    let tags: [Tag]
    @Binding var selectedCategory: Category?
    @Binding var selectedTag: Tag?
    
    @State private var selectedItem: SidebarItem?
    @State private var dropTargetCategory: UUID?
    
    var body: some View {
        List(selection: $selectedItem) {
            Section {
                ForEach(categories) { category in
                    ZStack {
                        // Invisible full-width drop zone
                        Color.clear
                            .contentShape(Rectangle())
                            .onDrop(of: [.text], isTargeted: Binding(
                                get: { dropTargetCategory == category.id },
                                set: { isTargeted in
                                    dropTargetCategory = isTargeted ? category.id : nil
                                }
                            )) { providers in
                                handleDrop(providers: providers, category: category)
                            }
                        
                        // Visible label
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .frame(width: 16, height: 16)
                            
                            Text(category.name)
                                .font(.system(size: 13))
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tag(SidebarItem.category(category))
                    .listRowBackground(
                        dropTargetCategory == category.id ?
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.25))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2) :
                        nil
                    )
                }
            } header: {
                Text("CATEGORIES")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Section {
                ForEach(tags) { tag in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 10, height: 10)
                        
                        Text(tag.name)
                            .font(.system(size: 13))
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tag(SidebarItem.tag(tag))
                }
            } header: {
                Text("TAGS")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Bookmarks")
        .frame(minWidth: 200, idealWidth: 220)
        .onChange(of: selectedItem) { _, newValue in
            switch newValue {
            case .category(let category):
                selectedCategory = category
                selectedTag = nil
            case .tag(let tag):
                selectedTag = tag
                selectedCategory = nil
            case .none:
                break
            }
        }
        .onAppear {
            // Initialize selection
            if let category = selectedCategory {
                selectedItem = .category(category)
            } else if let tag = selectedTag {
                selectedItem = .tag(tag)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], category: Category) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            guard let data = data as? Data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let bookmarkId = UUID(uuidString: uuidString) else {
                return
            }
            
            DispatchQueue.main.async {
                if let bookmark = dataStorage.bookmarks.first(where: { $0.id == bookmarkId }) {
                    var updated = bookmark
                    updated.categoryId = category.id
                    do {
                        try dataStorage.updateBookmark(updated)
                    } catch {
                        print("Failed to move bookmark: \(error)")
                    }
                }
            }
        }
        
        return true
    }
}

#Preview {
    let dataStorage = DataStorage.shared
    
    NavigationSplitView {
        SidebarView(
            categories: dataStorage.categories,
            tags: dataStorage.tags,
            selectedCategory: .constant(dataStorage.categories.first),
            selectedTag: .constant(nil)
        )
        .environmentObject(dataStorage)
    } detail: {
        Text("Detail View")
    }
}

