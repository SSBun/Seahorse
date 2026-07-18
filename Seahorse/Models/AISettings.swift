//
//  AISettings.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

@MainActor
class AISettings: ObservableObject {
    static let shared = AISettings()

    private static let agentProvidersKey = "ai_agent_providers"
    private static let selectedAgentProviderIDKey = "ai_selected_agent_provider_id"
    private static let selectedImageProviderIDKey = "ai_selected_image_provider_id"
    private static let codexImageModelKey = "ai_codex_image_model"

    private let agentProviderCredentials = AgentProviderCredentialStore()
    
    @Published var apiBaseURL: String {
        didSet {
            UserDefaults.standard.set(apiBaseURL, forKey: "ai_api_base_url")
        }
    }
    
    @Published var apiToken: String {
        didSet {
            UserDefaults.standard.set(apiToken, forKey: "ai_api_token")
        }
    }
    
    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: "ai_model")
        }
    }

    @Published private(set) var agentProviders: [AgentProviderProfile] {
        didSet {
            guard let data = try? JSONEncoder().encode(agentProviders) else { return }
            UserDefaults.standard.set(data, forKey: Self.agentProvidersKey)
        }
    }

    @Published private(set) var selectedAgentProviderID: String {
        didSet {
            UserDefaults.standard.set(selectedAgentProviderID, forKey: Self.selectedAgentProviderIDKey)
        }
    }

    @Published private(set) var selectedImageProviderID: String {
        didSet {
            UserDefaults.standard.set(selectedImageProviderID, forKey: Self.selectedImageProviderIDKey)
        }
    }

    @Published var additionalParsingInstructions: String {
        didSet {
            UserDefaults.standard.set(additionalParsingInstructions, forKey: "ai_additional_parsing_instructions")
        }
    }
    
    @Published var aiLanguage: AILanguage {
        didSet {
            UserDefaults.standard.set(aiLanguage.rawValue, forKey: "ai_language")
        }
    }

    @Published var imageModel: String {
        didSet {
            UserDefaults.standard.set(imageModel, forKey: "ai_image_model")
        }
    }

    @Published var codexImageModel: String {
        didSet {
            UserDefaults.standard.set(codexImageModel, forKey: Self.codexImageModelKey)
        }
    }

    @Published var autoParsingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoParsingEnabled, forKey: "ai_auto_parsing_enabled")
        }
    }

    @Published var autoParsingCreateTags: Bool {
        didSet {
            UserDefaults.standard.set(autoParsingCreateTags, forKey: "ai_auto_parsing_create_tags")
        }
    }
    
    private init() {
        // Load from UserDefaults or use defaults
        let apiBaseURL = UserDefaults.standard.string(forKey: "ai_api_base_url") ?? "https://api.openai.com/v1"
        let apiToken = UserDefaults.standard.string(forKey: "ai_api_token") ?? ""
        let model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-4o-mini"
        self.apiBaseURL = apiBaseURL
        self.apiToken = apiToken
        self.model = model

        let savedProviders = UserDefaults.standard.data(forKey: Self.agentProvidersKey)
            .flatMap { try? JSONDecoder().decode([AgentProviderProfile].self, from: $0) }
        var agentProviders = savedProviders ?? AgentProviderProfile.initialProfiles(
            apiBaseURL: apiBaseURL,
            model: model
        )
        if !agentProviders.contains(where: { $0.id == AgentProviderProfile.codexID }) {
            agentProviders.insert(.codex, at: 0)
        }

        let previousProvider = UserDefaults.standard.string(forKey: "ai_agent_provider")
        let migratedSelection = previousProvider == AgentProviderKind.openAICodex.rawValue
            ? AgentProviderProfile.codexID
            : AgentProviderProfile.legacyOpenAIID
        let savedSelection = UserDefaults.standard.string(forKey: Self.selectedAgentProviderIDKey)
        var selectedAgentProviderID = agentProviders.contains(where: { $0.id == savedSelection })
            ? savedSelection ?? migratedSelection
            : migratedSelection
        if !agentProviders.contains(where: { $0.id == selectedAgentProviderID }) {
            selectedAgentProviderID = agentProviders[0].id
        }
        self.agentProviders = agentProviders
        self.selectedAgentProviderID = selectedAgentProviderID

        let savedImageProviderID = UserDefaults.standard.string(forKey: Self.selectedImageProviderIDKey)
        let defaultImageProviderID = agentProviders.first(where: {
            $0.id == AgentProviderProfile.legacyOpenAIID && $0.kind.supportsImageGeneration
        })?.id ?? AgentProviderProfile.codexID
        if let savedImageProviderID, agentProviders.contains(where: {
            $0.id == savedImageProviderID && $0.kind.supportsImageGeneration
        }) {
            self.selectedImageProviderID = savedImageProviderID
        } else {
            self.selectedImageProviderID = defaultImageProviderID
        }

        self.imageModel = UserDefaults.standard.string(forKey: "ai_image_model") ?? "gpt-image-2"
        self.codexImageModel = UserDefaults.standard.string(forKey: Self.codexImageModelKey) ?? "gpt-5.4"
        
        self.additionalParsingInstructions = UserDefaults.standard.string(
            forKey: "ai_additional_parsing_instructions"
        ) ?? ""
        
        // Load AI Language or use English as default
        if let savedLanguage = UserDefaults.standard.string(forKey: "ai_language"),
           let language = AILanguage.allCases.first(where: { $0.rawValue == savedLanguage }) {
            self.aiLanguage = language
        } else {
            self.aiLanguage = .english
        }

        self.autoParsingEnabled = UserDefaults.standard.bool(forKey: "ai_auto_parsing_enabled")
        self.autoParsingCreateTags = UserDefaults.standard.object(forKey: "ai_auto_parsing_create_tags") as? Bool ?? true

        if
            savedProviders == nil,
            !apiToken.isEmpty,
            agentProviderCredentials.token(for: AgentProviderProfile.legacyOpenAIID) == nil
        {
            try? agentProviderCredentials.setToken(apiToken, for: AgentProviderProfile.legacyOpenAIID)
        }
        if let data = try? JSONEncoder().encode(agentProviders) {
            UserDefaults.standard.set(data, forKey: Self.agentProvidersKey)
        }
        UserDefaults.standard.set(selectedAgentProviderID, forKey: Self.selectedAgentProviderIDKey)
        UserDefaults.standard.set(selectedImageProviderID, forKey: Self.selectedImageProviderIDKey)
        UserDefaults.standard.removeObject(forKey: "ai_agent_provider")
    }

    /// The profile currently used by the bookmark Agent.
    ///
    /// - Complexity: O(n), where n is the number of saved providers.
    var selectedAgentProvider: AgentProviderProfile {
        agentProviders.first(where: { $0.id == selectedAgentProviderID }) ?? agentProviders[0]
    }

    /// Selects the provider used by the bookmark Agent.
    func selectAgentProvider(_ providerID: String) {
        guard agentProviders.contains(where: { $0.id == providerID }) else { return }
        selectedAgentProviderID = providerID
    }

    var imageGenerationProviders: [AgentProviderProfile] {
        agentProviders.filter { $0.kind.supportsImageGeneration }
    }

    var selectedImageProvider: AgentProviderProfile {
        imageGenerationProviders.first(where: { $0.id == selectedImageProviderID })
            ?? .codex
    }

    func selectImageProvider(_ providerID: String) {
        guard imageGenerationProviders.contains(where: { $0.id == providerID }) else { return }
        selectedImageProviderID = providerID
    }

    func updateCodexModel(_ model: String) {
        guard let index = agentProviders.firstIndex(where: { $0.id == AgentProviderProfile.codexID }) else {
            return
        }
        agentProviders[index].model = model
    }

    /// Returns the Keychain token associated with a compatible provider.
    func token(for providerID: String) -> String {
        agentProviderCredentials.token(for: providerID) ?? ""
    }

    /// Saves a compatible provider and selects it for the bookmark Agent.
    func saveAgentProvider(_ provider: AgentProviderProfile, token: String) throws {
        guard provider.kind != .openAICodex else { return }
        try agentProviderCredentials.setToken(token, for: provider.id)
        if let index = agentProviders.firstIndex(where: { $0.id == provider.id }) {
            agentProviders[index] = provider
        } else {
            agentProviders.append(provider)
        }
        selectedAgentProviderID = provider.id
    }

    /// Removes a compatible provider and its Keychain token.
    func removeAgentProvider(_ providerID: String) throws {
        guard
            let provider = agentProviders.first(where: { $0.id == providerID }),
            provider.kind != .openAICodex
        else {
            return
        }
        try agentProviderCredentials.removeToken(for: providerID)
        agentProviders.removeAll { $0.id == providerID }
        if selectedAgentProviderID == providerID {
            selectedAgentProviderID = agentProviders.first(where: { $0.kind != .openAICodex })?.id
                ?? AgentProviderProfile.codexID
        }
        if selectedImageProviderID == providerID {
            selectedImageProviderID = imageGenerationProviders.first?.id ?? AgentProviderProfile.codexID
        }
    }
}
