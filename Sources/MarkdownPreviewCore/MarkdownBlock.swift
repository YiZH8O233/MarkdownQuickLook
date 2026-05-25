import Foundation

public struct MarkdownTable: Equatable {
    public enum Alignment: Equatable {
        case left
        case center
        case right
    }

    public let headers: [String]
    public let alignments: [Alignment]
    public let rows: [[String]]

    public init(
        headers: [String],
        alignments: [Alignment]? = nil,
        rows: [[String]]
    ) {
        self.headers = headers
        self.alignments = alignments ?? Array(repeating: .left, count: headers.count)
        self.rows = rows
    }
}

public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case blockquote(String)
    case unorderedList([String])
    case orderedList([String])
    case image(alt: String, path: String)
    case codeBlock(language: String?, code: String)
    case table(MarkdownTable)
}
