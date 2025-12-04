//
//  SettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case category = "Category"
    case tag = "Tag"
    case ai = "AI"
    case advanced = "Advanced"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .basic: return "gearshape"
        case .category: return "folder.fill"
        case .tag: return "tag.fill"
        case .ai: return "sparkles"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @State private var selectedTab: SettingsTab = .basic
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BasicSettingsView()
                .environmentObject(dataStorage)
                .tabItem {
                    Label(L10n.basic, systemImage: "gearshape")
                }
                .tag(SettingsTab.basic)
            
            CategoryManagementView()
                .environmentObject(dataStorage)
                .tabItem {
                    Label(L10n.category, systemImage: "folder.fill")
                }
                .tag(SettingsTab.category)
            
            TagManagementView()
                .environmentObject(dataStorage)
                .tabItem {
                    Label(L10n.tag, systemImage: "tag.fill")
                }
                .tag(SettingsTab.tag)
            
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(SettingsTab.ai)
            
            AdvancedSettingsView()
                .environmentObject(dataStorage)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStorage.shared)
}

