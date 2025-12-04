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
        
        // Enable system proxy support (including VPN)
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPSEnable: true,
            // Use system proxy settings
            kCFProxyTypeKey: kCFProxyTypeAutoConfigurationURL
        ] as [AnyHashable: Any]
        
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
    
    /// Fetch data from URL with automatic proxy support
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
    
    /// Fetch data from URL with automatic proxy support
    func data(from url: URL) async throws -> (Data, URLResponse) {
        return try await session.data(from: url)
    }
}
