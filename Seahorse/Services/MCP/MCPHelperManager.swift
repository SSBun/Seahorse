#if os(macOS)
import Foundation
import AppKit

@MainActor
final class MCPHelperManager: ObservableObject {
    static let shared = MCPHelperManager()

    private let settings = MCPSettings.shared
    private let bridgeServer = MCPBridgeServer.shared
    private var helperProcess: Process?
    private var restartAttempts = 0
    private var intentionalStop = false

    private init() {}

    func startIfNeeded() {
        if settings.isEnabled {
            start()
        }
    }

    func start() {
        guard helperProcess == nil else { return }
        settings.regenerateInternalTokenIfNeeded()
        intentionalStop = false

        guard let helperScriptURL else {
            settings.status = .failed
            return
        }

        do {
            try bridgeServer.start()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", helperScriptURL.path]
            process.environment = helperEnvironment()
            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    self?.handleHelperExit(process.terminationStatus)
                }
            }
            try process.run()

            helperProcess = process
            settings.status = .running
        } catch {
            bridgeServer.stop()
            helperProcess = nil
            settings.status = .portUnavailable
        }
    }

    func stop() {
        intentionalStop = true
        restartAttempts = 0
        helperProcess?.terminate()
        helperProcess = nil
        bridgeServer.stop()
        settings.status = .stopped
    }

    func restart() {
        stop()
        if settings.isEnabled {
            start()
        }
    }

    private func handleHelperExit(_ status: Int32) {
        helperProcess = nil
        guard !intentionalStop, settings.isEnabled else { return }

        if restartAttempts == 0 {
            restartAttempts += 1
            start()
        } else {
            bridgeServer.stop()
            settings.status = .failed
        }
    }

    private func helperEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SEAHORSE_MCP_TOKEN"] = settings.externalToken
        environment["SEAHORSE_BRIDGE_TOKEN"] = settings.internalToken
        environment["SEAHORSE_BRIDGE_URL"] = "http://\(MCPSettings.mcpHost):\(MCPSettings.bridgePort)"
        environment["SEAHORSE_MCP_PORT"] = "\(MCPSettings.mcpPort)"
        return environment
    }

    private var helperScriptURL: URL? {
        let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("MCPHelper", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.js")
        if let bundled, FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let development = repoRoot
            .appendingPathComponent("MCPHelper", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.js")
        if FileManager.default.fileExists(atPath: development.path) {
            return development
        }

        return nil
    }
}
#endif
