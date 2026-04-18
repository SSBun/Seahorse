#if os(iOS)
//
//  iOSImageView.swift
//  Seahorse
//

import SwiftUI

struct iOSImageView: View {
    let imagePath: String

    var body: some View {
        Group {
            if imagePath.hasPrefix("http://") || imagePath.hasPrefix("https://") {
                remoteImage
            } else {
                localImage
            }
        }
    }

    @ViewBuilder
    private var remoteImage: some View {
        if let url = URL(string: imagePath) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    placeholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                @unknown default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var localImage: some View {
        let resolvedPath = StorageManager.shared.resolveImagePath(imagePath)
        #if canImport(UIKit)
        if let uiImage = UIImage(contentsOfFile: resolvedPath) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
        #endif
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
