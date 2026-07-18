#if os(macOS)
//
//  AISettingsView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI

struct AISettingsView: View {
    @StateObject private var aiSettings = AISettings.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AgentProvidersSettingsView()

                Divider()

                // Image Generation
                VStack(alignment: .leading, spacing: 10) {
                    Text("Image Generation")
                        .font(.system(size: 13, weight: .semibold))

                    Picker(
                        "Provider",
                        selection: Binding(
                            get: { aiSettings.selectedImageProviderID },
                            set: { aiSettings.selectImageProvider($0) }
                        )
                    ) {
                        ForEach(aiSettings.imageGenerationProviders) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if aiSettings.selectedImageProvider.kind == .openAICodex {
                        Text("Uses Codex model \(aiSettings.codexImageModel) and the ChatGPT connection configured above.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Image Model", text: $aiSettings.imageModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Text("Model for generating cover images (e.g., gpt-image-2)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Auto AI Parsing
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Auto AI Parsing", isOn: $aiSettings.autoParsingEnabled)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Automatically parse new bookmarks with AI to refine title, generate summary, and suggest tags")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if aiSettings.autoParsingEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Create New Tags", isOn: $aiSettings.autoParsingCreateTags)
                                .font(.system(size: 12))
                            Text("Allow AI to create at most two new tags when an existing tag does not fit")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }

                Divider()
                
                // Additional Parsing Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Additional Parsing Instructions")
                        .font(.system(size: 13, weight: .semibold))
                    
                    TextEditor(text: $aiSettings.additionalParsingInstructions)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Text("Optional preferences for language, tone, or emphasis. Core JSON, category, and tag rules always take priority.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

#Preview {
    AISettingsView()
        .frame(width: 600, height: 500)
}


#endif
