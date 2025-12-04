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
        TextEditor(text: $textContent)
            .font(.system(size: 14))
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

