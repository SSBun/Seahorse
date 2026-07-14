import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

actor ImageFileService {
    static let shared = ImageFileService()

    enum Error: Swift.Error, Equatable {
        case sourceNotReadable
        case unsupportedFormat
        case encodingFailed
    }

    private let validExtensions = Set([
        "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp"
    ])

    func copyImage(from sourceURL: URL, to directory: URL) throws -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw Error.sourceNotReadable
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard validExtensions.contains(fileExtension) else {
            throw Error.unsupportedFormat
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).\(fileExtension)"
        try FileManager.default.copyItem(
            at: sourceURL,
            to: directory.appendingPathComponent(filename)
        )
        return filename
    }

    #if os(macOS)
    func savePNG(_ image: NSImage, to directory: URL, prefix: String = "image") throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw Error.encodingFailed
        }
        return try writePNG(pngData, to: directory, prefix: prefix)
    }
    #elseif os(iOS)
    func savePNG(_ image: UIImage, to directory: URL, prefix: String = "image") throws -> String {
        guard let pngData = image.pngData() else {
            throw Error.encodingFailed
        }
        return try writePNG(pngData, to: directory, prefix: prefix)
    }
    #endif

    private func writePNG(_ data: Data, to directory: URL, prefix: String) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(prefix)-\(UUID().uuidString).png"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }
}
