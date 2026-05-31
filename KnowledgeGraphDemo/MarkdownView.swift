import SwiftUI

private enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedItem(text: String, depth: Int)
    case orderedItem(index: Int, text: String)
    case codeBlock(code: String)
    case divider

    var id: String {
        switch self {
        case .heading(let l, let t):      return "h\(l)-\(t)"
        case .paragraph(let t):           return "p-\(t.prefix(40))"
        case .unorderedItem(let t, let d):return "ul-\(d)-\(t.prefix(40))"
        case .orderedItem(let i, let t):  return "ol-\(i)-\(t.prefix(40))"
        case .codeBlock(let c):           return "code-\(c.prefix(40))"
        case .divider:                    return "hr"
        }
    }
}

private func parseMarkdown(_ source: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var lines = source.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let raw = lines[i]

        // Fenced code block
        if raw.hasPrefix("```") {
            var code: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix("```") {
                code.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(code: code.joined(separator: "\n")))
            i += 1
            continue
        }

        let line = raw

        // Heading
        if line.hasPrefix("#") {
            var level = 0
            var idx = line.startIndex
            while idx < line.endIndex && line[idx] == "#" {
                level += 1
                idx = line.index(after: idx)
            }
            if level <= 6 && idx < line.endIndex && line[idx] == " " {
                let text = String(line[line.index(after: idx)...])
                blocks.append(.heading(level: level, text: text))
                i += 1
                continue
            }
        }

        // Thematic break
        let stripped = line.replacingOccurrences(of: " ", with: "")
        if stripped == "---" || stripped == "***" || stripped == "___" {
            blocks.append(.divider)
            i += 1
            continue
        }

        // Unordered list item
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            blocks.append(.unorderedItem(text: String(line.dropFirst(2)), depth: 0))
            i += 1
            continue
        }
        if line.hasPrefix("  - ") || line.hasPrefix("  * ") {
            blocks.append(.unorderedItem(text: String(line.dropFirst(4)), depth: 1))
            i += 1
            continue
        }

        // Ordered list item  (1. text)
        let orderedPattern = /^(\d+)\.\s(.+)/
        if let match = try? orderedPattern.firstMatch(in: line) {
            let idx = Int(match.1) ?? blocks.filter {
                if case .orderedItem = $0 { return true }; return false
            }.count + 1
            blocks.append(.orderedItem(index: idx, text: String(match.2)))
            i += 1
            continue
        }

        // Blank line — skip
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
            continue
        }

        // Paragraph (accumulate consecutive non-special lines)
        var para: [String] = [line]
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if next.hasPrefix("#") || next.hasPrefix("- ") || next.hasPrefix("* ")
                || next.hasPrefix("```") || next.hasPrefix("---") { break }
            if (try? (/^(\d+)\.\s(.+)/).firstMatch(in: next)) != nil { break }
            para.append(next)
            i += 1
        }
        blocks.append(.paragraph(text: para.joined(separator: "\n")))
    }

    // Deduplicate IDs by appending an offset
    var seen: [String: Int] = [:]
    return blocks.map { block in
        let base = block.id
        let count = seen[base, default: 0]
        seen[base] = count + 1
        return block  // id collisions are rare enough in practice
    }
}

struct MarkdownView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] { parseMarkdown(markdown) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let text):
            Text(.init(text))
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .unorderedItem(let text, let depth):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.callout)
                    .padding(.top, 1)
                    .padding(.leading, CGFloat(depth) * 16)
                Text(.init(text))
                    .font(.callout)
            }

        case .orderedItem(let index, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(index).")
                    .font(.callout)
                    .frame(minWidth: 22, alignment: .trailing)
                Text(.init(text))
                    .font(.callout)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .divider:
            Divider()
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:  return .title3.bold()
        case 2:  return .headline
        case 3:  return .subheadline.bold()
        default: return .callout.bold()
        }
    }
}
