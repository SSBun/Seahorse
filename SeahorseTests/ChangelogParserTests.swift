import XCTest
@testable import Seahorse

final class ChangelogParserTests: XCTestCase {
    func testSectionsReturnsOnlyRequestedVersionUntilNextVersion() {
        let markdown = """
        ## [Unreleased]

        ### Added
        - Future change

        ## [1.8.0] - 2026-07-14

        ### Added
        - Current feature

        ### Fixed
        - Current fix

        ## [1.7.0] - 2026-07-09

        ### Added
        - Previous feature
        """

        let sections = ChangelogParser.sections(for: "1.8.0", in: markdown)

        XCTAssertEqual(
            sections,
            [
                ChangelogSection(title: "Added", items: ["Current feature"]),
                ChangelogSection(title: "Fixed", items: ["Current fix"]),
            ]
        )
    }

    func testSectionsRequiresAnExactVersionHeading() {
        let markdown = """
        ## [1.8.0-beta] - 2026-07-01

        ### Added
        - Beta feature
        """

        XCTAssertTrue(ChangelogParser.sections(for: "1.8.0", in: markdown).isEmpty)
    }

    func testSectionsReturnsEmptyWhenVersionIsMissingOrHasNoItems() {
        let markdown = """
        ## [1.8.0] - 2026-07-14

        ### Added

        ## [1.7.0] - 2026-07-09

        ### Added
        - Previous feature
        """

        XCTAssertTrue(ChangelogParser.sections(for: "1.8.0", in: markdown).isEmpty)
        XCTAssertTrue(ChangelogParser.sections(for: "2.0.0", in: markdown).isEmpty)
    }
}
