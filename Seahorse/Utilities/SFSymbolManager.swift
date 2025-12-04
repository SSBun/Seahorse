//
//  SFSymbolManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

class SFSymbolManager {
    static let shared = SFSymbolManager()
    
    private init() {}
    
    // 50 most common and useful SF Symbols
    let allIcons: [String] = [
        // Links & Web
        "link.circle.fill", "globe", "network", "antenna.radiowaves.left.and.right",
        
        // Books & Reading
        "book.fill", "newspaper.fill", "doc.fill", "doc.text.fill", "magazine.fill",
        "books.vertical.fill", "text.book.closed.fill", "character.book.closed.fill",
        
        // Bookmarks & Organization
        "bookmark.fill", "tag.fill", "folder.fill", "archivebox.fill", "tray.fill",
        "pin.fill", "paperclip", "flag.fill",
        
        // Media & Entertainment
        "play.rectangle.fill", "tv.fill", "music.note", "film.fill", "photo.fill",
        "video.fill", "headphones", "mic.fill",
        
        // Social & Communication
        "message.fill", "envelope.fill", "phone.fill", "bubble.left.and.bubble.right.fill",
        
        // Development & Tech
        "chevron.left.forwardslash.chevron.right", "terminal.fill", "cpu", "server.rack",
        "app.badge.fill", "gearshape.fill", "hammer.fill", "wrench.and.screwdriver.fill",
        
        // Business & Work
        "briefcase.fill", "calendar", "clock.fill", "chart.bar.fill", "chart.pie.fill",
        
        // Personal & Life
        "person.fill", "house.fill", "heart.fill", "star.fill", "bell.fill",
        
        // Education & Learning
        "graduationcap.fill", "pencil", "paintbrush.fill", "lightbulb.fill",
        
        // Finance & Shopping
        "cart.fill", "creditcard.fill", "dollarsign.circle.fill", "bag.fill"
    ]
    
    // Categorized for better organization in picker
    func iconsByCategory() -> [String: [String]] {
        return [
            "Links & Web": [
                "link.circle.fill", "globe", "network", "antenna.radiowaves.left.and.right"
            ],
            "Books & Reading": [
                "book.fill", "newspaper.fill", "doc.fill", "doc.text.fill", "magazine.fill",
                "books.vertical.fill", "text.book.closed.fill", "character.book.closed.fill"
            ],
            "Organization": [
                "bookmark.fill", "tag.fill", "folder.fill", "archivebox.fill", "tray.fill",
                "pin.fill", "paperclip", "flag.fill"
            ],
            "Media": [
                "play.rectangle.fill", "tv.fill", "music.note", "film.fill", "photo.fill",
                "video.fill", "headphones", "mic.fill"
            ],
            "Communication": [
                "message.fill", "envelope.fill", "phone.fill", "bubble.left.and.bubble.right.fill"
            ],
            "Development": [
                "chevron.left.forwardslash.chevron.right", "terminal.fill", "cpu", "server.rack",
                "app.badge.fill", "gearshape.fill", "hammer.fill", "wrench.and.screwdriver.fill"
            ],
            "Business": [
                "briefcase.fill", "calendar", "clock.fill", "chart.bar.fill", "chart.pie.fill"
            ],
            "Personal": [
                "person.fill", "house.fill", "heart.fill", "star.fill", "bell.fill"
            ],
            "Education": [
                "graduationcap.fill", "pencil", "paintbrush.fill", "lightbulb.fill"
            ],
            "Shopping": [
                "cart.fill", "creditcard.fill", "dollarsign.circle.fill", "bag.fill"
            ]
        ]
    }
    
    // Get a random icon (useful for defaults)
    func randomIcon() -> String {
        allIcons.randomElement() ?? "link.circle.fill"
    }
    
    // Check if a string is a valid SF Symbol
    func isValidSymbol(_ name: String) -> Bool {
        allIcons.contains(name)
    }
}

