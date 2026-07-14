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
    @State private var dataImage: NSImage?
    
    init(iconString: String, size: CGFloat = 32) {
        self.iconString = iconString
        self.size = size
    }
    
    var body: some View {
        Group {
            if iconString.hasPrefix("http://") || iconString.hasPrefix("https://") {
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
                    .onFailure { _ in
                        // Fallback will be handled by parent or just empty
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if iconString.hasPrefix("data:image") {
                if let dataImage {
                    Image(nsImage: dataImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // Fallback if data URL parsing fails
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: size))
                        .foregroundStyle(.white)
                }
            } else {
                // SF Symbol
                Image(systemName: iconString)
                    .font(.system(size: size))
                .foregroundStyle(.white)
            }
        }
        .task(id: iconString) {
            guard iconString.hasPrefix("data:image") else {
                dataImage = nil
                return
            }
            dataImage = await Task.detached(priority: .utility) {
                DataIconCache.image(for: iconString)
            }.value
        }
    }
}

private enum DataIconCache {
    static let cache = NSCache<NSString, NSImage>()

    static func image(for value: String) -> NSImage? {
        if let cached = cache.object(forKey: value as NSString) {
            return cached
        }
        guard let separator = value.firstIndex(of: ","),
              let data = Data(base64Encoded: String(value[value.index(after: separator)...])),
              let image = NSImage(data: data) else {
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
