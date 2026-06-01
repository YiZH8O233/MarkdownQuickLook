import Foundation

public struct LineMarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if Self.isThematicBreak(trimmed) {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                let code = codeLines.joined(separator: "\n")
                if let chart = Self.parseXYChart(code, language: language) {
                    blocks.append(.xyChart(chart))
                } else {
                    blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: code))
                }
                continue
            }

            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                if let table = Self.parseTable(tableLines) {
                    blocks.append(.table(table))
                } else {
                    blocks.append(.paragraph(tableLines.joined(separator: " ")))
                }
                continue
            }

            if let image = Self.parseImage(trimmed) {
                blocks.append(image)
                index += 1
                continue
            }

            if let heading = Self.parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                blocks.append(.blockquote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
                index += 1
                continue
            }

            if Self.isUnorderedListItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard Self.isUnorderedListItem(candidate) else { break }
                    items.append(String(candidate.dropFirst(2)))
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if let ordered = Self.orderedListText(trimmed) {
                var items = [ordered]
                index += 1
                while index < lines.count, let item = Self.orderedListText(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if paragraphLines.count == 1,
                   let headingLevel = Self.setextHeadingLevel(next) {
                    blocks.append(.heading(level: headingLevel, text: paragraphLines[0]))
                    index += 1
                    paragraphLines.removeAll()
                    break
                }
                if next.isEmpty ||
                    Self.isThematicBreak(next) ||
                    next.hasPrefix("#") ||
                    next.hasPrefix(">") ||
                    next.hasPrefix("```") ||
                    next.hasPrefix("|") ||
                    Self.isUnorderedListItem(next) ||
                    Self.orderedListText(next) != nil ||
                    Self.parseImage(next) != nil {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            if paragraphLines.isEmpty {
                continue
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }
}

private extension LineMarkdownParser {
    static func parseHeading(_ line: String) -> MarkdownBlock? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }
        let text = line.dropFirst(markerCount).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: markerCount, text: text)
    }

    static func parseImage(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("!["),
              let closeAlt = line.firstIndex(of: "]"),
              line[line.index(after: closeAlt)...].hasPrefix("("),
              line.hasSuffix(")") else {
            return nil
        }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeAlt])
        let pathStart = line.index(closeAlt, offsetBy: 2)
        let pathEnd = line.index(before: line.endIndex)
        return .image(alt: alt, path: String(line[pathStart..<pathEnd]))
    }

    static func isUnorderedListItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ")
    }

    static func isThematicBreak(_ line: String) -> Bool {
        let characters = line.filter { !$0.isWhitespace }
        guard characters.count >= 3,
              let marker = characters.first,
              marker == "*" || marker == "-" || marker == "_" else {
            return false
        }
        return characters.allSatisfy { $0 == marker }
    }

    static func setextHeadingLevel(_ line: String) -> Int? {
        let characters = line.filter { !$0.isWhitespace }
        guard characters.count >= 2,
              let marker = characters.first,
              marker == "=" || marker == "-" else {
            return nil
        }
        guard characters.allSatisfy({ $0 == marker }) else {
            return nil
        }
        return marker == "=" ? 1 : 2
    }

    static func orderedListText(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let number = line[..<dot]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let textStart = line.index(after: dot)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return String(line[line.index(after: textStart)...])
    }

    static func parseTable(_ lines: [String]) -> MarkdownTable? {
        guard lines.count >= 2 else { return nil }

        let headers = splitTableRow(lines[0])
        let alignmentCells = splitTableRow(lines[1])
        guard !headers.isEmpty,
              !alignmentCells.isEmpty,
              alignmentCells.allSatisfy(isAlignmentCell) else {
            return nil
        }

        let alignments = alignmentCells.map(parseAlignment)
        let rows = lines.dropFirst(2).map(splitTableRow).filter { !$0.isEmpty }
        return MarkdownTable(
            headers: headers,
            alignments: normalizedAlignments(alignments, count: headers.count),
            rows: rows.map { normalizedRow($0, count: headers.count) }
        )
    }

    static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func isAlignmentCell(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let withoutColons = trimmed.replacingOccurrences(of: ":", with: "")
        return !withoutColons.isEmpty && withoutColons.allSatisfy { $0 == "-" }
    }

    static func parseAlignment(_ cell: String) -> MarkdownTable.Alignment {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") { return .center }
        if trimmed.hasSuffix(":") { return .right }
        return .left
    }

    static func normalizedAlignments(_ alignments: [MarkdownTable.Alignment], count: Int) -> [MarkdownTable.Alignment] {
        if alignments.count >= count { return Array(alignments.prefix(count)) }
        return alignments + Array(repeating: .left, count: count - alignments.count)
    }

    static func normalizedRow(_ row: [String], count: Int) -> [String] {
        if row.count >= count { return Array(row.prefix(count)) }
        return row + Array(repeating: "", count: count - row.count)
    }

    static func parseXYChart(_ code: String, language: String) -> MarkdownXYChart? {
        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedLanguage.isEmpty || normalizedLanguage == "mermaid" else { return nil }

        let lines = code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.first == "xychart-beta" else { return nil }

        var title = ""
        var xAxisLabels: [String] = []
        var yAxisLabel = ""
        var yAxisRange: ClosedRange<Double>?
        var series: [MarkdownXYChart.Series] = []

        for line in lines.dropFirst() {
            if line.hasPrefix("title ") {
                title = quotedString(after: "title", in: line) ?? String(line.dropFirst("title".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if line.hasPrefix("x-axis ") {
                xAxisLabels = quotedArray(in: line)
                continue
            }

            if line.hasPrefix("y-axis ") {
                let parsedAxis = parseYAxis(line)
                yAxisLabel = parsedAxis.label
                yAxisRange = parsedAxis.range
                continue
            }

            if line.hasPrefix("bar ") {
                series.append(.init(kind: .bar, values: numberArray(in: line)))
                continue
            }

            if line.hasPrefix("line ") {
                series.append(.init(kind: .line, values: numberArray(in: line)))
                continue
            }
        }

        guard !xAxisLabels.isEmpty,
              let yAxisRange,
              !series.isEmpty,
              series.allSatisfy({ !$0.values.isEmpty }) else {
            return nil
        }

        return MarkdownXYChart(
            title: title,
            xAxisLabels: xAxisLabels,
            yAxisLabel: yAxisLabel,
            yAxisRange: yAxisRange,
            series: series
        )
    }

    static func quotedString(after marker: String, in line: String) -> String? {
        let searchStart = line.index(line.startIndex, offsetBy: marker.count)
        guard let openingQuote = line[searchStart...].firstIndex(of: "\"") else { return nil }
        let valueStart = line.index(after: openingQuote)
        guard let closingQuote = line[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(line[valueStart..<closingQuote])
    }

    static func quotedArray(in line: String) -> [String] {
        guard let start = line.firstIndex(of: "["),
              let end = line.lastIndex(of: "]"),
              start < end else {
            return []
        }

        let content = line[line.index(after: start)..<end]
        var values: [String] = []
        var current = ""
        var inQuote = false
        var isEscaped = false

        for character in content {
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
                    values.append(current)
                    current = ""
                }
                inQuote.toggle()
                continue
            }

            if inQuote {
                current.append(character)
            }
        }

        return values
    }

    static func numberArray(in line: String) -> [Double] {
        guard let start = line.firstIndex(of: "["),
              let end = line.lastIndex(of: "]"),
              start < end else {
            return []
        }

        return line[line.index(after: start)..<end]
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func parseYAxis(_ line: String) -> (label: String, range: ClosedRange<Double>?) {
        let label = quotedString(after: "y-axis", in: line) ?? ""
        let withoutLabel: Substring
        if let openingQuote = line.firstIndex(of: "\""),
           let closingQuote = line[line.index(after: openingQuote)...].firstIndex(of: "\"") {
            withoutLabel = line[line.index(after: closingQuote)...]
        } else {
            withoutLabel = line.dropFirst("y-axis".count)
        }

        let parts = withoutLabel.components(separatedBy: "-->")
        guard parts.count == 2,
              let lower = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let upper = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              lower < upper else {
            return (label, nil)
        }

        return (label, lower...upper)
    }
}
