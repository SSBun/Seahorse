#if os(macOS)
import Foundation

enum SidebarSelection: Hashable, Identifiable {
    case category(UUID)
    case tag(UUID)
    case smartCollection(UUID)
    case recent
    case unorganized
    case trash

    var id: String {
        switch self {
        case .category(let id): "category-\(id.uuidString)"
        case .tag(let id): "tag-\(id.uuidString)"
        case .smartCollection(let id): "smart-\(id.uuidString)"
        case .recent: "recent"
        case .unorganized: "unorganized"
        case .trash: "trash"
        }
    }
}
#endif
