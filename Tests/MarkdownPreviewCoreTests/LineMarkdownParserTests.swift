import XCTest
@testable import MarkdownPreviewCore

final class LineMarkdownParserTests: XCTestCase {
    func testParsesFirstVersionBlocks() {
        let markdown = """
        # Title

        Intro paragraph.

        > Quote here

        - One
        - Two

        1. First
        2. Second

        ![Diagram](images/diagram.png)

        ```swift
        let value = 42
        ```

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(blocks[1], .paragraph("Intro paragraph."))
        XCTAssertEqual(blocks[2], .blockquote("Quote here"))
        XCTAssertEqual(blocks[3], .unorderedList(["One", "Two"]))
        XCTAssertEqual(blocks[4], .orderedList(["First", "Second"]))
        XCTAssertEqual(blocks[5], .image(alt: "Diagram", path: "images/diagram.png"))
        XCTAssertEqual(blocks[6], .codeBlock(language: "swift", code: "let value = 42"))
        XCTAssertEqual(blocks[7], .table(["| A | B |", "| - | - |", "| 1 | 2 |"]))
    }
}
