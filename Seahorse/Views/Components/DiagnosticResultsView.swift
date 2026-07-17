#if os(macOS)
//
//  DiagnosticResultsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import AppKit

enum DiagnosticErrorCategory: String, CaseIterable, Identifiable {
    case all = "All Issues"
    case notFound = "Not Found / Gone"
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
        guard let reason = result.status.reason else { return false }

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

private enum DiagnosticPhase {
    case selection
    case results
}

struct DiagnosticResultsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStorage: DataStorage
    @ObservedObject var diagnosticService: DiagnosticService

    @State private var phase: DiagnosticPhase = .selection
    @State private var selectedBookmarkIds: Set<UUID> = []
    @State private var searchText = ""

    // Results phase state
    @State private var selectedResults = Set<UUID>()
    @State private var showingDeleteConfirmation = false
    @State private var selectedCategory: DiagnosticErrorCategory = .all

    /// Returns broken and unverified results in scan order.
    /// - Complexity: O(n).
    private var issueResults: [BookmarkDiagnosticResult] {
        diagnosticService.results.filter { result in
            result.status.reason != nil
        }
    }

    private var filteredBookmarks: [Bookmark] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = dataStorage.bookmarks
        if query.isEmpty { return all }
        return all.filter {
            $0.title.lowercased().contains(query) ||
            $0.url.lowercased().contains(query)
        }
    }

    var filteredResults: [BookmarkDiagnosticResult] {
        issueResults.filter { selectedCategory.matches($0) }
    }

    /// Returns filtered results that are safe to offer for deletion.
    /// - Complexity: O(n).
    var deletableFilteredResults: [BookmarkDiagnosticResult] {
        filteredResults.filter { result in
            if case .broken = result.status { return true }
            return false
        }
    }

    /// Returns filtered results that require manual verification.
    /// - Complexity: O(n).
    var unverifiedFilteredResults: [BookmarkDiagnosticResult] {
        filteredResults.filter { result in
            if case .unverified = result.status { return true }
            return false
        }
    }

    var categoryCounts: [DiagnosticErrorCategory: Int] {
        var counts: [DiagnosticErrorCategory: Int] = [:]
        for category in DiagnosticErrorCategory.allCases {
            let count = issueResults.filter { category.matches($0) }.count
            if count > 0 {
                counts[category] = count
            }
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if phase == .selection {
                selectionContent
            } else {
                resultsContent
            }
        }
        .frame(width: 700, height: 600)
        .alert("Move Bookmarks to Trash", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                deleteSelectedBookmarks()
            }
        } message: {
            Text("Move \(selectedResults.count) broken bookmark(s) to Trash? You can restore them later.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnostic")
                    .font(.system(size: 20, weight: .semibold))

                if phase == .results {
                    headerSubtitle
                }
            }

            Spacer()

            if phase == .selection {
                // Back to results if scan was previously run
                if !issueResults.isEmpty && !diagnosticService.isRunning {
                    Button("View Previous Results") {
                        phase = .results
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 12))
                }
            } else if diagnosticService.isRunning {
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
    }

    @ViewBuilder
    private var headerSubtitle: some View {
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

                if !diagnosticService.unverifiedBookmarks.isEmpty {
                    Text("• \(diagnosticService.unverifiedBookmarks.count) unverified")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }
        } else if !issueResults.isEmpty {
            HStack(spacing: 6) {
                if !diagnosticService.brokenBookmarks.isEmpty {
                    Text("\(diagnosticService.brokenBookmarks.count) broken")
                        .foregroundStyle(.red)
                }
                if !diagnosticService.unverifiedBookmarks.isEmpty {
                    Text("\(diagnosticService.unverifiedBookmarks.count) unverified")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12))
        } else if diagnosticService.checkedCount > 0 {
            Text("All bookmarks are accessible ✓")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        }
    }

    // MARK: - Selection Phase

    private var selectionContent: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            Divider()

            // Bookmark list
            if filteredBookmarks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No bookmarks found")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredBookmarks) { bookmark in
                            DiagnosticBookmarkRow(
                                bookmark: bookmark,
                                isSelected: selectedBookmarkIds.contains(bookmark.id),
                                onToggle: {
                                    if selectedBookmarkIds.contains(bookmark.id) {
                                        selectedBookmarkIds.remove(bookmark.id)
                                    } else {
                                        selectedBookmarkIds.insert(bookmark.id)
                                    }
                                }
                            )
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()

            // Footer
            selectionFooter
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Search bookmarks...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(16)
    }

    private var selectionFooter: some View {
        HStack(spacing: 12) {
            Button(action: {
                if selectedBookmarkIds.count == filteredBookmarks.count {
                    selectedBookmarkIds.removeAll()
                } else {
                    selectedBookmarkIds = Set(filteredBookmarks.map { $0.id })
                }
            }) {
                Text(selectedBookmarkIds.count == filteredBookmarks.count && !filteredBookmarks.isEmpty ? "Deselect All" : "Select All")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(filteredBookmarks.isEmpty)

            Spacer()

            Text("\(filteredBookmarks.count) bookmarks")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(action: {
                let selected = dataStorage.bookmarks.filter { selectedBookmarkIds.contains($0.id) }
                diagnosticService.start(bookmarks: selected)
                phase = .results
            }) {
                Text("Check Selected (\(selectedBookmarkIds.count))")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedBookmarkIds.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Results Phase

    private var resultsContent: some View {
        VStack(spacing: 0) {
            // Category filter
            if !issueResults.isEmpty {
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
                                        selectedResults.removeAll()
                                    }
                                )
                            }
                        }

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
            if issueResults.isEmpty {
                resultsEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        if !deletableFilteredResults.isEmpty {
                            resultSectionHeader(
                                title: "Broken",
                                count: deletableFilteredResults.count,
                                color: .red
                            )
                            ForEach(deletableFilteredResults) { result in
                                DiagnosticResultRow(
                                    result: result,
                                    isSelected: selectedResults.contains(result.id)
                                ) {
                                    toggleSelection(result.id)
                                }
                            }
                        }

                        if !unverifiedFilteredResults.isEmpty {
                            resultSectionHeader(
                                title: "Unverified",
                                count: unverifiedFilteredResults.count,
                                color: .orange
                            )
                            ForEach(unverifiedFilteredResults) { result in
                                DiagnosticResultRow(
                                    result: result,
                                    isSelected: false,
                                    onToggle: { }
                                )
                            }
                        }
                    }
                    .padding(.top, 1)
                }
            }

            // Footer with actions
            if !issueResults.isEmpty {
                Divider()

                resultsFooter
            }
        }
    }

    private func resultSectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var resultsEmptyState: some View {
        VStack(spacing: 16) {
            if diagnosticService.isRunning {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)

                Text("Scanning...")
                    .font(.system(size: 18, weight: .semibold))

                Text("No link issues found yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if diagnosticService.checkedCount > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("All Good!")
                    .font(.system(size: 18, weight: .semibold))

                Text("All your bookmarks are accessible.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
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
    }

    private var resultsFooter: some View {
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

            // New scan button
            Button("New Scan") {
                selectedResults.removeAll()
                selectedCategory = .all
                phase = .selection
            }
            .buttonStyle(.borderless)

            if !deletableFilteredResults.isEmpty,
               selectedResults.count < deletableFilteredResults.count {
                Button(selectedCategory == .all ? "Select All" : "Select All in Category") {
                    selectedResults = Set(deletableFilteredResults.map { $0.id })
                }
                .buttonStyle(.borderless)
                .disabled(diagnosticService.isRunning)
            }

            if !selectedResults.isEmpty {
                Button("Deselect All") {
                    selectedResults.removeAll()
                }
                .buttonStyle(.borderless)

                Button("Move Selected to Trash (\(selectedResults.count))") {
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

        do {
            try dataStorage.deleteItems(ids: bookmarksToDelete.map(\.id))
            diagnosticService.results.removeAll { selectedResults.contains($0.id) }
            diagnosticService.brokenBookmarks.removeAll { selectedResults.contains($0.id) }
            selectedResults.removeAll()
        } catch {
            GlobalToastManager.shared.show(message: error.localizedDescription, icon: "xmark.circle.fill")
        }
    }
}

// MARK: - Bookmark Selection Row

private struct DiagnosticBookmarkRow: View {
    let bookmark: Bookmark
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            BookmarkIconView(iconString: bookmark.icon, size: 16)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                if let url = URL(string: bookmark.url), let host = url.host {
                    Text(host)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Result Row

struct DiagnosticResultRow: View {
    let result: BookmarkDiagnosticResult
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    private var isBroken: Bool {
        if case .broken = result.status { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            if isBroken {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .onTapGesture { }
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill((isBroken ? Color.red : Color.orange).opacity(0.1))

                BookmarkIconView(iconString: result.bookmark.icon, size: 16)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 32, height: 32)

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

                if let reason = result.status.reason {
                    HStack(spacing: 4) {
                        Image(systemName: isBroken ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isBroken ? .red : .orange)

                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(isBroken ? .red : .orange)

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

            if let statusCode = result.httpStatusCode {
                Text("\(statusCode)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isBroken ? Color.red : Color.orange)
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
            if let url = URL(string: result.bookmark.url) {
                NSWorkspace.shared.open(url)
            }
        }
        .help("Click to open URL in browser for verification")
    }
}

// MARK: - Category Filter Button

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

#endif
