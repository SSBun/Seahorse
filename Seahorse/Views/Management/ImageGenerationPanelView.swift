#if os(macOS)
//
//  ImageGenerationPanelView.swift
//  Seahorse
//

import SwiftUI
import UniformTypeIdentifiers

struct ImageGenerationPanelView: View {
    @EnvironmentObject private var dataStorage: DataStorage
    @ObservedObject var service: ImageGenerationService
    @State private var selectedStyle: CoverStyle = .editorial
    @State private var selectedTaskID: UUID?

    private let styleColumns = [
        GridItem(.adaptive(minimum: 132, maximum: 180), spacing: 12)
    ]

    private var preparedBookmark: Bookmark? {
        guard let id = service.preparedBookmarkID else { return nil }
        return dataStorage.item(for: id)?.asBookmark
    }

    private var selectedTask: ImageGenerationTask? {
        service.tasks.first { $0.id == selectedTaskID }
    }

    var body: some View {
        Group {
            if let task = selectedTask {
                ImageGenerationDetailView(
                    task: task,
                    onBack: { selectedTaskID = nil },
                    onApply: { image in applyGeneratedCover(taskId: task.id, image: image) }
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let bookmark = preparedBookmark {
                                creationSection(for: bookmark)
                                Divider()
                            }
                            historySection
                        }
                        .padding(18)
                    }
                }
            }
        }
        .frame(minWidth: 660, minHeight: 560)
    }

    private var header: some View {
        HStack {
            Text("Cover Generation")
                .font(.system(size: 14, weight: .semibold))
            if service.activeCount > 0 {
                Text("\(service.activeCount) running")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if service.tasks.contains(where: { $0.status.isTerminal }) {
                Button("Clear Completed") {
                    service.clearCompleted()
                }
                .font(.system(size: 11))
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func creationSection(for bookmark: Bookmark) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create a cover")
                    .font(.system(size: 18, weight: .semibold))
                Text(bookmark.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let referenceImage = service.preparedReferenceImage {
                HStack(spacing: 10) {
                    Image(nsImage: referenceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Example image")
                            .font(.system(size: 12, weight: .medium))
                        Text("The generated cover will use this image as a visual reference.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        service.clearPreparedReferenceImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove example image")
                }
            }

            Text("Choose a style")
                .font(.system(size: 12, weight: .medium))

            LazyVGrid(columns: styleColumns, alignment: .leading, spacing: 12) {
                ForEach(CoverStyle.allCases) { style in
                    styleCard(style)
                }
            }

            Button {
                service.generate(for: bookmark, style: selectedStyle)
            } label: {
                Label("Generate Cover", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func styleCard(_ style: CoverStyle) -> some View {
        Button {
            selectedStyle = style
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(style.exampleAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(style.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(style.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        selectedStyle == style ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: selectedStyle == style ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityValue(selectedStyle == style ? "Selected" : style.subtitle)
        .accessibilityAddTraits(selectedStyle == style ? .isSelected : [])
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generations")
                .font(.system(size: 13, weight: .semibold))

            if service.tasks.isEmpty {
                Text("Generated covers will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(service.tasks) { task in
                        taskRow(task)
                        if task.id != service.tasks.last?.id {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: ImageGenerationTask) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedTaskID = task.id
            } label: {
                HStack(spacing: 12) {
                    Group {
                        switch task.status {
                        case .queued:
                            Image(systemName: "clock")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        case .generating:
                            ProgressView()
                                .controlSize(.small)
                        case .completed:
                            if let image = task.generatedImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.green)
                            }
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.bookmarkTitle)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text("\(task.style.title) · \(statusText(task.status))")
                            .font(.system(size: 10))
                            .foregroundStyle(statusColor(task.status))
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(task.generatedImage == nil)

            Spacer()

            switch task.status {
            case .completed:
                if let image = task.generatedImage {
                    Button("Apply") {
                        applyGeneratedCover(taskId: task.id, image: image)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            case .failed, .generating, .queued:
                Button(action: { service.removeTask(id: task.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statusText(_ status: ImageGenerationStatus) -> String {
        switch status {
        case .queued: "Queued"
        case .generating: "Generating..."
        case .completed: "Completed"
        case .failed(let message): message
        }
    }

    private func statusColor(_ status: ImageGenerationStatus) -> Color {
        switch status {
        case .queued: .secondary
        case .generating: .blue
        case .completed: .green
        case .failed: .red
        }
    }

    private func applyGeneratedCover(taskId: UUID, image: NSImage) {
        guard service.applyImage(taskId: taskId) != nil,
              let task = service.tasks.first(where: { $0.id == taskId }) else { return }
        let imagesDir = StorageManager.shared.getImagesDirectory()
        Task { @MainActor in
            guard let filename = try? await ImageFileService.shared.savePNG(
                image,
                to: imagesDir,
                prefix: "preview"
            ), let bookmark = dataStorage.item(for: task.bookmarkId)?.asBookmark else {
                Log.error("Failed to write preview image to disk", category: .ai)
                return
            }
            var updated = bookmark
            if updated.metadata != nil {
                updated.metadata?.imageURL = filename
            } else {
                updated.metadata = WebMetadata(imageURL: filename, url: updated.url)
            }
            try? dataStorage.updateBookmark(updated)
            Log.info("Applied generated cover to bookmark: \"\(bookmark.title)\"", category: .ai)
        }
    }
}

private struct ImageGenerationDetailView: View {
    let task: ImageGenerationTask
    let onBack: () -> Void
    let onApply: (NSImage) -> Void

    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Back to generations")

                Text(task.bookmarkTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if let image = task.generatedImage {
                    Button("Apply") { onApply(image) }
                        .buttonStyle(.bordered)
                }
                Button("Export", action: exportImage)
                    .buttonStyle(.borderedProminent)
                    .disabled(task.imageFilename == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HSplitView {
                if let filename = task.imageFilename {
                    ImageViewer(imagePath: filename)
                        .id(task.id)
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Image not found")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Image Metadata")
                        .font(.system(size: 13, weight: .semibold))
                    metadataRow("Bookmark", task.bookmarkTitle)
                    metadataRow("Style", task.style.title)
                    metadataRow("Generated", task.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let width = task.imageWidth, let height = task.imageHeight {
                        metadataRow("Dimensions", "\(width) × \(height) px")
                    }
                    if let bytes = task.imageByteCount {
                        metadataRow("File Size", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    }
                    if let format = task.imageFormat {
                        metadataRow("Format", format)
                    }
                    if let filename = task.imageFilename {
                        metadataRow("File", filename)
                    }
                    if let referenceFilename = task.referenceImageFilename {
                        metadataRow("Example Image", referenceFilename)
                    }
                    Spacer()
                    Text("Pinch to zoom. Drag to pan. Double-click to reset.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Unknown error")
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11))
                .textSelection(.enabled)
        }
    }

    private func exportImage() {
        guard let filename = task.imageFilename else { return }
        let sourceURL = URL(fileURLWithPath: StorageManager.shared.resolveImagePath(filename))
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "cover-\(task.id.uuidString.prefix(8)).png"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        do {
            try Data(contentsOf: sourceURL).write(to: destinationURL, options: .atomic)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
#endif
