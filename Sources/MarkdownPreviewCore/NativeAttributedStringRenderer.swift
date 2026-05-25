import AppKit

public struct NativeAttributedStringRenderer {
    public init() {}

    public func render(_ blocks: [MarkdownBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for block in blocks {
            switch block {
            case let .heading(level, text):
                result.append(markdownLine(
                    text,
                    font: .systemFont(ofSize: headingSize(level), weight: .semibold),
                    boldFont: .systemFont(ofSize: headingSize(level), weight: .bold),
                    spacing: 10
                ))
            case let .paragraph(text):
                result.append(markdownLine(
                    text,
                    font: .systemFont(ofSize: 14),
                    boldFont: .systemFont(ofSize: 14, weight: .semibold),
                    spacing: 8
                ))
            case let .blockquote(text):
                result.append(markdownLine(
                    "> \(text)",
                    font: .systemFont(ofSize: 14),
                    boldFont: .systemFont(ofSize: 14, weight: .semibold),
                    color: .secondaryLabelColor,
                    spacing: 8
                ))
            case let .unorderedList(items):
                for item in items {
                    result.append(markdownLine(
                        "- \(item)",
                        font: .systemFont(ofSize: 14),
                        boldFont: .systemFont(ofSize: 14, weight: .semibold),
                        spacing: 4
                    ))
                }
                result.append(NSAttributedString(string: "\n"))
            case let .orderedList(items):
                for (offset, item) in items.enumerated() {
                    result.append(markdownLine(
                        "\(offset + 1). \(item)",
                        font: .systemFont(ofSize: 14),
                        boldFont: .systemFont(ofSize: 14, weight: .semibold),
                        spacing: 4
                    ))
                }
                result.append(NSAttributedString(string: "\n"))
            case let .image(alt, path):
                let lowercasePath = path.lowercased()
                let isRemote = lowercasePath.hasPrefix("http://") || lowercasePath.hasPrefix("https://")
                let label = isRemote
                    ? "Remote image not loaded: \(path)"
                    : "Image: \(alt.isEmpty ? path : alt)"
                result.append(line(
                    label,
                    font: .systemFont(ofSize: 13),
                    color: .secondaryLabelColor,
                    spacing: 8
                ))
            case let .codeBlock(_, code):
                result.append(textBlock(
                    code,
                    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                    color: .labelColor,
                    spacingAfter: 10
                ))
            case let .table(table):
                result.append(tableBlock(table))
            }
        }

        return result
    }
}

private extension NativeAttributedStringRenderer {
    func displayText(_ text: String) -> String {
        var output = text
        while let start = output.range(of: ""),
              let end = output[start.upperBound...].range(of: "") {
            let markerRange = start.lowerBound..<end.upperBound
            let marker = String(output[markerRange])
            output.replaceSubrange(markerRange, with: replacement(forMarker: marker))
        }
        return output
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    func replacement(forMarker marker: String) -> String {
        if marker.contains("entity") {
            return quotedFields(in: marker).dropFirst().first ?? ""
        }
        return ""
    }

    func quotedFields(in text: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuote = false
        var isEscaped = false

        for character in text {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == "\"" {
                if inQuote {
                    fields.append(current)
                    current = ""
                }
                inQuote.toggle()
                continue
            }

            if inQuote {
                current.append(character)
            }
        }

        return fields
    }

    func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 26
        case 2: return 22
        case 3: return 18
        default: return 15
        }
    }

