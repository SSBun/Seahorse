//
//  AdvancedSettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import ApplicationServices

struct AdvancedSettingsView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @StateObject private var copyMonitor = CopyMonitor.shared
    @AppStorage("enableSystemNotifications") private var isNotificationEnabled: Bool = false
    
    @State private var showingPermissionAlert = false
    
    private var hasAccessibilityPermission: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Copy Detection Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Copy Detection")
                        .font(.system(size: 16, weight: .semibold))
                    
                    // Enable/Disable Switch
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Copy Detection")
                                .font(.system(size: 13, weight: .medium))
                            
                            Text("Automatically save items when you copy the same content twice within the time window")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $copyMonitor.isEnabled)
                            .toggleStyle(.switch)
                            .disabled(!hasAccessibilityPermission)
                    }
                    .padding(.vertical, 8)
                    
                    // Permission Status
                    if !hasAccessibilityPermission {
                        permissionWarningView
                    } else {
                        permissionGrantedView
                    }
                    
                    Divider()
                    
                    // Time Window Slider
                    if copyMonitor.isEnabled && hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Double Copy Time Window")
                                    .font(.system(size: 13, weight: .medium))
                                
                                Spacer()
                                
                                Text(String(format: "%.1fs", copyMonitor.timeWindow))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Slider(
                                value: $copyMonitor.timeWindow,
                                in: 0.2...5.0,
                                step: 0.2
                            )
                            
                            HStack {
                                Text("0.2s")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("5s")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Items will be saved when you copy the same content twice within this time window")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        
                        // Feedback Setting
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Success Feedback")
                                    .font(.system(size: 13, weight: .medium))
                                
                                Text("Play sound and haptic feedback when an item is saved")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $copyMonitor.enableFeedback)
                                .toggleStyle(.switch)
                        }
                    }
                }
                
                Divider()
                
                // System Notifications Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Notifications")
                        .font(.system(size: 16, weight: .semibold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Notification When Saving Items")
                                .font(.system(size: 13, weight: .medium))
                            
                            Text("Display a system notification at the top right when a new item is saved")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isNotificationEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: isNotificationEnabled) { oldValue, newValue in
                                if newValue {
                                    NotificationService.shared.requestAuthorization()
                                }
                            }
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Permission Information Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why Accessibility Permission?")
                        .font(.system(size: 13, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        permissionInfoRow(
                            icon: "keyboard",
                            title: "Global Keyboard Monitoring",
                            description: "To detect Cmd+C shortcuts even when Seahorse is in the background"
                        )
                        
                        permissionInfoRow(
                            icon: "lock.shield",
                            title: "Privacy & Security",
                            description: "We only monitor keyboard events, not the content you type. Your privacy is protected."
                        )
                        
                        permissionInfoRow(
                            icon: "checkmark.circle",
                            title: "System Protected",
                            description: "macOS requires explicit permission for keyboard monitoring to ensure security"
                        )
                    }
                }
            }
            .padding(30)
        }
    }
    
    private var permissionWarningView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text("Accessibility Permission Required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }
            
            Text("Copy detection requires Accessibility permission to monitor keyboard events globally.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Button("Open System Settings") {
                openSystemSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var permissionGrantedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
            Text("Accessibility Permission Granted")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func permissionInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func openSystemSettings() {
        // Open System Settings to Accessibility pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(DataStorage.shared)
        .frame(width: 600, height: 500)
}

