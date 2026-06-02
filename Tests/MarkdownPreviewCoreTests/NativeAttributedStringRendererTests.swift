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

    func testAppliesAcademicInkBlueThemeToHeadingsAndBoldText() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .heading(level: 1, text: "Title"),
            .heading(level: 2, text: "Section"),
            .paragraph("Normal **Important** text")
        ])

        let h1Color = try XCTUnwrap(output.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        let h2Range = (output.string as NSString).range(of: "Section")
        let h2Color = try XCTUnwrap(output.attribute(.foregroundColor, at: h2Range.location, effectiveRange: nil) as? NSColor)
        let boldRange = (output.string as NSString).range(of: "Important")
        let boldColor = try XCTUnwrap(output.attribute(.foregroundColor, at: boldRange.location, effectiveRange: nil) as? NSColor)

        XCTAssertEqual(h1Color.hexRGBString, "#0C447C")
        XCTAssertEqual(h2Color.hexRGBString, "#185FA5")
        XCTAssertEqual(boldColor.hexRGBString, "#185FA5")
    }

    func testRendersEscapedInlineBoldWithoutMarkdownMarkers() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("\\*\\*我眼里的影石\\*\\*是一家科技品牌")
        ])

        XCTAssertEqual(output.string, "我眼里的影石是一家科技品牌\n")
        XCTAssertFalse(output.string.contains("\\*\\*"))
        XCTAssertFalse(output.string.contains("**"))

        let boldRange = (output.string as NSString).range(of: "我眼里的影石")
        let font = try XCTUnwrap(output.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testRendersCommonInlineMarkdownStylesWithoutMarkers() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("*斜体* _强调_ **加粗** __强烈__ ***重点*** `code` [官网](https://example.com) <https://example.com/a> https://example.com/b ~~删除~~")
        ])

        XCTAssertEqual(output.string, "斜体 强调 加粗 强烈 重点 code 官网 https://example.com/a https://example.com/b 删除\n")
        XCTAssertFalse(output.string.contains("*"))
        XCTAssertFalse(output.string.contains("_"))
        XCTAssertFalse(output.string.contains("`"))
        XCTAssertFalse(output.string.contains("["))
        XCTAssertFalse(output.string.contains("]("))
        XCTAssertFalse(output.string.contains("~~"))

        let italicRange = (output.string as NSString).range(of: "斜体")
        let italicFont = try XCTUnwrap(output.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.italic))

        let boldRange = (output.string as NSString).range(of: "加粗")
        let boldFont = try XCTUnwrap(output.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.bold))

        let strongItalicRange = (output.string as NSString).range(of: "重点")
        let strongItalicFont = try XCTUnwrap(output.attribute(.font, at: strongItalicRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(strongItalicFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(strongItalicFont.fontDescriptor.symbolicTraits.contains(.italic))

        let codeRange = (output.string as NSString).range(of: "code")
        let codeFont = try XCTUnwrap(output.attribute(.font, at: codeRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))

        let linkRange = (output.string as NSString).range(of: "官网")
        XCTAssertNotNil(output.attribute(.link, at: linkRange.location, effectiveRange: nil))

        let strikethroughRange = (output.string as NSString).range(of: "删除")
        XCTAssertNotNil(output.attribute(.strikethroughStyle, at: strikethroughRange.location, effectiveRange: nil))
    }

    func testRendersTaskListMarkersAsNativeCheckboxGlyphs() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .unorderedList(["[x] 已完成", "[ ] 未完成"])
        ])

        XCTAssertTrue(output.string.contains("☑ 已完成"))
        XCTAssertTrue(output.string.contains("☐ 未完成"))
        XCTAssertFalse(output.string.contains("[x]"))
        XCTAssertFalse(output.string.contains("[ ]"))
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

    func testTablesUseContentAwareColumnsWithStablePadding() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["IP 层级", "含义", "用户感受", "营销价值"],
                rows: [[
                    "玩家自嘲梗",
                    "打农药的民间称呼被官方转译",
                    "亲切、懂梗、不端着",
                    "拉近官方与玩家距离"
                ]]
            ))
        ])

        let blocks = tableBlocks(in: output)
        let firstColumn = try XCTUnwrap(blocks[safe: 0])
        let secondColumn = try XCTUnwrap(blocks[safe: 1])
        let fourthColumn = try XCTUnwrap(blocks[safe: 3])

        XCTAssertEqual(firstColumn.table.layoutAlgorithm, .fixedLayoutAlgorithm)
        XCTAssertEqual(firstColumn.contentWidthValueType, .percentageValueType)
        XCTAssertLessThan(firstColumn.contentWidth, secondColumn.contentWidth)
        XCTAssertLessThan(firstColumn.contentWidth, fourthColumn.contentWidth)
        XCTAssertEqual(firstColumn.width(for: .padding, edge: .minX), 7)
        XCTAssertEqual(secondColumn.width(for: .padding, edge: .minX), 7)
    }

    func testWideTablesKeepShortIdentifierColumnsReadable() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .table(MarkdownTable(
                headers: ["产品", "公司", "首次公开/重要上线", "定位", "模型类型", "目标用户与主要场景", "获取方式与定价逻辑", "备注"],
                rows: [
                    [
                        "ChatGPT",
                        "OpenAI",
                        "2022-11；2024-2026持续扩展",
                        "通用AI助手/工作台",
                        "闭源多模态 + 推理模型路由",
                        "大众用户、知识工作者；搜索、写作、代码、语音、深度研究",
                        "Web/App/桌面；Free、Go、Plus、Pro、Business、Enterprise；API另计",
                        ""
                    ],
                    [
                        "Claude Code",
                        "Anthropic",
                        "2025起产品化",
                        "终端/IDE代码代理",
                        "闭源Agentic Coding模型",
                        "开发者团队；读库、改文件、跑命令、PR审查",
                        "Pro/Max/Team/Enterprise登录；或Console按token计费",
                        ""
                    ]
                ]
            ))
        ])

        let blocks = tableBlocks(in: output)
        let firstColumn = try XCTUnwrap(blocks[safe: 0])
        let secondColumn = try XCTUnwrap(blocks[safe: 1])

        XCTAssertGreaterThanOrEqual(firstColumn.contentWidth, 8)
        XCTAssertGreaterThanOrEqual(secondColumn.contentWidth, 8)
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

    func testRendersResolvedLocalImagesAsNativeAttachments() throws {
        let directory = try makeTemporaryDirectory()
        let imageURL = directory.appendingPathComponent("chart.png")
        try writePNG(to: imageURL, size: NSSize(width: 120, height: 60))

        let renderer = NativeAttributedStringRenderer(
            imageResolver: LocalImageResolver(markdownFileURL: directory.appendingPathComponent("report.md"))
        )

        let output = renderer.render([
            .image(alt: "Chart", path: "chart.png")
        ])

        XCTAssertFalse(output.string.contains("Image: Chart"))
        XCTAssertNil(output.string.range(of: "chart.png"))
        let attachment = try XCTUnwrap(firstAttachment(in: output))
        XCTAssertEqual(attachment.bounds.width, 120)
        XCTAssertEqual(attachment.bounds.height, 60)
    }

    func testKeepsTextFallbackForOversizedLocalImages() throws {
        let directory = try makeTemporaryDirectory()
        let imageURL = directory.appendingPathComponent("large.png")
        try Data(repeating: 0, count: 32).write(to: imageURL)

        let renderer = NativeAttributedStringRenderer(
            imageResolver: LocalImageResolver(markdownFileURL: directory.appendingPathComponent("report.md")),
            imageOptions: ImageRenderOptions(maxFileSizeBytes: 8)
        )

        let output = renderer.render([
            .image(alt: "Large chart", path: "large.png")
        ])

        XCTAssertTrue(output.string.contains("Image too large: large.png"))
        XCTAssertNil(firstAttachment(in: output))
    }

    func testRendersThematicBreakWithoutMarkdownMarkers() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("Before"),
            .thematicBreak,
            .paragraph("After")
        ])

        XCTAssertTrue(output.string.contains("Before"))
        XCTAssertTrue(output.string.contains("After"))
        XCTAssertFalse(output.string.contains("* * *"))
        XCTAssertFalse(output.string.contains("- * *"))
    }

    func testHidesEmptyReferenceParentheses() {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .paragraph("公开报道显示，消息已经披露。 ()")
        ])

        XCTAssertEqual(output.string, "公开报道显示，消息已经披露。\n")
    }

    func testPlainTextPreviewKeepsFullMarkdownWithoutNativeTableLayout() throws {
        let renderer = NativeAttributedStringRenderer()
        let markdown = """
        # Title

        | 产品 | 公司 |
        | --- | --- |
        | ChatGPT | OpenAI |

        Final line
        """

        let output = renderer.renderPlainText(markdown)

        XCTAssertTrue(output.string.contains("# Title"))
        XCTAssertTrue(output.string.contains("| 产品 | 公司 |"))
        XCTAssertTrue(output.string.contains("Final line"))
        XCTAssertTrue(tableBlocks(in: output).isEmpty)

        let font = try XCTUnwrap(output.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    func testRendersXYChartsAsNativeAttachments() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
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

        XCTAssertTrue(output.string.contains("常规DRAM季度合同价变动中枢"))
        XCTAssertFalse(output.string.contains("xychart-beta"))
        XCTAssertFalse(output.string.contains("bar ["))

        let attachment = try XCTUnwrap(firstAttachment(in: output))
        XCTAssertGreaterThan(attachment.bounds.width, 500)
        XCTAssertGreaterThan(attachment.bounds.height, 250)
    }

    private func tableBlocks(in output: NSAttributedString) -> [NSTextTableBlock] {
        var blocks: [NSTextTableBlock] = []
        output.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: output.length)
        ) { value, _, _ in
            guard let paragraph = value as? NSParagraphStyle,
                  let block = paragraph.textBlocks.first as? NSTextTableBlock else {
                return
            }
            blocks.append(block)
        }
        return blocks
    }

    private func firstAttachment(in output: NSAttributedString) -> NSTextAttachment? {
        var attachment: NSTextAttachment?
        output.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: output.length)
        ) { value, _, stop in
            guard let value = value as? NSTextAttachment else { return }
            attachment = value
            stop.pointee = true
        }
        return attachment
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePNG(to url: URL, size: NSSize) throws {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: url)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension NSColor {
    var hexRGBString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}