    func line(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        spacing: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacing
        paragraph.lineSpacing = 2

        return NSAttributedString(
            string: text + "\n",
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    func markdownLine(
        _ text: String,
        font: NSFont,
        boldFont: NSFont,
        color: NSColor = .labelColor,
        spacing: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacing
        paragraph.lineSpacing = 2

        let result = inlineMarkdown(
            displayText(text),
            font: font,
            boldFont: boldFont,
            color: color,
            paragraph: paragraph
        )
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]))
        return result
    }

    func inlineMarkdown(
        _ text: String,
        font: NSFont,
        boldFont: NSFont,
        color: NSColor,
        paragraph: NSParagraphStyle
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var index = text.startIndex
        var isBold = false

        while index < text.endIndex {
            if text[index...].hasPrefix("**") || text[index...].hasPrefix("__") {
                index = text.index(index, offsetBy: 2)
                isBold.toggle()
                continue
            }

            let nextIndex = text.index(after: index)
            result.append(NSAttributedString(
                string: String(text[index..<nextIndex]),
                attributes: [
                    .font: isBold ? boldFont : font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
            ))
            index = nextIndex
        }

        return result
    }

    func textBlock(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        spacingAfter: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let result = NSMutableAttributedString(
            string: text + "\n",
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = spacingAfter
        result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: spacer]))
        return result
    }

    func tableBlock(_ table: MarkdownTable) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraph = tableParagraphStyle()
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let rowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        for (chunkIndex, columns) in tableColumnGroups(columnCount: table.headers.count).enumerated() {
            if chunkIndex > 0 {
                result.append(NSAttributedString(string: "\n", attributes: rowAttributes))
            }

            for (rowIndex, lines) in formattedTableRows(table, columns: columns).enumerated() {
                let attributes = rowIndex == 0 ? headerAttributes : rowAttributes
                for line in lines {
                    result.append(NSAttributedString(string: line + "\n", attributes: attributes))
                }
                if rowIndex == 0 {
                    result.append(NSAttributedString(string: "\n", attributes: rowAttributes))
                }
            }
        }

        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = 10
        result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: spacer]))
        return result
    }

    func tableParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 2
        return paragraph
    }

    func tableColumnGroups(columnCount: Int) -> [[Int]] {
        guard columnCount > 4 else {
            return [Array(0..<columnCount)]
        }

        var groups: [[Int]] = []
        var index = 1
        while index < columnCount {
            let end = min(index + 3, columnCount)
            groups.append([0] + Array(index..<end))
            index = end
        }
        return groups
    }

    func formattedTableRows(_ table: MarkdownTable, columns: [Int]) -> [[String]] {
        let sourceRows = [table.headers] + table.rows
        let selectedRows = sourceRows.map { row in
            columns.map { column in
                column < row.count ? displayText(row[column]) : ""
            }
        }
        let widths = tableColumnWidths(rows: selectedRows)

        return selectedRows.map { row in
            let wrappedCells = row.enumerated().map { index, cell in
                wrapCell(cell, width: widths[index])
            }
            let rowHeight = wrappedCells.map(\.count).max() ?? 1

            return (0..<rowHeight).map { lineIndex in
                row.enumerated().map { index, _ in
                    let cellLine = lineIndex < wrappedCells[index].count ? wrappedCells[index][lineIndex] : ""
                    return pad(cellLine, to: widths[index])
                }.joined(separator: "   ").trimmingCharacters(in: .whitespaces)
            }
        }
    }

    func tableColumnWidths(rows: [[String]]) -> [Int] {
        let columnCount = rows.map(\.count).max() ?? 0
        let maxWidth: Int
        switch columnCount {
        case 0...2: maxWidth = 34
        case 3: maxWidth = 28
        default: maxWidth = 22
        }

        return (0..<columnCount).map { column in
            let widest = rows.compactMap { row -> Int? in
                guard column < row.count else { return nil }
                return displayWidth(row[column])
            }.max() ?? 8
            return min(max(widest, 8), maxWidth)
        }
    }

    func wrapCell(_ text: String, width: Int) -> [String] {
        guard !text.isEmpty else { return [""] }

        var lines: [String] = []
        var current = ""
        var currentWidth = 0

        for character in text {
            let characterWidth = displayWidth(character)
            if currentWidth > 0 && currentWidth + characterWidth > width {
                lines.append(current)
                current = ""
                currentWidth = 0
            }
            current.append(character)
            currentWidth += characterWidth
        }

        if !current.isEmpty {
            lines.append(current)
        }
        return lines.isEmpty ? [""] : lines
    }

    func pad(_ text: String, to width: Int) -> String {
        let padding = max(width - displayWidth(text), 0)
        return text + String(repeating: " ", count: padding)
    }

    func displayWidth(_ text: String) -> Int {
        text.reduce(0) { $0 + displayWidth($1) }
    }

    func displayWidth(_ character: Character) -> Int {
        for scalar in character.unicodeScalars {
            switch scalar.value {
            case 0x1100...0x115F,
                 0x2E80...0xA4CF,
                 0xAC00...0xD7A3,
                 0xF900...0xFAFF,
                 0xFE10...0xFE19,
                 0xFE30...0xFE6F,
                 0xFF00...0xFF60,
                 0xFFE0...0xFFE6:
                return 2
            default:
                continue
            }
        }
        return 1
    }
}
