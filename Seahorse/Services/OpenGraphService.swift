//
//  OpenGraphService.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import Foundation

class OpenGraphService {
    static let shared = OpenGraphService()
    
    private init() {}
    
    func fetchMetadata(url: URL) async throws -> WebMetadata {
        DLog("OGP: fetch start url='\(url.absoluteString)'", category: .network)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Use a browser-like User-Agent to avoid being blocked
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await NetworkManager.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            DLog("OGP: bad response", category: .network)
            throw URLError(.badServerResponse)
        }
        
        DLog("OGP: response ok status=\(httpResponse.statusCode) bytes=\(data.count)", category: .network)
        
        // Try to decode with UTF-8, fall back to ASCII if needed
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            DLog("OGP: failed to decode html", category: .network)
            throw URLError(.cannotDecodeContentData)
        }
        
        let metadata = parseMetadata(html: html, baseURL: url)
        DLog("OGP: parsed title=\(metadata.title ?? "nil") img=\(metadata.imageURL ?? "nil") favicon=\(metadata.faviconURL ?? "nil")", category: .network)
        return metadata
    }
    
    private func parseMetadata(html: String, baseURL: URL) -> WebMetadata {
        var data = WebMetadata()
        
        // Helper to extract content from meta tags
        func extractMetaContent(property: String) -> String? {
            let pattern = "<meta property=\"\(property)\" content=\"([^\"]+)\""
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = String(html[range])
                // Extract content value
                if let contentStart = match.range(of: "content=\""),
                   let contentEnd = match.range(of: "\"", options: .backwards) {
                    let content = String(match[contentStart.upperBound..<contentEnd.lowerBound])
                    return content
                }
            }
            // Try alternative format (name instead of property)
            let patternName = "<meta name=\"\(property)\" content=\"([^\"]+)\""
            if let range = html.range(of: patternName, options: .regularExpression) {
                let match = String(html[range])
                if let contentStart = match.range(of: "content=\""),
                   let contentEnd = match.range(of: "\"", options: .backwards) {
                    let content = String(match[contentStart.upperBound..<contentEnd.lowerBound])
                    return content
                }
            }
            return nil
        }
        
        // Title: og:title -> twitter:title -> <title>
        data.title = extractMetaContent(property: "og:title") ??
                     extractMetaContent(property: "twitter:title")
        
        if data.title == nil {
             if let titleRange = html.range(of: "<title>", options: .caseInsensitive),
                let endTitleRange = html.range(of: "</title>", options: .caseInsensitive, range: titleRange.upperBound..<html.endIndex) {
                 data.title = String(html[titleRange.upperBound..<endTitleRange.lowerBound])
             }
        }
        
        // Description: og:description -> twitter:description -> description
        data.description = extractMetaContent(property: "og:description") ??
                           extractMetaContent(property: "twitter:description") ??
                           extractMetaContent(property: "description")
        
        // Site Name: og:site_name
        data.siteName = extractMetaContent(property: "og:site_name")
        
        // Image: og:image -> twitter:image
        if let imagePath = extractMetaContent(property: "og:image") ?? extractMetaContent(property: "twitter:image") {
            // Handle relative URLs
            if let imageURL = URL(string: imagePath, relativeTo: baseURL) {
                data.imageURL = imageURL.absoluteString
            } else {
                data.imageURL = imagePath
            }
        }
        
        // Favicon: link rel="icon" -> link rel="shortcut icon" -> link rel="apple-touch-icon"
        func extractLinkHref(rel: String) -> String? {
            let pattern = "<link[^>]+rel=[\"']\(rel)[\"'][^>]+href=[\"']([^\"']+)[\"']"
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = String(html[range])
                if let hrefStart = match.range(of: "href=\"") ?? match.range(of: "href='"),
                   let hrefEnd = match.range(of: "\"", range: hrefStart.upperBound..<match.endIndex) ?? match.range(of: "'", range: hrefStart.upperBound..<match.endIndex) {
                    return String(match[hrefStart.upperBound..<hrefEnd.lowerBound])
                }
            }
            return nil
        }
        
        if let faviconPath = extractLinkHref(rel: "icon") ??
                             extractLinkHref(rel: "shortcut icon") ??
                             extractLinkHref(rel: "apple-touch-icon") {
            if let faviconURL = URL(string: faviconPath, relativeTo: baseURL) {
                data.faviconURL = faviconURL.absoluteString
            } else {
                data.faviconURL = faviconPath
            }
        } else {
            // Fallback to default /favicon.ico
            if let host = baseURL.host {
                data.faviconURL = "https://\(host)/favicon.ico"
            }
        }
        
        return data
    }
}
