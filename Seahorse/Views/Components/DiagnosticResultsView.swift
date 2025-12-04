//
//  DiagnosticResultsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import AppKit

enum DiagnosticErrorCategory: String, CaseIterable, Identifiable {
    case all = "All Errors"
    case notFound = "Not Found (404)"
    case forbidden = "Access Denied (401/403)"
    case serverError = "Server Error (5xx)"
    case networkError = "Network Error"
    case timeout = "Timeout"
    case sslError = "SSL/Certificate"
    case invalidURL = "Invalid URL"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "exclamationmark.triangle.fill"
        case .notFound: return "questionmark.circle.fill"
        case .forbidden: return "lock.fill"
        case .serverError: return "server.rack"
        case .networkError: return "wifi.exclamationmark"
        case .timeout: return "clock.badge.exclamationmark.fill"
        case .sslError: return "lock.shield.fill"
        case .invalidURL: return "link.badge.plus"
        case .other: return "exclamationmark.circle.fill"
        }
    }
    
    func matches(_ result: BookmarkDiagnosticResult) -> Bool {
        guard case .broken(let reason) = result.status else { return false }
        
        switch self {
        case .all:
            return true
        case .notFound:
            return reason.contains("Not Found") || reason.contains("404") || reason.contains("Gone")
        case .forbidden:
            return reason.contains("Forbidden") || reason.contains("401") || reason.contains("403") || reason.contains("Unauthorized")
        case .serverError:
            return reason.contains("Server Error") || reason.contains("5")
        case .networkError:
            return reason.contains("Network Error") || reason.contains("Cannot connect") || reason.contains("Connection lost") || reason.contains("Host not found") || reason.contains("No internet")
        case .timeout:
            return reason.contains("Timeout")
        case .sslError:
            return reason.contains("SSL") || reason.contains("Certificate")
        case .invalidURL:
            return reason.contains("Invalid URL") || reason.contains("Unsupported protocol")
        case .other:
            return !DiagnosticErrorCategory.allCases.dropFirst().dropLast().contains { category in
                category != .all && category != .other && category.matches(result)
            }
        }
    }
}

