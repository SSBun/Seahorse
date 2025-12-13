//
//  TagManagementView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct TagManagementView: View {
    @EnvironmentObject var dataStorage: DataStorage
    
    @State private var newTagName = ""
    @State private var selectedColor: Color = AppConfig.shared.defaultTagColor
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingTag: Tag?
    @State private var tagToDelete: Tag?
    @State private var showingDeleteConfirmation = false
    
    private var availableColors: [Color] {
        AppConfig.shared.availableColors
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Add New Tag Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add New Tag")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 12) {
                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        
                        Button(editingTag == nil ? "Add" : "Update") {
                            if editingTag != nil {
                                updateTag()
                            } else {
                                addTag()
                            }
                        }
                        .disabled(newTagName.isEmpty)
                        
                        if editingTag != nil {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .buttonStyle(.bordered)
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
                
                // Existing Tags
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Existing Tags")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        if !dataStorage.tags.isEmpty {
                            Text("Drag to reorder")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if dataStorage.tags.isEmpty {
                        Text("No tags yet. Add your first tag above.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        List {
                            ForEach(dataStorage.tags) { tag in
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(tag.name)
                                        .font(.system(size: 13))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        startEditing(tag)
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.borderless)
                                    
                                    Button(action: {
                                        tagToDelete = tag
                                        showingDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(editingTag?.id == tag.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            }
                            .onMove { source, destination in
                                dataStorage.reorderTags(fromOffsets: source, toOffset: destination)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.defaultMinListRowHeight, 32)
                        .frame(minHeight: 200)
                        .padding(.horizontal, -8)
                    }
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
            "Delete Tag",
            isPresented: $showingDeleteConfirmation,
            presenting: tagToDelete
        ) { tag in
            Button("Delete", role: .destructive) {
                deleteTag(tag)
            }
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
        } message: { tag in
            Text("Are you sure you want to delete '\(tag.name)'? This tag will be removed from all bookmarks.")
        }
    }
    
    private func addTag() {
        guard !newTagName.isEmpty else { return }
        
        // Check for duplicates
        if dataStorage.tagExists(name: newTagName) {
            alertMessage = "A tag with this name already exists"
            showingAlert = true
            return
        }
        
        let tag = Tag(name: newTagName, color: selectedColor)
        
        do {
            try dataStorage.addTag(tag)
            resetForm()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func startEditing(_ tag: Tag) {
        editingTag = tag
        newTagName = tag.name
        selectedColor = tag.color
    }
    
    private func updateTag() {
        guard let editing = editingTag else { return }
        
        // Check for duplicates (excluding current)
        if dataStorage.tagExists(name: newTagName, excluding: editing.id) {
            alertMessage = "A tag with this name already exists"
            showingAlert = true
            return
        }
        
        let updated = Tag(id: editing.id, name: newTagName, color: selectedColor)
        
        do {
            try dataStorage.updateTag(updated)
            resetForm()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func deleteTag(_ tag: Tag) {
        // Remove tag from all bookmarks first
        let bookmarksWithTag = dataStorage.bookmarks.filter { $0.tagIds.contains(tag.id) }
        for bookmark in bookmarksWithTag {
            var updated = bookmark
            updated.removeTag(tag.id)
            do {
                try dataStorage.updateBookmark(updated)
            } catch {
                print("Failed to remove tag from bookmark: \(error)")
            }
        }
        
        // Then delete the tag
        do {
            try dataStorage.deleteTag(tag)
            tagToDelete = nil
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
            tagToDelete = nil
        }
    }
    
    private func cancelEditing() {
        resetForm()
    }
    
    private func resetForm() {
        newTagName = ""
        selectedColor = AppConfig.shared.defaultTagColor
        editingTag = nil
    }
}

#Preview {
    TagManagementView()
        .environmentObject(DataStorage.shared)
        .frame(width: 600, height: 500)
}

