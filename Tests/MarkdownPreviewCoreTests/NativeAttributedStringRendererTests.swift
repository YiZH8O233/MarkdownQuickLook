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

    func testTableTabStopsExpandForLongColumns() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["已验证打法 / 案例", "可复用工具", "青岛站创新转译"],
                rows: [[
                    "苏州首届夏日农友会",
                    "地标点亮、NFC 打卡、交通痛车、文旅消费",
                    "从城市打卡升级为四条英雄领路的登陆路线"
                ]]
            ))
        ])

        let paragraph = try XCTUnwrap(output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let firstTab = try XCTUnwrap(paragraph.tabStops.first)
        XCTAssertGreaterThan(firstTab.location, 170)
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
