import AppKit
import XCTest
@testable import MarkdownPreviewCore

final class NativeAttributedStringRendererTests: XCTestCase {
    func testRendersFirstVersionBlocksAsReadableAttributedString() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .heading(level: 1, text: "Title"),
            .unorderedList(["One"]),
            .image(alt: "Remote", path: "https://example.com/a.png"),
            .codeBlock(language: "swift", code: "let value = 42"),
            .table(MarkdownTable(headers: ["A", "B"], rows: [["1", "2"]]))
        ])

        XCTAssertTrue(output.string.contains("Title"))
        XCTAssertTrue(output.string.contains("- One"))
        XCTAssertTrue(output.string.contains("Remote image not loaded: https://example.com/a.png"))
        XCTAssertTrue(output.string.contains("let value = 42"))
        XCTAssertTrue(output.string.contains("A"))
        XCTAssertTrue(output.string.contains("B"))
        XCTAssertFalse(output.string.contains("| A | B |"))
    }

    func testUsesMonospacedFontForCodeBlocks() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .codeBlock(language: "swift", code: "let value = 42")
        ])

        let font = try XCTUnwrap(output.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    func testRendersTablesWithoutMarkdownPipeSyntax() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["产品", "通用问答", "企业治理"],
                alignments: [.left, .right, .center],
                rows: [["ChatGPT", "5", "4"]]
            ))
        ])

        XCTAssertTrue(output.string.contains("产品"))
        XCTAssertTrue(output.string.contains("ChatGPT"))
        XCTAssertFalse(output.string.contains("|"))
        XCTAssertFalse(output.string.contains("---"))
    }

    func testRendersInlineBoldWithoutMarkdownMarkers() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("**页面结论** 青岛")
        ])

        XCTAssertEqual(output.string, "页面结论 青岛\n")
        let boldRange = NSRange(location: 0, length: 4)
        var effectiveRange = NSRange(location: 0, length: 0)
        let font = try XCTUnwrap(output.attribute(.font, at: 0, effectiveRange: &effectiveRange) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertEqual(effectiveRange.location, boldRange.location)
        XCTAssertEqual(effectiveRange.length, boldRange.length)
    }

    func testTablesUseNativeTextTableBlocks() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["产品", "公司", "首次公开/重要上线", "定位", "模型类型"],
                rows: [[
                    "ChatGPT",
                    "OpenAI",
                    "2022-11；2024-2026持续扩展",
                    "通用AI助手/工作台",
                    "闭源多模态 + 推理模型路由"
                ]]
            ))
        ])

        let paragraph = try XCTUnwrap(output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertTrue(paragraph.textBlocks.first is NSTextTableBlock)
        XCTAssertFalse(output.string.contains("\t"))
    }

    func testTablesCollapseBordersForConsistentGridLines() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["产品", "公司"],
                rows: [["ChatGPT", "OpenAI"]]
            ))
        ])

        let paragraph = try XCTUnwrap(output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let tableBlock = try XCTUnwrap(paragraph.textBlocks.first as? NSTextTableBlock)
        XCTAssertTrue(tableBlock.table.collapsesBorders)
    }

    func testRendersInlineBoldInsideTableCellsWithoutMarkdownMarkers() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["打法", "说明"],
                rows: [["**登陆青岛**", "抵达海滨暑期城市"]]
            ))
        ])

        XCTAssertFalse(output.string.contains("**"))
        let boldRange = (output.string as NSString).range(of: "登陆青岛")
        XCTAssertNotEqual(boldRange.location, NSNotFound)

        let font = try XCTUnwrap(output.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testTableCellsDoNotDrawBorders() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["产品", "公司"],
                rows: [["ChatGPT", "OpenAI"]]
            ))
        ])

        let paragraph = try XCTUnwrap(output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let tableBlock = try XCTUnwrap(paragraph.textBlocks.first as? NSTextTableBlock)
        XCTAssertEqual(tableBlock.width(for: .border, edge: .minX), 0)
        XCTAssertEqual(tableBlock.width(for: .border, edge: .maxX), 0)
        XCTAssertEqual(tableBlock.width(for: .border, edge: .minY), 0)
        XCTAssertEqual(tableBlock.width(for: .border, edge: .maxY), 0)
    }

    func testHidesResearchCitationMarkersAndKeepsEntityNames() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("ChatGPT增长很快。citeturn36view0turn21search1"),
            .paragraph("来自 entity[\"company\",\"OpenAI\",\"ai company\"] 的产品。")
        ])

        XCTAssertTrue(output.string.contains("ChatGPT增长很快。"))
        XCTAssertTrue(output.string.contains("来自 OpenAI 的产品。"))
        XCTAssertFalse(output.string.contains(""))
        XCTAssertFalse(output.string.contains("turn36view0"))
    }

    func testDoesNotTreatLocalPathStartingWithHTTPAsRemote() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .image(alt: "Local", path: "http-image.png")
        ])

        XCTAssertTrue(output.string.contains("Image: Local"))
        XCTAssertFalse(output.string.contains("Remote image not loaded"))
    }
}
