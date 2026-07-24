//
//  NetworkManager.swift
//  Seahorse
//
//  Created by Antigravity on 2025/12/03.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        
        // Set timeout intervals
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // Allow background tasks
        configuration.waitsForConnectivity = true
        
        // Use system cookies and credentials
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        
        // Enable HTTP/2
        configuration.httpMaximumConnectionsPerHost = 6
        
        self.session = URLSession(configuration: configuration)
    }
    
    /// Fetches data for a URL request.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
    
    /// Fetches data from a URL.
    func data(from url: URL) async throws -> (Data, URLResponse) {
        return try await session.data(from: url)
    }
}
