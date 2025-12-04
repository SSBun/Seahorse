//
//  ToolbarView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

enum ViewMode {
    case grid
    case list
}

struct ToolbarView: View {
    let selectedCategory: Category?
    @Binding var viewMode: ViewMode
    @Binding var searchText: String
    @ObservedObject var batchParsingService: BatchParsingService
    
    var body: some View {
        HStack(spacing: 10) {
            // Add button
            Button(action: {
                // Add bookmark action (mock)
            }) {
                Image(systemName: "plus")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help("Add Bookmark")
            
            // Delete button
            Button(action: {
                // Delete bookmark action (mock)
            }) {
                Image(systemName: "trash")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help("Delete Bookmark")
            
            Divider()
                .frame(height: 18)
            
            // Batch parsing button
            Button(action: {
                if batchParsingService.isRunning {
                    batchParsingService.pause()
                } else {
                    batchParsingService.start()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: batchParsingService.isRunning ? "pause.fill" : "play.fill")
                        .imageScale(.medium)
                        .foregroundStyle(batchParsingService.isRunning ? .orange : .blue)
                    
                    if batchParsingService.isRunning {
                        Text("\(batchParsingService.completedCount)/\(batchParsingService.totalCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.borderless)
            .help(batchParsingService.isRunning ? "Pause Batch Parsing" : "Start Batch Parsing")
            
            // Parsing progress indicator
            if batchParsingService.isRunning, let current = batchParsingService.currentBookmark {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    
                    Text("Parsing: \(current.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }
            }
            
            Divider()
                .frame(height: 18)
            
            // View mode toggle
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "square.grid.2x2")
                    .tag(ViewMode.grid)
                Image(systemName: "list.bullet")
                    .tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            
            Spacer()
            
            // Category title (optional)
            if let category = selectedCategory {
                Text(category.name)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(width: 220)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    let dataStorage = DataStorage.shared
    let batchParsingService = BatchParsingService(dataStorage: dataStorage)
    
    VStack {
        ToolbarView(
            selectedCategory: dataStorage.categories.first,
            viewMode: .constant(.grid),
            searchText: .constant(""),
            batchParsingService: batchParsingService
        )
        Divider()
        Spacer()
    }
    .frame(width: 800, height: 600)
}

