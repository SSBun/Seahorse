//
//  SeahorseApp.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import OSLog

#if os(macOS)
import AppKit

@main
struct SeahorseApp: App {
    // CRITICAL: Initialize StoragePathManager FIRST to establish security-scoped access
    @StateObject private var storagePathManager = StoragePathManager.shared
    @StateObject private var dataStorage = DataStorage.shared
    @StateObject private var batchParsingService = BatchParsingService(dataStorage: DataStorage.shared)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Copy monitoring
    @StateObject private var copyMonitor = CopyMonitor.shared

    // Auto AI Parsing
    @StateObject private var autoParsingService = AutoParsingService(dataStorage: DataStorage.shared)

    // Image Generation
    @StateObject private var imageGenerationService = ImageGenerationService.shared

    // Status Bar Manager
    @State private var statusBarManager: StatusBarManager?
    @StateObject private var mcpHelperManager = MCPHelperManager.shared

    // Item Detail Window State - shared across the single window instance
    @StateObject private var itemDetailState = ItemDetailState()

    init() {
        // Ensure storage path manager is initialized before data storage
        // This establishes security-scoped access to custom folders
        _ = StoragePathManager.shared

        // Initialize NotificationService early to set up delegate
        // This ensures notifications show as banners when app is in foreground
        _ = NotificationService.shared
    }

    var body: some Scene {
        // Main Window - Single window only (no tabs, no multiple windows)
        Window("Seahorse", id: "main") {
            ContentView(batchParsingService: batchParsingService)
                .environmentObject(dataStorage)
                .environmentObject(itemDetailState)
                .environmentObject(autoParsingService)
                .environmentObject(imageGenerationService)
                .task {
                    // Start monitoring copy events when app launches
                    copyMonitor.startMonitoring()
                    mcpHelperManager.startIfNeeded()
                }
                .onAppear {
                    // Initialize StatusBarManager
                    if statusBarManager == nil {
                        statusBarManager = StatusBarManager(batchParsingService: batchParsingService)
                    }
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

        // Item Detail Window - Single window only
        Window("Item Detail", id: "item-detail") {
            ItemDetailWindowView()
                .environmentObject(dataStorage)
                .environmentObject(itemDetailState)
                .environmentObject(imageGenerationService)
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
    @EnvironmentObject var itemDetailState: ItemDetailState

    var body: some View {
        Group {
            if let itemId = itemDetailState.currentItemId,
               let item = dataStorage.item(for: itemId) {
                ItemDetailView(item: item)
            } else {
                VStack {
                    Text("Select an item to view details")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            Log.info("detail_open window_appear source=\(itemDetailState.openRequestSourceName) item_set=\(itemDetailState.currentItemId != nil) elapsed_ms=\(itemDetailState.elapsedSinceOpenRequestMs())", category: .performance)
        }
        .onChange(of: itemDetailState.currentItemId) { _, itemId in
            Log.info("detail_open window_item_change source=\(itemDetailState.openRequestSourceName) has_item=\(itemId != nil) elapsed_ms=\(itemDetailState.elapsedSinceOpenRequestMs())", category: .performance)
        }
    }
}

// MARK: - Item Detail State

/// Shared state for the single item detail window
/// Ensures only one item detail window can exist and tracks the current item
@MainActor
final class ItemDetailState: ObservableObject {
    @Published var currentItemId: UUID?
    private var openRequestStartedAt: TimeInterval?
    private var openRequestSource = "unknown"
    var openRequestSourceName: String { openRequestSource }

    func showItem(_ itemId: UUID, source: String = "unknown", requestedAt: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        openRequestStartedAt = requestedAt
        openRequestSource = source
        Log.info("detail_open showItem source=\(source) item_type_pending=true elapsed_ms=\(elapsedSinceOpenRequestMs())", category: .performance)
        currentItemId = itemId
    }

    func elapsedSinceOpenRequestMs() -> String {
        guard let openRequestStartedAt else { return "n/a" }
        let elapsed = (ProcessInfo.processInfo.systemUptime - openRequestStartedAt) * 1000
        return String(format: "%.1f", elapsed)
    }
}

// App Delegate for handling quit events
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.info("Syncing data before quit...", category: .general)

        MCPHelperManager.shared.stop()
        DataStorage.shared.forceSaveAllData()

        Log.info("Data sync complete", category: .general)
        return .terminateNow
    }
}

#elseif os(iOS)

@main
struct SeahorseApp: App {
    @StateObject private var dataStorage = DataStorage.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var autoParsingService = AutoParsingService(dataStorage: DataStorage.shared)

    init() {
        // Initialize NotificationService early to set up delegate
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .environmentObject(dataStorage)
                .environmentObject(appearanceManager)
                .environmentObject(autoParsingService)
        }
    }
}

#endif
