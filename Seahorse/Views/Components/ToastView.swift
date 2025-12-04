//
//  ToastView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        )
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    ToastView(message: message, icon: icon)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                    
                    Spacer()
                }
                .padding(.top, 20)
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, duration: duration))
    }
}