struct DiagnosticResultsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStorage: DataStorage
    @ObservedObject var diagnosticService: DiagnosticService
    
    @State private var selectedResults = Set<UUID>()
    @State private var showingDeleteConfirmation = false
    @State private var selectedCategory: DiagnosticErrorCategory = .all
    
    var filteredResults: [BookmarkDiagnosticResult] {
        diagnosticService.brokenBookmarks.filter { selectedCategory.matches($0) }
    }
    
    var categoryCounts: [DiagnosticErrorCategory: Int] {
        var counts: [DiagnosticErrorCategory: Int] = [:]
        for category in DiagnosticErrorCategory.allCases {
            let count = diagnosticService.brokenBookmarks.filter { category.matches($0) }.count
            if count > 0 {
                counts[category] = count
            }
        }
        return counts
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnostic Results")
                        .font(.system(size: 20, weight: .semibold))
                    
                    if diagnosticService.isRunning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            
                            Text("Checking \(diagnosticService.checkedCount) of \(diagnosticService.totalCount)...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            if !diagnosticService.brokenBookmarks.isEmpty {
                                Text("• \(diagnosticService.brokenBookmarks.count) broken")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                        }
                    } else if !diagnosticService.brokenBookmarks.isEmpty {
                        Text("\(diagnosticService.brokenBookmarks.count) broken bookmarks found")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    } else if diagnosticService.checkedCount > 0 {
                        Text("All bookmarks are accessible ✓")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                // Stop button when running
                if diagnosticService.isRunning {
                    Button(action: {
                        diagnosticService.stop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Stop diagnostic scan")
                }
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Category filter (show when there are broken bookmarks, updates in real-time during scan)
            if !diagnosticService.brokenBookmarks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DiagnosticErrorCategory.allCases) { category in
                            if let count = categoryCounts[category], count > 0 {
                                CategoryFilterButton(
                                    category: category,
                                    count: count,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        selectedCategory = category
                                        selectedResults.removeAll() // Clear selection when changing category
                                    }
                                )
                            }
                        }
                        
                        // Show "updating" indicator during scan
                        if diagnosticService.isRunning {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text("Updating...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
            }
            
            // Progress bar
            if diagnosticService.isRunning {
                VStack(spacing: 8) {
                    ProgressView(value: diagnosticService.progress)
                        .progressViewStyle(.linear)
                    
                    if let current = diagnosticService.currentBookmark {
                        Text("Checking: \(current.title)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
            }
            
            // Results list
            if diagnosticService.brokenBookmarks.isEmpty {
                // Empty state or scanning with no errors yet
                VStack(spacing: 16) {
                    if diagnosticService.isRunning {
                        // Scanning, no errors found yet
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 8)
                        
                        Text("Scanning...")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("No broken bookmarks found yet")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else if diagnosticService.checkedCount > 0 {
                        // Scan complete, all good
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("All Good!")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("All your bookmarks are accessible.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        // No scan run yet
                        Image(systemName: "stethoscope")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("No Results Yet")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Run diagnostics to check your bookmarks.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show results (updates in real-time during scan)
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredResults) { result in
                            DiagnosticResultRow(
                                result: result,
                                isSelected: selectedResults.contains(result.id)
                            ) {
                                toggleSelection(result.id)
                            }
                        }
                    }
                    .padding(.top, 1)
                }
            }
            
            // Footer with actions
            if !diagnosticService.brokenBookmarks.isEmpty {
                Divider()
                
                HStack(spacing: 12) {
                    if !selectedResults.isEmpty {
                        Text("\(selectedResults.count) selected")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    if selectedCategory != .all {
                        Text("• \(selectedCategory.rawValue)")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }
                    
                    // Show scanning status in footer
                    if diagnosticService.isRunning {
                        HStack(spacing: 4) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Scanning in progress")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Select All in Current Category (disabled while scanning)
                    if selectedResults.count < filteredResults.count {
                        Button(selectedCategory == .all ? "Select All" : "Select All in Category") {
                            selectedResults = Set(filteredResults.map { $0.id })
                        }
                        .buttonStyle(.borderless)
                        .disabled(diagnosticService.isRunning)
                    }
                    
                    if !selectedResults.isEmpty {
                        Button("Deselect All") {
                            selectedResults.removeAll()
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Delete Selected (\(selectedResults.count))") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(diagnosticService.isRunning)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(width: 700, height: 600)
        .alert("Delete Bookmarks", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedBookmarks()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedResults.count) broken bookmark(s)? This action cannot be undone.")
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedResults.contains(id) {
            selectedResults.remove(id)
        } else {
            selectedResults.insert(id)
        }
    }
    
    private func deleteSelectedBookmarks() {
        let bookmarksToDelete = diagnosticService.brokenBookmarks
            .filter { selectedResults.contains($0.id) }
            .map { $0.bookmark }
        
        for bookmark in bookmarksToDelete {
            try? dataStorage.deleteBookmark(bookmark)
        }
        
        // Remove deleted items from results
        diagnosticService.brokenBookmarks.removeAll { selectedResults.contains($0.id) }
        selectedResults.removeAll()
    }
}

struct DiagnosticResultRow: View {
    let result: BookmarkDiagnosticResult
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                onToggle()
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .onTapGesture {
                // Prevent event from bubbling to parent
            }
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.1))
                
                BookmarkIconView(iconString: result.bookmark.icon, size: 16)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 32, height: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(result.bookmark.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .opacity(isHovered ? 1.0 : 0.0)
                }
                
                Text(result.bookmark.url)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if case .broken(let reason) = result.status {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                        
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        
                        if let errorMessage = result.errorMessage {
                            Text("• \(errorMessage)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status badge
            if let statusCode = result.httpStatusCode {
                Text("\(statusCode)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusCode >= 400 ? Color.red : Color.orange)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            // Open URL in browser for verification
            if let url = URL(string: result.bookmark.url) {
                NSWorkspace.shared.open(url)
            }
        }
        .help("Click to open URL in browser for verification")
    }
}

struct CategoryFilterButton: View {
    let category: DiagnosticErrorCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.red : Color(NSColor.controlBackgroundColor))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.red.opacity(0.1) : Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help("Filter by \(category.rawValue)")
    }
}

#Preview {
    let dataStorage = DataStorage.shared
    let diagnosticService = DiagnosticService(dataStorage: dataStorage)
    
    DiagnosticResultsView(diagnosticService: diagnosticService)
        .environmentObject(dataStorage)
}

