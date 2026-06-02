import AppKit

public struct ImageRenderOptions {
    public let maxFileSizeBytes: UInt64
    public let maxDisplaySize: NSSize

    public init(
        maxFileSizeBytes: UInt64 = 10 * 1024 * 1024,
        maxDisplaySize: NSSize = NSSize(width: 720, height: 480)
    ) {
        self.maxFileSizeBytes = maxFileSizeBytes
        self.maxDisplaySize = maxDisplaySize
    }
}

private struct InlineStyle {
    var bold = false
    var italic = false
    var strikethrough = false
}

public struct NativeAttributedStringRenderer {
    private let imageResolver: LocalImageResolver?
    private let imageOptions: ImageRenderOptions
    public let theme: MarkdownRenderTheme

    public init(
        imageResolver: LocalImageResolver? = nil,
        imageOptions: ImageRenderOptions = ImageRenderOptions(),
        theme: MarkdownRenderTheme = .academicInkBlue
    ) {
        self.imageResolver = imageResolver
        self.imageOptions = imageOptions
        self.theme = theme
    }

    public func render(_ blocks: [MarkdownBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for block in blocks {
            switch block {
            case let .heading(level, text):
                result.append(markdownLine(
                    text,
                    font: .systemFont(ofSize: headingSize(level), weight: .semibold),
                    boldFont: .systemFont(ofSize: headingSize(level), weight: .bold),
                    color: headingColor(level),
                    boldColor: headingColor(level),
                    spacing: 10
                ))
            case let .paragraph(text):
                result.append(markdownLine(
                    text,
                    font: .systemFont(ofSize: 14),
                    boldFont: .systemFont(ofSize: 14, weight: .semibold),
                    color: theme.primaryTextColor,
                    boldColor: theme.boldTextColor,
                    spacing: 8
                ))
            case let .blockquote(text):
                result.append(markdownLine(
                    "> \(text)",
                    font: .systemFont(ofSize: 14),
                    boldFont: .systemFont(ofSize: 14, weight: .semibold),
                    color: theme.quoteAccentColor,
                    boldColor: theme.quoteAccentColor,
                    spacing: 8
                ))
            case let .unorderedList(items):
                for item in items {
                    result.append(markdownLine(
                        unorderedListDisplayText(item),
                        font: .systemFont(ofSize: 14),
                        boldFont: .systemFont(ofSize: 14, weight: .semibold),
                        color: theme.primaryTextColor,
                        boldColor: theme.boldTextColor,
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
                        color: theme.primaryTextColor,
                        boldColor: theme.boldTextColor,
                        spacing: 4
                    ))
                }
                result.append(NSAttributedString(string: "\n"))
            case let .image(alt, path):
                result.append(imageBlock(alt: alt, path: path))
            case let .codeBlock(_, code):
                result.append(textBlock(
                    code,
                    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                    color: theme.primaryTextColor,
                    backgroundColor: theme.codeBackgroundColor,
                    spacingAfter: 10
                ))
            case .thematicBreak:
                result.append(thematicBreak())
            case let .table(table):
                result.append(tableBlock(table))
            case let .xyChart(chart):
                result.append(xyChartBlock(chart))
            case let .pieChart(chart):
                result.append(pieChartBlock(chart))
            case let .quadrantChart(chart):
                result.append(quadrantChartBlock(chart))
            case let .timeline(timeline):
                result.append(timelineBlock(timeline))
            }
        }

        return result
    }

    public func renderPlainText(_ text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 6

        return NSAttributedString(
            string: plainPreviewText(text),
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: theme.primaryTextColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}

private extension NativeAttributedStringRenderer {
    func plainPreviewText(_ text: String) -> String {
        var output = text
        while let start = output.range(of: ""),
              let end = output[start.upperBound...].range(of: "") {
            let markerRange = start.lowerBound..<end.upperBound
            let marker = String(output[markerRange])
            output.replaceSubrange(markerRange, with: replacement(forMarker: marker))
        }
        output = output.replacingOccurrences(of: "\\*\\*", with: "**")
        output = output.replacingOccurrences(of: "\\_\\_", with: "__")
        output = output.replacingOccurrences(of: "\\*", with: "*")
        output = output.replacingOccurrences(of: "\\_", with: "_")
        output = output.replacingOccurrences(of: "\\~", with: "~")
        output = output.replacingOccurrences(of: "\\`", with: "`")
        output = output.replacingOccurrences(of: "\\[", with: "[")
        output = output.replacingOccurrences(of: "\\]", with: "]")
        output = output.replacingOccurrences(of: "\\(", with: "(")
        output = output.replacingOccurrences(of: "\\)", with: ")")
        output = output.replacingOccurrences(of: " ()", with: "")
        output = output.replacingOccurrences(of: "()", with: "")
        return output
    }

    func displayText(_ text: String) -> String {
        return plainPreviewText(text)
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

    func headingColor(_ level: Int) -> NSColor {
        switch level {
        case 1:
            return theme.heading1TextColor
        case 2:
            return theme.heading2TextColor
        case 3:
            return theme.heading3TextColor
        default:
            return theme.heading2TextColor
        }
    }

    func unorderedListDisplayText(_ item: String) -> String {
        if item.hasPrefix("[x] ") || item.hasPrefix("[X] ") {
            return "☑ \(item.dropFirst(4))"
        }
        if item.hasPrefix("[ ] ") {
            return "☐ \(item.dropFirst(4))"
        }
        return "- \(item)"
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
        color: NSColor,
        boldColor: NSColor,
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
            boldColor: boldColor,
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
        boldColor: NSColor,
        paragraph: NSParagraphStyle
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        appendInlineMarkdown(
            text,
            to: result,
            style: InlineStyle(),
            font: font,
            boldFont: boldFont,
            italicFont: italicFont(for: font),
            boldItalicFont: italicFont(for: boldFont),
            color: color,
            boldColor: boldColor,
            paragraph: paragraph
        )
        return result
    }

    func appendInlineMarkdown(
        _ text: String,
        to result: NSMutableAttributedString,
        style: InlineStyle,
        font: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        boldItalicFont: NSFont,
        color: NSColor,
        boldColor: NSColor,
        paragraph: NSParagraphStyle
    ) {
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "`",
               let closing = findClosing("`", in: text, after: text.index(after: index)) {
                appendCodeText(
                    String(text[text.index(after: index)..<closing]),
                    to: result,
                    paragraph: paragraph
                )
                index = text.index(after: closing)
                continue
            }

            if let link = parseInlineLink(in: text, at: index) {
                appendLinkedText(
                    link.label,
                    destination: link.destination,
                    to: result,
                    style: style,
                    font: font,
                    boldFont: boldFont,
                    italicFont: italicFont,
                    boldItalicFont: boldItalicFont,
                    paragraph: paragraph
                )
                index = link.end
                continue
            }

            if let link = parseAngleAutolink(in: text, at: index) {
                appendLinkedText(
                    link.label,
                    destination: link.destination,
                    to: result,
                    style: style,
                    font: font,
                    boldFont: boldFont,
                    italicFont: italicFont,
                    boldItalicFont: boldItalicFont,
                    paragraph: paragraph
                )
                index = link.end
                continue
            }

            if let link = parseBareURL(in: text, at: index) {
                appendLinkedText(
                    link.label,
                    destination: link.destination,
                    to: result,
                    style: style,
                    font: font,
                    boldFont: boldFont,
                    italicFont: italicFont,
                    boldItalicFont: boldItalicFont,
                    paragraph: paragraph
                )
                index = link.end
                continue
            }

            if let marker = inlineMarker(in: text, at: index),
               let closing = findClosing(marker.literal, in: text, after: text.index(index, offsetBy: marker.literal.count)) {
                var nextStyle = style
                nextStyle.bold = nextStyle.bold || marker.bold
                nextStyle.italic = nextStyle.italic || marker.italic
                nextStyle.strikethrough = nextStyle.strikethrough || marker.strikethrough

                appendInlineMarkdown(
                    String(text[text.index(index, offsetBy: marker.literal.count)..<closing]),
                    to: result,
                    style: nextStyle,
                    font: font,
                    boldFont: boldFont,
                    italicFont: italicFont,
                    boldItalicFont: boldItalicFont,
                    color: color,
                    boldColor: boldColor,
                    paragraph: paragraph
                )
                index = text.index(closing, offsetBy: marker.literal.count)
                continue
            }

            let nextIndex = text.index(after: index)
            appendStyledText(
                String(text[index..<nextIndex]),
                to: result,
                style: style,
                font: font,
                boldFont: boldFont,
                italicFont: italicFont,
                boldItalicFont: boldItalicFont,
                color: color,
                boldColor: boldColor,
                paragraph: paragraph
            )
            index = nextIndex
        }
    }

    func appendStyledText(
        _ text: String,
        to result: NSMutableAttributedString,
        style: InlineStyle,
        font: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        boldItalicFont: NSFont,
        color: NSColor,
        boldColor: NSColor,
        paragraph: NSParagraphStyle
    ) {
        result.append(NSAttributedString(
            string: text,
            attributes: attributes(
                for: style,
                font: font,
                boldFont: boldFont,
                italicFont: italicFont,
                boldItalicFont: boldItalicFont,
                color: color,
                boldColor: boldColor,
                paragraph: paragraph
            )
        ))
    }

    func appendCodeText(_ text: String, to result: NSMutableAttributedString, paragraph: NSParagraphStyle) {
        result.append(NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: theme.primaryTextColor,
                .backgroundColor: theme.codeBackgroundColor,
                .paragraphStyle: paragraph
            ]
        ))
    }

    func appendLinkedText(
        _ text: String,
        destination: String,
        to result: NSMutableAttributedString,
        style: InlineStyle,
        font: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        boldItalicFont: NSFont,
        paragraph: NSParagraphStyle
    ) {
        var attributes = attributes(
            for: style,
            font: font,
            boldFont: boldFont,
            italicFont: italicFont,
            boldItalicFont: boldItalicFont,
            color: theme.quoteAccentColor,
            boldColor: theme.quoteAccentColor,
            paragraph: paragraph
        )
        attributes[.link] = destination
        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        result.append(NSAttributedString(string: text, attributes: attributes))
    }

    func attributes(
        for style: InlineStyle,
        font: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        boldItalicFont: NSFont,
        color: NSColor,
        boldColor: NSColor,
        paragraph: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont(
                for: style,
                font: font,
                boldFont: boldFont,
                italicFont: italicFont,
                boldItalicFont: boldItalicFont
            ),
            .foregroundColor: style.bold ? boldColor : color,
            .paragraphStyle: paragraph
        ]
        if style.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }

