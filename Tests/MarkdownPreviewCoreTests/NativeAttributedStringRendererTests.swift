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
            .table(["| A | B |", "| 1 | 2 |"])
        ])

        XCTAssertTrue(output.string.contains("Title"))
        XCTAssertTrue(output.string.contains("- One"))
        XCTAssertTrue(output.string.contains("Remote image not loaded: https://example.com/a.png"))
        XCTAssertTrue(output.string.contains("let value = 42"))
        XCTAssertTrue(output.string.contains("| A | B |"))
    }

    func testUsesMonospacedFontForCodeBlocks() throws {
        let renderer = NativeAttributedStringRenderer()

        let output = renderer.render([
            .codeBlock(language: "swift", code: "let value = 42")
        ])

        let font = try XCTUnwrap(output.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }
}
