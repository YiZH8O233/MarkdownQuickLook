import AppKit

public struct NativeAttributedStringRenderer {
    public init() {}

    public func render(_ blocks: [MarkdownBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for block in blocks {
            switch block {
            case let .heading(level, text):
                result.append(line(
                    text,
                    font: .systemFont(ofSize: headingSize(level), weight: .semibold),
                    spacing: 10
                ))
            case let .paragraph(text):
                result.append(line(text, font: .systemFont(ofSize: 14), spacing: 8))
            case let .blockquote(text):
                result.append(line(
                    "> \(text)",
                    font: .systemFont(ofSize: 14),
                    color: .secondaryLabelColor,
                    spacing: 8
                ))
            case let .unorderedList(items):
                for item in items {
                    result.append(line("- \(item)", font: .systemFont(ofSize: 14), spacing: 4))
                }
                result.append(NSAttributedString(string: "\n"))
            case let .orderedList(items):
                for (offset, item) in items.enumerated() {
                    result.append(line("\(offset + 1). \(item)", font: .systemFont(ofSize: 14), spacing: 4))
                }
                result.append(NSAttributedString(string: "\n"))
            case let .image(alt, path):
                let label = path.lowercased().hasPrefix("http")
                    ? "Remote image not loaded: \(path)"
                    : "Image: \(alt.isEmpty ? path : alt)"
                result.append(line(
                    label,
                    font: .systemFont(ofSize: 13),
                    color: .secondaryLabelColor,
                    spacing: 8
                ))
            case let .codeBlock(_, code):
                result.append(line(
                    code,
                    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                    color: .labelColor,
                    spacing: 10
                ))
            case let .table(lines):
                result.append(line(
                    lines.joined(separator: "\n"),
                    font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                    spacing: 10
                ))
            }
        }

        return result
    }
}

private extension NativeAttributedStringRenderer {
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
}
