import XCTest
@testable import Seahorse

final class BookmarkParsingPolicyTests: XCTestCase {
    func testStructuredResponseDecodesBookmarkSuggestions() throws {
        let json = """
        {
          "title": "Swift Concurrency",
          "summary": "A practical guide to structured concurrency.",
          "categoryName": "Development",
          "newCategorySuggestion": null,
          "tags": ["Swift", "Concurrency"],
          "sfSymbol": "chevron.left.forwardslash.chevron.right"
        }
        """

        let parsed = try JSONDecoder().decode(ParsedBookmarkData.self, from: Data(json.utf8))

        XCTAssertEqual(parsed.refinedTitle, "Swift Concurrency")
        XCTAssertEqual(parsed.summary, "A practical guide to structured concurrency.")
        XCTAssertEqual(parsed.suggestedCategoryName, "Development")
        XCTAssertNil(parsed.suggestedNewCategoryName)
        XCTAssertEqual(parsed.suggestedTagNames, ["Swift", "Concurrency"])
        XCTAssertEqual(parsed.suggestedSFSymbol, "chevron.left.forwardslash.chevron.right")
    }

    func testResolutionPrefersExistingTaxonomyAndLimitsNewTags() {
        let development = Category(name: "Development", icon: "folder", color: .blue)
        let none = Category(name: "None", icon: "folder", color: .gray)
        let swift = Tag(name: "Swift", color: .blue)
        let ai = Tag(name: "AI", color: .purple)
        let parsed = ParsedBookmarkData(
            refinedTitle: "Title",
            summary: "Summary",
            suggestedCategoryName: " development ",
            suggestedTagNames: [
                "new topic",
                " Swift ",
                "NEW TOPIC",
                "Development",
                "Example",
                "Article",
                "new second",
                "new third",
                "example.com",
                "AI"
            ],
            suggestedSFSymbol: nil
        )

        let resolution = BookmarkParsingPolicy.resolve(
            parsed,
            sourceURL: "https://docs.example.com/article",
            categories: [development, none],
            tags: [swift, ai]
        )

        XCTAssertEqual(resolution.category?.id, development.id)
        XCTAssertEqual(resolution.existingTags.map(\.id), [swift.id, ai.id])
        XCTAssertEqual(resolution.suggestedNewTagNames, ["new topic", "new second"])
    }

    func testAutomaticMergePreservesExistingUserMetadata() {
        let currentCategory = Category(name: "Research", icon: "folder", color: .blue)
        let suggestedCategory = Category(name: "Development", icon: "folder", color: .green)
        let currentTagID = UUID()
        let resolution = BookmarkParsingResolution(
            refinedTitle: "AI Title",
            summary: "AI summary",
            category: suggestedCategory,
            suggestedNewCategoryName: nil,
            existingTags: [Tag(name: "Swift", color: .blue)],
            suggestedNewTagNames: ["concurrency"],
            suggestedSFSymbol: nil
        )
        let bookmark = Bookmark(
            title: "User Title",
            url: "https://example.com",
            categoryId: currentCategory.id,
            notes: "User summary",
            tagIds: [currentTagID]
        )

        let updated = resolution.bookmark(
            fillingMissingValuesIn: bookmark,
            unclassifiedCategoryID: UUID(),
            newTagIDs: [UUID()]
        )

        XCTAssertEqual(updated.title, "User Title")
        XCTAssertEqual(updated.notes, "User summary")
        XCTAssertEqual(updated.categoryId, currentCategory.id)
        XCTAssertEqual(updated.tagIds, [currentTagID])
        XCTAssertTrue(updated.isParsed)
    }

    func testReparseDiffLeavesUserAuthoredChangesUnselected() throws {
        let currentCategory = Category(name: "Research", icon: "folder", color: .blue)
        let suggestedCategory = Category(name: "Development", icon: "folder", color: .green)
        let currentTag = Tag(name: "Swift", color: .blue)
        let suggestedTag = Tag(name: "Concurrency", color: .purple)
        let resolution = BookmarkParsingResolution(
            refinedTitle: "AI Title",
            summary: "AI summary",
            category: suggestedCategory,
            suggestedNewCategoryName: nil,
            existingTags: [suggestedTag],
            suggestedNewTagNames: ["actors"],
            suggestedSFSymbol: nil
        )

        let diff = BookmarkParsingDiff(
            currentTitle: "User Title",
            currentSummary: "User summary",
            currentCategory: currentCategory,
            currentTags: [currentTag],
            resolution: resolution
        )

        XCTAssertFalse(try XCTUnwrap(diff.title).isSelectedByDefault)
        XCTAssertFalse(try XCTUnwrap(diff.summary).isSelectedByDefault)
        XCTAssertFalse(try XCTUnwrap(diff.category).isSelectedByDefault)
        XCTAssertFalse(try XCTUnwrap(diff.tags).isSelectedByDefault)
        XCTAssertEqual(diff.tags?.currentValue, ["Swift"])
        XCTAssertEqual(diff.tags?.suggestedValue, ["Concurrency", "actors"])
    }

