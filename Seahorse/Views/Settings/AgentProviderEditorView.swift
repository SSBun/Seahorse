#if os(macOS)
import SwiftUI

/// Edits one compatible Agent provider without exposing its token to persistence.
struct AgentProviderEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var provider: AgentProviderProfile
    @State private var token: String
    @State private var errorMessage = ""

    private let onSave: (AgentProviderProfile, String) throws -> Void

    init(
        provider: AgentProviderProfile,
        token: String,
        onSave: @escaping (AgentProviderProfile, String) throws -> Void
    ) {
        _provider = State(initialValue: provider)
        _token = State(initialValue: token)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            LabeledContent("Type", value: provider.kind.displayName)

            TextField("Name", text: $provider.name)
            TextField("API Base URL", text: $provider.apiBaseURL)
            SecureField("API Token", text: $token)
            TextField("Model", text: $provider.model)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .navigationTitle(provider.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
    }

    private func save() {
        provider.name = provider.name.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.apiBaseURL = provider.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.model = provider.model.trimmingCharacters(in: .whitespacesAndNewlines)
        token = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !provider.name.isEmpty else {
            errorMessage = "Enter a provider name."
            return
        }
        guard
            let url = URL(string: provider.apiBaseURL),
            url.scheme != nil,
            url.host != nil
        else {
            errorMessage = "Enter a valid API Base URL."
            return
        }
        guard !token.isEmpty else {
            errorMessage = "Enter an API token."
            return
        }
        guard !provider.model.isEmpty else {
            errorMessage = "Enter a model name."
            return
        }

        do {
            try onSave(provider, token)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
