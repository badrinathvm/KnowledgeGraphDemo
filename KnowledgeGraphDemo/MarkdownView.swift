import SwiftUI

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedItem(text: String, depth: Int)
    case orderedItem(index: Int, text: String)
    case codeBlock(code: String)
    case divider
}

// Returns (number, restOfLine) when line starts with "1. " pattern, nil otherwise.
private func orderedListPrefix(_ line: String) -> (index: Int, text: String)? {
    var i = line.startIndex
    while i < line.endIndex && line[i].isNumber {
        i = line.index(after: i)
    }
    guard i > line.startIndex else { return nil }
    guard i < line.endIndex, line[i] == "." else { return nil }
    let afterDot = line.index(after: i)
    guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
    let num = Int(String(line[line.startIndex..<i])) ?? 1
    return (num, String(line[line.index(afterDot, offsetBy: 1)...]))
}

private func parseMarkdown(_ source: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = source.components(separatedBy: "\n")
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

        // Heading
        if raw.hasPrefix("#") {
            var level = 0
            var idx = raw.startIndex
            while idx < raw.endIndex && raw[idx] == "#" {
                level += 1
                idx = raw.index(after: idx)
            }
            if level <= 6, idx < raw.endIndex, raw[idx] == " " {
                let text = String(raw[raw.index(after: idx)...])
                blocks.append(.heading(level: level, text: text))
                i += 1
                continue
            }
        }

        // Thematic break
        let stripped = raw.replacingOccurrences(of: " ", with: "")
        if stripped == "---" || stripped == "***" || stripped == "___" {
            blocks.append(.divider)
            i += 1
            continue
        }

        // Unordered list item
        if raw.hasPrefix("    - ") || raw.hasPrefix("    * ") {
            blocks.append(.unorderedItem(text: String(raw.dropFirst(6)), depth: 1))
            i += 1
            continue
        }
        if raw.hasPrefix("  - ") || raw.hasPrefix("  * ") {
            blocks.append(.unorderedItem(text: String(raw.dropFirst(4)), depth: 1))
            i += 1
            continue
        }
        if raw.hasPrefix("- ") || raw.hasPrefix("* ") {
            blocks.append(.unorderedItem(text: String(raw.dropFirst(2)), depth: 0))
            i += 1
            continue
        }

        // Ordered list item
        if let (num, text) = orderedListPrefix(raw) {
            blocks.append(.orderedItem(index: num, text: text))
            i += 1
            continue
        }

        // Blank line
        if raw.trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
            continue
        }

        // Paragraph — accumulate consecutive non-special lines
        var para: [String] = [raw]
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if next.hasPrefix("#") || next.hasPrefix("- ") || next.hasPrefix("* ")
                || next.hasPrefix("```") { break }
            let noSpaces = next.replacingOccurrences(of: " ", with: "")
            if noSpaces == "---" || noSpaces == "***" || noSpaces == "___" { break }
            if orderedListPrefix(next) != nil { break }
            para.append(next)
            i += 1
        }
        blocks.append(.paragraph(text: para.joined(separator: "\n")))
    }

    return blocks
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
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let text):
            Text(.init(text))
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .unorderedItem(let text, let depth):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(.top, 1)
                    .padding(.leading, CGFloat(depth) * 16)
                Text(.init(text))
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

        case .orderedItem(let index, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(index).")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 22, alignment: .trailing)
                Text(.init(text))
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
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
