enum ChangelogParser {
    static func sections(for version: String, in markdown: String) -> [ChangelogSection] {
        let targetHeading = "## [\(version)]"
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var sections: [ChangelogSection] = []
        var isReadingVersion = false

        for line in lines {
            if !isReadingVersion {
                isReadingVersion = line == targetHeading || line.hasPrefix(targetHeading + " ")
                continue
            }

            if line.hasPrefix("## ") {
                break
            }

            if line.hasPrefix("### ") {
                sections.append(ChangelogSection(title: String(line.dropFirst(4)), items: []))
            } else if line.hasPrefix("- "), !sections.isEmpty {
                sections[sections.count - 1].items.append(String(line.dropFirst(2)))
            }
        }

        return sections.filter { !$0.title.isEmpty && !$0.items.isEmpty }
    }
}
