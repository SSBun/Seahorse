//
//  AISettings.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import Foundation
import SwiftUI

@MainActor
class AISettings: ObservableObject {
    static let shared = AISettings()
    
    @Published var apiBaseURL: String {
        didSet {
            UserDefaults.standard.set(apiBaseURL, forKey: "ai_api_base_url")
        }
    }
    
    @Published var apiToken: String {
        didSet {
            UserDefaults.standard.set(apiToken, forKey: "ai_api_token")
        }
    }
    
    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: "ai_model")
        }
    }
    
    @Published var pageSummaryPrompt: String {
        didSet {
            UserDefaults.standard.set(pageSummaryPrompt, forKey: "ai_page_summary_prompt")
        }
    }
    
    @Published var categorizingPrompt: String {
        didSet {
            UserDefaults.standard.set(categorizingPrompt, forKey: "ai_categorizing_prompt")
        }
    }
    
    @Published var tagSuggestionPrompt: String {
        didSet {
            UserDefaults.standard.set(tagSuggestionPrompt, forKey: "ai_tag_suggestion_prompt")
        }
    }
    
    @Published var titleRefinementPrompt: String {
        didSet {
            UserDefaults.standard.set(titleRefinementPrompt, forKey: "ai_title_refinement_prompt")
        }
    }
    
    @Published var aiLanguage: AILanguage {
        didSet {
            UserDefaults.standard.set(aiLanguage.rawValue, forKey: "ai_language")
        }
    }
    
    private init() {
        // Load from UserDefaults or use defaults
        self.apiBaseURL = UserDefaults.standard.string(forKey: "ai_api_base_url") ?? "https://api.openai.com/v1"
        self.apiToken = UserDefaults.standard.string(forKey: "ai_api_token") ?? ""
        self.model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-4o-mini"
        
        self.pageSummaryPrompt = UserDefaults.standard.string(forKey: "ai_page_summary_prompt") ?? """
Summarize the following webpage content concisely in 50 words or less. Focus on the main topic and key points.

Title: {title}
Content: {content}

Return only the summary text, nothing else. Keep it under 50 words.
"""
        
        self.categorizingPrompt = UserDefaults.standard.string(forKey: "ai_categorizing_prompt") ?? """
Based on the following webpage content and title, suggest the most appropriate category.

Title: {title}
Content: {content}

Available Categories: {categories}

If an existing category fits well, return only that category name. If none of the existing categories fit well, suggest a NEW category name that would be appropriate for this content (single word, capitalized, like "Technology", "Finance", "Design", etc.).

Return only one category name, nothing else.
"""
        
        self.tagSuggestionPrompt = UserDefaults.standard.string(forKey: "ai_tag_suggestion_prompt") ?? """
Based on the following webpage content and title, suggest 2-4 relevant tags.

Title: {title}
Content: {content}

Available Tags: {tags}

You can suggest existing tags from the list OR create NEW tags if none fit well. New tags should be concise (1-2 words), lowercase, and descriptive.

Return only the tag names separated by commas, nothing else. Example: swift, ios, tutorial, machine-learning
"""
        
        self.titleRefinementPrompt = UserDefaults.standard.string(forKey: "ai_title_refinement_prompt") ?? """
Clean up the following webpage title while preserving its original meaning. Only remove:
- Site names or platform names (like "GitHub", "Medium", "Dev.to") if they appear as suffixes
- URL paths and separators (like " | ", " - ", " :: ") that separate the main title from the site name
- Redundant prefixes that don't add meaning

Keep the main content and meaning intact. Do not rephrase or summarize.

Original Title: {title}

Return only the cleaned title, nothing else.
"""
        
        // Load AI Language or use English as default
        if let savedLanguage = UserDefaults.standard.string(forKey: "ai_language"),
           let language = AILanguage.allCases.first(where: { $0.rawValue == savedLanguage }) {
            self.aiLanguage = language
        } else {
            self.aiLanguage = .english
        }
    }
}

