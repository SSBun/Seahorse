import XCTest
@testable import Seahorse

final class CollectionSearchBenchmarkTests: XCTestCase {
    func testSearchBenchmarksAtExpectedScales() {
        for count in [300, 3_000, 10_000] {
            let items = makeItems(count: count)
            let buildStart = ContinuousClock.now
            let records = CollectionSearch.makeRecords(items: items, tagsByID: [:])
            let buildDuration = buildStart.duration(to: .now)

            var queryDurations: [Duration] = []
            for queryIndex in 0..<20 {
                let queryStart = ContinuousClock.now
                let results = CollectionSearch.items(
                    in: records,
                    matching: CollectionSearch.Criteria(
                        query: "target-\(queryIndex % 10)",
                        order: .nameAscending
                    )
                )
                queryDurations.append(queryStart.duration(to: .now))
                XCTAssertFalse(results.isEmpty)
            }

            let sorted = queryDurations.sorted()
            let p50 = sorted[sorted.count / 2]
            let p95 = sorted[Int(Double(sorted.count - 1) * 0.95)]
            let metrics = "search_benchmark count=\(count) build_ms=\(milliseconds(buildDuration)) p50_ms=\(milliseconds(p50)) p95_ms=\(milliseconds(p95))"
            XCTContext.runActivity(named: metrics) { _ in }

            XCTAssertLessThan(milliseconds(p95), 1_000, "10,000 条以内的单次后台搜索不应达到秒级")
        }
    }

    private func makeItems(count: Int) -> [AnyCollectionItem] {
        let categoryID = UUID()
        return (0..<count).map { index in
            AnyCollectionItem(Bookmark(
                title: "Bookmark \(index) target-\(index % 10)",
                url: "https://example\(index % 50).com/item/\(index)",
                categoryId: categoryID,
                addedDate: Date(timeIntervalSince1970: TimeInterval(index)),
                notes: "Fixture notes \(index)"
            ))
        }
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }
}
