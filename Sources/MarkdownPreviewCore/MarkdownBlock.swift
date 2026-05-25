import Foundation

public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case blockquote(String)
    case unorderedList([String])
    case orderedList([String])
    case image(alt: String, path: String)
    case codeBlock(language: String?, code: String)
    case table([String])
}
