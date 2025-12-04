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
    
    init(iconString: String, size: CGFloat = 32) {
        self.iconString = iconString
        self.size = size
    }
    
    var body: some View {
        Group {
            if iconString.hasPrefix("http://") || iconString.hasPrefix("https://") {
                // Remote URL
                KFImage(URL(string: iconString))
                    .placeholder {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    .onFailure { _ in
                        // Fallback will be handled by parent or just empty
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if iconString.hasPrefix("data:image") {
                // Data URL (base64 encoded image)
                if let dataURL = URL(string: iconString),
                   let data = try? Data(contentsOf: dataURL),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
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

