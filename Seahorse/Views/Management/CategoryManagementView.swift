//
//  CategoryManagementView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject var dataStorage: DataStorage
    
    @State private var newCategoryName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor: Color = AppConfig.shared.defaultCategoryColor
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingCategory: Category?
    @State private var categoryToDelete: Category?
    @State private var showingDeleteConfirmation = false
    @State private var showingIconPicker = false

    // Default categories that cannot be edited or deleted
    private let defaultCategoryNames = ["All Bookmarks", "Favorites", "Github", "None"]

    private func isDefaultCategory(_ category: Category) -> Bool {
        defaultCategoryNames.contains(category.name)
    }

    private func getNoneCategory() -> Category? {
        dataStorage.categories.first(where: { $0.name == "None" })
    }
    
    private var availableColors: [Color] {
        AppConfig.shared.availableColors
    }

    private var iconsByCategory: [String: [String]] {
        SFSymbolManager.shared.iconsByCategory()
    }

    // All categories are visible (no filtering)
    private var visibleCategories: [Category] {
        dataStorage.categories
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Add New Category Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add New Category")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 12) {
                        TextField("Category name", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        
                        Button(editingCategory == nil ? "Add" : "Update") {
                            if editingCategory != nil {
                                updateCategory()
                            } else {
                                addCategory()
                            }
                        }
                        .disabled(newCategoryName.isEmpty)
                        
                        if editingCategory != nil {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button(action: {
                            showingIconPicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 24))
                                    .frame(width: 48, height: 48)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Selected Icon")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(selectedIcon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingIconPicker) {
                            IconPickerSheet(selectedIcon: $selectedIcon)
                                .frame(width: 360, height: 480)
                        }
                    }
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Existing Categories
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Existing Categories")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Text("Drag to reorder")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    List {
                        ForEach(visibleCategories) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                    .frame(width: 20)

                                Text(category.name)
                                    .font(.system(size: 13))

                                if isDefaultCategory(category) {
                                    Text("(Default)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if !isDefaultCategory(category) {
                                    Button(action: {
                                        startEditing(category)
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)

                                    Button(action: {
                                        categoryToDelete = category
                                        showingDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(editingCategory?.id == category.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .onMove { source, destination in
                            dataStorage.reorderCategories(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 32)
                    .frame(minHeight: 200)
                    .padding(.horizontal, -8)
                }
                
                Spacer()
            }
            .padding(30)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: $showingDeleteConfirmation,
            presenting: categoryToDelete
        ) { category in
            Button("Delete", role: .destructive) {
                deleteCategory(category)
            }
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
        } message: { category in
            Text("Are you sure you want to delete '\(category.name)'? Bookmarks in this category will be moved to the 'None' category.")
        }
    }
    
    private func addCategory() {
        guard !newCategoryName.isEmpty else { return }
        
        // Check for duplicates
        if dataStorage.categoryExists(name: newCategoryName) {
            alertMessage = "A category with this name already exists"
            showingAlert = true
            return
        }
        
        let category = Category(name: newCategoryName, icon: selectedIcon, color: selectedColor)
        
        do {
            try dataStorage.addCategory(category)
            resetForm()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func startEditing(_ category: Category) {
        // Prevent editing default categories
        if isDefaultCategory(category) {
            alertMessage = "Default categories cannot be edited"
            showingAlert = true
            return
        }
        
        editingCategory = category
        newCategoryName = category.name
        selectedIcon = category.icon
        selectedColor = category.color
    }
    
    private func deleteCategory(_ category: Category) {
        // Double-check not a default category
        if isDefaultCategory(category) {
            alertMessage = "Default categories cannot be deleted"
            showingAlert = true
            categoryToDelete = nil
            return
        }
        
        // Check if there are bookmarks in this category
        let bookmarksInCategory = dataStorage.bookmarks.filter { $0.categoryId == category.id }
        if !bookmarksInCategory.isEmpty {
            // Move bookmarks to "None" category
            if let noneCategory = getNoneCategory() {
                // Reassign all bookmarks to None category
                for bookmark in bookmarksInCategory {
                    var updated = bookmark
                    updated.categoryId = noneCategory.id
                    do {
                        try dataStorage.updateBookmark(updated)
                    } catch {
                        print("Failed to move bookmark: \(error)")
                    }
                }
            }
        }
        
        do {
            try dataStorage.deleteCategory(category)
            categoryToDelete = nil
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
            categoryToDelete = nil
        }
    }
    
    private func updateCategory() {
        guard let editing = editingCategory else { return }
        
        // Check for duplicates (excluding current)
        if dataStorage.categoryExists(name: newCategoryName, excluding: editing.id) {
            alertMessage = "A category with this name already exists"
            showingAlert = true
            return
        }
        
        let updated = Category(id: editing.id, name: newCategoryName, icon: selectedIcon, color: selectedColor)
        
        do {
            try dataStorage.updateCategory(updated)
            resetForm()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func cancelEditing() {
        resetForm()
    }
    
    private func resetForm() {
        newCategoryName = ""
        selectedIcon = "folder.fill"
        selectedColor = .blue
        editingCategory = nil
    }

}

#Preview {
    CategoryManagementView()
        .environmentObject(DataStorage.shared)
        .frame(width: 600, height: 500)
}

