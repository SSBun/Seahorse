//
//  IconPickerPopover.swift
//  Seahorse
//
//  Created by caishilin on 2025/04/02.
//

import SwiftUI

struct IconPickerPopover: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recentIcons") private var recentIconsData: String = ""

    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var recentIcons: [String] = []
    @State private var windowSize: CGSize = CGSize(width: 360, height: 480)

    private var gridColumns: [GridItem] {
        let iconSize: CGFloat = 40
        let spacing: CGFloat = 8
        let availableWidth = windowSize.width - 32 // padding
        let count = max(Int(availableWidth / (iconSize + spacing)), 6)
        return Array(repeating: GridItem(.fixed(iconSize), spacing: spacing), count: count)
    }

    private var allCategories: [String] {
        var categories = Array(SFSymbolManager.shared.iconsByCategory().keys.sorted())
        categories.insert("All", at: 0)
        categories.insert("Recent", at: 0)
        return categories
    }

    private var filteredIcons: [String] {
        let icons: [String]

        if !searchText.isEmpty {
            icons = SFSymbolManager.shared.searchIcons(query: searchText)
        } else if selectedCategory == "Recent" {
            icons = recentIcons.isEmpty ? ["folder.fill"] : recentIcons
        } else if selectedCategory == "All" {
            icons = SFSymbolManager.shared.allIcons
        } else {
            icons = SFSymbolManager.shared.iconsByCategory()[selectedCategory] ?? []
        }

        return icons
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Choose Icon")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))

                    TextField("Search icons...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Category picker (horizontal scroll)
                if searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(allCategories, id: \.self) { category in
                                CategoryButton(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 32)
                    .padding(.bottom, 4)

                    Divider()
                }

                // Icon grid - takes remaining space with 3:4 ratio
                ScrollView {
                    if filteredIcons.isEmpty {
                        ContentUnavailableView {
                            Label("No Icons Found", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try a different search term")
                        }
                        .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 8) {
                            ForEach(filteredIcons, id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon
                                ) {
                                    selectIcon(icon)
                                }
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                windowSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                windowSize = newSize
            }
        }
        .frame(minWidth: 280, idealWidth: 360, maxWidth: 480,
               minHeight: 360, idealHeight: 480, maxHeight: 640)
        .onAppear {
            loadRecentIcons()
        }
    }

    private func selectIcon(_ icon: String) {
        selectedIcon = icon
        addToRecentIcons(icon)
        dismiss()
    }

    private func loadRecentIcons() {
        let decoder = JSONDecoder()
        if let data = recentIconsData.data(using: .utf8),
           let icons = try? decoder.decode([String].self, from: data) {
            recentIcons = icons
        }
    }

    private func addToRecentIcons(_ icon: String) {
        var icons = recentIcons
        icons.removeAll { $0 == icon }
        icons.insert(icon, at: 0)
        icons = Array(icons.prefix(20))

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(icons),
           let jsonString = String(data: data, encoding: .utf8) {
            recentIconsData = jsonString
            recentIcons = icons
        }
    }
}

// MARK: - Supporting Views

private struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color(NSColor.controlBackgroundColor)
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help(icon)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        }
        return Color(NSColor.controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor
        }
        return Color.clear
    }
}

#Preview {
    IconPickerPopover(selectedIcon: .constant("folder.fill"))
        .frame(width: 360, height: 480)
}
