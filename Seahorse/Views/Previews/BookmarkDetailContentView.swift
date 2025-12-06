//
//  BookmarkDetailContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import WebKit

struct BookmarkDetailContentView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    
    // Snapshot state
    @State private var isSnapshotMode = false
    @State private var snapshotSelection: CGRect?
    @State private var snapshotOverlaySize: CGSize = .zero
    @State private var isSavingSnapshot = false
    @State private var snapshotError: String?
    
    private var currentBookmark: Bookmark? {
        dataStorage.bookmarks.first(where: { $0.id == bookmark.id }) ?? bookmark
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            bookmarkToolbar
            
            // WebView
            if let bookmark = currentBookmark,
               let url = URL(string: bookmark.url) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ControllableWebView(
                            url: url,
                            webView: $webView,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            isLoading: $isLoading
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear {
                                        snapshotOverlaySize = proxy.size
                                    }
                                    .onChange(of: proxy.size) { _, newValue in
                                        snapshotOverlaySize = newValue
                                    }
                            }
                        )
                        
                        if isSnapshotMode {
                            SnapshotSelectionOverlay(
                                selection: $snapshotSelection,
                                containerSize: geo.size,
                                isSaving: isSavingSnapshot,
                                onSave: captureSnapshot,
                                onCancel: exitSnapshotMode,
                                errorMessage: snapshotError
                            )
                        }
                    }
                }
            } else {
                Text("Invalid URL")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var bookmarkToolbar: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: {
                webView?.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .foregroundStyle(canGoBack ? .primary : .secondary)
            .frame(width: 28, height: 28)
            .background(canGoBack ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .cornerRadius(6)
            
            // Forward button
            Button(action: {
                webView?.goForward()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .foregroundStyle(canGoForward ? .primary : .secondary)
            .frame(width: 28, height: 28)
            .background(canGoForward ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .cornerRadius(6)
            
            Divider()
                .frame(height: 20)
            
            // Open in Browser button
            Button(action: {
                let targetURL = currentBookmark?.url ?? bookmark.url
                if let url = URL(string: targetURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "safari")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help("Open in Browser")
            
            // Refresh button
            Button(action: {
                if isLoading {
                    webView?.stopLoading()
                } else {
                    webView?.reload()
                }
            }) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help(isLoading ? "Stop Loading" : "Refresh")
            
            // Snapshot button
            Button(action: toggleSnapshotMode) {
                Image(systemName: isSnapshotMode ? "camera.metering.matrix" : "camera.viewfinder")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSnapshotMode ? Color.accentColor : .primary)
            .frame(width: 28, height: 28)
            .background(isSnapshotMode ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help(isSnapshotMode ? "Exit snapshot mode" : "Capture snapshot for preview")
            
            // Copy Link button
            Button(action: {
                let targetURL = currentBookmark?.url ?? bookmark.url
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(targetURL, forType: .string)
            }) {
                Image(systemName: "link")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help("Copy Link")
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - Snapshot Actions
    
    private func toggleSnapshotMode() {
        if isSnapshotMode {
            exitSnapshotMode()
        } else {
            snapshotSelection = nil
            snapshotError = nil
            isSnapshotMode = true
        }
    }
    
    private func exitSnapshotMode() {
        isSnapshotMode = false
        snapshotSelection = nil
        snapshotError = nil
    }
    
    private func captureSnapshot() {
        guard let selection = snapshotSelection,
              selection.width > 1,
              selection.height > 1 else {
            snapshotError = "Drag to select an area before saving."
            return
        }
        
        guard let webView = webView else {
            snapshotError = "Web view not ready yet."
            return
        }
        
        let overlaySize = snapshotOverlaySize
        guard overlaySize.width > 0, overlaySize.height > 0 else {
            snapshotError = "Unable to measure web view size."
            return
        }
        
        let bounds = webView.bounds
        let scaleX = bounds.width / overlaySize.width
        let scaleY = bounds.height / overlaySize.height
        let rect = CGRect(
            x: selection.origin.x * scaleX,
            y: selection.origin.y * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )
        
        let config = WKSnapshotConfiguration()
        config.rect = rect
        
        isSavingSnapshot = true
        snapshotError = nil
        
        webView.takeSnapshot(with: config) { image, error in
            DispatchQueue.main.async {
                self.isSavingSnapshot = false
                
                if let error = error {
                    self.snapshotError = error.localizedDescription
                    return
                }
                
                guard let image = image else {
                    self.snapshotError = "Snapshot failed to produce an image."
                    return
                }
                
                guard let path = saveImageToStorage(image) else {
                    self.snapshotError = "Could not save snapshot image."
                    return
                }
                
                updatePreviewImagePath(path)
                exitSnapshotMode()
            }
        }
    }
    
    private func saveImageToStorage(_ image: NSImage) -> String? {
        let imagesDir = StorageManager.shared.getImagesDirectory()
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            snapshotError = "Failed to prepare storage directory."
            return nil
        }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            snapshotError = "Unable to convert snapshot to PNG."
            return nil
        }
        
        let filename = "snapshot-\(UUID().uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            return filename // store filename only for portability
        } catch {
            snapshotError = "Failed to write snapshot: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func updatePreviewImagePath(_ path: String) {
        guard var updated = currentBookmark else { return }
        
        if updated.metadata != nil {
            updated.metadata?.imageURL = path
        } else {
            updated.metadata = WebMetadata(imageURL: path, url: updated.url)
        }
        
        do {
            try dataStorage.updateBookmark(updated)
        } catch {
            snapshotError = "Failed to save preview image to bookmark."
        }
    }
}

// MARK: - Snapshot Selection Overlay

private struct SnapshotSelectionOverlay: View {
    @Binding var selection: CGRect?
    let containerSize: CGSize
    let isSaving: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let errorMessage: String?
    
    @State private var dragStart: CGPoint?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.12)
                .contentShape(Rectangle())
                .gesture(dragGesture)
            
            if let rect = selection {
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Rectangle().fill(Color.accentColor.opacity(0.2)))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .animation(.easeInOut(duration: 0.1), value: rect)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Drag to select an area")
                        .font(.system(size: 12, weight: .semibold))
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else if selection == nil {
                    Text("Click and drag over the page to choose the snapshot rectangle.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.ultraThickMaterial)
            .cornerRadius(10)
            .padding()
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? value.startLocation
                dragStart = start
                selection = rect(from: start, to: value.location)
            }
            .onEnded { value in
                let start = dragStart ?? value.startLocation
                selection = rect(from: start, to: value.location)
                dragStart = nil
            }
    }
    
    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

