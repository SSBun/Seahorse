//
//  CardStyleOptionView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct CardStyleOptionView: View {
    let style: CardStyle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Preview
                Group {
                    if style == .standard {
                        standardPreview
                    } else {
                        compactPreview
                    }
                }
                .frame(width: 120, height: 80)
                
                // Label
                VStack(spacing: 4) {
                    Text(style.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text(style.description)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 24)
                }
            }
            .padding(12)
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ?
                        Color.accentColor.opacity(0.15) :
                        Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var standardPreview: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 50, height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 3)
                    .cornerRadius(1.5)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var compactPreview: some View {
        HStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 35, height: 3)
                    .cornerRadius(1.5)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 30, height: 2)
                    .cornerRadius(1)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        CardStyleOptionView(
            style: .standard,
            isSelected: true,
            onSelect: {}
        )
        
        CardStyleOptionView(
            style: .compact,
            isSelected: false,
            onSelect: {}
        )
    }
    .padding()
    .frame(width: 400, height: 200)
}

