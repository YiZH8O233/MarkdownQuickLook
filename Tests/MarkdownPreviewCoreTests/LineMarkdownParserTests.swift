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

    func testParsesCommonListAndFenceVariants() {
        let markdown = """
        + Plus list item

        1) Parenthesized ordered item

        ~~~swift
        let value = 42
        ~~~
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .unorderedList(["Plus list item"]),
            .orderedList(["Parenthesized ordered item"]),
            .codeBlock(language: "swift", code: "let value = 42")
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

    func testParsesMermaidPieChartBlocks() {
        let markdown = """
        ```mermaid
        pie showData
            title "2025年下半年新增AI应用触达形态占比"
            "插件 / In-App AI" : 81.5
            "PC网页应用" : 10.7
            "原生App" : 7.8
        ```
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .pieChart(MarkdownPieChart(
                title: "2025年下半年新增AI应用触达形态占比",
                showData: true,
                slices: [
                    .init(label: "插件 / In-App AI", value: 81.5),
                    .init(label: "PC网页应用", value: 10.7),
                    .init(label: "原生App", value: 7.8)
                ]
            ))
        ])
    }

    func testParsesMermaidQuadrantChartBlocks() {
        let markdown = """
        ```mermaid
        quadrantChart
            title 重点产品竞争二维矩阵
            x-axis C端分发能力弱 --> C端分发能力强
            y-axis 企业落地深度弱 --> 企业落地深度强
            quadrant-1 平台双强
            quadrant-2 企业优先
            quadrant-3 垂直/单点
            quadrant-4 流量优先
            ChatGPT: [0.92, 0.80]
            Gemini: [0.88, 0.86]
        ```
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .quadrantChart(MarkdownQuadrantChart(
                title: "重点产品竞争二维矩阵",
                xAxisStart: "C端分发能力弱",
                xAxisEnd: "C端分发能力强",
                yAxisStart: "企业落地深度弱",
                yAxisEnd: "企业落地深度强",
                quadrants: ["平台双强", "企业优先", "垂直/单点", "流量优先"],
                points: [
                    .init(label: "ChatGPT", x: 0.92, y: 0.80),
                    .init(label: "Gemini", x: 0.88, y: 0.86)
                ]
            ))
        ])
    }

    func testParsesMermaidTimelineBlocks() {
        let markdown = """
        ```mermaid
        timeline
            title 重点产品技术路线与发布节点
            2024-Q1 : Gemini 1.5公开MoE与长上下文
                    : Claude 3家族发布
            2024-Q2 : 元宝App上线
        ```
        """

        let blocks = LineMarkdownParser().parse(markdown)

        XCTAssertEqual(blocks, [
            .timeline(MarkdownTimeline(
                title: "重点产品技术路线与发布节点",
                periods: [
                    .init(label: "2024-Q1", events: ["Gemini 1.5公开MoE与长上下文", "Claude 3家族发布"]),
                    .init(label: "2024-Q2", events: ["元宝App上线"])
                ]
            ))
        ])
    }
}
