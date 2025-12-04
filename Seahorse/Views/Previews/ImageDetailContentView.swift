//
//  ImageDetailContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import Kingfisher

struct ImageDetailContentView: View {
    let imageItem: ImageItem
    
    var body: some View {
        Group {
            if !imageItem.imagePath.isEmpty {
                ImageViewer(imagePath: imageItem.imagePath)
            } else {
                Text("No image available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

