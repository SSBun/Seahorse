#if os(iOS)
//
//  iOSImageView.swift
//  Seahorse
//

import SwiftUI
import Kingfisher

struct iOSImageView: View {
    let imagePath: String

    var body: some View {
        if let url = imageURL {
            KFImage.url(url)
                .cacheOriginalImage()
                .placeholder {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
                .onFailure { _ in }
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
    }

    private var imageURL: URL? {
        if let url = URL(string: imagePath), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        return URL(fileURLWithPath: StorageManager.shared.resolveImagePath(imagePath))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Image not available")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#endif
