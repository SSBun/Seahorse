#if os(iOS)
//
//  iOSTextNoteView.swift
//  Seahorse
//

import SwiftUI

struct iOSTextNoteView: View {
    let textItem: TextItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(textItem.content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let notes = textItem.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

#endif
