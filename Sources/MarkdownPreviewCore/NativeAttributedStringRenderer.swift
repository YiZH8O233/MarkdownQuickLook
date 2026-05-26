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
        let columnCount = tableColumnCount(for: table)
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false
        textTable.setContentWidth(100, type: .percentageValueType)

        appendTableRow(
            table.headers,
            to: result,
            textTable: textTable,
            rowIndex: 0,
            columnCount: columnCount,
            alignments: table.alignments,
            isHeader: true
        )

        for (offset, row) in table.rows.enumerated() {
            appendTableRow(
                row,
                to: result,
                textTable: textTable,
                rowIndex: offset + 1,
                columnCount: columnCount,
                alignments: table.alignments,
                isHeader: false
            )
        }

        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = 10
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .paragraphStyle: spacer
        ]))
        return result
    }

    func appendTableRow(
        _ cells: [String],
        to result: NSMutableAttributedString,
        textTable: NSTextTable,
        rowIndex: Int,
        columnCount: Int,
        alignments: [MarkdownTable.Alignment],
        isHeader: Bool
    ) {
        let font = NSFont.systemFont(ofSize: 13, weight: isHeader ? .semibold : .regular)

        for columnIndex in 0..<columnCount {
            let cellText = columnIndex < cells.count ? cells[columnIndex] : ""
            let paragraph = tableCellParagraphStyle(
                textTable: textTable,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                alignment: columnIndex < alignments.count ? alignments[columnIndex] : .left,
                isHeader: isHeader
            )
            result.append(NSAttributedString(
                string: displayText(cellText) + "\n",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ]
            ))
        }
    }

    func tableCellParagraphStyle(
        textTable: NSTextTable,
        rowIndex: Int,
        columnIndex: Int,
        alignment: MarkdownTable.Alignment,
        isHeader: Bool
    ) -> NSParagraphStyle {
        let block = NSTextTableBlock(
            table: textTable,
            startingRow: rowIndex,
            rowSpan: 1,
            startingColumn: columnIndex,
            columnSpan: 1
        )
        block.setWidth(0.5, type: .absoluteValueType, for: .border)
        block.setWidth(7, type: .absoluteValueType, for: .padding)
        block.setBorderColor(NSColor.separatorColor.withAlphaComponent(0.45))
        block.verticalAlignment = .topAlignment
        if isHeader {
            block.backgroundColor = NSColor.controlBackgroundColor
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.textBlocks = [block]
        paragraph.alignment = textAlignment(for: alignment)
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 0
        return paragraph
    }

    func tableColumnCount(for table: MarkdownTable) -> Int {
        max(
            table.headers.count,
            table.rows.map(\.count).max() ?? 0,
            1
        )
    }

    func textAlignment(for alignment: MarkdownTable.Alignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}
