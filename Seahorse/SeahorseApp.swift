//
//  SeahorseApp.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import AppKit
import OSLog

@main
struct SeahorseApp: App {
    // CRITICAL: Initialize StoragePathManager FIRST to establish security-scoped access
    @StateObject private var storagePathManager = StoragePathManager.shared
    @StateObject private var dataStorage = DataStorage.shared
    @StateObject private var batchParsingService = BatchParsingService(dataStorage: DataStorage.shared)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Copy monitoring
    @StateObject private var copyMonitor = CopyMonitor.shared
    
    // Status Bar Manager
    @State private var statusBarManager: StatusBarManager?
    
    // Settings
    // Removed showInDock as it's now dynamic based on window visibility
    
    init() {
        // Ensure storage path manager is initialized before data storage
        // This establishes security-scoped access to custom folders
        _ = StoragePathManager.shared
        
        // Initialize NotificationService early to set up delegate
        // This ensures notifications show as banners when app is in foreground
        _ = NotificationService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(batchParsingService: batchParsingService)
                .environmentObject(dataStorage)
                .task {
                    // Start monitoring copy events when app launches
                    copyMonitor.startMonitoring()
                }
                .onAppear {
                    // Initialize StatusBarManager
                    if statusBarManager == nil {
                        statusBarManager = StatusBarManager(batchParsingService: batchParsingService)
                    }
                    
                    // Initial state: Headless
                    // Hide the window immediately on launch
                    if let window = NSApp.windows.first {
                        window.orderOut(nil)
                    }
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .newItem) {}
            
            // Edit menu with import
            CommandGroup(after: .pasteboard) {
                Button("Import Bookmarks...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowImportDialog"), object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
        
        // Item Detail Window - supports multiple windows based on item ID
        WindowGroup(id: "item-detail", for: UUID.self) { itemId in
            ItemDetailWindowView(itemId: itemId.wrappedValue)
                .environmentObject(dataStorage)
        } defaultValue: {
            UUID()
        }
        .defaultSize(width: 1600, height: 1000)
        .defaultPosition(.center)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(dataStorage)
        }
    }
}

// MARK: - Item Detail Window View

struct ItemDetailWindowView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let itemId: UUID
    
    var body: some View {
        Group {
            if let item = dataStorage.items.first(where: { $0.id == itemId }) {
                ItemDetailView(item: item)
            } else {
                VStack {
                    Text("Item not found")
                        .foregroundStyle(.secondary)
                    Text("Item ID: \(itemId.uuidString)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// App Delegate for handling quit events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.info("🔄 Syncing data before quit...", category: .general)
        
        // Force save all database data synchronously
        Task { @MainActor in
            DataStorage.shared.forceSaveAllData()
        }
        
        Log.info("✅ Data sync complete", category: .general)
        return .terminateNow
    }
}
