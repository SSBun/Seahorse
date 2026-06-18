//
//  ImageGenerationService.swift
//  Seahorse
//

import SwiftUI
import OSLog

enum ImageGenerationStatus: Equatable {
    case queued
    case generating
    case completed
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .failed, .completed: return true
        default: return false
        }
    }
}

struct ImageGenerationTask: Identifiable, Equatable {
    let id = UUID()
    let bookmarkId: UUID
    let bookmarkTitle: String
    let createdAt: Date
    var status: ImageGenerationStatus
    var generatedImage: NSImage?

    static func == (lhs: ImageGenerationTask, rhs: ImageGenerationTask) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class ImageGenerationService: ObservableObject {
    static let shared = ImageGenerationService()

    @Published var tasks: [ImageGenerationTask] = []
    @Published var showingPanel = false

    var activeCount: Int {
        tasks.filter { !$0.status.isTerminal }.count
    }

    var isRunning: Bool {
        tasks.contains { !$0.status.isTerminal }
    }

    private var backgroundTasks: [UUID: Task<(), Never>] = [:]

    func generate(for bookmark: Bookmark) {
        let taskEntry = ImageGenerationTask(
            bookmarkId: bookmark.id,
            bookmarkTitle: bookmark.title,
            createdAt: Date(),
            status: .queued
        )
        tasks.append(taskEntry)
        Log.info("Queued cover generation for: \"\(bookmark.title)\"", category: .ai)

        let taskId = taskEntry.id
        let backgroundTask: Task<(), Never> = Task.detached { [weak self] in
            guard let self else { return }
            await self.runGeneration(taskId: taskId, bookmark: bookmark)
        }
        backgroundTasks[taskId] = backgroundTask
    }

    func removeTask(id: UUID) {
        backgroundTasks[id]?.cancel()
        backgroundTasks.removeValue(forKey: id)
        tasks.removeAll { $0.id == id }
    }

    func clearCompleted() {
        let completedIds = tasks.filter { $0.status.isTerminal }.map(\.id)
        for id in completedIds {
            backgroundTasks.removeValue(forKey: id)
        }
        tasks.removeAll { $0.status.isTerminal }
    }

    func applyImage(taskId: UUID) -> NSImage? {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }),
              let image = tasks[index].generatedImage else { return nil }
        tasks[index].status = .completed
        return image
    }

    private func runGeneration(taskId: UUID, bookmark: Bookmark) async {
        updateStatus(taskId: taskId, status: .generating)

        do {
            let aiManager = AIManager()
            let imageData = try await aiManager.generateCoverImage(
                title: bookmark.title,
                description: bookmark.metadata?.description,
                url: bookmark.url,
                siteName: bookmark.metadata?.siteName
            )

            guard let image = NSImage(data: imageData) else {
                Log.error("Failed to create NSImage from data (\(imageData.count) bytes)", category: .ai)
                updateStatus(taskId: taskId, status: .failed("Failed to decode image"))
                return
            }

            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].generatedImage = image
                tasks[index].status = .completed
            }
            Log.info("Cover generation completed for: \"\(bookmark.title)\"", category: .ai)
        } catch {
            Log.error("Cover generation failed: \(error.localizedDescription)", category: .ai)
            updateStatus(taskId: taskId, status: .failed(error.localizedDescription))
        }
    }

    private func updateStatus(taskId: UUID, status: ImageGenerationStatus) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = status
        }
    }
}
