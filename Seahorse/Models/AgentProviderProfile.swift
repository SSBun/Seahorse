import Foundation

/// A saved model endpoint that may be selected for the bookmark Agent.
struct AgentProviderProfile: Codable, Equatable, Identifiable, Sendable {
    static let codexID = "codex"
    static let legacyOpenAIID = "openai-compatible-default"

    let id: String
    var name: String
    var kind: AgentProviderKind
    var apiBaseURL: String
    var model: String

    static let codex = AgentProviderProfile(
        id: codexID,
        name: "Codex",
        kind: .openAICodex,
        apiBaseURL: "",
        model: "gpt-5.4-mini"
    )

    /// Creates a new editable compatible-provider profile.
    static func make(kind: AgentProviderKind) -> AgentProviderProfile {
        switch kind {
        case .openAICompatible:
            AgentProviderProfile(
                id: UUID().uuidString,
                name: kind.displayName,
                kind: kind,
                apiBaseURL: "https://api.openai.com/v1",
                model: "gpt-4o-mini"
            )
        case .claudeCompatible:
            AgentProviderProfile(
                id: UUID().uuidString,
                name: kind.displayName,
                kind: kind,
                apiBaseURL: "https://api.anthropic.com",
                model: "claude-sonnet-4-5"
            )
        case .openAICodex:
            codex
        }
    }

    /// Creates the initial profiles from the previous single OpenAI-compatible setting.
    static func initialProfiles(apiBaseURL: String, model: String) -> [AgentProviderProfile] {
        [
            codex,
            AgentProviderProfile(
                id: legacyOpenAIID,
                name: AgentProviderKind.openAICompatible.displayName,
                kind: .openAICompatible,
                apiBaseURL: apiBaseURL,
                model: model
            )
        ]
    }
}
