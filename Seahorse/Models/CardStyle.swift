//
//  CardStyle.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

enum CardStyle: String, CaseIterable, Codable {
    case standard = "Standard"
    case compact = "Compact"
    
    var description: String {
        switch self {
        case .standard:
            return "Standard size with full details"
        case .compact:
            return "Smaller cards for dense layouts"
        }
    }
}

