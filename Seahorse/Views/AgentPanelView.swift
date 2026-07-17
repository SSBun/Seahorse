#if os(macOS)

import SwiftUI

private struct AgentChatMessage: Identifiable, Hashable {
    enum Role {
        case user
        case assistant
        case error
    }

    let id = UUID()
    let role: Role
    let text: String
    let results: [Bookmark]
}

struct AgentPanelView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @EnvironmentObject var itemDetailState: ItemDetailState
    @Environment(\.openWindow) private var openWindow

    @State private var messages: [AgentChatMessage] = [
        AgentChatMessage(
            role: .assistant,
            text: "Ask me to find bookmarks.",
            results: []
        )
    ]
    @State private var inputText = ""
    @State private var isSearching = false
    @State private var sessionID = UUID()

    private let agentService = AgentService()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            composer
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            Label("Agent", systemImage: "sparkles")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if isSearching {
                ProgressView()
                    .scaleEffect(0.65)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(_ message: AgentChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(.system(size: 13))
                .foregroundStyle(message.role == .error ? .red : .primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .background(messageBackground(for: message.role))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if !message.results.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.results) { result in
                        resultButton(result)
                    }
                }
            }
        }
    }

    private func resultButton(_ bookmark: Bookmark) -> some View {
        Button {
            itemDetailState.showItem(bookmark.id, source: "agent")
            openWindow(id: "item-detail")
        } label: {
            HStack(alignment: .top, spacing: 10) {
                BookmarkIconView(iconString: bookmark.icon, size: 18)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                    Text(host(for: bookmark.url))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Search bookmarks with Agent", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit {
                    send()
                }

            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            .help("Send")
        }
        .padding(10)
    }

    private func send() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isSearching else { return }

        inputText = ""
        messages.append(AgentChatMessage(role: .user, text: query, results: []))
        isSearching = true

        Task {
            do {
                let response = try await agentService.send(query, to: sessionID)
                await MainActor.run {
                    let bookmarksByID = Dictionary(
                        uniqueKeysWithValues: dataStorage.bookmarks.map { ($0.id, $0) }
                    )
                    let results = response.bookmarkIDs.compactMap { bookmarksByID[$0] }
                    messages.append(AgentChatMessage(role: .assistant, text: response.answer, results: results))
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    messages.append(AgentChatMessage(role: .error, text: error.localizedDescription, results: []))
                    isSearching = false
                }
            }
        }
    }

    private func messageBackground(for role: AgentChatMessage.Role) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.18)
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .error:
            return Color.red.opacity(0.12)
        }
    }

    private func host(for urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}

#endif
