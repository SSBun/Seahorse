//
//  ImportBookmarksView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportBookmarksView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStorage: DataStorage
    
    @State private var isImporting = false
    @State private var importedBookmarks: [Bookmark] = []
    @State private var selectedFileURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var importSuccess = false
    @State private var importCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Bookmarks")
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
                    if importSuccess {
                        // Success message
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            
                            Text("Successfully imported \(importCount) bookmarks!")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Your bookmarks have been added to the \"None\" category. You can organize them later.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Import from File")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("You can import bookmarks from:")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 12))
                                    Text("JSON files exported from Seahorse")
                                        .font(.system(size: 12))
                                }
                                
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 12))
                                    Text("HTML bookmark files from Chrome, Firefox, Safari, etc.")
                                        .font(.system(size: 12))
                                }
                            }
                            .padding(.leading, 8)
                        }
                        
                        Divider()
                        
                        // File selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select File")
                                .font(.system(size: 14, weight: .semibold))
                            
                            if let url = selectedFileURL {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(url.lastPathComponent)
                                            .font(.system(size: 13, weight: .medium))
                                        Text(url.path)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { selectedFileURL = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            } else {
                                Button(action: selectFile) {
                                    HStack {
                                        Image(systemName: "folder.badge.plus")
                                            .font(.system(size: 16))
                                        Text("Choose File...")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if isImporting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Importing bookmarks...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Button(importSuccess ? "Done" : "Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !importSuccess {
                    Button("Import") {
                        performImport()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFileURL == nil || isImporting)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400)
        .alert("Import Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.json,
            UTType.html,
            UTType(filenameExtension: "htm")!
        ]
        panel.message = "Select a bookmark file to import"
        
        if panel.runModal() == .OK {
            selectedFileURL = panel.url
        }
    }
    
    private func performImport() {
        guard let fileURL = selectedFileURL else { return }
        
        isImporting = true
        DLog("Import UI: start import file='\(fileURL.lastPathComponent)'", category: .ui)
        
        Task {
            do {
                var bookmarks = try await ImportService.importBookmarks(from: fileURL)
                DLog("Import UI: ImportService returned count=\(bookmarks.count)", category: .ui)
                
                // Assign None category to all imported bookmarks
                if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                    DLog("Import UI: assigning category='None' id=\(noneCategory.id.uuidString) to all imported bookmarks", category: .ui)
                    bookmarks = bookmarks.map { bookmark in
                        Bookmark(
                            id: bookmark.id,
                            title: bookmark.title,
                            url: bookmark.url,
                            icon: bookmark.icon,
                            categoryId: noneCategory.id,
                            isFavorite: bookmark.isFavorite,
                            addedDate: bookmark.addedDate,
                            notes: bookmark.notes,
                            tagIds: bookmark.tagIds
                        )
                    }
                }
                
                // Import bookmarks
                var addedCount = 0
                var duplicateCount = 0
                for bookmark in bookmarks {
                    do {
                        try dataStorage.addBookmark(bookmark)
                        addedCount += 1
                    } catch DatabaseError.duplicateBookmarkURL {
                        // Skip duplicates silently
                        duplicateCount += 1
                    } catch {
                        // Other errors should still surface
                        throw error
                    }
                }
                
                DLog("Import UI: finished added=\(addedCount) duplicates=\(duplicateCount)", category: .ui)
                
                await MainActor.run {
                    importCount = addedCount
                    importSuccess = true
                    isImporting = false
                }
            } catch {
                DLog("Import UI: failed with error=\(error.localizedDescription)", category: .ui)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    ImportBookmarksView()
        .environmentObject(DataStorage.shared)
}

