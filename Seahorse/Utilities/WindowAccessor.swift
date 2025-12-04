//
//  WindowAccessor.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/04.
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
