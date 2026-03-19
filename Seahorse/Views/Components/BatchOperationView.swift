//
//  BatchOperationView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import SwiftUI

struct BatchOperationView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @ObservedObject var batchParsingService: BatchParsingService
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var selectedBookmarkIds: Set<UUID> = []

    private var noneCategoryId: UUID? {
        dataStorage.categories.first(where: { $0.name == "None" })?.id
    }

    private var noneCategoryBookmarks: [Bookmark] {
        guard let categoryId = noneCategoryId else { return [] }
        return dataStorage.bookmarks.filter { $0.categoryId == categoryId }
    }

    private var filteredBookmarks: [Bookmark] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return noneCategoryBookmarks
        }
        return noneCategoryBookmarks.filter {
            $0.title.lowercased().contains(query) ||
            $0.url.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Batch Operation")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                TextField("Search bookmarks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()

            // List
            if filteredBookmarks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(noneCategoryBookmarks.isEmpty ? "No bookmarks in None category" : "No matching bookmarks")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredBookmarks) { bookmark in
                            BatchBookmarkRow(
                                bookmark: bookmark,
                                isSelected: selectedBookmarkIds.contains(bookmark.id),
                                onToggle: {
                                    if selectedBookmarkIds.contains(bookmark.id) {
                                        selectedBookmarkIds.remove(bookmark.id)
                                    } else {
                                        selectedBookmarkIds.insert(bookmark.id)
                                    }
                                }
                            )
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }

            // Bottom toolbar
            HStack(spacing: 12) {
                // Select all button
                Button(action: {
                    if selectedBookmarkIds.count == filteredBookmarks.count {
                        selectedBookmarkIds.removeAll()
                    } else {
                        selectedBookmarkIds = Set(filteredBookmarks.map { $0.id })
                    }
                }) {
                    Text(selectedBookmarkIds.count == filteredBookmarks.count && !filteredBookmarks.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .disabled(filteredBookmarks.isEmpty)

                Spacer()

                // Progress bar (center)
                if batchParsingService.isRunning {
                    ProgressView(value: batchParsingService.progress)
                        .frame(width: 200)
                        .progressViewStyle(.linear)

                    Text("\(batchParsingService.completedCount)/\(batchParsingService.totalCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                }

                Spacer()

                // Stop button (left of execute)
                if batchParsingService.isRunning {
                    Button(action: {
                        batchParsingService.pause()
                    }) {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .help("Stop")
                }

                // Execute button
                Button(action: {
                    let selected = noneCategoryBookmarks.filter { selectedBookmarkIds.contains($0.id) }
                    batchParsingService.start(bookmarks: selected)
                }) {
                    Text("Parse (\(selectedBookmarkIds.count))")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBookmarkIds.isEmpty || batchParsingService.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 480, height: 500)
    }
}

// MARK: - Bookmark Row

private struct BatchBookmarkRow: View {
    let bookmark: Bookmark
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                if let url = URL(string: bookmark.url), let host = url.host {
                    Text(host)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if bookmark.isParsed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
