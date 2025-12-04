//
//  SortPreferenceManager.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/17.
//

import Foundation
import SwiftUI

@MainActor
class SortPreferenceManager: ObservableObject {
    static let shared = SortPreferenceManager()
    
    @Published var sortOption: SortOption {
        didSet {
            saveSortOption()
        }
    }
    
    private let sortOptionKey = "seahorse.sort.option"
    
    private init() {
        // Load saved sort option
        if let savedValue = UserDefaults.standard.string(forKey: sortOptionKey),
           let option = SortOption(rawValue: savedValue) {
            self.sortOption = option
        } else {
            self.sortOption = .newestFirst // Default
        }
    }
    
    private func saveSortOption() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: sortOptionKey)
    }
}

