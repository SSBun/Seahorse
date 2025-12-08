//
//  SparkleUpdater.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/08.
//

import Foundation
import Sparkle

@MainActor
final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()
    
    private let controller: SPUStandardUpdaterController
    
    @Published var automaticallyChecksForUpdates: Bool
    @Published var automaticallyDownloadsUpdates: Bool
    
    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        let updater = controller.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }
    
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
    
    func setAutomaticallyChecks(_ value: Bool) {
        controller.updater.automaticallyChecksForUpdates = value
        automaticallyChecksForUpdates = value
    }
    
    func setAutomaticallyDownloads(_ value: Bool) {
        controller.updater.automaticallyDownloadsUpdates = value
        automaticallyDownloadsUpdates = value
    }
    
    var currentVersionDescription: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}

