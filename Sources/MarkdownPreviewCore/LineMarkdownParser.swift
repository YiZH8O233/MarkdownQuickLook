import Foundation

public struct LineMarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var footnotes: [MarkdownFootnote] = []
        var index = 0

        while index < lines.count {
            if index == 0, let frontMatterEnd = Self.frontMatterEndIndex(in: lines) {
                index = frontMatterEnd + 1
                continue
            }

            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let footnote = Self.parseFootnoteDefinitionStart(trimmed) {
                var textLines = footnote.text.isEmpty ? [] : [footnote.text]
                index += 1
                while index < lines.count, Self.isFootnoteContinuation(lines[index]) {
                    let continuation = lines[index].trimmingCharacters(in: .whitespaces)
                    if !continuation.isEmpty {
                        textLines.append(continuation)
                    }
                    index += 1
                }
                footnotes.append(.init(label: footnote.label, text: textLines.joined(separator: " ")))
                continue
            }

            if Self.isThematicBreak(trimmed) {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            if let fence = Self.parseFenceStart(trimmed) {
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !Self.isFenceEnd(lines[index].trimmingCharacters(in: .whitespaces), fence: fence) {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                let code = codeLines.joined(separator: "\n")
                if let chart = Self.parseXYChart(code, language: fence.language) {
                    blocks.append(.xyChart(chart))
                } else if let chart = Self.parsePieChart(code, language: fence.language) {
                    blocks.append(.pieChart(chart))
                } else if let chart = Self.parseQuadrantChart(code, language: fence.language) {
                    blocks.append(.quadrantChart(chart))
                } else if let timeline = Self.parseTimeline(code, language: fence.language) {
                    blocks.append(.timeline(timeline))
                } else {
                    blocks.append(.codeBlock(language: fence.language.isEmpty ? nil : fence.language, code: code))
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
                    Self.parseFenceStart(next) != nil ||
                    next.hasPrefix("|") ||
                    Self.isUnorderedListItem(next) ||
                    Self.orderedListText(next) != nil ||
                    Self.parseFootnoteDefinitionStart(next) != nil ||
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

        if !footnotes.isEmpty {
            blocks.append(.footnotes(footnotes))
        }

        return blocks
    }
}

private extension LineMarkdownParser {
    static func frontMatterEndIndex(in lines: [String]) -> Int? {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var sawMetadataLine = false
        for index in lines.indices.dropFirst() {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." {
                return sawMetadataLine ? index : nil
            }
            if !trimmed.isEmpty,
               (trimmed.contains(":") || trimmed.hasPrefix("- ")) {
                sawMetadataLine = true
            }
        }
        return nil
    }

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
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
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
        guard let marker = line.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }
        let number = line[..<marker]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let textStart = line.index(after: marker)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return String(line[line.index(after: textStart)...])
    }

    static func parseFootnoteDefinitionStart(_ line: String) -> (label: String, text: String)? {
        guard line.hasPrefix("[^"),
              let closeLabel = line.firstIndex(of: "]") else {
            return nil
        }
        let colon = line.index(after: closeLabel)
        guard colon < line.endIndex, line[colon] == ":" else { return nil }

        let labelStart = line.index(line.startIndex, offsetBy: 2)
        let label = String(line[labelStart..<closeLabel]).trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return nil }

        let textStart = line.index(after: colon)
        let text = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
        return (label, text)
    }

    static func isFootnoteContinuation(_ line: String) -> Bool {
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    static func parseFenceStart(_ line: String) -> (marker: Character, count: Int, language: String)? {
        guard let marker = line.first, marker == "`" || marker == "~" else { return nil }
        let count = line.prefix(while: { $0 == marker }).count
        guard count >= 3 else { return nil }
        let language = String(line.dropFirst(count)).trimmingCharacters(in: .whitespaces)
        return (marker, count, language)
    }

    static func isFenceEnd(_ line: String, fence: (marker: Character, count: Int, language: String)) -> Bool {
        let markerCount = line.prefix(while: { $0 == fence.marker }).count
        guard markerCount >= fence.count else { return false }
        return line.dropFirst(markerCount).allSatisfy(\.isWhitespace)
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
        guard isMermaidLanguage(language) else { return nil }
        let lines = normalizedMermaidLines(code)

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

    static func parsePieChart(_ code: String, language: String) -> MarkdownPieChart? {
        guard isMermaidLanguage(language) else { return nil }
        let lines = normalizedMermaidLines(code)
        guard let firstLine = lines.first,
              firstLine == "pie" || firstLine.hasPrefix("pie ") else {
            return nil
        }

        var title = ""
        var slices: [MarkdownPieChart.Slice] = []

        for line in lines.dropFirst() {
            if line.hasPrefix("title ") {
                title = quotedString(after: "title", in: line) ?? String(line.dropFirst("title".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let item = parseLabelValueLine(line) else { continue }
            slices.append(.init(label: item.label, value: item.value))
        }

        guard !slices.isEmpty else { return nil }
        return MarkdownPieChart(
            title: title,
            showData: firstLine.contains("showData"),
            slices: slices
        )
    }

    static func parseQuadrantChart(_ code: String, language: String) -> MarkdownQuadrantChart? {
        guard isMermaidLanguage(language) else { return nil }
        let lines = normalizedMermaidLines(code)
        guard lines.first == "quadrantChart" else { return nil }

        var title = ""
        var xAxis = ("", "")
        var yAxis = ("", "")
        var quadrants = Array(repeating: "", count: 4)
        var points: [MarkdownQuadrantChart.Point] = []

        for line in lines.dropFirst() {
            if line.hasPrefix("title ") {
                title = quotedString(after: "title", in: line) ?? String(line.dropFirst("title".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if line.hasPrefix("x-axis ") {
                xAxis = parseDirectionalAxis(line, marker: "x-axis")
                continue
            }

            if line.hasPrefix("y-axis ") {
                yAxis = parseDirectionalAxis(line, marker: "y-axis")
                continue
            }

            if line.hasPrefix("quadrant-") {
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2,
                      let numberText = parts[0].split(separator: "-").last,
                      let number = Int(numberText),
                      (1...4).contains(number) else {
                    continue
                }
                quadrants[number - 1] = String(parts[1]).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let point = parseQuadrantPoint(line) else { continue }
            points.append(point)
        }

        guard !points.isEmpty else { return nil }
        return MarkdownQuadrantChart(
            title: title,
            xAxisStart: xAxis.0,
            xAxisEnd: xAxis.1,
            yAxisStart: yAxis.0,
            yAxisEnd: yAxis.1,
            quadrants: quadrants,
            points: points
        )
    }

    static func parseTimeline(_ code: String, language: String) -> MarkdownTimeline? {
        guard isMermaidLanguage(language) else { return nil }
        let lines = normalizedMermaidLines(code)
        guard lines.first == "timeline" else { return nil }

        var title = ""
        var periods: [MarkdownTimeline.Period] = []
        var currentLabel = ""
        var currentEvents: [String] = []

        func flushCurrentPeriod() {
            guard !currentLabel.isEmpty, !currentEvents.isEmpty else { return }
            periods.append(.init(label: currentLabel, events: currentEvents))
            currentLabel = ""
            currentEvents = []
        }

        for line in lines.dropFirst() {
            if line.hasPrefix("title ") {
                title = quotedString(after: "title", in: line) ?? String(line.dropFirst("title".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let colon = line.firstIndex(of: ":") else { continue }
            let label = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let event = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !event.isEmpty else { continue }

            if label.isEmpty {
                if !currentLabel.isEmpty {
                    currentEvents.append(event)
                }
            } else {
                flushCurrentPeriod()
                currentLabel = label
                currentEvents = [event]
            }
        }
        flushCurrentPeriod()

        guard !periods.isEmpty else { return nil }
        return MarkdownTimeline(title: title, periods: periods)
    }

    static func isMermaidLanguage(_ language: String) -> Bool {
        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedLanguage.isEmpty || normalizedLanguage == "mermaid"
    }

    static func normalizedMermaidLines(_ code: String) -> [String] {
        code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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

    static func parseLabelValueLine(_ line: String) -> (label: String, value: Double)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let label = unquoted(String(line[..<colon]).trimmingCharacters(in: .whitespaces))
        let valueText = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, let value = Double(valueText) else { return nil }
        return (label, value)
    }

    static func parseDirectionalAxis(_ line: String, marker: String) -> (String, String) {
        let text = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        let parts = text.components(separatedBy: "-->")
        guard parts.count == 2 else { return ("", "") }
        return (
            parts[0].trimmingCharacters(in: .whitespaces),
            parts[1].trimmingCharacters(in: .whitespaces)
        )
    }

    static func parseQuadrantPoint(_ line: String) -> MarkdownQuadrantChart.Point? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let label = unquoted(String(line[..<colon]).trimmingCharacters(in: .whitespaces))
        let values = numberArray(in: line)
        guard values.count == 2 else { return nil }
        return .init(
            label: label,
            x: min(max(values[0], 0), 1),
            y: min(max(values[1], 0), 1)
        )
    }

    static func unquoted(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
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
