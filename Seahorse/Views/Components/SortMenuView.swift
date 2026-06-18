#if os(macOS)
//
//  SortMenuView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import SwiftUI

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

    var body: some View {
        Menu {
            Picker("Sort", selection: $sortPreferenceManager.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.displayName, systemImage: option.iconName)
                        .tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "line.3.horizontal.decrease.circle")
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

#endif
