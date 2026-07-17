//
//  DiagnosticService.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//
//  Concurrent diagnostic processing with up to 10 parallel workers
//  Uses Swift's TaskGroup for safe concurrency and an Actor for thread-safe state management

import Foundation

enum BookmarkStatus: Equatable {
    /// Indicates that the link check is still running.
    case checking
    /// Indicates that the link responded successfully.
    case accessible
    /// Indicates that the link could not be verified by this check.
    case unverified(reason: String)
    /// Indicates that the link is known to be invalid.
    case broken(reason: String)

    /// Describes why a link is broken or could not be verified.
    var reason: String? {
        switch self {
        case .unverified(let reason), .broken(let reason):
            return reason
        case .checking, .accessible:
            return nil
        }
    }
}

struct BookmarkDiagnosticResult: Identifiable {
    let id = UUID()
    let bookmark: Bookmark
    var status: BookmarkStatus
    var httpStatusCode: Int?
    var errorMessage: String?
}

@MainActor
class DiagnosticService: ObservableObject {
    /// Loads a request and returns its response without imposing HTTP status semantics.
    typealias RequestLoader = (URLRequest) async throws -> (Data, URLResponse)

    @Published var isRunning = false
    @Published var currentBookmark: Bookmark?
    @Published var progress: Double = 0
    @Published var totalCount: Int = 0
    @Published var checkedCount: Int = 0
    @Published var results: [BookmarkDiagnosticResult] = []
    @Published var brokenBookmarks: [BookmarkDiagnosticResult] = []

    /// Returns results that require manual verification.
    /// - Complexity: O(n).
    var unverifiedBookmarks: [BookmarkDiagnosticResult] {
        results.filter { result in
            if case .unverified = result.status { return true }
            return false
        }
    }
    
    private var task: Task<Void, Never>?
    private weak var dataStorage: DataStorage?
    private let requestLoader: RequestLoader
    
    init(
        dataStorage: DataStorage,
        requestLoader: @escaping RequestLoader = { request in
            try await NetworkManager.shared.data(for: request)
        }
    ) {
        self.dataStorage = dataStorage
        self.requestLoader = requestLoader
    }
    
    func start(bookmarks: [Bookmark]? = nil) {
        guard !isRunning, let dataStorage = dataStorage else { return }

        let targetBookmarks = bookmarks ?? dataStorage.bookmarks
        guard !targetBookmarks.isEmpty else { return }

        isRunning = true
        totalCount = targetBookmarks.count
        checkedCount = 0
        progress = 0
        results = []
        brokenBookmarks = []

        print("🚀 Starting concurrent diagnostic scan")
        print("  📊 Total bookmarks: \(targetBookmarks.count)")
        print("  ⚡️ Concurrent workers: 10")

        let startTime = Date()

        task = Task {
            await performConcurrentDiagnostics(bookmarks: targetBookmarks)
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Diagnostic scan complete")
            print("  ⏱️ Duration: \(String(format: "%.2f", duration)) seconds")
            print("  📈 Speed: \(String(format: "%.1f", Double(targetBookmarks.count) / duration)) bookmarks/second")
            print("  ❌ Broken bookmarks: \(self.brokenBookmarks.count)")
            print("  ❓ Unverified bookmarks: \(self.unverifiedBookmarks.count)")
            
            await MainActor.run {
                self.isRunning = false
                self.currentBookmark = nil
            }
        }
    }
    
