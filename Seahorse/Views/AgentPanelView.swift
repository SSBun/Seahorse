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
        .frame(minWidth: 300, idealWidth: 380, maxWidth: 600, minHeight: 420, idealHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
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
        .background(.bar)
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
                .padding(14)
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
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 40)
                }

                Text(renderedText(for: message))
                    .font(.body)
                    .foregroundStyle(message.role == .error ? .red : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(messageBackground(for: message.role), in: RoundedRectangle(cornerRadius: 12))

                if message.role != .user {
                    Spacer(minLength: 40)
                }
            }

            if !message.results.isEmpty {
                VStack(spacing: 8) {
                    ForEach(message.results) { result in
                        resultButton(result)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func resultButton(_ bookmark: Bookmark) -> some View {
        Button {
            itemDetailState.showItem(bookmark.id, source: "agent")
            openWindow(id: "item-detail")
        } label: {
            HStack(spacing: 12) {
                BookmarkIconView(iconString: bookmark.icon, size: 18)
                    .frame(width: 34, height: 34)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(bookmark.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    Text(host(for: bookmark.url))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
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
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            .help("Send")
        }
        .padding(10)
        .background(.bar)
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

    private func renderedText(for message: AgentChatMessage) -> AttributedString {
        guard message.role == .assistant else {
            return AttributedString(message.text)
        }
        return (try? AttributedString(markdown: message.text)) ?? AttributedString(message.text)
    }

    private func host(for urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}

#endif
