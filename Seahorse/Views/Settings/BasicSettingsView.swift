//
//  BasicSettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct BasicSettingsView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var storagePathManager = StoragePathManager.shared
    @StateObject private var exportImportManager = ExportImportManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var aiSettings = AISettings.shared
    @StateObject private var startupManager = StartupManager.shared
    
    private var colorOptions: [Color] {
        AppConfig.shared.availableColors
    }
    
    @State private var showRestartAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Language Setting
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.appLanguage)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Picker("", selection: $languageManager.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 300)
                    .onChange(of: languageManager.appLanguage) { _, _ in
                        showRestartAlert = true
                    }
                    .accessibilityLabel(L10n.appLanguage)
                    .accessibilityHint(L10n.appLanguageHint)
                    
                    Text(L10n.appLanguageHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // AI Language Setting
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.aiParsingLanguage)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Picker("", selection: $aiSettings.aiLanguage) {
                        ForEach(AILanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 300)
                    .accessibilityLabel(L10n.aiParsingLanguage)
                    .accessibilityHint(L10n.aiParsingLanguageHint)
                    
                    Text(L10n.aiParsingLanguageHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Primary Color Setting
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.primaryColor)
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: appearanceManager.accentColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    appearanceManager.accentColor = color
                                }
                        }
                    }
                }
                
                Divider()
                
                // Startup Setting
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.startup)
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.launchAtLogin)
                                .font(.system(size: 13, weight: .medium))
                            
                            Text(L10n.launchAtLoginHint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $startupManager.launchAtLogin)
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.launchAtLogin)
                            .accessibilityHint(L10n.launchAtLoginHint)
                    }
                }
                
                Divider()
                
                // Appearance Setting
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.appearance)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Picker("", selection: $appearanceManager.selectedMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 300)
                    .accessibilityLabel(L10n.appearance)
                }
                
                Divider()
                
                // Preference Folder
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.preferenceFolder)
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 8) {
                        Text(storagePathManager.getDisplayPath())
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        
                        Button(L10n.changeDots) {
                            storagePathManager.changeStorageLocation(dataStorage: dataStorage) { success in
                                if !success {
                                    NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: nil, userInfo: ["message": "Failed to change storage location"])
                                }
                            }
                        }
                        .accessibilityLabel(L10n.changeDots)
                        
                        if storagePathManager.customPath != nil {
                            Button(L10n.reset) {
                                storagePathManager.resetToDefaultLocation()
                            }
                            .help(L10n.resetToDefaultLocation)
                            .accessibilityLabel(L10n.reset)
                            .accessibilityHint(L10n.resetToDefaultLocation)
                        }
                    }
                    
                    Text(L10n.storeBookmarksHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Export & Import
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.dataManagement)
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            exportImportManager.exportData(dataStorage: dataStorage)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text(L10n.export)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(exportImportManager.isExporting)
                        .accessibilityLabel(L10n.export)
                        
                        Button(action: {
                            exportImportManager.importData(dataStorage: dataStorage)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                Text(L10n.import)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(exportImportManager.isImporting)
                        .accessibilityLabel(L10n.import)
                    }
                    .frame(maxWidth: 300)
                    
                    Text(L10n.exportHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    if let error = exportImportManager.lastError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                
                Spacer()
            }
            .padding(30)
        }
        .alert(L10n.restartRequired, isPresented: $showRestartAlert) {
            Button(L10n.ok, role: .cancel) { }
        } message: {
            Text(L10n.restartMessage)
        }
    }
}

#Preview {
    BasicSettingsView()
        .environmentObject(DataStorage.shared)
        .frame(width: 600, height: 400)
}

