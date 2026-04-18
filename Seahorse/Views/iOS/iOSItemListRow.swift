#if os(iOS)
//
//  iOSItemListRow.swift
//  Seahorse
//

import SwiftUI

struct iOSItemListRow: View {
    let item: AnyCollectionItem
    let category: Category?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = category {
                        Text(category.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(category.color.opacity(0.2))
                            .foregroundStyle(category.color)
                            .clipShape(Capsule())
                    }

                    Text(dateString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        switch item.itemType {
        case .bookmark:
            return item.asBookmark?.title ?? "Untitled"
        case .image:
            return "Image"
        case .text:
            return item.asTextItem?.contentPreview ?? "Note"
        }
    }

    private var iconName: String {
        switch item.itemType {
        case .bookmark:
            return item.asBookmark?.icon ?? "link.circle.fill"
        case .image:
            return "photo.fill"
        case .text:
            return "doc.text.fill"
        }
    }

    private var iconColor: Color {
        switch item.itemType {
        case .bookmark:
            return .blue
        case .image:
            return .purple
        case .text:
            return .green
        }
    }

    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.addedDate, relativeTo: Date())
    }
}

#endif