    func resolvedFont(
        for style: InlineStyle,
        font: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        boldItalicFont: NSFont
    ) -> NSFont {
        if style.bold && style.italic { return boldItalicFont }
        if style.bold { return boldFont }
        if style.italic { return italicFont }
        return font
    }

    func italicFont(for font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }

    func inlineMarker(in text: String, at index: String.Index) -> (literal: String, bold: Bool, italic: Bool, strikethrough: Bool)? {
        let markers: [(String, Bool, Bool, Bool)] = [
            ("***", true, true, false),
            ("___", true, true, false),
            ("**", true, false, false),
            ("__", true, false, false),
            ("~~", false, false, true),
            ("*", false, true, false),
            ("_", false, true, false)
        ]

        for marker in markers where matchesMarker(marker.0, in: text, at: index) {
            return marker
        }
        return nil
    }

    func matchesMarker(_ marker: String, in text: String, at index: String.Index) -> Bool {
        guard text[index...].hasPrefix(marker) else { return false }
        if marker == "*" || marker == "_" {
            if text[index...].hasPrefix(marker + marker) { return false }
            if index > text.startIndex {
                let previous = text[text.index(before: index)]
                if String(previous) == marker { return false }
            }
            let next = text.index(after: index)
            if next < text.endIndex, String(text[next]) == marker { return false }
            if marker == "_",
               index > text.startIndex,
               next < text.endIndex,
               text[text.index(before: index)].isLetter || text[text.index(before: index)].isNumber,
               text[next].isLetter || text[next].isNumber {
                return false
            }
        }
        return true
    }

