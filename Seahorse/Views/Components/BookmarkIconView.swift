#if os(macOS)
//
//  BookmarkIconView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import Kingfisher

struct BookmarkIconView: View {
    let iconString: String
    let size: CGFloat
    let allowsImageLoading: Bool
    let onRemoteLoadResult: ((String, Bool, String) -> Void)?
    @State private var dataImage: NSImage?
    @State private var loadedIconString: String?
    
    init(
        iconString: String,
        size: CGFloat = 32,
        allowsImageLoading: Bool = true,
        onRemoteLoadResult: ((String, Bool, String) -> Void)? = nil
    ) {
        self.iconString = iconString
        self.size = size
        self.allowsImageLoading = allowsImageLoading
        self.onRemoteLoadResult = onRemoteLoadResult
    }
    
    var body: some View {
        Group {
            if iconString.hasPrefix("http://") || iconString.hasPrefix("https://") {
                if allowsImageLoading || loadedIconString == iconString {
                    // Remote URL
                    KFImage(URL(string: iconString))
                        .setProcessor(DownsamplingImageProcessor(size: CGSize(width: size * 2, height: size * 2)))
                        .scaleFactor(NSScreen.main?.backingScaleFactor ?? 2.0)
                        .cacheOriginalImage()
                        .placeholder {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        .fade(duration: 0.15)
                        .onSuccess { result in
                            loadedIconString = iconString
                            onRemoteLoadResult?(
                                iconString,
                                true,
                                String(describing: result.cacheType)
                            )
                        }
                        .onFailure { _ in
                            onRemoteLoadResult?(iconString, false, "none")
                        }
                        .cancelOnDisappear(true)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    placeholderIcon
                }
            } else if iconString.hasPrefix("data:image") {
                if loadedIconString == iconString, let dataImage {
                    Image(nsImage: dataImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    placeholderIcon
                }
            } else {
                // SF Symbol
                Image(systemName: iconString)
                    .font(.system(size: size))
                .foregroundStyle(.white)
            }
        }
        .task(id: dataImageLoadID) {
            guard allowsImageLoading, iconString.hasPrefix("data:image") else { return }
            let decodeTask = Task.detached(priority: .utility) {
                DataIconCache.image(for: iconString)
            }
            let decodedImage = await withTaskCancellationHandler {
                await decodeTask.value
            } onCancel: {
                decodeTask.cancel()
            }
            guard !Task.isCancelled else { return }
            dataImage = decodedImage
            loadedIconString = decodedImage == nil ? nil : iconString
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "link.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(.white)
    }

    private var dataImageLoadID: String? {
        allowsImageLoading ? iconString : nil
    }
}

private enum DataIconCache {
    static let cache = NSCache<NSString, NSImage>()

    static func image(for value: String) -> NSImage? {
        if let cached = cache.object(forKey: value as NSString) {
            return cached
        }
        guard !Task.isCancelled,
              let separator = value.firstIndex(of: ","),
              let data = Data(base64Encoded: String(value[value.index(after: separator)...])),
              !Task.isCancelled,
              let image = NSImage(data: data),
              !Task.isCancelled else {
            return nil
        }
        cache.setObject(image, forKey: value as NSString)
        return image
    }
}

#Preview {
    HStack(spacing: 20) {
        // SF Symbol
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            BookmarkIconView(iconString: "book.fill", size: 32)
        }
        .frame(width: 80, height: 80)
        
        // Remote URL
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            BookmarkIconView(iconString: "https://github.com/favicon.ico", size: 32)
        }
        .frame(width: 80, height: 80)
    }
    .padding()
}


#endif
