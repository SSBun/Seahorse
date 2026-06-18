//
//  ImageGenerationPanelView.swift
//  Seahorse
//

import SwiftUI

struct ImageGenerationPanelView: View {
    @ObservedObject var service: ImageGenerationService
    let onApply: (UUID, NSImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Cover Generation")
                    .font(.system(size: 13, weight: .semibold))
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if service.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No generation tasks")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.tasks) { task in
                            taskRow(task)
                            if task.id != service.tasks.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: min(CGFloat(service.tasks.count) * 80 + 60, 400))
    }

    @ViewBuilder
    private func taskRow(_ task: ImageGenerationTask) -> some View {
        HStack(spacing: 10) {
            // Thumbnail or spinner
            Group {
                switch task.status {
                case .queued:
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                case .generating:
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 40, height: 40)
                case .completed:
                    if let image = task.generatedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                    }
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 40, height: 40)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(task.bookmarkTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(statusText(task.status))
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor(task.status))
            }

            Spacer()

            // Actions
            switch task.status {
            case .completed:
                if let image = task.generatedImage {
                    Button("Apply") {
                        onApply(task.id, image)
                    }
                    .font(.system(size: 11))
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
        case .queued: return "Queued"
        case .generating: return "Generating..."
        case .completed: return "Completed"
        case .failed(let msg): return msg.count > 40 ? String(msg.prefix(40)) + "..." : msg
        }
    }

    private func statusColor(_ status: ImageGenerationStatus) -> Color {
        switch status {
        case .queued: return .secondary
        case .generating: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