    func findClosing(_ marker: String, in text: String, after start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if text[index] == "\\" {
                index = text.index(after: index)
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                continue
            }
            if matchesMarker(marker, in: text, at: index) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    func parseInlineLink(in text: String, at index: String.Index) -> (label: String, destination: String, end: String.Index)? {
        guard text[index] == "[" else { return nil }
        guard let closeLabel = text[index...].firstIndex(of: "]") else { return nil }
        let openDestination = text.index(after: closeLabel)
        guard openDestination < text.endIndex, text[openDestination] == "(" else { return nil }
        guard let closeDestination = text[openDestination...].firstIndex(of: ")") else { return nil }

        let labelStart = text.index(after: index)
        let destinationStart = text.index(after: openDestination)
        let label = String(text[labelStart..<closeLabel])
        let destination = String(text[destinationStart..<closeDestination])
        guard !label.isEmpty, !destination.isEmpty else { return nil }
        return (label, destination, text.index(after: closeDestination))
    }

    func parseAngleAutolink(in text: String, at index: String.Index) -> (label: String, destination: String, end: String.Index)? {
        guard text[index] == "<",
              let close = text[index...].firstIndex(of: ">") else {
            return nil
        }
        let start = text.index(after: index)
        let label = String(text[start..<close])
        guard isAutolink(label) else { return nil }
        return (label, label, text.index(after: close))
    }

    func parseBareURL(in text: String, at index: String.Index) -> (label: String, destination: String, end: String.Index)? {
        guard text[index...].hasPrefix("http://") || text[index...].hasPrefix("https://") else {
            return nil
        }

        var end = index
        while end < text.endIndex, !text[end].isWhitespace {
            end = text.index(after: end)
        }

        var trimmedEnd = end
        while trimmedEnd > index {
            let previous = text[text.index(before: trimmedEnd)]
            if ".,;:)]}".contains(previous) {
                trimmedEnd = text.index(before: trimmedEnd)
            } else {
                break
            }
        }
        guard trimmedEnd > index else { return nil }
        let label = String(text[index..<trimmedEnd])
        return (label, label, trimmedEnd)
    }

    func isAutolink(_ text: String) -> Bool {
        text.hasPrefix("http://") ||
            text.hasPrefix("https://") ||
            (text.contains("@") && !text.contains(" "))
    }

    func textBlock(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        backgroundColor: NSColor? = nil,
        spacingAfter: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if let backgroundColor {
            attributes[.backgroundColor] = backgroundColor
        }

        let result = NSMutableAttributedString(
            string: text + "\n",
            attributes: attributes
        )
        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = spacingAfter
        result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: spacer]))
        return result
    }

    func thematicBreak() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 12
        return NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .paragraphStyle: paragraph
        ])
    }

    func tableBlock(_ table: MarkdownTable) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let columnCount = tableColumnCount(for: table)
        let columnWidths = tableColumnWidthPercentages(for: table, columnCount: columnCount)
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.layoutAlgorithm = .fixedLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false
        textTable.setContentWidth(100, type: .percentageValueType)

        appendTableRow(
            table.headers,
            to: result,
            textTable: textTable,
            rowIndex: 0,
            columnCount: columnCount,
            columnWidths: columnWidths,
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
                columnWidths: columnWidths,
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
        columnWidths: [CGFloat],
        alignments: [MarkdownTable.Alignment],
        isHeader: Bool
    ) {
        let font = NSFont.systemFont(ofSize: 13, weight: isHeader ? .semibold : .regular)
        let boldFont = NSFont.systemFont(ofSize: 13, weight: .bold)

        for columnIndex in 0..<columnCount {
            let cellText = columnIndex < cells.count ? cells[columnIndex] : ""
            let paragraph = tableCellParagraphStyle(
                textTable: textTable,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                columnCount: columnCount,
                columnWidth: columnWidths[columnIndex],
                alignment: columnIndex < alignments.count ? alignments[columnIndex] : .left,
                isHeader: isHeader
            )
            result.append(inlineMarkdown(
                displayText(cellText),
                font: font,
                boldFont: boldFont,
                color: isHeader ? theme.heading2TextColor : theme.primaryTextColor,
                boldColor: isHeader ? theme.heading2TextColor : theme.boldTextColor,
                paragraph: paragraph
            ))
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: font,
                .foregroundColor: isHeader ? theme.heading2TextColor : theme.primaryTextColor,
                .paragraphStyle: paragraph
            ]))
        }
    }

    func tableCellParagraphStyle(
        textTable: NSTextTable,
        rowIndex: Int,
        columnIndex: Int,
        columnCount: Int,
        columnWidth: CGFloat,
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
        block.setContentWidth(columnWidth, type: .percentageValueType)
        block.setWidth(7, type: .absoluteValueType, for: .padding)
        block.verticalAlignment = .topAlignment
        if isHeader {
            block.backgroundColor = theme.tableHeaderBackgroundColor
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.textBlocks = [block]
        paragraph.alignment = textAlignment(for: alignment)
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 0
        return paragraph
    }

    func tableColumnWidthPercentages(for table: MarkdownTable, columnCount: Int) -> [CGFloat] {
        let headerFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let rowFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let rows = [table.headers] + table.rows
        let rawWidths = (0..<columnCount).map { columnIndex in
            let measured = rows.enumerated().compactMap { rowIndex, row -> CGFloat? in
                guard columnIndex < row.count else { return nil }
                let font = rowIndex == 0 ? headerFont : rowFont
                return measuredColumnWidth(row[columnIndex], font: font, columnCount: columnCount)
            }
            let widest = measured.max() ?? 80
            return widest
        }

        let total = rawWidths.reduce(0, +)
        guard total > 0 else {
            return Array(repeating: 100 / CGFloat(columnCount), count: columnCount)
        }
        return rawWidths.map { $0 / total * 100 }
    }

    func measuredColumnWidth(_ text: String, font: NSFont, columnCount: Int) -> CGFloat {
        let plainText = plainInlineText(text, font: font)
        let readableWidth = measuredTextWidth(plainText, font: font)
        let tokenWidth = longestUnbreakableTokenWidth(in: plainText, font: font)
        let baseMinimum: CGFloat = columnCount >= 6 ? 96 : 80
        let maximum: CGFloat = columnCount >= 6 ? 220 : 360
        let preferredWeight: CGFloat = columnCount >= 6 ? 0.35 : 0.75
        let minimum = min(max(tokenWidth + 18, baseMinimum), maximum)
        let preferred = min(max(readableWidth + 18, minimum), maximum)
        return minimum + (preferred - minimum) * preferredWeight
    }

    func measuredCellWidth(_ text: String, font: NSFont) -> CGFloat {
        measuredTextWidth(plainInlineText(text, font: font), font: font)
    }

    func plainInlineText(_ text: String, font: NSFont) -> String {
        let paragraph = NSMutableParagraphStyle()
        return inlineMarkdown(
            displayText(text),
            font: font,
            boldFont: font,
            color: theme.primaryTextColor,
            boldColor: theme.primaryTextColor,
            paragraph: paragraph
        ).string
    }

    func measuredTextWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    func longestUnbreakableTokenWidth(in text: String, font: NSFont) -> CGFloat {
        let tokens = asciiWordTokens(in: text)
        guard !tokens.isEmpty else { return 0 }
        return tokens.map { measuredTextWidth($0, font: font) }.max() ?? 0
    }

    func asciiWordTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for character in text {
            if character.isASCIIWordTokenCharacter {
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current)
                current.removeAll()
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
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

    func imageBlock(alt: String, path: String) -> NSAttributedString {
        guard let imageResolver else {
            return fallbackImageLine(alt: alt, path: path)
        }

        switch imageResolver.resolve(path) {
        case let .remoteRejected(remotePath):
            return line(
                "Remote image not loaded: \(remotePath)",
                font: .systemFont(ofSize: 13),
                color: theme.secondaryTextColor,
                spacing: 8
            )
        case let .missing(missingPath):
            return line(
                "Missing image: \(missingPath)",
                font: .systemFont(ofSize: 13),
                color: theme.secondaryTextColor,
                spacing: 8
            )
        case let .local(url):
            guard isSupportedLocalImage(url) else {
                return line(
                    "Unsupported image: \(path)",
                    font: .systemFont(ofSize: 13),
                    color: theme.secondaryTextColor,
                    spacing: 8
                )
            }

            guard localFileSize(url) <= imageOptions.maxFileSizeBytes else {
                return line(
                    "Image too large: \(path)",
                    font: .systemFont(ofSize: 13),
                    color: theme.secondaryTextColor,
                    spacing: 8
                )
            }

            guard let image = NSImage(contentsOf: url),
                  image.size.width > 0,
                  image.size.height > 0 else {
                return line(
                    "Image could not be loaded: \(path)",
                    font: .systemFont(ofSize: 13),
                    color: theme.secondaryTextColor,
                    spacing: 8
                )
            }

            return imageAttachmentBlock(image)
        }
    }

    func fallbackImageLine(alt: String, path: String) -> NSAttributedString {
        let lowercasePath = path.lowercased()
        let isRemote = lowercasePath.hasPrefix("http://") || lowercasePath.hasPrefix("https://")
        let label = isRemote
            ? "Remote image not loaded: \(path)"
            : "Image: \(alt.isEmpty ? path : alt)"
        return line(
            label,
            font: .systemFont(ofSize: 13),
            color: theme.secondaryTextColor,
            spacing: 8
        )
    }

    func imageAttachmentBlock(_ image: NSImage) -> NSAttributedString {
        let scaledSize = scaledImageSize(image.size, maxSize: imageOptions.maxDisplaySize)
        image.size = scaledSize

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -4, width: scaledSize.width, height: scaledSize.height)

        let result = NSMutableAttributedString(attachment: attachment)
        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = 10
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .paragraphStyle: spacer
        ]))
        return result
    }

    func isSupportedLocalImage(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "tif", "tiff", "heic", "heif", "webp", "ppm"
        ]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func localFileSize(_ url: URL) -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? UInt64) ?? 0
    }

    func scaledImageSize(_ size: NSSize, maxSize: NSSize) -> NSSize {
        guard size.width > 0, size.height > 0 else { return size }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1)
        return NSSize(width: size.width * scale, height: size.height * scale)
    }

    func xyChartBlock(_ chart: MarkdownXYChart) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if !chart.title.isEmpty {
            result.append(line(
                chart.title,
                font: .systemFont(ofSize: 14, weight: .semibold),
                color: theme.heading2TextColor,
                spacing: 4
            ))
        }

        let image = xyChartImage(for: chart)
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -4, width: image.size.width, height: image.size.height)

        result.append(NSAttributedString(attachment: attachment))

        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = 12
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .paragraphStyle: spacer
        ]))
        return result
    }

    func xyChartImage(for chart: MarkdownXYChart) -> NSImage {
        let size = NSSize(width: 720, height: 320)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        theme.backgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let plotRect = NSRect(x: 58, y: 54, width: size.width - 82, height: size.height - 82)
        drawChartGrid(in: plotRect, chart: chart)
        drawChartSeries(in: plotRect, chart: chart)
        drawChartLabels(in: plotRect, chart: chart)

        return image
    }

    func pieChartBlock(_ chart: MarkdownPieChart) -> NSAttributedString {
        chartBlock(title: chart.title, image: pieChartImage(for: chart))
    }

    func quadrantChartBlock(_ chart: MarkdownQuadrantChart) -> NSAttributedString {
        chartBlock(title: chart.title, image: quadrantChartImage(for: chart))
    }

    func timelineBlock(_ timeline: MarkdownTimeline) -> NSAttributedString {
        chartBlock(title: timeline.title, image: timelineImage(for: timeline))
    }

    func chartBlock(title: String, image: NSImage) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if !title.isEmpty {
            result.append(line(
                title,
                font: .systemFont(ofSize: 14, weight: .semibold),
                color: theme.heading2TextColor,
                spacing: 4
            ))
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -4, width: image.size.width, height: image.size.height)
        result.append(NSAttributedString(attachment: attachment))

        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacing = 12
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 1),
            .paragraphStyle: spacer
        ]))
        return result
    }

    func pieChartImage(for chart: MarkdownPieChart) -> NSImage {
        let size = NSSize(width: 720, height: 320)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        theme.backgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let total = chart.slices.map(\.value).reduce(0, +)
        guard total > 0 else { return image }

        let center = NSPoint(x: 190, y: 160)
        let radius: CGFloat = 102
        var startAngle: CGFloat = 90

        for (index, slice) in chart.slices.enumerated() {
            let sweep = CGFloat(slice.value / total) * 360
            let endAngle = startAngle - sweep
            let path = NSBezierPath()
            path.move(to: center)
            path.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            path.close()
            chartPaletteColor(index).setFill()
            path.fill()

            if chart.showData, sweep > 18 {
                let midAngle = (startAngle + endAngle) / 2 * .pi / 180
                let labelPoint = NSPoint(
                    x: center.x + cos(midAngle) * radius * 0.58 - 16,
                    y: center.y + sin(midAngle) * radius * 0.58 - 7
                )
                drawChartText(formatPercentage(slice.value / total), at: labelPoint, font: .systemFont(ofSize: 10, weight: .medium), color: theme.backgroundColor)
            }

            startAngle = endAngle
        }

        drawLegend(
            items: chart.slices.enumerated().map { index, slice in
                "\(slice.label)  \(formatValue(slice.value))"
            },
            colors: chart.slices.indices.map(chartPaletteColor),
            at: NSPoint(x: 360, y: 238)
        )

        return image
    }

    func quadrantChartImage(for chart: MarkdownQuadrantChart) -> NSImage {
        let size = NSSize(width: 720, height: 380)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        theme.backgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let plotRect = NSRect(x: 88, y: 56, width: 440, height: 280)
        theme.subtleRuleColor.withAlphaComponent(0.45).setFill()
        NSRect(x: plotRect.minX, y: plotRect.midY, width: plotRect.width / 2, height: plotRect.height / 2).fill()
        NSRect(x: plotRect.midX, y: plotRect.minY, width: plotRect.width / 2, height: plotRect.height / 2).fill()

        theme.ruleColor.setStroke()
        let border = NSBezierPath(rect: plotRect)
        border.lineWidth = 1
        border.stroke()

        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: plotRect.midX, y: plotRect.minY))
        vertical.line(to: NSPoint(x: plotRect.midX, y: plotRect.maxY))
        vertical.stroke()

        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: plotRect.minX, y: plotRect.midY))
        horizontal.line(to: NSPoint(x: plotRect.maxX, y: plotRect.midY))
        horizontal.stroke()

        drawQuadrantLabels(chart.quadrants, in: plotRect)
        drawChartText(chart.xAxisStart, at: NSPoint(x: plotRect.minX, y: 24), font: .systemFont(ofSize: 10), color: theme.secondaryTextColor)
        drawChartText(chart.xAxisEnd, at: NSPoint(x: plotRect.maxX - 96, y: 24), font: .systemFont(ofSize: 10), color: theme.secondaryTextColor)
        drawChartText(chart.yAxisStart, at: NSPoint(x: 10, y: plotRect.minY), font: .systemFont(ofSize: 10), color: theme.secondaryTextColor)
        drawChartText(chart.yAxisEnd, at: NSPoint(x: 10, y: plotRect.maxY - 14), font: .systemFont(ofSize: 10), color: theme.secondaryTextColor)

        for (index, point) in chart.points.enumerated() {
            let x = plotRect.minX + CGFloat(point.x) * plotRect.width
            let y = plotRect.minY + CGFloat(point.y) * plotRect.height
            let dotRect = NSRect(x: x - 4, y: y - 4, width: 8, height: 8)
            chartPaletteColor(index).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            drawChartText(point.label, at: NSPoint(x: x + 7, y: y - 6), font: .systemFont(ofSize: 9), color: theme.primaryTextColor)
        }

        return image
    }

    func timelineImage(for timeline: MarkdownTimeline) -> NSImage {
        let rowHeight: CGFloat = 52
        let size = NSSize(width: 720, height: max(260, CGFloat(timeline.periods.count) * rowHeight + 42))
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        theme.backgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let lineX: CGFloat = 130
        let topY = size.height - 34
        let bottomY: CGFloat = 34
        theme.ruleColor.setStroke()
        let spine = NSBezierPath()
        spine.move(to: NSPoint(x: lineX, y: bottomY))
        spine.line(to: NSPoint(x: lineX, y: topY))
        spine.lineWidth = 1.3
        spine.stroke()

        for (index, period) in timeline.periods.enumerated() {
            let y = topY - CGFloat(index) * rowHeight
            chartPaletteColor(index).setFill()
            NSBezierPath(ovalIn: NSRect(x: lineX - 5, y: y - 5, width: 10, height: 10)).fill()
            let labelFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
            let eventFont = NSFont.systemFont(ofSize: 11)
            let textBaselineY = y - 9
            drawChartText(period.label, at: NSPoint(x: 28, y: textBaselineY), font: labelFont, color: theme.heading2TextColor)

            let eventText = period.events.joined(separator: "  /  ")
            drawWrappedChartText(
                eventText,
                in: NSRect(x: 154, y: textBaselineY - 13, width: 540, height: 32),
                font: eventFont,
                color: theme.primaryTextColor
            )
        }

        return image
    }

    func drawChartGrid(in plotRect: NSRect, chart: MarkdownXYChart) {
        let axisColor = theme.ruleColor
        let gridColor = theme.subtleRuleColor
        let tickCount = 5

        for tick in 0...tickCount {
            let fraction = CGFloat(tick) / CGFloat(tickCount)
            let y = plotRect.minY + plotRect.height * fraction
            let path = NSBezierPath()
            path.move(to: NSPoint(x: plotRect.minX, y: y))
            path.line(to: NSPoint(x: plotRect.maxX, y: y))
            (tick == 0 ? axisColor : gridColor).setStroke()
            path.lineWidth = tick == 0 ? 1.2 : 0.6
            path.stroke()

            let value = chart.yAxisRange.lowerBound + Double(fraction) * (chart.yAxisRange.upperBound - chart.yAxisRange.lowerBound)
            drawChartText(formatTick(value), at: NSPoint(x: 8, y: y - 7), font: .systemFont(ofSize: 10), color: theme.secondaryTextColor)
        }

        let yAxis = NSBezierPath()
        yAxis.move(to: NSPoint(x: plotRect.minX, y: plotRect.minY))
        yAxis.line(to: NSPoint(x: plotRect.minX, y: plotRect.maxY))
        axisColor.setStroke()
        yAxis.lineWidth = 1.2
        yAxis.stroke()

        if !chart.yAxisLabel.isEmpty {
            drawChartText(chart.yAxisLabel, at: NSPoint(x: plotRect.minX, y: plotRect.maxY + 12), font: .systemFont(ofSize: 10, weight: .medium), color: theme.secondaryTextColor)
        }
    }

    func drawChartSeries(in plotRect: NSRect, chart: MarkdownXYChart) {
        let count = chartPointCount(chart)
        guard count > 0 else { return }

        let barSeries = chart.series.filter { $0.kind == .bar }
        let lineSeries = chart.series.filter { $0.kind == .line }
        let slotWidth = plotRect.width / CGFloat(count)
        let zeroY = yPosition(for: 0, in: plotRect, range: chart.yAxisRange)

        for (seriesIndex, series) in barSeries.enumerated() {
            let barGroupWidth = slotWidth * 0.54
            let barWidth = max(4, barGroupWidth / CGFloat(max(barSeries.count, 1)))
            let startOffset = -barGroupWidth / 2 + barWidth * CGFloat(seriesIndex)

            for index in 0..<min(count, series.values.count) {
                let value = series.values[index]
                let xCenter = plotRect.minX + slotWidth * (CGFloat(index) + 0.5)
                let y = yPosition(for: value, in: plotRect, range: chart.yAxisRange)
                let rect = NSRect(
                    x: xCenter + startOffset,
                    y: min(zeroY, y),
                    width: barWidth * 0.82,
                    height: max(abs(y - zeroY), 1)
                )
                theme.chartColor.withAlphaComponent(0.86).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
            }
        }

        for series in lineSeries {
            let path = NSBezierPath()
            for index in 0..<min(count, series.values.count) {
                let point = NSPoint(
                    x: plotRect.minX + slotWidth * (CGFloat(index) + 0.5),
                    y: yPosition(for: series.values[index], in: plotRect, range: chart.yAxisRange)
                )
                index == 0 ? path.move(to: point) : path.line(to: point)
            }
            theme.chartColor.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    func drawChartLabels(in plotRect: NSRect, chart: MarkdownXYChart) {
        let count = chartPointCount(chart)
        guard count > 0 else { return }

        let slotWidth = plotRect.width / CGFloat(count)
        let font = NSFont.systemFont(ofSize: 10)
        for index in 0..<min(count, chart.xAxisLabels.count) {
            let label = chart.xAxisLabels[index]
            let labelSize = (label as NSString).size(withAttributes: [.font: font])
            let x = plotRect.minX + slotWidth * (CGFloat(index) + 0.5) - labelSize.width / 2
            drawChartText(label, at: NSPoint(x: x, y: plotRect.minY - 24), font: font, color: theme.secondaryTextColor)
        }
    }

    func drawChartText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
        (text as NSString).draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    func drawWrappedChartText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    func drawLegend(items: [String], colors: [NSColor], at origin: NSPoint) {
        for (index, item) in items.enumerated() {
            let y = origin.y - CGFloat(index) * 28
            colors[index % max(colors.count, 1)].setFill()
            NSBezierPath(roundedRect: NSRect(x: origin.x, y: y - 2, width: 12, height: 12), xRadius: 2, yRadius: 2).fill()
            drawChartText(item, at: NSPoint(x: origin.x + 20, y: y - 4), font: .systemFont(ofSize: 11), color: theme.primaryTextColor)
        }
    }

    func drawQuadrantLabels(_ labels: [String], in plotRect: NSRect) {
        let positions = [
            NSPoint(x: plotRect.midX + 12, y: plotRect.maxY - 24),
            NSPoint(x: plotRect.minX + 12, y: plotRect.maxY - 24),
            NSPoint(x: plotRect.minX + 12, y: plotRect.midY - 24),
            NSPoint(x: plotRect.midX + 12, y: plotRect.midY - 24)
        ]

        for index in 0..<min(labels.count, positions.count) where !labels[index].isEmpty {
            drawChartText(labels[index], at: positions[index], font: .systemFont(ofSize: 11, weight: .medium), color: theme.secondaryTextColor)
        }
    }

    func chartPaletteColor(_ index: Int) -> NSColor {
        let colors = [
            theme.chartColor,
            theme.quoteAccentColor,
            theme.heading2TextColor,
            theme.boldTextColor,
            theme.secondaryTextColor
        ]
        return colors[index % colors.count]
    }

    func formatPercentage(_ value: Double) -> String {
        "\(Int(round(value * 100)))%"
    }

    func formatValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    func yPosition(for value: Double, in plotRect: NSRect, range: ClosedRange<Double>) -> CGFloat {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let fraction = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        return plotRect.minY + CGFloat(fraction) * plotRect.height
    }

    func chartPointCount(_ chart: MarkdownXYChart) -> Int {
        max(
            chart.xAxisLabels.count,
            chart.series.map(\.values.count).max() ?? 0
        )
    }

    func formatTick(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private extension Character {
    var isASCIIWordTokenCharacter: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1, scalar.isASCII else {
            return false
        }

        if CharacterSet.alphanumerics.contains(scalar) {
            return true
        }

        return scalar == "/" || scalar == "-" || scalar == "_" || scalar == "."
    }
}
