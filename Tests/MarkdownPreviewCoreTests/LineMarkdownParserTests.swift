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

    func testParsesThematicBreaksBeforeUnorderedLists() {
        let markdown = """
        Intro

        * * *

        - Real list item
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .paragraph("Intro"),
            .thematicBreak,
            .unorderedList(["Real list item"])
        ])
    }

    func testParsesSetextHeadingsWithoutExposingUnderlineMarkers() {
        let markdown = """
        Main title
        ==========

        Section title
        -------------
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .heading(level: 1, text: "Main title"),
            .heading(level: 2, text: "Section title")
        ])
    }

    func testParsesMermaidXYChartBlocks() {
        let markdown = """
        ```mermaid
        xychart-beta
            title "常规DRAM季度合同价变动中枢"
            x-axis ["1Q24","2Q24","3Q24","4Q24"]
            y-axis "QoQ %" -20 --> 100
            bar [15.5, 5.5, 10.5, 2.5]
        ```
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .xyChart(MarkdownXYChart(
                title: "常规DRAM季度合同价变动中枢",
                xAxisLabels: ["1Q24", "2Q24", "3Q24", "4Q24"],
                yAxisLabel: "QoQ %",
                yAxisRange: -20...100,
                series: [
                    MarkdownXYChart.Series(kind: .bar, values: [15.5, 5.5, 10.5, 2.5])
                ]
            ))
        ])
    }
}
