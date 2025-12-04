//
//  AddTextView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/01.
//

import SwiftUI

struct AddTextView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.dismiss) var dismiss
    
    // Editing mode
    let editingItem: TextItem?
    
    @State private var content = ""
    @State private var notes = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var isFavorite = false
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(editingItem: TextItem? = nil) {
        self.editingItem = editingItem
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingItem == nil ? "Add Text Note" : "Edit Text Note")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Enter your text content here...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $content)
                                .font(.system(size: 13))
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Notes (optional metadata)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Notes")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add additional notes or metadata...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $notes)
                                .font(.system(size: 13))
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        }
                    }
                    
                    Divider()
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.system(size: 13, weight: .semibold))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(dataStorage.categories) { category in
                                if category.name != "All Bookmarks" && category.name != "Favorites" {
                                    CategorySelectionButton(
                                        category: category,
                                        isSelected: selectedCategoryId == category.id,
                                        onSelect: {
                                            selectedCategoryId = category.id
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .semibold))
                        
                        if dataStorage.tags.isEmpty {
                            Text("No tags available. Create tags in Settings.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(dataStorage.tags) { tag in
                                    TagSelectionButton(
                                        tag: tag,
                                        isSelected: selectedTagIds.contains(tag.id),
                                        onToggle: {
                                            if selectedTagIds.contains(tag.id) {
                                                selectedTagIds.remove(tag.id)
                                            } else {
                                                selectedTagIds.insert(tag.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Favorite Toggle
                    HStack {
                        Toggle(isOn: $isFavorite) {
                            HStack(spacing: 8) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                                Text("Add to Favorites")
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(editingItem == nil ? "Add Text Note" : "Save Changes") {
                    saveTextNote()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 700)
        .onAppear {
            if let item = editingItem {
                populateFields(from: item)
            } else {
                // Set default category
                if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                    selectedCategoryId = noneCategory.id
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func populateFields(from item: TextItem) {
        content = item.content
        notes = item.notes ?? ""
        selectedCategoryId = item.categoryId
        selectedTagIds = Set(item.tagIds)
        isFavorite = item.isFavorite
    }
    
    private func saveTextNote() {
        guard !content.isEmpty else { return }
        
        let categoryId = selectedCategoryId ?? {
            if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                return noneCategory.id
            }
            return dataStorage.categories.first?.id ?? UUID()
        }()
        
        if let editingItem = editingItem {
            let updatedItem = TextItem(
                id: editingItem.id,
                content: content,
                categoryId: categoryId,
                isFavorite: isFavorite,
                addedDate: editingItem.addedDate,
                notes: notes.isEmpty ? nil : notes,
                tagIds: Array(selectedTagIds),
                isParsed: editingItem.isParsed
            )
            
            do {
                try dataStorage.updateItem(AnyCollectionItem(updatedItem))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        } else {
            let textItem = TextItem(
                content: content,
                categoryId: categoryId,
                isFavorite: isFavorite,
                notes: notes.isEmpty ? nil : notes,
                tagIds: Array(selectedTagIds)
            )
            
            // Add to dataStorage
            dataStorage.addItem(AnyCollectionItem(textItem))
            dismiss()
        }
    }
}

#Preview {
    AddTextView()
        .environmentObject(DataStorage.shared)
}
