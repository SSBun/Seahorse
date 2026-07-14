import AppKit
import XCTest
@testable import Seahorse

final class ImageFileServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testCopyImagePreservesExtensionAndContents() async throws {
        let source = temporaryDirectory.appendingPathComponent("source.webp")
        let expected = Data([0, 1, 2, 3, 4])
        try expected.write(to: source)
        let destination = temporaryDirectory.appendingPathComponent("Images", isDirectory: true)

        let filename = try await ImageFileService.shared.copyImage(from: source, to: destination)

        XCTAssertEqual(URL(fileURLWithPath: filename).pathExtension, "webp")
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(filename)), expected)
    }

    func testCopyImageRejectsUnsupportedExtension() async throws {
        let source = temporaryDirectory.appendingPathComponent("source.txt")
        try Data("not an image".utf8).write(to: source)

        do {
            _ = try await ImageFileService.shared.copyImage(from: source, to: temporaryDirectory)
            XCTFail("Expected unsupported extension")
        } catch let error as ImageFileService.Error {
            XCTAssertEqual(error, .unsupportedFormat)
        }
    }

    func testSavePNGReturnsPortableFilenameAndWritesPNG() async throws {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        let filename = try await ImageFileService.shared.savePNG(
            image,
            to: temporaryDirectory,
            prefix: "preview"
        )

        XCTAssertTrue(filename.hasPrefix("preview-"))
        XCTAssertEqual(URL(fileURLWithPath: filename).pathExtension, "png")
        let data = try Data(contentsOf: temporaryDirectory.appendingPathComponent(filename))
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }
}
