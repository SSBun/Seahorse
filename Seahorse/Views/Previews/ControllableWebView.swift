//
//  ControllableWebView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI
import WebKit

struct ControllableWebView: NSViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Store reference and set up observer
        DispatchQueue.main.async {
            self.webView = webView
            context.coordinator.setupObserver(for: webView)
        }
        
        // Store initial URL in coordinator
        context.coordinator.setInitialURL(url)
        
        // Load initial URL
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update navigation state immediately
        context.coordinator.updateNavigationState(for: webView)
        
        // Only reload if the external URL parameter actually changed
        // Don't reload if user navigated within the webview
        if context.coordinator.shouldReload(for: url) {
            context.coordinator.setInitialURL(url)
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            isLoading: $isLoading
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var canGoBack: Bool
        @Binding var canGoForward: Bool
        @Binding var isLoading: Bool
        private var observation: NSKeyValueObservation?
        private var lastInitialURL: URL?
        
        init(
            canGoBack: Binding<Bool>,
            canGoForward: Binding<Bool>,
            isLoading: Binding<Bool>
        ) {
            _canGoBack = canGoBack
            _canGoForward = canGoForward
            _isLoading = isLoading
        }
        
        func setInitialURL(_ url: URL) {
            lastInitialURL = url
        }
        
        func shouldReload(for newURL: URL) -> Bool {
            // Only reload if the external URL parameter actually changed
            // This prevents reloading when user navigates within the webview
            guard let lastURL = lastInitialURL else {
                return true
            }
            return lastURL != newURL
        }
        
        func setupObserver(for webView: WKWebView) {
            // Observe loading state
            observation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.isLoading = webView.isLoading
                    self?.updateNavigationState(for: webView)
                }
            }
        }
        
        func updateNavigationState(for webView: WKWebView) {
            DispatchQueue.main.async {
                self.canGoBack = webView.canGoBack
                self.canGoForward = webView.canGoForward
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
                self.updateNavigationState(for: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.updateNavigationState(for: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.updateNavigationState(for: webView)
            }
            print("WebView error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.updateNavigationState(for: webView)
            }
            print("WebView error: \(error.localizedDescription)")
        }
        
        deinit {
            observation?.invalidate()
        }
    }
}

