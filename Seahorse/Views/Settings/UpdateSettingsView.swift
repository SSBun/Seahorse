//
//  UpdateSettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/08.
//

import SwiftUI
import Sparkle

struct UpdateSettingsView: View {
    @StateObject private var updater = SparkleUpdater.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Updates")
                .font(.system(size: 16, weight: .semibold))
            
            Text("Keep Seahorse up to date with the latest improvements.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.setAutomaticallyChecks($0) }
                    ))
                    
                    Toggle("Automatically download updates", isOn: Binding(
                        get: { updater.automaticallyDownloadsUpdates },
                        set: { updater.setAutomaticallyDownloads($0) }
                    ))
                    
                    HStack(spacing: 8) {
                        Button {
                            updater.checkForUpdates()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Check for Updates")
                            }
                        }
                        
                        Text("Current version: \(updater.currentVersionDescription)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    UpdateSettingsView()
}

