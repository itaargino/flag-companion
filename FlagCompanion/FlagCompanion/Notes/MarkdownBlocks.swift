import Foundation

/// One block of a note for the preview: a heading, a fenced code block or a
/// paragraph. SwiftUI's `Text` renders inline Markdown but drops headings and
/// code fences, so the preview splits the note into blocks first.
nonisolated enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case code(String)
    case paragraph(String)
}

nonisolated enum MarkdownBlocks {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]?

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }

        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                if let open = code {
                    blocks.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    flushParagraph()
                    code = []
                }
            } else if code != nil {
                code?.append(line)
            } else if let heading = heading(in: line) {
                flushParagraph()
                blocks.append(heading)
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
            } else {
                paragraph.append(line)
            }
        }
        // An unclosed fence still shows its code, as most Markdown editors do.
        if let open = code { blocks.append(.code(open.joined(separator: "\n"))) }
        flushParagraph()
        return blocks
    }

    private static func heading(in line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        let text = line.dropFirst(hashes + 1).trimmingCharacters(in: .whitespaces)
        return .heading(level: hashes, text: text)
    }
}