    /// Perform concurrent diagnostics using TaskGroup with 10 parallel workers
    private func performConcurrentDiagnostics(bookmarks: [Bookmark]) async {
        let maxConcurrentTasks = 10
        var bookmarkIndex = 0
        
        // Use an actor for thread-safe access to shared mutable state
        actor DiagnosticCoordinator {
            var checkedCount = 0
            var results: [BookmarkDiagnosticResult] = []
            var brokenResults: [BookmarkDiagnosticResult] = []
            
            func recordResult(_ result: BookmarkDiagnosticResult) {
                results.append(result)
                if case .broken = result.status {
                    brokenResults.append(result)
                }
                checkedCount += 1
            }
            
            func getResults() -> (all: [BookmarkDiagnosticResult], broken: [BookmarkDiagnosticResult], count: Int) {
                (results, brokenResults, checkedCount)
            }
        }
        
        let coordinator = DiagnosticCoordinator()
        
        await withTaskGroup(of: (Int, BookmarkDiagnosticResult).self) { group in
            // Start initial batch of concurrent tasks
            for i in 0..<min(maxConcurrentTasks, bookmarks.count) {
                group.addTask {
                    let result = await self.checkBookmark(bookmarks[i])
                    return (i, result)
                }
            }
            bookmarkIndex = min(maxConcurrentTasks, bookmarks.count)
            
            // Process results and spawn new tasks
            for await (_, result) in group {
                // Check for cancellation
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }
                
                guard await MainActor.run(body: { self.isRunning }) else {
                    group.cancelAll()
                    break
                }
                
                // Record result in coordinator
                await coordinator.recordResult(result)
                
                // Update UI on main actor
                let stats = await coordinator.getResults()
                await MainActor.run {
                    self.results = stats.all
                    self.brokenBookmarks = stats.broken
                    self.checkedCount = stats.count
                    self.progress = Double(stats.count) / Double(self.totalCount)
                }
                
                // Spawn next task if there are more bookmarks to check
                if bookmarkIndex < bookmarks.count {
                    let nextIndex = bookmarkIndex
                    bookmarkIndex += 1
                    
                    group.addTask {
                        // Small staggered delay to avoid overwhelming servers
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                        let result = await self.checkBookmark(bookmarks[nextIndex])
                        return (nextIndex, result)
                    }
                    
                    // Update current bookmark for UI display
                    await MainActor.run {
                        self.currentBookmark = bookmarks[nextIndex]
                    }
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
        currentBookmark = nil
    }
    
    func reset() {
        stop()
        progress = 0
        totalCount = 0
        checkedCount = 0
        results = []
        brokenBookmarks = []
    }

    /// Classifies an HTTP response without treating temporary or restricted responses as broken.
    static func status(forHTTPStatusCode statusCode: Int) -> BookmarkStatus {
        switch statusCode {
        case 200...399:
            return .accessible
        case 401:
            return .unverified(reason: "Authentication Required (401)")
        case 403:
            return .unverified(reason: "Access Restricted (403)")
        case 404:
            return .unverified(reason: "Not Found (404)")
        case 410:
            return .broken(reason: "Gone (410)")
        case 429:
            return .unverified(reason: "Rate Limited (429)")
        case 400...499:
            return .unverified(reason: "Client Response (\(statusCode))")
        case 500...599:
            return .unverified(reason: "Server Error (\(statusCode))")
        default:
            return .unverified(reason: "Unexpected HTTP Status (\(statusCode))")
        }
    }
    
    private func checkBookmark(_ bookmark: Bookmark) async -> BookmarkDiagnosticResult {
        guard let url = URL(string: bookmark.url) else {
            return BookmarkDiagnosticResult(
                bookmark: bookmark,
                status: .broken(reason: "Invalid URL"),
                httpStatusCode: nil,
                errorMessage: "The URL format is invalid"
            )
        }
        
        // Check if it's a valid HTTP/HTTPS URL
        guard url.scheme == "http" || url.scheme == "https" else {
            return BookmarkDiagnosticResult(
                bookmark: bookmark,
                status: .broken(reason: "Unsupported protocol"),
                httpStatusCode: nil,
                errorMessage: "Only HTTP/HTTPS URLs are supported"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Use HEAD to avoid downloading content
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        do {
            var response = try await requestLoader(request).1

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 405 || httpResponse.statusCode == 501 {
                request.httpMethod = "GET"
                request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
                response = try await requestLoader(request).1
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let status = Self.status(forHTTPStatusCode: statusCode)
                return BookmarkDiagnosticResult(
                    bookmark: bookmark,
                    status: status,
                    httpStatusCode: statusCode,
                    errorMessage: nil
                )
            }
            
            return BookmarkDiagnosticResult(
                bookmark: bookmark,
                status: .unverified(reason: "Non-HTTP Response"),
                httpStatusCode: nil,
                errorMessage: "The server did not return an HTTP response"
            )
            
        } catch let error as NSError {
            let reason: String
            let message: String
            
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorTimedOut:
                    reason = "Timeout"
                    message = "The request timed out"
                case NSURLErrorCannotFindHost:
                    reason = "Host not found"
                    message = "The server could not be found"
                case NSURLErrorCannotConnectToHost:
                    reason = "Cannot connect"
                    message = "Unable to connect to the server"
                case NSURLErrorNetworkConnectionLost:
                    reason = "Connection lost"
                    message = "Network connection was lost"
                case NSURLErrorNotConnectedToInternet:
                    reason = "No internet"
                    message = "Not connected to the internet"
                case NSURLErrorSecureConnectionFailed:
                    reason = "SSL Error"
                    message = "Secure connection failed"
                case NSURLErrorServerCertificateUntrusted:
                    reason = "Certificate Error"
                    message = "Server certificate is not trusted"
                default:
                    reason = "Network Error"
                    message = error.localizedDescription
                }
            } else {
                reason = "Error"
                message = error.localizedDescription
            }
            
            return BookmarkDiagnosticResult(
                bookmark: bookmark,
                status: .unverified(reason: reason),
                httpStatusCode: nil,
                errorMessage: message
            )
        }
    }
}
