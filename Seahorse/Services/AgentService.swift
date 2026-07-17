#if os(macOS)

import Foundation

struct AgentSearchResponse: Codable, Equatable {
    let answer: String
    let bookmarkIDs: [UUID]

    private enum CodingKeys: String, CodingKey {
        case answer
        case bookmarkIDs = "bookmarkIds"
    }
}

struct AgentServiceConfiguration: Sendable {
    let endpoint: URL
    let internalToken: String
    let provider: AgentProviderKind
    let apiToken: String?
    let apiBaseURL: String?
    let model: String

    init(
        endpoint: URL,
        internalToken: String,
        provider: AgentProviderKind = .openAICompatible,
        apiToken: String? = nil,
        apiBaseURL: String? = nil,
        model: String
    ) {
        self.endpoint = endpoint
        self.internalToken = internalToken
        self.provider = provider
        self.apiToken = apiToken
        self.apiBaseURL = apiBaseURL
        self.model = model
    }
}

enum CodexConnectionState: String, Decodable {
    case disconnected
    case connecting
    case connected
    case failed
}

struct CodexConnectionStatus: Decodable, Equatable {
    let state: CodexConnectionState
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case state = "status"
        case error
    }
}

struct CodexModelDescriptor: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let supportsImageGeneration: Bool
}

enum AgentServiceError: LocalizedError {
    case invalidResponse
    case helper(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The Agent helper returned an invalid response."
        case .helper(let message):
            message
        }
    }
}

