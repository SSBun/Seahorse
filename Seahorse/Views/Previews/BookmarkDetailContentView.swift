#if os(macOS)
//
//  BookmarkDetailContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import AppKit
import WebKit

struct BookmarkDetailContentView: View {
    @EnvironmentObject var dataStorage: DataStorage
    let bookmark: Bookmark
    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var showWebPreview = false

    // Snapshot state
    @State private var isSnapshotMode = false
    @State private var snapshotSelection: CGRect?
    @State private var snapshotOverlaySize: CGSize = .zero
    @State private var isSavingSnapshot = false
    @State private var snapshotError: String?
    @AppStorage("snapshotAspectRatioV2") private var snapshotAspectRatio = SnapshotAspectRatio.sixteenNine.rawValue

    private var currentBookmark: Bookmark? {
        dataStorage.item(for: bookmark.id)?.asBookmark ?? bookmark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            bookmarkToolbar
            loadingBar

            if showWebPreview {
                webPreview
            } else {
                webPreviewPlaceholder
            }
        }
        .onAppear {
            Log.info("detail_open bookmark_detail_appear", category: .performance)
        }
    }

    @ViewBuilder
    private var webPreview: some View {
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
                            aspectRatio: $snapshotAspectRatio,
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

    private var webPreviewPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(currentBookmark?.url ?? bookmark.url)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Button {
                showWebPreview = true
            } label: {
                Label("Open Web Preview", systemImage: "safari")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var loadingBar: some View {
        if showWebPreview && isLoading {
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .frame(height: 2)
        } else {
            Color.clear
                .frame(height: 2)
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
            .disabled(!showWebPreview)
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
            .disabled(!showWebPreview)
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
                    Log.error("snapshot_save failed to write image bookmark=\(bookmark.id.uuidString)", category: .ui)
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
            Log.info("snapshot_preview_updated bookmark=\(updated.id.uuidString) image=\(path)", category: .ui)
        } catch {
            snapshotError = "Failed to save preview image to bookmark."
            Log.error("snapshot_preview_update_failed bookmark=\(updated.id.uuidString) error=\(error.localizedDescription)", category: .ui)
        }
    }
}

// MARK: - Snapshot Selection Overlay

private struct SnapshotSelectionOverlay: View {
    @Binding var selection: CGRect?
    @Binding var aspectRatio: String
    let containerSize: CGSize
    let isSaving: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let errorMessage: String?

    @State private var dragStart: CGPoint?
    @State private var movingStartRect: CGRect?
    @State private var resizingStartRect: CGRect?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.12)
                .contentShape(Rectangle())
                .gesture(createGesture)
                .onTapGesture {
                    selection = nil
                }

                if let rect = selection {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(
                            Rectangle()
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .allowsHitTesting(false)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            isHovering ? NSCursor.openHand.set() : NSCursor.arrow.set()
                        }
                        .onTapGesture {}
                        .highPriorityGesture(moveGesture)
                        .zIndex(1)
                        .animation(.easeInOut(duration: 0.1), value: rect)

                    ForEach(ResizeHandle.allCases) { handle in
                        Circle()
                            .fill(Color.accentColor)
                            .stroke(.white, lineWidth: 1)
                            .frame(width: 10, height: 10)
                            .padding(8)
                            .contentShape(Rectangle())
                            .position(handle.point(in: rect))
                            .highPriorityGesture(resizeGesture(handle))
                            .zIndex(2)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Drag to select an area")
                        .font(.system(size: 12, weight: .semibold))
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Picker("Ratio", selection: $aspectRatio) {
                        ForEach(SnapshotAspectRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 96)
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
            .zIndex(3)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStart ?? value.startLocation
                dragStart = start
                selection = rect(from: start, to: value.location, aspectRatio: selectedAspectRatio.value)
            }
            .onEnded { value in
                let start = dragStart ?? value.startLocation
                selection = rect(from: start, to: value.location, aspectRatio: selectedAspectRatio.value)
                dragStart = nil
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard let rect = movingStartRect ?? selection else { return }
                movingStartRect = rect
                NSCursor.closedHand.set()
                selection = clamped(
                    CGRect(
                        x: rect.origin.x + value.translation.width,
                        y: rect.origin.y + value.translation.height,
                        width: rect.width,
                        height: rect.height
                    )
                )
            }
            .onEnded { _ in
                movingStartRect = nil
                NSCursor.openHand.set()
            }
    }

    private func resizeGesture(_ handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard let rect = resizingStartRect ?? selection else { return }
                resizingStartRect = rect
                selection = resized(rect, handle: handle, translation: value.translation)
            }
            .onEnded { _ in
                resizingStartRect = nil
            }
    }

    private var selectedAspectRatio: SnapshotAspectRatio {
        SnapshotAspectRatio(rawValue: aspectRatio) ?? .fourThree
    }

    private func rect(from start: CGPoint, to end: CGPoint, aspectRatio: CGFloat?) -> CGRect {
        let start = clamped(start)
        let end = clamped(end)

        guard let aspectRatio else {
            return clamped(
                CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
            )
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        var width = abs(dx)
        var height = abs(dy)

        if width / max(height, 1) > aspectRatio {
            width = height * aspectRatio
        } else {
            height = width / aspectRatio
        }

        return clamped(
            CGRect(
                x: dx >= 0 ? start.x : start.x - width,
                y: dy >= 0 ? start.y : start.y - height,
                width: width,
                height: height
            )
        )
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), containerSize.width),
            y: min(max(point.y, 0), containerSize.height)
        )
    }

    private func clamped(_ rect: CGRect) -> CGRect {
        CGRect(
            x: min(max(rect.origin.x, 0), max(containerSize.width - rect.width, 0)),
            y: min(max(rect.origin.y, 0), max(containerSize.height - rect.height, 0)),
            width: min(rect.width, containerSize.width),
            height: min(rect.height, containerSize.height)
        )
    }

    private func resized(_ startRect: CGRect, handle: ResizeHandle, translation: CGSize) -> CGRect {
        let anchor = handle.anchor(in: startRect)
        let dragged = CGPoint(
            x: handle.point(in: startRect).x + translation.width,
            y: handle.point(in: startRect).y + translation.height
        )
        return rect(from: anchor, to: dragged, aspectRatio: selectedAspectRatio.value)
    }

    private enum ResizeHandle: CaseIterable, Identifiable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var id: Self { self }

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft:
                return CGPoint(x: rect.minX, y: rect.minY)
            case .topRight:
                return CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft:
                return CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight:
                return CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }

        func anchor(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft:
                return CGPoint(x: rect.maxX, y: rect.maxY)
            case .topRight:
                return CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomLeft:
                return CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomRight:
                return CGPoint(x: rect.minX, y: rect.minY)
            }
        }
    }
}

private enum SnapshotAspectRatio: String, CaseIterable, Identifiable {
    case free = "Free"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case square = "1:1"
    case threeTwo = "3:2"

    var id: String { rawValue }

    var value: CGFloat? {
        switch self {
        case .free:
            return nil
        case .fourThree:
            return 4.0 / 3.0
        case .sixteenNine:
            return 16.0 / 9.0
        case .square:
            return 1.0
        case .threeTwo:
            return 3.0 / 2.0
        }
    }
}


#endif
