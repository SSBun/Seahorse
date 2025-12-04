//
//  Language.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case simplifiedChinese = "简体中文"
    case traditionalChinese = "繁體中文"
    case japanese = "日本語"
    case korean = "한국어"
    case french = "Français"
    case german = "Deutsch"
    case spanish = "Español"
    case italian = "Italiano"
    case portuguese = "Português"
    case russian = "Русский"
    case arabic = "العربية"
    
    var id: String { rawValue }
    
    var code: String {
        switch self {
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .french: return "fr"
        case .german: return "de"
        case .spanish: return "es"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .arabic: return "ar"
        }
    }
}

enum AILanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case simplifiedChinese = "简体中文"
    case traditionalChinese = "繁體中文"
    case japanese = "日本語"
    case korean = "한국어"
    case french = "Français"
    case german = "Deutsch"
    case spanish = "Español"
    case italian = "Italiano"
    case portuguese = "Português"
    case russian = "Русский"
    case arabic = "العربية"
    
    var id: String { rawValue }
    
    var promptSuffix: String {
        switch self {
        case .english:
            return "Respond in English."
        case .simplifiedChinese:
            return "用简体中文回答。"
        case .traditionalChinese:
            return "用繁體中文回答。"
        case .japanese:
            return "日本語で答えてください。"
        case .korean:
            return "한국어로 답변해 주세요."
        case .french:
            return "Répondez en français."
        case .german:
            return "Antworten Sie auf Deutsch."
        case .spanish:
            return "Responda en español."
        case .italian:
            return "Rispondi in italiano."
        case .portuguese:
            return "Responda em português."
        case .russian:
            return "Отвечайте на русском языке."
        case .arabic:
            return "أجب باللغة العربية."
        }
    }
}

