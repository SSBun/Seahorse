import Foundation

enum SmartCollectionDateFilter: String, CaseIterable, Codable, Identifiable {
    case anyTime
    case today
    case lastSevenDays
    case lastThirtyDays
    case custom

    var id: String { rawValue }
}
