#if os(macOS)
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

    @State private var showRestartAlert = false
    @State private var backupFolders: [URL] = []
    @State private var selectedBackup: URL?
    @State private var showingRestoreConfirmation = false

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
                    .frame(maxWidth: 300, alignment: .leading)
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
                    .frame(maxWidth: 300, alignment: .leading)
                    .accessibilityLabel(L10n.aiParsingLanguage)
                    .accessibilityHint(L10n.aiParsingLanguageHint)
                    
                    Text(L10n.aiParsingLanguageHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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

                MCPSettingsSectionView()

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

                // Card Style Setting
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.cardStyle)
                        .font(.system(size: 13, weight: .semibold))

                    // Grid Column Count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grid Column Count")
                            .font(.system(size: 12, weight: .medium))

                        HStack(spacing: 12) {
                            Toggle("Auto", isOn: $appearanceManager.isAutoColumnCount)
                                .toggleStyle(.switch)

                            if !appearanceManager.isAutoColumnCount {
                                Picker("", selection: $appearanceManager.gridColumnCount) {
                                    ForEach(2...6, id: \.self) { count in
                                        Text("\(count)").tag(count)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    // Minimum Card Width (only when Auto is on)
                    if appearanceManager.isAutoColumnCount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Min Card Width")
                                .font(.system(size: 12, weight: .medium))

                            HStack(spacing: 8) {
                                TextField("", value: Binding(
                                    get: { Int(appearanceManager.cardMinWidth) },
                                    set: { appearanceManager.cardMinWidth = CGFloat($0) }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)

                                Text("pt")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Spacing")
                                .font(.system(size: 12, weight: .medium))

                            HStack(spacing: 8) {
                                TextField("", value: Binding(
                                    get: { Int(appearanceManager.cardPadding) },
                                    set: { appearanceManager.cardPadding = CGFloat($0) }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)

                                Text("pt")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Card Aspect Ratio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Aspect Ratio")
                            .font(.system(size: 12, weight: .medium))

                        Picker("", selection: $appearanceManager.cardAspectRatio) {
                            ForEach(CardAspectRatio.allCases, id: \.self) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
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

                        Button(action: {
                            backupData()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "archivebox.fill")
                                Text("Backup")
                            }
                        }
                        .disabled(exportImportManager.isBackingUp)
                        .help("Create backup in data folder")
                    }

                    Text(L10n.storeBookmarksHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    // Backup List
                    BackupListView()
                        .environmentObject(dataStorage)
                        .padding(.top, 8)
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
        .confirmationDialog(
            "Restore from Backup",
            isPresented: $showingRestoreConfirmation,
            presenting: selectedBackup
        ) { backup in
            Button("Restore", role: .destructive) {
                restoreFromBackup(backup)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([backup])
            }
            Button("Cancel", role: .cancel) { }
        } message: { backup in
            Text("This will replace your current data with the backup from \(exportImportManager.formatBackupName(backup)). This action cannot be undone.")
        }
        .onAppear {
            refreshBackupList()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BackupCompleted"))) { _ in
            refreshBackupList()
        }
    }

    private func backupData() {
        exportImportManager.backupToDataFolder(dataStorage: dataStorage) { success, url in
            if success, let url = url {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": "Backup created: \(url.lastPathComponent)"]
                )
                NotificationCenter.default.post(name: NSNotification.Name("BackupCompleted"), object: nil)
            } else if let error = exportImportManager.lastError {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": error]
                )
            }
        }
    }

    private func refreshBackupList() {
        Task {
            backupFolders = await exportImportManager.scanBackupFolders()
        }
    }

    private func restoreFromBackup(_ backup: URL) {
        exportImportManager.restoreFromBackup(backup, dataStorage: dataStorage) { success in
            if success {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": "Data restored successfully from backup"]
                )
            } else if let error = exportImportManager.lastError {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": error]
                )
            }
        }
    }

}

// MARK: - Backup List View

struct BackupListView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @StateObject private var exportImportManager = ExportImportManager.shared
    @State private var backupFolders: [URL] = []
    @State private var selectedBackup: URL?
    @State private var showingRestoreConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !backupFolders.isEmpty {
                Text("Backups")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(backupFolders, id: \.self) { backup in
                            BackupRow(
                                backup: backup,
                                formattedName: exportImportManager.formatBackupName(backup),
                                isSelected: selectedBackup == backup,
                                onTap: {
                                    selectedBackup = backup
                                    showingRestoreConfirmation = true
                                },
                                onDelete: {
                                    refreshBackups()
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
        .onAppear {
            refreshBackups()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BackupCompleted"))) { _ in
            refreshBackups()
        }
        .confirmationDialog(
            "Restore from Backup",
            isPresented: $showingRestoreConfirmation,
            presenting: selectedBackup
        ) { backup in
            Button("Restore", role: .destructive) {
                restoreBackup(backup)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([backup])
            }
            Button("Cancel", role: .cancel) { }
        } message: { backup in
            Text("This will replace your current data with the backup from \(exportImportManager.formatBackupName(backup)). This action cannot be undone.")
        }
    }

    private func refreshBackups() {
        Task {
            backupFolders = await exportImportManager.scanBackupFolders()
        }
    }

    private func restoreBackup(_ backup: URL) {
        exportImportManager.restoreFromBackup(backup, dataStorage: dataStorage) { success in
            if success {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": "Data restored successfully from backup"]
                )
            } else if let error = exportImportManager.lastError {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": error]
                )
            }
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: URL
    let formattedName: String
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(formattedName)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Button(action: onTap) {
                Text("Restore")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([backup])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Button {
                onTap()
            } label: {
                Label("Restore...", systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button(role: .destructive) {
                try? FileManager.default.removeItem(at: backup)
                onDelete()
            } label: {
                Label("Delete Backup", systemImage: "trash")
            }
        }
    }
}

#Preview {
    BasicSettingsView()
        .environmentObject(DataStorage.shared)
        .frame(width: 600, height: 400)
}


#endif
