#if os(macOS)
//
//  ImageGenerationService.swift
//  Seahorse
//

import SwiftUI
import OSLog

enum CoverStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case editorial
    case minimal
    case gradient
    case illustration
    case cinematic
    case surreal
    case clay3D
    case geometric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editorial: "Editorial"
        case .minimal: "Minimal"
        case .gradient: "Gradient"
        case .illustration: "Illustration"
        case .cinematic: "Cinematic"
        case .surreal: "Surreal"
        case .clay3D: "Soft 3D"
        case .geometric: "Geometric"
        }
    }

    var subtitle: String {
        switch self {
        case .editorial: "Refined magazine art"
        case .minimal: "Simple and quiet"
        case .gradient: "Luminous digital color"
        case .illustration: "Expressive drawn art"
        case .cinematic: "Dramatic photography"
        case .surreal: "Dreamlike photography"
        case .clay3D: "Tactile sculpted forms"
        case .geometric: "Bold abstract structure"
        }
    }

    var exampleAssetName: String {
        switch self {
        case .editorial: "coverExampleEditorial"
        case .minimal: "coverExampleMinimal"
        case .gradient: "coverExampleGradient"
        case .illustration: "coverExampleIllustration"
        case .cinematic: "coverExampleCinematic"
        case .surreal: "coverExampleSurreal"
        case .clay3D: "coverExampleClay3D"
        case .geometric: "coverExampleGeometric"
        }
    }

    var prompt: String {
        switch self {
        case .editorial:
            "Editorial magazine art direction with a sophisticated focal point, asymmetric composition, balanced negative space, a restrained warm palette, tactile paper texture, and a premium print finish."
        case .minimal:
            "Minimalist art with one clear symbolic form, generous negative space, a restrained neutral palette with one accent color, precise geometry, and soft natural lighting."
        case .gradient:
            "Abstract luminous gradient artwork with flowing translucent color fields, soft depth, subtle grain, and a vivid contemporary digital aesthetic."
        case .illustration:
            "Polished editorial illustration with expressive hand-drawn shapes, confident color blocking, subtle texture, and warm narrative character."
        case .cinematic:
            "Cinematic photographic scene with dramatic natural lighting, atmospheric depth, rich contrast, realistic detail, and premium film-still color grading."
        case .surreal:
            "Surreal editorial photography with one impossible architectural gesture, dreamlike scale, refined muted color, realistic detail, and a calm contemplative mood."
        case .clay3D:
            "Premium soft 3D clay render with rounded sculptural forms, tactile materials, controlled studio lighting, gentle shadows, and sophisticated color harmony."
        case .geometric:
            "Abstract geometric cover art with a monumental arch, layered angular forms, a restrained Bauhaus-inspired palette, subtle paper grain, and a bold balanced composition."
        }
    }
}

enum ImageGenerationStatus: Codable, Equatable {
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

struct ImageGenerationTask: Codable, Identifiable, Equatable {
    var id = UUID()
    let bookmarkId: UUID
    let bookmarkTitle: String
    let style: CoverStyle
    let createdAt: Date
    var status: ImageGenerationStatus
    var referenceImageFilename: String?
    var imageFilename: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var imageByteCount: Int64?
    var imageFormat: String?

    var generatedImage: NSImage? {
        guard let imageFilename else { return nil }
        return NSImage(contentsOfFile: StorageManager.shared.resolveImagePath(imageFilename))
    }

