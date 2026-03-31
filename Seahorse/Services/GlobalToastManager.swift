//
//  GlobalToastManager.swift
//  Seahorse
//
//  Created by caishilin on 2026/03/30.
//

import SwiftUI

/// Global toast state manager that can be observed by any view
@MainActor
class GlobalToastManager: ObservableObject {
    static let shared = GlobalToastManager()

    @Published var isPresented = false
    @Published var message = ""
    @Published var icon = "checkmark.circle.fill"

    private init() {}

    func show(message: String, icon: String = "checkmark.circle.fill") {
        self.message = message
        self.icon = icon
        self.isPresented = true
    }
}
