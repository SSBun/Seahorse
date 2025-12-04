//
//  MainWindowDelegate.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/04.
//

import AppKit

class MainWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of closing it
        sender.orderOut(nil)
        
        // Switch to accessory mode (hide Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Return false to prevent the actual close event (which might destroy the window)
        return false
    }
}
