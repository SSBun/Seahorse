//
//  BookmarkDetailContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import WebKit

struct BookmarkDetailContentView: View {
    let bookmark: Bookmark
    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            bookmarkToolbar
            
            // WebView
            if let url = URL(string: bookmark.url) {
                ControllableWebView(
                    url: url,
                    webView: $webView,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading
                )
            } else {
                Text("Invalid URL")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var bookmarkToolbar: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: {
                webView?.goBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .foregroundStyle(canGoBack ? .primary : .secondary)
            .frame(width: 28, height: 28)
            .background(canGoBack ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .cornerRadius(6)
            
            // Forward button
            Button(action: {
                webView?.goForward()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .foregroundStyle(canGoForward ? .primary : .secondary)
            .frame(width: 28, height: 28)
            .background(canGoForward ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .cornerRadius(6)
            
            Divider()
                .frame(height: 20)
            
            // Open in Browser button
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "safari")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help("Open in Browser")
            
            // Refresh button
            Button(action: {
                if isLoading {
                    webView?.stopLoading()
                } else {
                    webView?.reload()
                }
            }) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help(isLoading ? "Stop Loading" : "Refresh")
            
            // Copy Link button
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bookmark.url, forType: .string)
            }) {
                Image(systemName: "link")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .help("Copy Link")
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