actor AgentService {
    typealias ConfigurationProvider = @Sendable () async throws -> AgentServiceConfiguration
    private typealias HelperConfigurationProvider = @Sendable () async throws -> AgentHelperConfiguration

    private let session: URLSession
    private let configurationProvider: ConfigurationProvider
    private let helperConfigurationProvider: HelperConfigurationProvider

    init(session: URLSession = .shared) {
        self.session = session
        configurationProvider = {
            try await AgentService.liveConfiguration()
        }
        helperConfigurationProvider = {
            try await AgentService.liveHelperConfiguration()
        }
    }

    init(session: URLSession, configurationProvider: @escaping ConfigurationProvider) {
        self.session = session
        self.configurationProvider = configurationProvider
        helperConfigurationProvider = {
            let configuration = try await configurationProvider()
            return AgentHelperConfiguration(
                endpoint: configuration.endpoint,
                internalToken: configuration.internalToken
            )
        }
    }

    func send(_ message: String, to sessionID: UUID) async throws -> AgentSearchResponse {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            return AgentSearchResponse(answer: "Ask me what bookmarks you want to find.", bookmarkIDs: [])
        }

        let configuration = try await configurationProvider()
        let body = AgentPromptRequest(
            sessionID: sessionID,
            message: trimmedMessage,
            configuration: configuration
        )
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.internalToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(AgentErrorResponse.self, from: data)
            throw AgentServiceError.helper(error?.error ?? "Agent helper failed with HTTP \(httpResponse.statusCode).")
        }
        return try JSONDecoder().decode(AgentSearchResponse.self, from: data)
    }

    func codexConnectionStatus() async throws -> CodexConnectionStatus {
        try await codexRequest(method: "GET", response: CodexConnectionStatus.self)
    }

    func startCodexConnection() async throws -> URL {
        let response = try await codexRequest(method: "POST", response: CodexStartResponse.self)
        return response.authorizationURL
    }

    func disconnectCodex() async throws {
        let _: CodexConnectionStatus = try await codexRequest(
            method: "DELETE",
            response: CodexConnectionStatus.self
        )
    }

    func codexModels() async throws -> [CodexModelDescriptor] {
        try await codexRequest(
            method: "GET",
            path: "agent/providers/codex/models",
            response: [CodexModelDescriptor].self
        )
    }

    func generateCodexImage(
        prompt: String,
        model: String,
        referenceImageData: Data? = nil
    ) async throws -> Data {
        let body = try JSONEncoder().encode(CodexImageRequest(
            model: model,
            prompt: prompt,
            referenceImageBase64: referenceImageData?.base64EncodedString()
        ))
        let response = try await codexRequest(
            method: "POST",
            path: "agent/images/codex",
            body: body,
            response: CodexImageResponse.self
        )
        guard
            let data = Data(base64Encoded: response.imageBase64, options: [.ignoreUnknownCharacters]),
            !data.isEmpty
        else {
            throw AgentServiceError.invalidResponse
        }
        return data
    }

    private func codexRequest<Response: Decodable>(
        method: String,
        path: String = "agent/auth/codex",
        body: Data? = nil,
        response: Response.Type
    ) async throws -> Response {
        let configuration = try await helperConfigurationProvider()
        let endpoint = configuration.endpoint
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        if path == "agent/images/codex" {
            request.timeoutInterval = 330
        }
        request.httpMethod = method
        request.httpBody = body
        request.setValue(
            "Bearer \(configuration.internalToken)",
            forHTTPHeaderField: "Authorization"
        )
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, urlResponse) = try await session.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AgentServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(AgentErrorResponse.self, from: data)
            throw AgentServiceError.helper(
                error?.error ?? "Codex connection failed with HTTP \(httpResponse.statusCode)."
            )
        }
        return try JSONDecoder().decode(response, from: data)
    }

    private static func liveConfiguration() async throws -> AgentServiceConfiguration {
        let helper = try await liveHelperConfiguration()
        return try await MainActor.run {
            let aiSettings = AISettings.shared
            let provider = aiSettings.selectedAgentProvider
            switch provider.kind {
            case .openAICodex:
                return AgentServiceConfiguration(
                    endpoint: helper.endpoint,
                    internalToken: helper.internalToken,
                    provider: .openAICodex,
                    model: provider.model
                )
            case .openAICompatible, .claudeCompatible:
                break
            }

            let apiToken = aiSettings.token(for: provider.id)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiToken.isEmpty else {
                throw AIError.missingAPIKey
            }

            let apiBaseURL = provider.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiBaseURL.isEmpty else {
                throw AIError.missingBaseURL
            }
            guard let baseURL = URL(string: apiBaseURL), baseURL.scheme != nil, baseURL.host != nil else {
                throw AIError.invalidURL(apiBaseURL)
            }

            let model = provider.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty else {
                throw AgentServiceError.helper("AI model is not configured. Please set it in Settings > AI.")
            }
            return AgentServiceConfiguration(
                endpoint: helper.endpoint,
                internalToken: helper.internalToken,
                provider: provider.kind,
                apiToken: apiToken,
                apiBaseURL: baseURL.absoluteString,
                model: model
            )
        }
    }

    private static func liveHelperConfiguration() async throws -> AgentHelperConfiguration {
        return try await MainActor.run {
            MCPHelperManager.shared.start()
            guard let endpoint = URL(
                string: "http://\(MCPSettings.mcpHost):\(MCPSettings.mcpPort)/agent"
            ) else {
                throw AgentServiceError.invalidResponse
            }
            return AgentHelperConfiguration(
                endpoint: endpoint,
                internalToken: MCPSettings.shared.internalToken
            )
        }
    }
}

private struct AgentHelperConfiguration: Sendable {
    let endpoint: URL
    let internalToken: String
}

private struct AgentPromptRequest: Encodable {
    let sessionId: String
    let message: String
    let configuration: AgentAPIConfiguration

    init(sessionID: UUID, message: String, configuration: AgentServiceConfiguration) {
        sessionId = sessionID.uuidString
        self.message = message
        self.configuration = AgentAPIConfiguration(
            provider: configuration.provider.rawValue,
            apiToken: configuration.apiToken,
            apiBaseURL: configuration.apiBaseURL,
            model: configuration.model
        )
    }
}

private struct AgentAPIConfiguration: Encodable {
    let provider: String
    let apiToken: String?
    let apiBaseURL: String?
    let model: String
}

private struct CodexStartResponse: Decodable {
    let authorizationURL: URL
}

private struct CodexImageRequest: Encodable {
    let model: String
    let prompt: String
    let referenceImageBase64: String?
}

private struct CodexImageResponse: Decodable {
    let imageBase64: String
}

private struct AgentErrorResponse: Decodable {
    let error: String
}

#endif
