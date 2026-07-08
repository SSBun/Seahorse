#if os(macOS)
import Foundation

enum MCPServerStatus: String {
    case stopped = "Stopped"
    case running = "Running"
    case failed = "Failed"
    case portUnavailable = "Port unavailable"
}

@MainActor
final class MCPSettings: ObservableObject {
    static let shared = MCPSettings()

    static let mcpHost = "127.0.0.1"
    static let mcpPort = 17373
    static let bridgePort = 17374

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var status: MCPServerStatus = .stopped

    @Published private(set) var externalToken: String {
        didSet { defaults.set(externalToken, forKey: Keys.externalToken) }
    }

    @Published private(set) var internalToken: String {
        didSet { defaults.set(internalToken, forKey: Keys.internalToken) }
    }

    var mcpURL: String {
        "http://\(Self.mcpHost):\(Self.mcpPort)/mcp"
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "seahorse.mcp.enabled"
        static let externalToken = "seahorse.mcp.externalToken"
        static let internalToken = "seahorse.mcp.internalToken"
    }

    private init() {
        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        externalToken = defaults.string(forKey: Keys.externalToken) ?? Self.makeToken()
        internalToken = defaults.string(forKey: Keys.internalToken) ?? Self.makeToken()
        defaults.set(externalToken, forKey: Keys.externalToken)
        defaults.set(internalToken, forKey: Keys.internalToken)
    }

    func regenerateExternalToken() {
        externalToken = Self.makeToken()
    }

    func regenerateInternalTokenIfNeeded() {
        if internalToken.isEmpty {
            internalToken = Self.makeToken()
        }
    }

    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return UUID().uuidString + UUID().uuidString
    }
}
#endif
