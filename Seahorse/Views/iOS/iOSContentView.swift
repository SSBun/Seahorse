#if os(iOS)
//
//  iOSContentView.swift
//  Seahorse
//

import SwiftUI

struct iOSContentView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager

    private var colorScheme: ColorScheme? {
        switch appearanceManager.selectedMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some View {
        TabView {
            iOSHomePageView()
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2")
                }
            iOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(colorScheme)
    }
}

#endif
