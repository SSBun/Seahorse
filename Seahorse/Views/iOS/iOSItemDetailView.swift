#if os(iOS)
//
//  iOSItemDetailView.swift
//  Seahorse
//

import SwiftUI

struct iOSItemDetailView: View {
    let item: AnyCollectionItem
    @EnvironmentObject var dataStorage: DataStorage

    var body: some View {
        contentView
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = externalURL {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "safari")
                        }
                    }
                }
            }
    }

    private var externalURL: URL? {
        guard item.itemType == .bookmark,
              let bookmark = item.asBookmark else { return nil }
        return URL(string: bookmark.url)
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.itemType {
        case .bookmark:
            if let bookmark = item.asBookmark, let url = URL(string: bookmark.url) {
                iOSWebView(url: url)
                    .ignoresSafeArea(edges: .bottom)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        metadataSection
                    }
            } else {
                unavailableContent
            }
        case .image:
            if let imageItem = item.asImageItem {
                ScrollView {
                    iOSImageView(imagePath: imageItem.imagePath)
                        .frame(maxWidth: .infinity)
                    metadataSection
                }
            } else {
                unavailableContent
            }
        case .text:
            if let textItem = item.asTextItem {
                ScrollView {
                    iOSTextNoteView(textItem: textItem)
                    metadataSection
                }
            } else {
                unavailableContent
            }
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Content unavailable")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let category = dataStorage.category(for: item.categoryId) {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.caption2)
                        Text(category.name)
                            .font(.caption)
                    }
                    .foregroundStyle(category.color)
                }

                Spacer()

                Label(item.addedDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let tags = dataStorage.tags(for: item.tagIds)
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.secondarySystemFill))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationTitle: String {
        switch item.itemType {
        case .bookmark:
            return item.asBookmark?.title ?? "Bookmark"
        case .image:
            return "Image"
        case .text:
            return "Note"
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#endif
