import Foundation

/// A model API protocol supported by the bookmark Agent.
enum AgentProviderKind: String, Codable, CaseIterable, Sendable {
    /// Uses the ChatGPT subscription OAuth flow and Codex Responses API.
    case openAICodex = "openai-codex"

    /// Uses an OpenAI-compatible Chat Completions endpoint.
    case openAICompatible = "openai-compatible"

    /// Uses an Anthropic-compatible Messages endpoint.
    case claudeCompatible = "claude-compatible"

    static let configurableKinds: [AgentProviderKind] = [
        .openAICompatible,
        .claudeCompatible
    ]

    var displayName: String {
        switch self {
        case .openAICodex:
            "Codex"
        case .openAICompatible:
            "OpenAI Compatible"
        case .claudeCompatible:
            "Claude Compatible"
        }
    }

    var supportsImageGeneration: Bool {
        self != .claudeCompatible
    }
}
