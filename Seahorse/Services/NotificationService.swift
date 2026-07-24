//
//  NotificationService.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/04.
//

import Foundation
import UserNotifications
import OSLog
import SwiftUI

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaultsKey = "enableSystemNotifications"
    
    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            objectWillChange.send()
            if newValue {
                requestAuthorization()
            }
        }
    }
    
    override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Log.error("Failed to request notification authorization: \(error)", category: .general)
            } else if !granted {
                Log.warning("Notification authorization denied", category: .general)
                // Disable the setting if user denied permission
                DispatchQueue.main.async {
                    self.isEnabled = false
                }
            }
        }
    }
    
    func showItemSavedNotification(itemType: String, title: String) {
        showNotification(
            title: "Item Saved",
            body: "\(itemType): \(title)",
            categoryIdentifier: "ITEM_SAVED"
        )
    }

    private func showNotification(title: String, body: String, categoryIdentifier: String) {
        guard isEnabled else { return }
        
        // Check authorization status
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                // Request authorization if not yet authorized
                DispatchQueue.main.async {
                    self.requestAuthorization()
                }
                return
            }
            
            // Check alert style - if set to "Notification Center only", we can't show banners
            // But willPresent delegate should still be called when app is in foreground
            Log.info("Notification alert style: \(settings.alertStyle.rawValue)", category: .general)
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            
            // Create notification request
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Show immediately
            )
            
            // Add notification
            self.notificationCenter.add(request) { error in
                if let error = error {
                    Log.error("Failed to show notification: \(error)", category: .general)
                } else {
                    Log.info("Notification sent: \(title)", category: .general)
                }
            }
        }
    }
    
    private func getItemTypeName(for item: AnyCollectionItem) -> String {
        if item.asBookmark != nil {
            return "Bookmark"
        } else if item.asImageItem != nil {
            return "Image"
        } else if item.asTextItem != nil {
            return "Note"
        }
        return "Item"
    }
    
    private func getItemTitle(for item: AnyCollectionItem) -> String {
        if let bookmark = item.asBookmark {
            let trimmedTitle = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
            // Avoid showing placeholder titles in notifications
            if !trimmedTitle.isEmpty && trimmedTitle.lowercased() != "loading..." {
                return trimmedTitle
            }
            
            // Fallback to domain or full URL
            let normalizedURLString = BookmarkURLNormalizer.normalize(bookmark.url)
            if let url = URL(string: normalizedURLString), let host = url.host, !host.isEmpty {
                return host
            }
            return normalizedURLString.isEmpty ? bookmark.url : normalizedURLString
        } else if let imageItem = item.asImageItem {
            // Extract filename from path or use a default
            if let url = URL(string: imageItem.imagePath) {
                return url.lastPathComponent.isEmpty ? "Image" : url.lastPathComponent
            }
            return "Image"
        } else if let textItem = item.asTextItem {
            // Use first line or first 50 characters
            let firstLine = textItem.firstLine
            let candidate = firstLine.prefix(51)
            return candidate.count > 50 ? String(candidate.prefix(50)) + "..." : String(candidate)
        }
        return "Item"
    }
    
    func showNotification(for item: AnyCollectionItem) {
        let itemType = getItemTypeName(for: item)
        let title = getItemTitle(for: item)
        showItemSavedNotification(itemType: itemType, title: title)
    }

    func showBookmarkAlreadyCollectedNotification(for item: AnyCollectionItem) {
        showNotification(
            title: "Bookmark Already Collected",
            body: "\(getItemTitle(for: item)) is already in your collection.",
            categoryIdentifier: "BOOKMARK_ALREADY_COLLECTED"
        )
    }

    func showBookmarkRefreshedNotification(for item: AnyCollectionItem) {
        showNotification(
            title: "Bookmark Collected Again",
            body: "Moved \(getItemTitle(for: item)) to the top by updating its added time.",
            categoryIdentifier: "BOOKMARK_REFRESHED"
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Log.info("willPresent notification called - showing as banner", category: .general)
        
        // Show notification as banner (floating at top right) with sound
        // .banner = transient notification that auto-dismisses (floating banner)
        // .list = also adds to notification center
        // .sound = play sound
        // .badge = update app badge
        #if os(macOS)
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
        #else
        completionHandler([.banner, .sound])
        #endif
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed
        completionHandler()
    }
}
