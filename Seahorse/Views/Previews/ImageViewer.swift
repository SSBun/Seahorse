//
//  ImageViewer.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import Kingfisher

struct ImageViewer: View {
    let imagePath: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.1)
                
                let resolvedPath = StorageManager.shared.resolveImagePath(imagePath)
                
                if let url = URL(string: imagePath), (url.scheme == "http" || url.scheme == "https") {
                    // Remote image using Kingfisher
                    KFImage.url(url)
                        .placeholder {
                            ProgressView()
                        }
                        .onFailure { _ in
                            Text("Failed to load image")
                                .foregroundStyle(.secondary)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let nsImage = NSImage(contentsOfFile: resolvedPath) {
                    // Local image
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Image not found")
                        .foregroundStyle(.secondary)
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.0 {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.0
                        lastScale = 2.0
                    }
                }
            }
        }
    }
}

