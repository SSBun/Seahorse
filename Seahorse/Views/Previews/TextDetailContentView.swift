#if os(macOS)
//
//  TextDetailContentView.swift
//  Seahorse
//
//  Created by caishilin on 2025/12/03.
//

import SwiftUI

struct TextDetailContentView: View {
    let textItem: TextItem
    @EnvironmentObject var dataStorage: DataStorage
    @State private var textContent: String = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Markdown")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))

                MarkdownTextEditor(text: $textContent, isEditable: true, fontSize: 14, minHeight: 400)
                    .frame(minHeight: 400)
                    .onChange(of: textContent) { oldValue, newValue in
                        scheduleTextContentSave(newValue)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .padding()
        }
        .onAppear {
            textContent = textItem.content
        }
        .onDisappear {
            saveTask?.cancel()
            saveTextContent(textContent)
        }
    }

    private func scheduleTextContentSave(_ content: String) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            saveTextContent(content)
        }
    }

    private func saveTextContent(_ newContent: String) {
        var updatedItem = dataStorage.item(for: textItem.id)?.asTextItem ?? textItem
        guard newContent != updatedItem.content else { return }
        updatedItem.content = newContent
        updatedItem.modifiedDate = Date()
        dataStorage.updateItem(AnyCollectionItem(updatedItem))
    }
}

#endif
