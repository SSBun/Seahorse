import AppKit
import XCTest
@testable import Seahorse

final class AgentProviderProfileTests: XCTestCase {
    func testInitialProfilesMigrateExistingOpenAICompatibleSettings() {
        let profiles = AgentProviderProfile.initialProfiles(
            apiBaseURL: "https://example.com/v1",
            model: "existing-model"
        )

        XCTAssertEqual(profiles.first, .codex)
        XCTAssertEqual(
            profiles.last,
            AgentProviderProfile(
                id: AgentProviderProfile.legacyOpenAIID,
                name: AgentProviderKind.openAICompatible.displayName,
                kind: .openAICompatible,
                apiBaseURL: "https://example.com/v1",
                model: "existing-model"
            )
        )
    }

    func testProfilePersistenceDoesNotContainCredentialFields() throws {
        let profile = AgentProviderProfile.make(kind: .claudeCompatible)

        let data = try JSONEncoder().encode(profile)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["apiToken"])
        XCTAssertNil(object["token"])
        XCTAssertEqual(object["kind"] as? String, "claude-compatible")
    }

    func testImageGenerationExcludesClaudeCompatibleProviders() {
        XCTAssertTrue(AgentProviderKind.openAICodex.supportsImageGeneration)
        XCTAssertTrue(AgentProviderKind.openAICompatible.supportsImageGeneration)
        XCTAssertFalse(AgentProviderKind.claudeCompatible.supportsImageGeneration)
    }

    func testCoverStylesHaveDistinctGenerationPrompts() {
        XCTAssertEqual(CoverStyle.allCases.count, 8)
        XCTAssertEqual(Set(CoverStyle.allCases.map(\.prompt)).count, CoverStyle.allCases.count)
        XCTAssertEqual(Set(CoverStyle.allCases.map(\.exampleAssetName)).count, CoverStyle.allCases.count)
        XCTAssertTrue(CoverStyle.allCases.allSatisfy { !$0.title.isEmpty && !$0.prompt.isEmpty })
        for style in CoverStyle.allCases {
            XCTAssertNotNil(NSImage(named: style.exampleAssetName), "Missing image asset for \(style.title)")
        }
    }

    func testImageGenerationRecordRoundTripsWithoutTransientImage() throws {
        let task = ImageGenerationTask(
            bookmarkId: UUID(),
            bookmarkTitle: "Example",
            style: .cinematic,
            createdAt: Date(timeIntervalSince1970: 123),
            status: .completed,
            referenceImageFilename: "cover-reference-example.png",
            imageFilename: "generated-cover-example.png",
            imageWidth: 1536,
            imageHeight: 1024,
            imageByteCount: 42,
            imageFormat: "PNG"
        )

        let restored = try JSONDecoder().decode(
            ImageGenerationTask.self,
            from: JSONEncoder().encode(task)
        )

        XCTAssertEqual(restored.id, task.id)
        XCTAssertEqual(restored.status, .completed)
        XCTAssertEqual(restored.referenceImageFilename, "cover-reference-example.png")
        XCTAssertEqual(restored.imageFilename, "generated-cover-example.png")
        XCTAssertEqual(restored.imageWidth, 1536)
        XCTAssertNil(restored.generatedImage)

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(task)) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "referenceImageFilename")
        let legacyTask = try JSONDecoder().decode(
            ImageGenerationTask.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        XCTAssertNil(legacyTask.referenceImageFilename)
    }
}
