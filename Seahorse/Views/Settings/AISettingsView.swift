//
//  AISettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct AISettingsView: View {
    @StateObject private var aiSettings = AISettings.shared
    @State private var showingTestAlert = false
    @State private var testResult = ""
    @State private var isTesting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // API Base URL
                VStack(alignment: .leading, spacing: 10) {
                    Text("API Base URL")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextField("https://api.openai.com/v1", text: $aiSettings.apiBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    Text("The base URL for AI API requests")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // API Token
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("API Token")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        Button(action: testConnection) {
                            HStack(spacing: 4) {
                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12))
                                }
                                Text("Test Connection")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTesting || aiSettings.apiToken.isEmpty)
                    }
                    
                    SecureField("Enter your API token", text: $aiSettings.apiToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    Text("Your API token will be stored in UserDefaults")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Model
                VStack(alignment: .leading, spacing: 10) {
                    Text("Model")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextField("gpt-4o-mini", text: $aiSettings.model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    Text("The AI model to use (e.g., gpt-4o-mini, gpt-4, gpt-3.5-turbo)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Page Summary Prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Page Summary Prompt")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextEditor(text: $aiSettings.pageSummaryPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Text("Use {title} and {content} as placeholders for webpage title and content")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Categorizing Prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Categorizing Prompt")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextEditor(text: $aiSettings.categorizingPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 140)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Text("Use {title}, {content}, and {categories} as placeholders")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Tag Suggestion Prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tag Suggestion Prompt")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextEditor(text: $aiSettings.tagSuggestionPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 140)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Text("Use {title}, {content}, and {tags} as placeholders")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(30)
        }
        .alert("Connection Test", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(testResult)
        }
    }
    
    private func testConnection() {
        isTesting = true
        Task {
            do {
                let aiManager = AIManager()
                let result = try await aiManager.testConnection()
                await MainActor.run {
                    testResult = result
                    showingTestAlert = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Connection failed: \(error.localizedDescription)"
                    showingTestAlert = true
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    AISettingsView()
        .frame(width: 600, height: 500)
}

