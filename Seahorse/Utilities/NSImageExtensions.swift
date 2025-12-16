//
//  NSImageExtensions.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/02.
//  Performance optimization: Image thumbnail generation
//

import AppKit

extension NSImage {
    /// Resizes the image to the specified size, maintaining aspect ratio
    /// - Parameter size: Target size for the resized image
    /// - Returns: A new NSImage resized to the target size
    func resized(to size: CGSize) -> NSImage {
        // If image is already smaller than target, return original
        if self.size.width <= size.width && self.size.height <= size.height {
            return self
        }
        
        let resized = NSImage(size: size)
        resized.lockFocus()
        
        // Calculate aspect ratio to maintain proportions
        let aspectRatio = self.size.width / self.size.height
        var drawSize = size
        
        if aspectRatio > 1 {
            // Landscape: fit width
            drawSize.height = size.width / aspectRatio
        } else {
            // Portrait: fit height
            drawSize.width = size.height * aspectRatio
        }
        
        // Center the image
        let drawRect = NSRect(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        
        self.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: self.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        
        resized.unlockFocus()
        return resized
    }
}
