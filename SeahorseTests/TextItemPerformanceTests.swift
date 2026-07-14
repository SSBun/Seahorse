import XCTest
@testable import Seahorse

final class TextItemPerformanceTests: XCTestCase {
    private let categoryID = UUID()

    func testFirstLineRecognizesFoundationNewlineCharacters() {
        XCTAssertEqual(String(item("First\rSecond").firstLine), "First")
        XCTAssertEqual(String(item("First\u{2028}Second").firstLine), "First")
        XCTAssertEqual(String(item("No newline").firstLine), "No newline")
    }

    func testContentPreviewStopsAtTwoHundredCharacters() {
        let exact = String(repeating: "🙂", count: 200)
        let long = exact + "last"

        XCTAssertEqual(item(exact).contentPreview, exact)
        XCTAssertEqual(item(long).contentPreview, exact + "...")
    }

    private func item(_ content: String) -> TextItem {
        TextItem(content: content, categoryId: categoryID)
    }
}
