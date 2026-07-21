//
//  UpdateManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/12.
//

#if os(macOS)
import Foundation
import Sparkle

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Starts Sparkle's standard update check, download, and installation flow.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#endif
