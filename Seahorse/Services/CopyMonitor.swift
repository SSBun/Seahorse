//
//  CopyMonitor.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices
import UniformTypeIdentifiers
import Carbon

@MainActor
class CopyMonitor: ObservableObject {
    static let shared = CopyMonitor(dataStorage: DataStorage.shared)
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false
    
    // Double-copy detection state
    private var lastCopyTime: Date?
    private var lastCopyContent: ClipboardContent?
    
    // Configurable properties
    // Configurable properties
    @AppStorage("copyMonitorEnabled") var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @AppStorage("copyTimeWindow") var timeWindow: TimeInterval = 5.0 {
        didSet {
            // Clamp between 0.2 and 5 seconds
            let clamped = max(0.2, min(5.0, timeWindow))
            if clamped != timeWindow {
                timeWindow = clamped
            }
        }
    }
    
    @AppStorage("enableCopyFeedback") var enableFeedback: Bool = true
    
    let dataStorage: DataStorage
    private lazy var pasteHandler: PasteHandler = PasteHandler(dataStorage: dataStorage)
    
    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring && isEnabled else { return }
        
        // Check accessibility permission
        guard checkAccessibilityPermission() else {
            Log.warning("Accessibility permission not granted, requesting...", category: .general)
            requestAccessibilityPermission()
            // Try again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startMonitoring()
            }
            return
        }
        
        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                
                let monitor = Unmanaged<CopyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            Log.error("Failed to create event tap", category: .general)
            return
        }
        
        // Check if event tap is enabled
        if !CGEvent.tapIsEnabled(tap: eventTap) {
            Log.error("Event tap is not enabled. Please grant accessibility permission.", category: .general)
            return
        }
        
        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            Log.error("Failed to create run loop source", category: .general)
            return
        }
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        isMonitoring = true
        
        Log.info("✅ CopyMonitor started - listening for Cmd+C globally", category: .general)
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        isMonitoring = false
        Log.info("CopyMonitor stopped", category: .general)
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check if it's a key down event
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        // Check for Cmd+C (Command key + 'C' key)
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 'C' key code is 8, Command key is .maskCommand
        if flags.contains(.maskCommand) && keyCode == 8 {
            Task { @MainActor in
                await self.handleCopyEvent()
            }
        }
        
        // Pass the event through
        return Unmanaged.passUnretained(event)
    }
    
    private func handleCopyEvent() async {
        // Small delay to ensure clipboard is updated
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Read clipboard content
        guard let content = readClipboardContent() else {
            return
        }
        
        let currentTime = Date()
        
        // Check if this is a double-copy
        if let lastContent = lastCopyContent,
           let lastTime = lastCopyTime,
           content == lastContent,
           currentTime.timeIntervalSince(lastTime) < self.timeWindow {
            // Double copy detected!
            Log.info("🔄 Double copy detected! Saving as collection item...", category: .general)
            await saveAsCollectionItem(content: content)
            
            // Reset state after saving
            lastCopyTime = nil
            lastCopyContent = nil
        } else {
            // Update state
            lastCopyTime = currentTime
            lastCopyContent = content
        }
    }
    
    // MARK: - Clipboard Reading
    
    private func readClipboardContent() -> ClipboardContent? {
        let pasteboard = NSPasteboard.general
        
        // Priority 1: Check for URL
        if let urlString = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string),
           let url = URL(string: urlString),
           (url.scheme == "http" || url.scheme == "https" || url.scheme == "file") {
            return .url(urlString)
        }
        
        // Priority 2: Check for plain text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .text(text)
        }
        
        // Priority 3: Check for image
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            // For images, we'll use a hash or just mark as image
            // Since we can't easily compare images, we'll save it directly
            return .image(image)
        }
        
        return nil
    }
    
    // MARK: - Save Logic
    
    private func saveAsCollectionItem(content: ClipboardContent) async {
        switch content {
        case .url(let urlString):
            await saveURL(urlString)
        case .text(let text):
            await saveText(text)
        case .image(let image):
            await saveImage(image)
        }
    }
    
    private func saveURL(_ urlString: String) async {
        // Check if URL already exists
        let existingBookmark = dataStorage.bookmarks.first { bookmark in
            bookmark.url.lowercased() == urlString.lowercased()
        }
        
        if existingBookmark != nil {
            Log.info("URL already exists, skipping: \(urlString.prefix(50))", category: .general)
            return
        }
        
        // Use PasteHandler to create bookmark
        await MainActor.run {
            // Create NSItemProvider from URL
            if let url = URL(string: urlString) {
                let provider = NSItemProvider(object: url as NSURL)
                pasteHandler.handlePaste(providers: [provider])
            }
        }
    }
    
    private func saveText(_ text: String) async {
        // Check if text already exists (exact match)
        let existingTextItem = dataStorage.items.first { item in
            if let textItem = item.asTextItem {
                return textItem.content == text
            }
            return false
        }
        
        if existingTextItem != nil {
            Log.info("Text already exists, skipping", category: .general)
            return
        }
        
        // Use PasteHandler to create text item
        await MainActor.run {
            let provider = NSItemProvider(object: text as NSString)
            pasteHandler.handlePaste(providers: [provider])
        }
    }
    
    private func saveImage(_ image: NSImage) async {
        // For images, create a provider that supports image type
        await MainActor.run {
            // Create NSItemProvider that can provide NSImage
            let provider = NSItemProvider()
            
            // Register the image object
            provider.registerObject(image, visibility: .all)
            
            // Also register data representation for better compatibility
            provider.registerDataRepresentation(forTypeIdentifier: UTType.image.identifier, visibility: .all) { completion in
                // Convert NSImage to PNG data
                guard let tiffData = image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    completion(nil, nil)
                    return nil
                }
                completion(pngData, nil)
                return nil
            }
            
            // Use PasteHandler to process
            pasteHandler.handlePaste(providers: [provider])
        }
    }
    
    // MARK: - Permission Management
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        // This will show system dialog requesting permission
    }
    
    deinit {
        // Clean up resources synchronously
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }
}

// MARK: - Clipboard Content

enum ClipboardContent: Equatable {
    case url(String)
    case text(String)
    case image(NSImage)
    
    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        switch (lhs, rhs) {
        case (.url(let lhsUrl), .url(let rhsUrl)):
            return lhsUrl.lowercased() == rhsUrl.lowercased()
        case (.text(let lhsText), .text(let rhsText)):
            return lhsText == rhsText
        case (.image, .image):
            // Images are considered equal if both are images
            // For simplicity, we'll just check type
            return true
        default:
            return false
        }
    }
}
