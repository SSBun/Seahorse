//
//  LocalizationHelper.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

/// Helper for accessing localized strings
struct L10n {
    // MARK: - Common
    static let add = NSLocalizedString("Add", comment: "Add button")
    static let cancel = NSLocalizedString("Cancel", comment: "Cancel button")
    static let delete = NSLocalizedString("Delete", comment: "Delete button")
    static let edit = NSLocalizedString("Edit", comment: "Edit button")
    static let ok = NSLocalizedString("OK", comment: "OK button")
    static let save = NSLocalizedString("Save Changes", comment: "Save changes button")
    static let reset = NSLocalizedString("Reset", comment: "Reset button")
    static let export = NSLocalizedString("Export", comment: "Export button")
    static let `import` = NSLocalizedString("Import", comment: "Import button")
    
    // MARK: - Bookmark
    static let addBookmark = NSLocalizedString("Add Bookmark", comment: "Add bookmark title")
    static let allBookmarks = NSLocalizedString("All Bookmarks", comment: "All bookmarks category")
    static let favorites = NSLocalizedString("Favorites", comment: "Favorites category")
    static let aiParsed = NSLocalizedString("AI Parsed", comment: "AI parsed badge")
    
    // MARK: - Tabs
    static let basic = NSLocalizedString("Basic", comment: "Basic settings tab")
    static let category = NSLocalizedString("Category", comment: "Category tab")
    static let tag = NSLocalizedString("Tag", comment: "Tag tab")
    static let tags = NSLocalizedString("Tags", comment: "Tags section")
    
    // MARK: - Settings
    static let appLanguage = NSLocalizedString("App Language", comment: "App language setting")
    static let appLanguageHint = NSLocalizedString("App language will take effect after restart", comment: "App language hint")
    static let aiParsingLanguage = NSLocalizedString("AI Parsing Language", comment: "AI parsing language setting")
    static let aiParsingLanguageHint = NSLocalizedString("AI will generate summaries and suggestions in this language", comment: "AI parsing language hint")
    static let primaryColor = NSLocalizedString("Primary Color", comment: "Primary color setting")
    static let appearance = NSLocalizedString("Appearance", comment: "Appearance setting")
    static let cardStyle = NSLocalizedString("Card Style", comment: "Card style setting")
    static let preferenceFolder = NSLocalizedString("Data Folder", comment: "Data folder setting")
    static let changeDots = NSLocalizedString("Change...", comment: "Change button with dots")
    static let resetToDefaultLocation = NSLocalizedString("Reset to default location", comment: "Reset to default location tooltip")
    static let storeBookmarksHint = NSLocalizedString("Store all data (bookmarks, images, settings) in this location", comment: "Store data hint")
    static let dataManagement = NSLocalizedString("Data Management", comment: "Data management section")
    static let exportHint = NSLocalizedString("Export creates a folder with the same structure as Preference Folder. You can use this for migration or backup.", comment: "Export hint")
    
    // MARK: - Preview
    static let title = NSLocalizedString("Title", comment: "Title label")
    static let url = NSLocalizedString("URL", comment: "URL label")
    static let summary = NSLocalizedString("Summary", comment: "Summary label")
    static let added = NSLocalizedString("Added", comment: "Added date label")
    static let openInBrowser = NSLocalizedString("Open in Browser", comment: "Open in browser button")
    static let copyURL = NSLocalizedString("Copy URL", comment: "Copy URL button")
    static let openURL = NSLocalizedString("Open URL", comment: "Open URL menu item")
    
    // MARK: - Alerts
    static let restartRequired = NSLocalizedString("Restart Required", comment: "Restart required alert title")
    static let restartMessage = NSLocalizedString("The app language change will take effect after you restart Seahorse.", comment: "Restart required message")
    
    // MARK: - Diagnostic
    static let checkBrokenBookmarks = NSLocalizedString("Check for Broken Bookmarks", comment: "Check for broken bookmarks tooltip")
    static let viewDiagnosticProgress = NSLocalizedString("View Diagnostic Progress", comment: "View diagnostic progress tooltip")
}

