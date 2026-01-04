//
//  StatusBarManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/04.
//

import AppKit
import Combine
import SwiftUI

@MainActor
class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var batchParsingService: BatchParsingService
    private var cancellables = Set<AnyCancellable>()
    
    init(batchParsingService: BatchParsingService) {
        self.batchParsingService = batchParsingService
        super.init()
        setupStatusItem()
        setupObservers()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Enable layer backing for animations
            button.wantsLayer = true
            
            // Use custom icon, fallback to system symbol if missing
            if let image = NSImage(named: "seahorse_icon") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "ant.circle.fill", accessibilityDescription: "Seahorse")
            }
            
            button.action = #selector(handleButtonClick(_:))
            button.target = self
            // Listen for both left and right clicks
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupObservers() {
        // Observe batch parsing service to update menu if needed
        batchParsingService.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning in
                self?.updateStatusIcon(isRunning: isRunning)
            }
            .store(in: &cancellables)
            
        // Observe item added notification for feedback
        NotificationCenter.default.publisher(for: NSNotification.Name("SeahorseItemAdded"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSuccessFeedback()
            }
            .store(in: &cancellables)
    }
    
    private func performSuccessFeedback() {
        // 1. Shake Animation
        shakeIcon()
        
        // 2. Sound/Haptic (if enabled)
        if UserDefaults.standard.bool(forKey: "enableCopyFeedback") {
            // Play system sound
            NSSound(named: "Glass")?.play()
            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
    
    private func shakeIcon() {
        guard let button = statusItem.button else { return }
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-5, 5, -3, 3, -2, 2, 0]
        
        button.layer?.add(animation, forKey: "shake")
    }
    
    private func updateStatusIcon(isRunning: Bool) {
        guard let button = statusItem.button else { return }
        // Keep the same icon for now
        if let image = NSImage(named: "seahorse_icon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "ant.circle.fill", accessibilityDescription: "Seahorse")
        }
    }
    
    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            // Right click: Show Menu
            showMenu()
        } else {
            // Left click (or others): Toggle Window
            toggleWindow()
        }
    }
    
    private func toggleWindow() {
        // Activate app and set policy to regular (Dock icon visible)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Find the main window and show it
        // We look for a window that is not a panel/sheet/status item
        // Since we only have one main window, taking the first one that responds to makeKeyAndOrderFront is usually safe
        // or we can rely on the fact that we hid it.
        
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: if no window found (unlikely if we just hid it), try to unhide all
            NSApp.unhide(nil)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        
        // Quick Actions
        menu.addItem(withTitle: "Add Bookmark", action: #selector(addBookmark), keyEquivalent: "b").target = self
        menu.addItem(withTitle: "Add Image", action: #selector(addImage), keyEquivalent: "i").target = self
        menu.addItem(withTitle: "Add Note", action: #selector(addNote), keyEquivalent: "n").target = self
        
        menu.addItem(NSMenuItem.separator())
        
        // Services
        let parsingTitle = batchParsingService.isRunning ? "Pause Parsing" : "Start Parsing"
        menu.addItem(withTitle: parsingTitle, action: #selector(toggleParsing), keyEquivalent: "").target = self
        
        if batchParsingService.isRunning {
            let statsItem = NSMenuItem(title: "Parsing: \(batchParsingService.completedCount)/\(batchParsingService.totalCount)", action: nil, keyEquivalent: "")
            statsItem.isEnabled = false
            menu.addItem(statsItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // App Controls
        menu.addItem(withTitle: "Open Seahorse", action: #selector(openApp), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q").target = self
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Clear it so left click doesn't show it next time
    }
    
    // MARK: - Actions
    
    @objc private func addBookmark() {
        openApp()
        NotificationCenter.default.post(name: NSNotification.Name("ShowAddBookmark"), object: nil)
    }
    
    @objc private func addImage() {
        openApp()
        NotificationCenter.default.post(name: NSNotification.Name("ShowAddImage"), object: nil)
    }
    
    @objc private func addNote() {
        openApp()
        NotificationCenter.default.post(name: NSNotification.Name("ShowAddText"), object: nil)
    }
    
    @objc private func toggleParsing() {
        if batchParsingService.isRunning {
            batchParsingService.pause()
        } else {
            batchParsingService.start()
        }
    }
    
    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
