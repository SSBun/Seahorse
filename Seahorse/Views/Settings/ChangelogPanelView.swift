#if os(macOS)
import SwiftUI

struct ChangelogPanelView: View {
    @Environment(\.dismiss) private var dismiss

    let version: String
    private let sections: [ChangelogSection]

    init(version: String, bundle: Bundle = .main) {
        self.version = version

        guard
            let url = bundle.url(forResource: "CHANGELOG", withExtension: "md"),
            let markdown = try? String(contentsOf: url, encoding: .utf8)
        else {
            sections = []
            return
        }

        sections = ChangelogParser.sections(for: version, in: markdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("What's New in \(version)")
                    .font(.headline)

                Spacer()

                Button(action: close) {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
                .keyboardShortcut(.cancelAction)
                .help("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                if sections.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        Text("Changelog is unavailable for this version.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))

                                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundStyle(.secondary)
                                            .accessibilityHidden(true)

                                        Text(item)
                                            .font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
        }
        .frame(width: 520, height: 420)
    }

    private func close() {
        dismiss()
    }
}
#endif
