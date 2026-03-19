//
//  SortMenuView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import SwiftUI

struct SortMenuView: View {
    @Binding var selectedOption: SortOption
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Sort Options
            ForEach(SortOption.allCases) { option in
                SortMenuRow(
                    option: option,
                    isSelected: selectedOption == option,
                    onSelect: {
                        selectedOption = option
                        onDismiss()
                    }
                )
            }
        }
        .padding(.vertical, 6)
        .frame(width: 240)
    }
}

// MARK: - Sort Menu Row

private struct SortMenuRow: View {
    let option: SortOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: option.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18)

                Text(option.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.white.opacity(0.06)
        }
        return .clear
    }
}

// MARK: - Sort Option Extension

extension SortOption {
    var displayName: String {
        rawValue
    }

    var iconName: String {
        switch self {
        case .none:
            return "line.3.horizontal.decrease"
        case .nameAscending:
            return "textformat.abc"
        case .newestFirst:
            return "arrow.down"
        case .oldestFirst:
            return "arrow.up"
        case .groupBySite:
            return "folder.badge.gearshape"
        }
    }
}

// MARK: - Sort Menu Button (Toolbar Trigger)

struct SortMenuButton: View {
    @ObservedObject var sortPreferenceManager: SortPreferenceManager
    @State private var isPopoverPresented = false

    var body: some View {
        Button(action: {
            isPopoverPresented.toggle()
        }) {
            Label("Sort", systemImage: "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SortMenuView(
                selectedOption: Binding(
                    get: { sortPreferenceManager.sortOption },
                    set: { sortPreferenceManager.sortOption = $0 }
                ),
                onDismiss: {
                    isPopoverPresented = false
                }
            )
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

#Preview {
    VStack {
        SortMenuButton(sortPreferenceManager: SortPreferenceManager.shared)
    }
    .padding(40)
    .frame(width: 400, height: 300)
    .background(Color(NSColor.textBackgroundColor))
}
