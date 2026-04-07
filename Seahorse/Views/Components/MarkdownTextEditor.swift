//
//  MarkdownTextEditor.swift
//  Seahorse
//
//  Created by Claude on 2026/04/03.
//

import SwiftUI
import Highlightr
import AppKit

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var fontSize: CGFloat = 13
    var minHeight: CGFloat = 200
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isRichText = false

        // Setup Highlightr with theme based on color scheme
        let highlightr = Highlightr()!
        let theme = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        highlightr.setTheme(to: theme)
        context.coordinator.highlightr = highlightr
        context.coordinator.colorScheme = colorScheme

        // Set initial text
        textView.string = text
        context.coordinator.updateHighlighting(textView: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Update theme if color scheme changed
        if colorScheme != context.coordinator.colorScheme {
            let theme = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
            context.coordinator.highlightr?.setTheme(to: theme)
            context.coordinator.colorScheme = colorScheme
            context.coordinator.updateHighlighting(textView: textView)
        } else if textView.string != text {
            textView.string = text
            context.coordinator.updateHighlighting(textView: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        var highlightr: Highlightr?
        var colorScheme: ColorScheme = .light
        var isUpdating = false

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }

            parent.text = textView.string
            updateHighlighting(textView: textView)
        }

        func updateHighlighting(textView: NSTextView) {
            guard let highlightr = highlightr else { return }
            isUpdating = true

            let text = textView.string
            let highlighted = highlightr.highlight(text, as: "markdown")

            // Preserve cursor position
            let selectedRange = textView.selectedRange()

            // Apply attributed text
            if let attributed = highlighted {
                textView.textStorage?.setAttributedString(attributed)
            }

            // Restore cursor position
            textView.setSelectedRange(selectedRange)

            isUpdating = false
        }
    }
}

// SwiftUI wrapper for read-only preview
struct MarkdownTextPreview: NSViewRepresentable {
    let text: String
    var fontSize: CGFloat = 14
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 5, height: 5)

        // Setup Highlightr with theme based on color scheme
        let highlightr = Highlightr()!
        let theme = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        highlightr.setTheme(to: theme)

        // Apply highlighting
        if let highlighted = highlightr.highlight(text, as: "markdown") {
            textView.textStorage?.setAttributedString(highlighted)
        } else {
            textView.string = text
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Read-only, but need to update if color scheme changes
        // Since we can't detect that easily here, we could trigger updates via the caller
    }
}
