#if os(macOS)
import SwiftUI

/// Manages the saved model providers used by the bookmark Agent.
struct AgentProvidersSettingsView: View {
    @StateObject private var settings = AISettings.shared
    @State private var codexStatus = CodexConnectionStatus(state: .disconnected, error: nil)
    @State private var codexModels: [CodexModelDescriptor] = []
    @State private var isConnectingCodex = false
    @State private var codexModelPicker: CodexModelPickerPurpose?
    @State private var editingProvider: AgentProviderProfile?
    @State private var editingToken = ""
    @State private var providerPendingDeletion: AgentProviderProfile?
    @State private var isConfirmingDeletion = false
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @State private var codexConnectionTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Agent Providers")
                    .font(.headline)

                Spacer()

                Menu("Add Provider", systemImage: "plus") {
                    ForEach(AgentProviderKind.configurableKinds, id: \.self) { kind in
                        Button(kind.displayName) {
                            addProvider(kind)
                        }
                    }
                }
            }

            ForEach(settings.agentProviders) { provider in
                HStack(spacing: 10) {
                    Button {
                        settings.selectAgentProvider(provider.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName: settings.selectedAgentProviderID == provider.id
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                settings.selectedAgentProviderID == provider.id
                                    ? Color.accentColor
                                    : Color.secondary
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.body)
                                Text(providerSubtitle(provider))
                                    .font(.caption)
                                    .foregroundStyle(providerSubtitleColor(provider))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(provider.kind == .openAICodex && codexStatus.state != .connected)

                    if provider.kind == .openAICodex {
                        VStack(alignment: .trailing, spacing: 4) {
                            Button("Agent: \(provider.model)") {
                                codexModelPicker = .agent
                            }
                            Button("Image: \(settings.codexImageModel)") {
                                codexModelPicker = .image
                            }
                        }
                        .disabled(codexModels.isEmpty)

                        if isConnectingCodex {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Connecting Codex")
                        }
                        Button(
                            codexStatus.state == .connected ? "Disconnect" : "Connect",
                            action: codexStatus.state == .connected ? disconnectCodex : connectCodex
                        )
                        .disabled(isConnectingCodex)
                    } else {
                        Menu("Provider Actions", systemImage: "ellipsis.circle") {
                            Button("Edit", systemImage: "pencil") {
                                editProvider(provider)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                providerPendingDeletion = provider
                                isConfirmingDeletion = true
                            }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 8))
            }

            Text("The selected provider powers the bookmark Agent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            await refreshCodexStatus()
            await refreshCodexModels()
        }
        .onDisappear {
            codexConnectionTask?.cancel()
        }
        .sheet(item: $editingProvider) { provider in
            NavigationStack {
                AgentProviderEditorView(
                    provider: provider,
                    token: editingToken,
                    onSave: settings.saveAgentProvider
                )
            }
        }
        .sheet(item: $codexModelPicker) { purpose in
            CodexModelPickerView(
                models: purpose == .image
                    ? codexModels.filter(\.supportsImageGeneration)
                    : codexModels,
                selectedModelID: purpose == .image
                    ? settings.codexImageModel
                    : settings.agentProviders.first(where: {
                        $0.id == AgentProviderProfile.codexID
                    })?.model ?? "",
                onSelect: { model in
                    if purpose == .image {
                        settings.codexImageModel = model.id
                    } else {
                        settings.updateCodexModel(model.id)
                    }
                    codexModelPicker = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Provider?",
            isPresented: $isConfirmingDeletion,
            presenting: providerPendingDeletion
        ) { provider in
            Button("Delete \(provider.name)", role: .destructive) {
                deleteProvider(provider)
            }
        } message: { provider in
            Text("This removes \(provider.name) and its saved API token.")
        }
        .onChange(of: isConfirmingDeletion) { _, isPresented in
            if !isPresented {
                providerPendingDeletion = nil
            }
        }
        .alert("Agent Providers", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func providerSubtitle(_ provider: AgentProviderProfile) -> String {
        if provider.kind != .openAICodex {
            return "\(provider.kind.displayName) · \(provider.model)"
        }
        switch codexStatus.state {
        case .connected:
            return "Connected · \(provider.model)"
        case .connecting:
            return "Waiting for browser sign-in"
        case .failed:
            return codexStatus.error ?? "Connection failed"
        case .disconnected:
            return "Not connected"
        }
    }

    private func providerSubtitleColor(_ provider: AgentProviderProfile) -> Color {
        guard provider.kind == .openAICodex else { return .secondary }
        switch codexStatus.state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .failed:
            return .red
        case .disconnected:
            return .secondary
        }
    }

    private func addProvider(_ kind: AgentProviderKind) {
        editingToken = ""
        editingProvider = .make(kind: kind)
    }

    private func editProvider(_ provider: AgentProviderProfile) {
        editingToken = settings.token(for: provider.id)
        editingProvider = provider
    }

    private func deleteProvider(_ provider: AgentProviderProfile) {
        do {
            try settings.removeAgentProvider(provider.id)
        } catch {
            showAlert(error.localizedDescription)
        }
        providerPendingDeletion = nil
    }

    private func connectCodex() {
        codexConnectionTask?.cancel()
        isConnectingCodex = true
        codexStatus = CodexConnectionStatus(state: .connecting, error: nil)
        codexConnectionTask = Task {
            defer { isConnectingCodex = false }
            do {
                let service = AgentService()
                let authorizationURL = try await service.startCodexConnection()
                guard NSWorkspace.shared.open(authorizationURL) else {
                    throw AgentServiceError.helper("Could not open the Codex sign-in page.")
                }

                for _ in 0..<600 {
                    try await Task.sleep(for: .milliseconds(500))
                    codexStatus = try await service.codexConnectionStatus()
                    switch codexStatus.state {
                    case .connected:
                        settings.selectAgentProvider(AgentProviderProfile.codexID)
                        showAlert("Codex is connected and selected for the bookmark Agent.")
                        return
                    case .failed:
                        throw AgentServiceError.helper(codexStatus.error ?? "Codex sign-in failed.")
                    case .connecting, .disconnected:
                        continue
                    }
                }
                throw AgentServiceError.helper("Codex sign-in timed out. Please try again.")
            } catch is CancellationError {
                return
            } catch {
                codexStatus = CodexConnectionStatus(state: .failed, error: error.localizedDescription)
                showAlert(error.localizedDescription)
            }
        }
    }

    private func disconnectCodex() {
        codexConnectionTask?.cancel()
        isConnectingCodex = true
        codexConnectionTask = Task {
            defer { isConnectingCodex = false }
            do {
                try await AgentService().disconnectCodex()
                codexStatus = CodexConnectionStatus(state: .disconnected, error: nil)
                selectFallbackProvidersAfterCodexDisconnect()
            } catch {
                showAlert(error.localizedDescription)
            }
        }
    }

    private func refreshCodexStatus() async {
        do {
            codexStatus = try await AgentService().codexConnectionStatus()
            if codexStatus.state == .disconnected {
                selectFallbackProvidersAfterCodexDisconnect()
            }
        } catch {
            codexStatus = CodexConnectionStatus(state: .failed, error: error.localizedDescription)
        }
    }

    private func refreshCodexModels() async {
        do {
            codexModels = try await AgentService().codexModels()
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func selectFallbackProvidersAfterCodexDisconnect() {
        if settings.selectedAgentProviderID == AgentProviderProfile.codexID,
           let fallback = settings.agentProviders.first(where: { $0.kind != .openAICodex }) {
            settings.selectAgentProvider(fallback.id)
        }
        if settings.selectedImageProviderID == AgentProviderProfile.codexID,
           let fallback = settings.imageGenerationProviders.first(where: { $0.kind == .openAICompatible }) {
            settings.selectImageProvider(fallback.id)
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}

private enum CodexModelPickerPurpose: String, Identifiable {
    case agent
    case image

    var id: String { rawValue }
}

private struct CodexModelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let models: [CodexModelDescriptor]
    let selectedModelID: String
    let onSelect: (CodexModelDescriptor) -> Void

    private var filteredModels: [CodexModelDescriptor] {
        guard !searchText.isEmpty else { return models }
        return models.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredModels) { model in
                Button {
                    onSelect(model)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                            Text(model.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.supportsImageGeneration {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                                .help("Supports image generation")
                        }
                        if model.id == selectedModelID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search Codex models")
            .navigationTitle("Codex Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }
}
#endif
