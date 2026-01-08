//
//  BookmarkURLNormalizer.swift
//  Seahorse
//
//  Created by GPT-5.2 on 2026/01/08.
//

import Foundation

enum BookmarkURLNormalizer {
    /// Normalizes bookmark URLs for duplicate detection (not for display).
    /// - Trims whitespace
    /// - Adds `https://` when scheme is missing
    /// - Lowercases scheme/host
    /// - Removes fragment
    /// - Removes default ports (80/443)
    /// - Removes trailing slash (except root `/`)
    static func normalize(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let candidate: String
        if !trimmed.contains("://") {
            candidate = "https://\(trimmed)"
        } else {
            candidate = trimmed
        }
        
        guard var components = URLComponents(string: candidate) else {
            return trimmed.lowercased()
        }
        
        if let scheme = components.scheme {
            components.scheme = scheme.lowercased()
        }
        if let host = components.host {
            components.host = host.lowercased()
        }
        
        components.fragment = nil
        
        if (components.scheme == "http" && components.port == 80) ||
            (components.scheme == "https" && components.port == 443) {
            components.port = nil
        }
        
        if components.percentEncodedPath.isEmpty {
            components.percentEncodedPath = "/"
        }
        if components.percentEncodedPath.count > 1 && components.percentEncodedPath.hasSuffix("/") {
            components.percentEncodedPath.removeLast()
        }
        
        if let q = components.percentEncodedQuery, q.isEmpty {
            components.percentEncodedQuery = nil
        }
        
        return components.string ?? trimmed.lowercased()
    }
}

