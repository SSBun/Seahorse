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

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background with rounded corners to mask TextEditor's sharp corners
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))

            TextEditor(text: $textContent)
                .font(.system(size: 14))
                .padding(5)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .padding()
        .onAppear {
            textContent = textItem.content
        }
        .onChange(of: textContent) { oldValue, newValue in
            saveTextContent(newValue)
        }
    }

    private func saveTextContent(_ newContent: String) {
        var updatedItem = textItem
        updatedItem.content = newContent
        updatedItem.modifiedDate = Date()
        dataStorage.updateItem(AnyCollectionItem(updatedItem))
    }
}
