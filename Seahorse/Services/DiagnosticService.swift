//
//  DiagnosticService.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//
//  Concurrent diagnostic processing with up to 10 parallel workers
//  Uses Swift's TaskGroup for safe concurrency and an Actor for thread-safe state management

import Foundation

enum BookmarkStatus {
    case checking
    case accessible
    case broken(reason: String)
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
    @Published var isRunning = false
    @Published var currentBookmark: Bookmark?
    @Published var progress: Double = 0
    @Published var totalCount: Int = 0
    @Published var checkedCount: Int = 0
    @Published var results: [BookmarkDiagnosticResult] = []
    @Published var brokenBookmarks: [BookmarkDiagnosticResult] = []
    
    private var task: Task<Void, Never>?
    private weak var dataStorage: DataStorage?
    
    init(dataStorage: DataStorage) {
        self.dataStorage = dataStorage
    }
    
    func start() {
        guard !isRunning, let dataStorage = dataStorage else { return }
        
        let allBookmarks = dataStorage.bookmarks
        guard !allBookmarks.isEmpty else { return }
        
        isRunning = true
        totalCount = allBookmarks.count
        checkedCount = 0
        progress = 0
        results = []
        brokenBookmarks = []
        
        print("🚀 Starting concurrent diagnostic scan")
        print("  📊 Total bookmarks: \(allBookmarks.count)")
        print("  ⚡️ Concurrent workers: 10")
        
        let startTime = Date()
        
        task = Task {
            await performConcurrentDiagnostics(bookmarks: allBookmarks)
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Diagnostic scan complete")
            print("  ⏱️ Duration: \(String(format: "%.2f", duration)) seconds")
            print("  📈 Speed: \(String(format: "%.1f", Double(allBookmarks.count) / duration)) bookmarks/second")
            print("  ❌ Broken bookmarks: \(self.brokenBookmarks.count)")
            
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
                return (results, brokenResults, checkedCount)
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
            let (_, response) = try await NetworkManager.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                
                switch statusCode {
                case 200...299:
                    return BookmarkDiagnosticResult(
                        bookmark: bookmark,
                        status: .accessible,
                        httpStatusCode: statusCode,
                        errorMessage: nil
                    )
                case 300...399:
                    // Redirect - still accessible
                    return BookmarkDiagnosticResult(
                        bookmark: bookmark,
                        status: .accessible,
                        httpStatusCode: statusCode,
                        errorMessage: nil
                    )
                case 400...499:
                    let reason: String
                    switch statusCode {
                    case 401:
                        reason = "Unauthorized (401)"
                    case 403:
                        reason = "Forbidden (403)"
                    case 404:
                        reason = "Not Found (404)"
                    case 410:
                        reason = "Gone (410)"
                    default:
                        reason = "Client Error (\(statusCode))"
                    }
                    return BookmarkDiagnosticResult(
                        bookmark: bookmark,
                        status: .broken(reason: reason),
                        httpStatusCode: statusCode,
                        errorMessage: "The page returned an error: \(reason)"
                    )
                case 500...599:
                    return BookmarkDiagnosticResult(
                        bookmark: bookmark,
                        status: .broken(reason: "Server Error (\(statusCode))"),
                        httpStatusCode: statusCode,
                        errorMessage: "The server is experiencing issues"
                    )
                default:
                    return BookmarkDiagnosticResult(
                        bookmark: bookmark,
                        status: .broken(reason: "Unknown Status (\(statusCode))"),
                        httpStatusCode: statusCode,
                        errorMessage: "Unexpected HTTP status code"
                    )
                }
            }
            
            return BookmarkDiagnosticResult(
                bookmark: bookmark,
                status: .accessible,
                httpStatusCode: nil,
                errorMessage: nil
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
                status: .broken(reason: reason),
                httpStatusCode: nil,
                errorMessage: message
            )
        }
    }
}

