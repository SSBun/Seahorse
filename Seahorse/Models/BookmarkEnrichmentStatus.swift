import Foundation

enum BookmarkEnrichmentStatus: String, Codable {
    case pending
    case fetchingMetadata
    case parsingWithAI
    case failed
}
