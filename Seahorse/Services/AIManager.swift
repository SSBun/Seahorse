//
//  AIManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import OpenAI
import OSLog

enum AIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case missingAPIKey
    case missingBaseURL
    case networkError(Error)
    case apiError(String)
    case webFetchError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid API URL: '\(url)'. Must be a valid URL (e.g., https://api.openai.com/v1)"
        case .invalidResponse:
            return "Invalid response from API"
        case .missingAPIKey:
            return "API key is not configured. Please set it in Settings > AI"
        case .missingBaseURL:
            return "Base URL is not configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .webFetchError(let message):
            return "Failed to fetch web content: \(message)"
        }
    }
}

struct ParsedBookmarkData {
    let refinedTitle: String
    let summary: String
    let suggestedCategoryName: String?
    let suggestedTagNames: [String]
    let suggestedSFSymbol: String?
}

actor AIManager {
    nonisolated private func getSettings() async -> (apiToken: String, apiBaseURL: String, model: String, pageSummaryPrompt: String, categorizingPrompt: String, tagSuggestionPrompt: String, titleRefinementPrompt: String, aiLanguage: AILanguage) {
        await MainActor.run {
            let settings = AISettings.shared
            return (
                apiToken: settings.apiToken,
                apiBaseURL: settings.apiBaseURL,
                model: settings.model,
                pageSummaryPrompt: settings.pageSummaryPrompt,
                categorizingPrompt: settings.categorizingPrompt,
                tagSuggestionPrompt: settings.tagSuggestionPrompt,
                titleRefinementPrompt: settings.titleRefinementPrompt,
                aiLanguage: settings.aiLanguage
            )
        }
    }

    nonisolated private func getImageSettings() async -> (apiToken: String, apiBaseURL: String, model: String) {
        await MainActor.run {
            let settings = AISettings.shared
            if settings.useSharedImageApi {
                return (apiToken: settings.apiToken, apiBaseURL: settings.apiBaseURL, model: settings.imageModel)
            }
            return (apiToken: settings.imageApiToken, apiBaseURL: settings.imageApiBaseURL, model: settings.imageModel)
        }
    }
    
    private func createClient() async throws -> OpenAI {
        let settings = await getSettings()
        
        guard !settings.apiToken.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let baseURLString = settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !baseURLString.isEmpty else {
            throw AIError.missingBaseURL
        }
        
        // Parse the URL to extract host and path
        guard let baseURL = URL(string: baseURLString) else {
            throw AIError.invalidURL(baseURLString)
        }
        
        // Extract host (domain) from the URL
        guard let host = baseURL.host else {
            throw AIError.invalidURL(baseURLString)
        }
        
        // Construct the host string with optional path
        var hostString = host
        if baseURL.path != "/" && !baseURL.path.isEmpty {
            hostString += baseURL.path
        }
        
        // Construct the configuration with just the host
        let configuration = OpenAI.Configuration(
            token: settings.apiToken,
            host: hostString
        )
        
        return OpenAI(configuration: configuration)
    }
    
    func testConnection() async throws -> String {
        let settings = await getSettings()
        let client = try await createClient()
        
        let query = ChatQuery(
            messages: [
                ChatQuery.ChatCompletionMessageParam(role: .user, content: "Hello, respond with 'OK' if you receive this message.")!
            ],
            model: .init(settings.model)
        )
        
        do {
            let result = try await client.chats(query: query)
            
            guard let content = result.choices.first?.message.content else {
                throw AIError.invalidResponse
            }
            
            return "✅ Connection successful! Response: \(content)"
        } catch {
            throw AIError.apiError(error.localizedDescription)
        }
    }
    
    func fetchWebContent(url: String) async throws -> (title: String, content: String) {
        guard let webURL = URL(string: url) else {
            throw AIError.webFetchError("Invalid URL")
        }
        
        // Step 1: Create URLRequest with proper headers
        var request = URLRequest(url: webURL)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        // Step 2: Fetch web content
        do {
            let (data, response) = try await NetworkManager.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.webFetchError("Invalid response from server")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw AIError.webFetchError("HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            }
            
            // Try to detect encoding from response or use UTF-8
            var encoding = String.Encoding.utf8
            if let textEncodingName = httpResponse.textEncodingName {
                let cfEncoding = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
                if cfEncoding != kCFStringEncodingInvalidId {
                    encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
                }
            }
            
            guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
                throw AIError.webFetchError("Unable to decode HTML content")
            }
            
            // Step 3: Extract title and clean content
            let title = extractTitle(from: html)
            let content = cleanHTML(html)
            
            return (title, content)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.webFetchError("Network error: \(error.localizedDescription)")
        }
    }
    
    private func extractTitle(from html: String) -> String {
        // Try to extract <title> tag
        if let titleRange = html.range(of: "<title>", options: .caseInsensitive),
           let endTitleRange = html.range(of: "</title>", options: .caseInsensitive, range: titleRange.upperBound..<html.endIndex) {
            let title = String(html[titleRange.upperBound..<endTitleRange.lowerBound])
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to extract og:title meta tag
        if let ogTitleRange = html.range(of: "property=\"og:title\" content=\"", options: .caseInsensitive),
           let endQuoteRange = html.range(of: "\"", range: ogTitleRange.upperBound..<html.endIndex) {
            let title = String(html[ogTitleRange.upperBound..<endQuoteRange.lowerBound])
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "Untitled"
    }
    
    private func cleanHTML(_ html: String) -> String {
        var text = html
        
        // Remove script and style tags with their content
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        // Remove HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit to first 4000 characters to avoid token limits
        if text.count > 4000 {
            text = String(text.prefix(4000)) + "..."
        }
        
        return text
    }
    
    func fetchFavicon(url: String) async -> String? {
        guard let webURL = URL(string: url) else { return nil }
        
        // Try common favicon URLs
        let faviconPaths = [
            "/favicon.ico",
            "/favicon.png",
            "/apple-touch-icon.png",
            "/apple-touch-icon-precomposed.png"
        ]
        
        guard let baseURL = webURL.scheme.map({ "\($0)://\(webURL.host ?? "")" }) else {
            return nil
        }
        
        for path in faviconPaths {
            let faviconURL = baseURL + path
            if let url = URL(string: faviconURL) {
                var request = URLRequest(url: url)
                request.timeoutInterval = 3
                
                do {
                    let (_, response) = try await NetworkManager.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode) {
                        return faviconURL
                    }
                } catch {
                    continue
                }
            }
        }
        
        return nil
    }
    
    func parseBookmarkContent(
        title: String,
        content: String,
        availableCategories: [String],
        availableTags: [String]
    ) async throws -> ParsedBookmarkData {
        let settings = await getSettings()
        let client = try await createClient()
        let languageSuffix = "\n\n" + settings.aiLanguage.promptSuffix
        
        // 1. Refine title
        let titlePrompt = settings.titleRefinementPrompt
            .replacingOccurrences(of: "{title}", with: title)
            + languageSuffix
        
        let refinedTitle = try await callAI(client: client, model: settings.model, prompt: titlePrompt)
        
        // 2. Generate summary
        let summaryPrompt = settings.pageSummaryPrompt
            .replacingOccurrences(of: "{title}", with: refinedTitle)
            .replacingOccurrences(of: "{content}", with: content)
            + languageSuffix
        
        let summary = try await callAI(client: client, model: settings.model, prompt: summaryPrompt)
        
        // 3. Suggest category
        let categoryPrompt = settings.categorizingPrompt
            .replacingOccurrences(of: "{title}", with: refinedTitle)
            .replacingOccurrences(of: "{content}", with: content)
            .replacingOccurrences(of: "{categories}", with: availableCategories.joined(separator: ", "))
            + languageSuffix
        
        let suggestedCategory = try await callAI(client: client, model: settings.model, prompt: categoryPrompt)
        let categoryName = suggestedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 4. Suggest tags
        let tagPrompt = settings.tagSuggestionPrompt
            .replacingOccurrences(of: "{title}", with: refinedTitle)
            .replacingOccurrences(of: "{content}", with: content)
            .replacingOccurrences(of: "{tags}", with: availableTags.joined(separator: ", "))
            + languageSuffix
        
        let suggestedTagsStr = try await callAI(client: client, model: settings.model, prompt: tagPrompt)
        let tagNames = suggestedTagsStr
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 5. Suggest SF Symbol icon based on content
        let sfSymbolPrompt = """
        Based on the following webpage title and summary, suggest ONE appropriate SF Symbol icon name that best represents the content.
        
        Title: \(refinedTitle)
        Summary: \(summary)
        
        Choose from common SF Symbols like:
        - Document/Text: doc.text.fill, doc.richtext.fill, newspaper.fill, book.fill, text.book.closed.fill
        - Code/Development: chevron.left.forwardslash.chevron.right, hammer.fill, wrench.fill, terminal.fill, cpu.fill
        - Design: paintbrush.fill, pencil.and.ruler.fill, cube.fill, photo.fill
        - Communication: envelope.fill, message.fill, bubble.left.and.bubble.right.fill, phone.fill
        - Media: play.rectangle.fill, music.note, video.fill, camera.fill, photo.on.rectangle.fill
        - Education: graduationcap.fill, book.closed.fill, studentdesk
        - Business: briefcase.fill, chart.bar.fill, dollarsign.circle.fill, cart.fill
        - Science: flask.fill, testtube.2, atom, function
        - Social: person.2.fill, person.3.fill, bubble.left.fill
        - Location: map.fill, globe, location.fill, pin.fill
        - Technology: laptopcomputer, server.rack, wifi, antenna.radiowaves.left.and.right
        - Shopping: bag.fill, cart.fill, creditcard.fill, tag.fill
        - Food: fork.knife, cup.and.saucer.fill
        - Health: heart.fill, cross.case.fill, medical.thermometer
        - Sports: sportscourt.fill, figure.run, dumbbell.fill
        - Entertainment: tv.fill, gamecontroller.fill, film.fill
        - Finance: banknote.fill, chart.line.uptrend.xyaxis, bitcoinsign.circle.fill
        - Cloud: cloud.fill, icloud.fill, externaldrive.fill
        - Security: lock.shield.fill, key.fill, checkmark.shield.fill
        - General: link.circle.fill, star.fill, flag.fill, bookmark.fill
        
        Return ONLY the SF Symbol name, nothing else.
        """
        
        let suggestedSFSymbol = try await callAI(client: client, model: settings.model, prompt: sfSymbolPrompt)
        let sfSymbolName = suggestedSFSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ParsedBookmarkData(
            refinedTitle: refinedTitle,
            summary: summary,
            suggestedCategoryName: categoryName.isEmpty || categoryName == "None" ? nil : categoryName,
            suggestedTagNames: tagNames,
            suggestedSFSymbol: sfSymbolName.isEmpty ? nil : sfSymbolName
        )
    }
    
    private func createImageClient() async throws -> OpenAI {
        let settings = await getImageSettings()

        Log.info("Creating image AI client — model: \(settings.model), baseURL: \(settings.apiBaseURL), token: \(settings.apiToken.isEmpty ? "empty" : "set(\(settings.apiToken.prefix(4))...)")", category: .ai)

        guard !settings.apiToken.isEmpty else {
            Log.error("Image AI client failed: API token is empty", category: .ai)
            throw AIError.missingAPIKey
        }

        let baseURLString = settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURLString.isEmpty else {
            Log.error("Image AI client failed: base URL is empty", category: .ai)
            throw AIError.missingBaseURL
        }
        guard let baseURL = URL(string: baseURLString) else {
            Log.error("Image AI client failed: invalid base URL — \(baseURLString)", category: .ai)
            throw AIError.invalidURL(baseURLString)
        }
        guard let host = baseURL.host else {
            Log.error("Image AI client failed: cannot extract host from — \(baseURLString)", category: .ai)
            throw AIError.invalidURL(baseURLString)
        }

        var hostString = host
        if baseURL.path != "/" && !baseURL.path.isEmpty {
            hostString += baseURL.path
        }

        Log.debug("Image AI client host: \(hostString)", category: .ai)
        let configuration = OpenAI.Configuration(token: settings.apiToken, host: hostString, timeoutInterval: 300)
        return OpenAI(configuration: configuration)
    }

    func generateCoverImage(title: String, description: String?, url: String, siteName: String?) async throws -> Data {
        Log.info("Starting cover image generation for bookmark: \"\(title)\"", category: .ai)

        let settings = await getImageSettings()
        Log.debug("Image settings — model: \(settings.model)", category: .ai)

        let client = try await createImageClient()

        var promptParts = ["Generate a visually appealing cover image for a bookmark/link collection app."]
        promptParts.append("The bookmark title is: \"\(title)\"")
        if let desc = description, !desc.isEmpty {
            promptParts.append("Description: \"\(desc.prefix(200))\"")
        }
        if let site = siteName, !site.isEmpty {
            promptParts.append("Website: \(site)")
        }
        promptParts.append("Create a modern, clean illustration that represents the content. No text in the image.")

        let prompt = promptParts.joined(separator: " ")
        Log.debug("Image generation prompt (\(prompt.count) chars): \(prompt.prefix(200))...", category: .ai)

        let query = ImagesQuery(
            prompt: prompt,
            model: Model(settings.model),
            n: 1,
            responseFormat: .b64_json,
            size: ._1024x1536
        )

        Log.info("Sending image generation request — model: \(settings.model), size: 1024x1536", category: .ai)

        do {
            let result = try await client.images(query: query)
            Log.debug("Image API returned \(result.data.count) image(s)", category: .ai)

            guard let imageData = result.data.first else {
                Log.error("Image API returned empty data array", category: .ai)
                throw AIError.invalidResponse
            }

            if let revised = imageData.revisedPrompt {
                Log.debug("Revised prompt: \(revised.prefix(200))", category: .ai)
            }

            guard let b64 = imageData.b64Json else {
                Log.error("Image API returned no b64_json — url field present: \(imageData.url != nil)", category: .ai)
                throw AIError.invalidResponse
            }

            guard let data = Data(base64Encoded: b64) else {
                Log.error("Failed to decode base64 image data (length: \(b64.count))", category: .ai)
                throw AIError.invalidResponse
            }

            Log.info("Cover image generated successfully — \(data.count) bytes", category: .ai)
            return data
        } catch let error as AIError {
            Log.error("Cover image generation failed (AIError): \(error.localizedDescription)", category: .ai)
            throw error
        } catch {
            Log.error("Cover image generation failed: \(error.localizedDescription)", category: .ai)
            throw AIError.apiError(error.localizedDescription)
        }
    }

    private func callAI(client: OpenAI, model: String, prompt: String) async throws -> String {
        guard let userMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: prompt) else {
            throw AIError.invalidResponse
        }
        
        let query = ChatQuery(
            messages: [userMessage],
            model: .init(model),
            temperature: 0.7
        )
        
        do {
            let result = try await client.chats(query: query)
            
            guard let content = result.choices.first?.message.content else {
                throw AIError.invalidResponse
            }
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw AIError.networkError(error)
        }
    }
}