    func testResolutionRejectsUnknownSFSymbol() {
        let parsed = ParsedBookmarkData(
            refinedTitle: "Title",
            summary: "Summary",
            suggestedCategoryName: nil,
            suggestedTagNames: [],
            suggestedSFSymbol: "definitely.not.a.real.symbol"
        )

        let resolution = BookmarkParsingPolicy.resolve(
            parsed,
            sourceURL: "https://example.com",
            categories: [],
            tags: []
        )

        XCTAssertNil(resolution.suggestedSFSymbol)
    }

    func testStructuredResponseRejectsMissingRequiredFields() {
        let json = """
        {
          "summary": "Missing title and tags",
          "categoryName": null,
          "newCategorySuggestion": null,
          "sfSymbol": null
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(ParsedBookmarkData.self, from: Data(json.utf8))
        )
    }

    func testAutomaticMergeFillsMissingMetadata() {
        let none = Category(name: "None", icon: "folder", color: .gray)
        let development = Category(name: "Development", icon: "folder", color: .blue)
        let swift = Tag(name: "Swift", color: .blue)
        let newTagID = UUID()
        let resolution = BookmarkParsingResolution(
            refinedTitle: "Parsed Title",
            summary: "Parsed summary",
            category: development,
            suggestedNewCategoryName: nil,
            existingTags: [swift],
            suggestedNewTagNames: ["concurrency"],
            suggestedSFSymbol: nil
        )
        let bookmark = Bookmark(
            title: "Loading...",
            url: "https://example.com",
            categoryId: none.id
        )

        let updated = resolution.bookmark(
            fillingMissingValuesIn: bookmark,
            unclassifiedCategoryID: none.id,
            newTagIDs: [newTagID]
        )

        XCTAssertEqual(updated.title, "Parsed Title")
        XCTAssertEqual(updated.notes, "Parsed summary")
        XCTAssertEqual(updated.categoryId, development.id)
        XCTAssertEqual(updated.tagIds, [swift.id, newTagID])
    }

    func testAutomaticMergeReplacesOnlyMatchingProvisionalMetadata() {
        let resolution = BookmarkParsingResolution(
            refinedTitle: "AI Title",
            summary: "AI summary",
            category: nil,
            suggestedNewCategoryName: nil,
            existingTags: [],
            suggestedNewTagNames: [],
            suggestedSFSymbol: nil
        )
        let provisionalBookmark = Bookmark(
            title: "OGP Title",
            url: "https://example.com",
            categoryId: UUID(),
            notes: "OGP summary"
        )

        let replaced = resolution.bookmark(
            fillingMissingValuesIn: provisionalBookmark,
            unclassifiedCategoryID: nil,
            newTagIDs: [],
            provisionalTitle: "OGP Title",
            provisionalSummary: "OGP summary"
        )
        var editedBookmark = provisionalBookmark
        editedBookmark.title = "User Title"
        editedBookmark.notes = "User summary"
        let preserved = resolution.bookmark(
            fillingMissingValuesIn: editedBookmark,
            unclassifiedCategoryID: nil,
            newTagIDs: [],
            provisionalTitle: "OGP Title",
            provisionalSummary: "OGP summary"
        )

        XCTAssertEqual(replaced.title, "AI Title")
        XCTAssertEqual(replaced.notes, "AI summary")
        XCTAssertEqual(preserved.title, "User Title")
        XCTAssertEqual(preserved.notes, "User summary")
    }

    func testUnknownCategoryCanOnlyBecomeInteractiveSuggestion() {
        let parsed = ParsedBookmarkData(
            refinedTitle: "Title",
            summary: "Summary",
            suggestedCategoryName: "Invented",
            suggestedTagNames: [],
            suggestedSFSymbol: nil,
            suggestedNewCategoryName: " New Research "
        )

        let resolution = BookmarkParsingPolicy.resolve(
            parsed,
            sourceURL: "https://example.com",
            categories: [],
            tags: []
        )

        XCTAssertNil(resolution.category)
        XCTAssertEqual(resolution.suggestedNewCategoryName, "New Research")
    }

    func testExistingCategorySuppressesNewCategorySuggestion() {
        let development = Category(name: "Development", icon: "folder", color: .blue)
        let parsed = ParsedBookmarkData(
            refinedTitle: "Title",
            summary: "Summary",
            suggestedCategoryName: "Development",
            suggestedTagNames: [],
            suggestedSFSymbol: nil,
            suggestedNewCategoryName: "New Research"
        )

        let resolution = BookmarkParsingPolicy.resolve(
            parsed,
            sourceURL: "https://example.com",
            categories: [development],
            tags: []
        )

        XCTAssertEqual(resolution.category?.id, development.id)
        XCTAssertNil(resolution.suggestedNewCategoryName)
    }
}