    static func == (lhs: ImageGenerationTask, rhs: ImageGenerationTask) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class ImageGenerationService: ObservableObject {
    static let shared = ImageGenerationService()

    @Published var tasks: [ImageGenerationTask] = []
    @Published private(set) var preparedBookmarkID: UUID?
    @Published private(set) var preparedReferenceImage: NSImage?

    var activeCount: Int {
        tasks.filter { !$0.status.isTerminal }.count
    }

    var isRunning: Bool {
        tasks.contains { !$0.status.isTerminal }
    }

    private var backgroundTasks: [UUID: Task<(), Never>] = [:]

    private init() {
        loadTasks()
    }

    func prepare(for bookmark: Bookmark, referenceImage: NSImage? = nil) {
        preparedBookmarkID = bookmark.id
        preparedReferenceImage = referenceImage
    }

    /// Clears the transient bookmark selected for a new generation.
    func clearPreparedBookmark() {
        preparedBookmarkID = nil
        preparedReferenceImage = nil
    }

    func clearPreparedReferenceImage() {
        preparedReferenceImage = nil
    }

    func generate(for bookmark: Bookmark, style: CoverStyle) {
        let referenceImageData = preparedReferenceImage?.tiffRepresentation
        let taskEntry = ImageGenerationTask(
            bookmarkId: bookmark.id,
            bookmarkTitle: bookmark.title,
            style: style,
            createdAt: Date(),
            status: .queued
        )
        tasks.append(taskEntry)
        persistTasks()
        Log.info("Queued \(style.rawValue) cover generation for: \"\(bookmark.title)\"", category: .ai)

        let taskId = taskEntry.id
        let backgroundTask: Task<(), Never> = Task.detached { [weak self] in
            guard let self else { return }
            await self.runGeneration(
                taskId: taskId,
                bookmark: bookmark,
                style: style,
                referenceImageData: referenceImageData
            )
        }
        backgroundTasks[taskId] = backgroundTask
    }

    func removeTask(id: UUID) {
        backgroundTasks[id]?.cancel()
        backgroundTasks.removeValue(forKey: id)
        if let task = tasks.first(where: { $0.id == id }) {
            deleteImages(for: task)
        }
        tasks.removeAll { $0.id == id }
        persistTasks()
    }

    func clearCompleted() {
        let completedTasks = tasks.filter { $0.status.isTerminal }
        for task in completedTasks {
            backgroundTasks.removeValue(forKey: task.id)
            deleteImages(for: task)
        }
        tasks.removeAll { $0.status.isTerminal }
        persistTasks()
    }

    func applyImage(taskId: UUID) -> NSImage? {
        tasks.first(where: { $0.id == taskId })?.generatedImage
    }

    private func runGeneration(
        taskId: UUID,
        bookmark: Bookmark,
        style: CoverStyle,
        referenceImageData: Data?
    ) async {
        defer { backgroundTasks.removeValue(forKey: taskId) }
        updateStatus(taskId: taskId, status: .generating)

        do {
            var referencePNGData: Data?
            if let referenceImageData {
                guard let referenceImage = NSImage(data: referenceImageData) else {
                    updateStatus(taskId: taskId, status: .failed("Failed to decode reference image"))
                    return
                }
                let referenceFilename = try await ImageFileService.shared.savePNG(
                    referenceImage,
                    to: StorageManager.shared.getImagesDirectory(),
                    prefix: "cover-reference"
                )
                guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
                    try? FileManager.default.removeItem(
                        at: StorageManager.shared.getImagesDirectory().appendingPathComponent(referenceFilename)
                    )
                    return
                }
                tasks[index].referenceImageFilename = referenceFilename
                persistTasks()
                referencePNGData = try Data(
                    contentsOf: StorageManager.shared.getImagesDirectory().appendingPathComponent(referenceFilename)
                )
            }

            let aiManager = AIManager()
            let imageData = try await aiManager.generateCoverImage(
                title: bookmark.title,
                description: bookmark.metadata?.description,
                url: bookmark.url,
                siteName: bookmark.metadata?.siteName,
                stylePrompt: style.prompt,
                referenceImageData: referencePNGData
            )

            guard let image = NSImage(data: imageData) else {
                Log.error("Failed to create NSImage from data (\(imageData.count) bytes)", category: .ai)
                updateStatus(taskId: taskId, status: .failed("Failed to decode image"))
                return
            }

            let filename = try await ImageFileService.shared.savePNG(
                image,
                to: StorageManager.shared.getImagesDirectory(),
                prefix: "generated-cover"
            )
            guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
                try? FileManager.default.removeItem(
                    at: StorageManager.shared.getImagesDirectory().appendingPathComponent(filename)
                )
                return
            }
            let fileURL = StorageManager.shared.getImagesDirectory().appendingPathComponent(filename)
            let byteCount = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value
            let representation = image.representations.first
            tasks[index].imageFilename = filename
            tasks[index].imageWidth = representation?.pixelsWide
            tasks[index].imageHeight = representation?.pixelsHigh
            tasks[index].imageByteCount = byteCount
            tasks[index].imageFormat = "PNG"
            tasks[index].status = .completed
            persistTasks()
            Log.info("Cover generation completed for: \"\(bookmark.title)\"", category: .ai)
        } catch {
            Log.error("Cover generation failed: \(error.localizedDescription)", category: .ai)
            updateStatus(taskId: taskId, status: .failed(error.localizedDescription))
        }
    }

    private func updateStatus(taskId: UUID, status: ImageGenerationStatus) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = status
            persistTasks()
        }
    }

    private var recordsURL: URL {
        StorageManager.shared.getDataDirectory().appendingPathComponent("image-generations.json")
    }

    private func loadTasks() {
        guard FileManager.default.fileExists(atPath: recordsURL.path) else { return }
        do {
            var loaded = try JSONDecoder().decode(
                [ImageGenerationTask].self,
                from: Data(contentsOf: recordsURL)
            )
            var changed = false
            for index in loaded.indices {
                if !loaded[index].status.isTerminal {
                    loaded[index].status = .failed("Interrupted when the app closed")
                    changed = true
                }
                if let filename = loaded[index].imageFilename {
                    let path = StorageManager.shared.resolveImagePath(filename)
                    if loaded[index].status == .completed && !FileManager.default.fileExists(atPath: path) {
                        loaded[index].status = .failed("Generated image file is missing")
                        changed = true
                    }
                }
            }
            tasks = loaded
            if changed { persistTasks() }
        } catch {
            Log.error("Failed to load image generation records: \(error.localizedDescription)", category: .storage)
        }
    }

    private func persistTasks() {
        do {
            try FileManager.default.createDirectory(
                at: recordsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(tasks).write(to: recordsURL, options: .atomic)
        } catch {
            Log.error("Failed to save image generation records: \(error.localizedDescription)", category: .storage)
        }
    }

    private func deleteImages(for task: ImageGenerationTask) {
        for filename in [task.imageFilename, task.referenceImageFilename].compactMap({ $0 }) {
            guard (filename.hasPrefix("generated-cover-") || filename.hasPrefix("cover-reference-")),
                  URL(fileURLWithPath: filename).lastPathComponent == filename else { continue }
            try? FileManager.default.removeItem(
                at: StorageManager.shared.getImagesDirectory().appendingPathComponent(filename)
            )
        }
    }
}
#endif
