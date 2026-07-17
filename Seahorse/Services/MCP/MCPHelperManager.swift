#if os(macOS)
import Foundation
import AppKit
import Darwin

@MainActor
final class MCPHelperManager: ObservableObject {
    static let shared = MCPHelperManager()

    private let settings = MCPSettings.shared
    private let bridgeServer = MCPBridgeServer.shared
    private var helperProcess: Process?
    private var restartAttempts = 0
    private var intentionalStop = false

    private init() {}

    nonisolated static func matchingHelperProcessIDs(
        in processList: String,
        helperScriptPath: String
    ) -> [Int32] {
        let bundledNodePath = URL(fileURLWithPath: helperScriptPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("node")
            .path
        let helperCommands = [
            "node \(helperScriptPath)",
            "\(bundledNodePath) \(helperScriptPath)"
        ]

        return processList.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard
                parts.count == 2,
                let processID = Int32(parts[0]),
                helperCommands.contains(parts[1].trimmingCharacters(in: .whitespaces))
            else {
                return nil
            }
            return processID
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
            if let bundledNodeURL {
                process.executableURL = bundledNodeURL
                process.arguments = [helperScriptURL.path]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["node", helperScriptURL.path]
            }
            process.environment = helperEnvironment()
            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    self?.handleHelperExit(process)
                }
            }
            helperProcess = process
            try process.run()

            settings.status = settings.isEnabled ? .running : .stopped
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
        Task {
            await forceRestart()
        }
    }

    func forceRestart() async {
        guard settings.status != .restarting else { return }
        guard let helperScriptURL else {
            settings.status = .failed
            return
        }

        settings.status = .restarting
        intentionalStop = true
        restartAttempts = 0

        if let process = helperProcess {
            helperProcess = nil
            await terminate(process)
        }
        bridgeServer.stop()

        let processList = await Task.detached(priority: .userInitiated) {
            Self.loadProcessList()
        }.value
        let staleProcessIDs = Self.matchingHelperProcessIDs(
            in: processList,
            helperScriptPath: helperScriptURL.path
        )
        for processID in staleProcessIDs {
            await terminate(processID)
        }

        intentionalStop = false
        start()
    }

    private func handleHelperExit(_ process: Process) {
        guard helperProcess === process else { return }
        helperProcess = nil
        guard !intentionalStop else { return }

        if restartAttempts == 0 {
            restartAttempts += 1
            start()
        } else {
            bridgeServer.stop()
            settings.status = .failed
        }
    }

    private func terminate(_ process: Process) async {
        guard process.isRunning else { return }
        process.terminate()
        if await waitForExit(of: process) { return }

        kill(process.processIdentifier, SIGKILL)
        _ = await waitForExit(of: process)
    }

    private func terminate(_ processID: Int32) async {
        guard processExists(processID) else { return }
        kill(processID, SIGTERM)
        if await waitForExit(of: processID) { return }

        kill(processID, SIGKILL)
        _ = await waitForExit(of: processID)
    }

    private func waitForExit(of process: Process) async -> Bool {
        for _ in 0..<20 {
            if !process.isRunning { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !process.isRunning
    }

    private func waitForExit(of processID: Int32) async -> Bool {
        for _ in 0..<20 {
            if !processExists(processID) { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !processExists(processID)
    }

    private func processExists(_ processID: Int32) -> Bool {
        if kill(processID, 0) == 0 { return true }
        return errno == EPERM
    }

    private nonisolated static func loadProcessList() -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axww", "-o", "pid=,command="]
        process.standardOutput = output

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func helperEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SEAHORSE_MCP_TOKEN"] = settings.externalToken
        environment["SEAHORSE_BRIDGE_TOKEN"] = settings.internalToken
        environment["SEAHORSE_BRIDGE_URL"] = "http://\(MCPSettings.mcpHost):\(MCPSettings.bridgePort)"
        environment["SEAHORSE_MCP_PORT"] = "\(MCPSettings.mcpPort)"
        environment["SEAHORSE_MCP_ENABLED"] = settings.isEnabled ? "true" : "false"
        environment["SEAHORSE_CODEX_AUTH_PATH"] = codexAuthURL.path
        return environment
    }

    private var codexAuthURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Seahorse", directoryHint: .isDirectory)
            .appending(path: "Codex", directoryHint: .isDirectory)
            .appending(path: "auth.json")
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

    private var bundledNodeURL: URL? {
        let nodeURL = Bundle.main.resourceURL?
            .appendingPathComponent("MCPHelper", isDirectory: true)
            .appendingPathComponent("node")
        guard let nodeURL, FileManager.default.isExecutableFile(atPath: nodeURL.path) else {
            return nil
        }
        return nodeURL
    }
}
#endif
