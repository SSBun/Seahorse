#if os(macOS)

import Foundation

struct AgentBookmarkResult: Identifiable, Hashable {
    let id: UUID
    let bookmark: Bookmark
    let reason: String
}

struct AgentSearchResponse {
    let answer: String
    let results: [AgentBookmarkResult]
}

actor AgentService {
    private let aiManager = AIManager()
    private let maxCandidates = 40

    func searchBookmarks(
        query: String,
        bookmarks: [Bookmark],
        categories: [Category],
        tags: [Tag]
    ) async throws -> AgentSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return AgentSearchResponse(answer: "Ask me what bookmarks you want to find.", results: [])
        }

        let candidates = candidateBookmarks(
            for: trimmedQuery,
            bookmarks: bookmarks,
            categories: categories,
            tags: tags
        )

        guard !candidates.isEmpty else {
            return AgentSearchResponse(answer: "I could not find matching bookmarks.", results: [])
        }

        let prompt = makePrompt(query: trimmedQuery, candidates: candidates, categories: categories, tags: tags)
        let raw = try await aiManager.complete(prompt: prompt)
        let parsed: ParsedAgentResponse
        do {
            parsed = try parseResponse(raw)
        } catch {
            return AgentSearchResponse(answer: raw, results: [])
        }
        let bookmarksById = Dictionary(uniqueKeysWithValues: bookmarks.map { ($0.id.uuidString.lowercased(), $0) })

        let results = parsed.results.compactMap { result -> AgentBookmarkResult? in
            guard let bookmark = bookmarksById[result.id.lowercased()] else { return nil }
            return AgentBookmarkResult(id: bookmark.id, bookmark: bookmark, reason: result.reason)
        }

        return AgentSearchResponse(answer: parsed.answer, results: results)
    }

    private func candidateBookmarks(
        for query: String,
        bookmarks: [Bookmark],
        categories: [Category],
        tags: [Tag]
    ) -> [Bookmark] {
        let tokens = query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }

        let scored = bookmarks.map { bookmark in
            let text = searchableText(for: bookmark, categories: categories, tags: tags)
            let score = tokens.reduce(0) { total, token in
                total + (text.contains(token) ? 1 : 0)
            }
            return (bookmark: bookmark, score: score)
        }

        let matches = scored
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.bookmark.addedDate > $1.bookmark.addedDate
                }
                return $0.score > $1.score
            }
            .map(\.bookmark)

        if !matches.isEmpty {
            return Array(matches.prefix(maxCandidates))
        }

        return Array(bookmarks.sorted { $0.addedDate > $1.addedDate }.prefix(maxCandidates))
    }

    private func searchableText(for bookmark: Bookmark, categories: [Category], tags: [Tag]) -> String {
        var fields = [bookmark.title, bookmark.url]
        if let notes = bookmark.notes { fields.append(notes) }
        if let description = bookmark.metadata?.description { fields.append(description) }
        if let siteName = bookmark.metadata?.siteName { fields.append(siteName) }
        if let category = categories.first(where: { $0.id == bookmark.categoryId }) {
            fields.append(category.name)
        }
        fields.append(contentsOf: tags.filter { bookmark.tagIds.contains($0.id) }.map(\.name))
        return fields.joined(separator: " ").lowercased()
    }

    private func makePrompt(
        query: String,
        candidates: [Bookmark],
        categories: [Category],
        tags: [Tag]
    ) -> String {
        let candidateLines = candidates.map { bookmark in
            let category = categories.first(where: { $0.id == bookmark.categoryId })?.name ?? "None"
            let tagNames = tags.filter { bookmark.tagIds.contains($0.id) }.map(\.name).joined(separator: ", ")
            let description = bookmark.metadata?.description ?? ""
            let notes = bookmark.notes ?? ""
            return """
            id: \(bookmark.id.uuidString)
            title: \(bookmark.title)
            url: \(bookmark.url)
            category: \(category)
            tags: \(tagNames)
            description: \(description)
            notes: \(notes)
            """
        }.joined(separator: "\n---\n")

        return """
        You are the Seahorse bookmark search agent.
        User query: \(query)

        Select the 5 most relevant bookmarks from the candidates. Return strict JSON only, with no markdown.
        Schema:
        {"answer":"short answer","results":[{"id":"bookmark uuid","reason":"short reason"}]}

        Candidates:
        \(candidateLines)
        """
    }

    private func parseResponse(_ raw: String) throws -> ParsedAgentResponse {
        let json = extractJSON(raw)
        guard let data = json.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        return try JSONDecoder().decode(ParsedAgentResponse.self, from: data)
    }

    private func extractJSON(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}

private struct ParsedAgentResponse: Decodable {
    let answer: String
    let results: [ParsedAgentResult]
}

private struct ParsedAgentResult: Decodable {
    let id: String
    let reason: String
}

#endif
