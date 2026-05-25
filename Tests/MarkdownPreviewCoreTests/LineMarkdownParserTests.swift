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

        XCTAssertEqual(blocks.count, 8)
        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(blocks[1], .paragraph("Intro paragraph."))
        XCTAssertEqual(blocks[2], .blockquote("Quote here"))
        XCTAssertEqual(blocks[3], .unorderedList(["One", "Two"]))
        XCTAssertEqual(blocks[4], .orderedList(["First", "Second"]))
        XCTAssertEqual(blocks[5], .image(alt: "Diagram", path: "images/diagram.png"))
        XCTAssertEqual(blocks[6], .codeBlock(language: "swift", code: "    let value = 42"))
        XCTAssertEqual(blocks[7], .table(MarkdownTable(
            headers: ["A", "B"],
            alignments: [.left, .left],
            rows: [["1", "2"]]
        )))
    }

    func testParsesPipeTablesWithAlignmentRows() {
        let markdown = """
        | 产品 | 通用问答 | 企业治理 |
        |---|---:|:---:|
        | ChatGPT | 5 | 4 |
        | Claude | 4 | 5 |
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .table(MarkdownTable(
                headers: ["产品", "通用问答", "企业治理"],
                alignments: [.left, .right, .center],
                rows: [
                    ["ChatGPT", "5", "4"],
                    ["Claude", "4", "5"]
                ]
            ))
        ])
    }
}
