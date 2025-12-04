//
//  NewItemsConfirmationView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct NewItemsConfirmationView: View {
    let suggestedNewCategory: String?
    let suggestedNewTags: [String]
    @Binding var selectedNewCategory: Bool
    @Binding var selectedNewTags: Set<String>
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                
                Text("Create New Items?")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("AI suggested new categories and tags that don't exist yet. Select which ones you'd like to create:")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                // New Category
                if let newCat = suggestedNewCategory {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Category")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Toggle(isOn: $selectedNewCategory) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                                Text(newCat)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                
                // New Tags
                if !suggestedNewTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Tags")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(suggestedNewTags, id: \.self) { tag in
                                Toggle(isOn: Binding(
                                    get: { selectedNewTags.contains(tag) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedNewTags.insert(tag)
                                        } else {
                                            selectedNewTags.remove(tag)
                                        }
                                    }
                                )) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "tag.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                        Text(tag)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.green.opacity(0.1))
                                    )
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Selected") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!selectedNewCategory && selectedNewTags.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
    }
}

#Preview {
    NewItemsConfirmationView(
        suggestedNewCategory: "Technology",
        suggestedNewTags: ["swift", "ios", "tutorial"],
        selectedNewCategory: .constant(true),
        selectedNewTags: .constant(["swift", "ios"]),
        onConfirm: {},
        onCancel: {}
    )
}

