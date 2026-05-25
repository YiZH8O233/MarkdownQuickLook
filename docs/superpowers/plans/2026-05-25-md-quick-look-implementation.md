# Markdown Quick Look Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS Quick Look extension that previews `.md` and `.markdown` files with basic Markdown styling and no remote content loading.

**Architecture:** Put all parse, file, image-policy, and text-rendering decisions in a Swift Package so they can be tested with `swift test` before the full Xcode app exists. The macOS container app stays minimal, and the Quick Look Preview Extension adapts Quick Look file requests into the shared core renderer.

**Tech Stack:** Swift 6, macOS 13+, Swift Package Manager for core tests, AppKit for native preview UI, QuickLookUI for the preview extension, XCTest for behavior tests.

---

## File Structure

Create these files and keep responsibilities narrow:

- `Package.swift` defines the testable Swift package.
- `Sources/MarkdownPreviewCore/MarkdownBlock.swift` defines parsed Markdown block types.
- `Sources/MarkdownPreviewCore/LineMarkdownParser.swift` parses first-version Markdown into blocks.
- `Sources/MarkdownPreviewCore/MarkdownFileReader.swift` reads text with UTF-8 first and system fallback second.
- `Sources/MarkdownPreviewCore/LocalImageResolver.swift` enforces local-relative-image-only policy.
- `Sources/MarkdownPreviewCore/PreviewLimits.swift` decides when to use simplified rendering for large files.
- `Sources/MarkdownPreviewCore/NativeAttributedStringRenderer.swift` converts blocks to `NSAttributedString` with AppKit fonts/colors.
- `Tests/MarkdownPreviewCoreTests/*.swift` cover parser, reader, image policy, limits, and renderer behavior.
- `MarkdownQuickLook/MarkdownQuickLookApp.swift` defines the tiny container app entry point.
- `MarkdownQuickLook/ContentView.swift` shows installation/use instructions in native SwiftUI.
- `MarkdownQuickLookPreview/PreviewViewController.swift` implements the Quick Look preview controller.
- `MarkdownQuickLookPreview/Info.plist` registers `.md` and `.markdown` content support.
- `Samples/*.md` provides manual validation files.
- `README.md` explains build, install, Finder preview test, and Quick Look cache refresh.
- `MarkdownQuickLook.xcodeproj/project.pbxproj` defines the app and extension targets once the source layout is stable.

## Task 1: Core Package and Markdown Block Parser

**Files:**
- Create: `Package.swift`
- Create: `Sources/MarkdownPreviewCore/MarkdownBlock.swift`
- Create: `Sources/MarkdownPreviewCore/LineMarkdownParser.swift`
- Create: `Tests/MarkdownPreviewCoreTests/LineMarkdownParserTests.swift`

- [ ] **Step 1: Write the failing parser tests**

```swift
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
```

- [ ] **Step 2: Run the parser test and verify it fails**

Run: `swift test --filter LineMarkdownParserTests`

Expected: the command fails because `MarkdownPreviewCore` or `LineMarkdownParser` does not exist yet.

- [ ] **Step 3: Add the package and parser implementation**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownPreviewCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkdownPreviewCore", targets: ["MarkdownPreviewCore"])
    ],
    targets: [
        .target(name: "MarkdownPreviewCore"),
        .testTarget(name: "MarkdownPreviewCoreTests", dependencies: ["MarkdownPreviewCore"])
    ]
)
```

`MarkdownBlock.swift`:

```swift
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
```

`LineMarkdownParser.swift` must implement a small line parser with these rules:

```swift
public struct LineMarkdownParser {
    public init() {}

    public func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.table(tableLines))
                continue
            }

            if let image = Self.parseImage(trimmed) {
                blocks.append(image)
                index += 1
                continue
            }

            if let heading = Self.parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                blocks.append(.blockquote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
                index += 1
                continue
            }

            if Self.isUnorderedListItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard Self.isUnorderedListItem(candidate) else { break }
                    items.append(String(candidate.dropFirst(2)))
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if let ordered = Self.orderedListText(trimmed) {
                var items = [ordered]
                index += 1
                while index < lines.count, let item = Self.orderedListText(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix(">") || next.hasPrefix("```") || next.hasPrefix("|") || Self.isUnorderedListItem(next) || Self.orderedListText(next) != nil || Self.parseImage(next) != nil {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }
}
```

Add these private helpers in the same file:

```swift
private extension LineMarkdownParser {
    static func parseHeading(_ line: String) -> MarkdownBlock? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }
        let text = line.dropFirst(markerCount).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: markerCount, text: text)
    }

    static func parseImage(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("!["),
              let closeAlt = line.firstIndex(of: "]"),
              line[line.index(after: closeAlt)...].hasPrefix("("),
              line.hasSuffix(")") else {
            return nil
        }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeAlt])
        let pathStart = line.index(closeAlt, offsetBy: 2)
        let pathEnd = line.index(before: line.endIndex)
        return .image(alt: alt, path: String(line[pathStart..<pathEnd]))
    }

    static func isUnorderedListItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ")
    }

    static func orderedListText(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let number = line[..<dot]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let textStart = line.index(after: dot)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return String(line[line.index(after: textStart)...])
    }
}
```

- [ ] **Step 4: Run the parser tests**

Run: `swift test --filter LineMarkdownParserTests`

Expected: `Test Suite 'LineMarkdownParserTests' passed`.

- [ ] **Step 5: Commit parser foundation**

```bash
git add Package.swift Sources/MarkdownPreviewCore Tests/MarkdownPreviewCoreTests
git commit -m "Add Markdown parser core"
```

## Task 2: File Reading, Image Policy, and Large File Limits

**Files:**
- Create: `Sources/MarkdownPreviewCore/MarkdownFileReader.swift`
- Create: `Sources/MarkdownPreviewCore/LocalImageResolver.swift`
- Create: `Sources/MarkdownPreviewCore/PreviewLimits.swift`
- Create: `Tests/MarkdownPreviewCoreTests/MarkdownFileReaderTests.swift`
- Create: `Tests/MarkdownPreviewCoreTests/LocalImageResolverTests.swift`
- Create: `Tests/MarkdownPreviewCoreTests/PreviewLimitsTests.swift`

- [ ] **Step 1: Write failing tests for file and policy behavior**

Add tests that create temporary files with `FileManager.default.temporaryDirectory`, then assert:

```swift
XCTAssertEqual(try MarkdownFileReader().readText(from: utf8URL), "# Hello")
XCTAssertEqual(LocalImageResolver(markdownFileURL: mdURL).resolve("images/a.png"), .local(existingImageURL))
XCTAssertEqual(LocalImageResolver(markdownFileURL: mdURL).resolve("https://example.com/a.png"), .remoteRejected("https://example.com/a.png"))
XCTAssertEqual(LocalImageResolver(markdownFileURL: mdURL).resolve("missing.png"), .missing("missing.png"))
XCTAssertFalse(PreviewLimits(maxStyledBytes: 1024).shouldUseSimplifiedPreview(fileSize: 512))
XCTAssertTrue(PreviewLimits(maxStyledBytes: 1024).shouldUseSimplifiedPreview(fileSize: 2048))
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `swift test --filter MarkdownPreviewCoreTests`

Expected: fail with missing type errors for `MarkdownFileReader`, `LocalImageResolver`, or `PreviewLimits`.

- [ ] **Step 3: Implement the file reader**

```swift
import Foundation

public struct MarkdownFileReader {
    public enum ReadError: Error, Equatable {
        case unreadable
    }

    public init() {}

    public func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let fallback = String(data: data, encoding: .macOSRoman) {
            return fallback
        }
        throw ReadError.unreadable
    }
}
```

- [ ] **Step 4: Implement image resolution and limits**

```swift
import Foundation

public enum ImageResolution: Equatable {
    case local(URL)
    case remoteRejected(String)
    case missing(String)
}

public struct LocalImageResolver {
    private let baseDirectory: URL
    private let fileManager: FileManager

    public init(markdownFileURL: URL, fileManager: FileManager = .default) {
        self.baseDirectory = markdownFileURL.deletingLastPathComponent()
        self.fileManager = fileManager
    }

    public func resolve(_ rawPath: String) -> ImageResolution {
        if rawPath.lowercased().hasPrefix("http://") || rawPath.lowercased().hasPrefix("https://") {
            return .remoteRejected(rawPath)
        }

        let candidate = baseDirectory.appendingPathComponent(rawPath).standardizedFileURL
        guard candidate.path.hasPrefix(baseDirectory.standardizedFileURL.path) else {
            return .missing(rawPath)
        }

        return fileManager.fileExists(atPath: candidate.path) ? .local(candidate) : .missing(rawPath)
    }
}

public struct PreviewLimits {
    public let maxStyledBytes: UInt64

    public init(maxStyledBytes: UInt64 = 1_000_000) {
        self.maxStyledBytes = maxStyledBytes
    }

    public func shouldUseSimplifiedPreview(fileSize: UInt64) -> Bool {
        fileSize > maxStyledBytes
    }
}
```

- [ ] **Step 5: Run policy tests**

Run: `swift test --filter MarkdownPreviewCoreTests`

Expected: all core tests pass.

- [ ] **Step 6: Commit file and policy core**

```bash
git add Sources/MarkdownPreviewCore Tests/MarkdownPreviewCoreTests
git commit -m "Add file reading and image policies"
```

## Task 3: Native Attributed Text Renderer

**Files:**
- Create: `Sources/MarkdownPreviewCore/NativeAttributedStringRenderer.swift`
- Create: `Tests/MarkdownPreviewCoreTests/NativeAttributedStringRendererTests.swift`

- [ ] **Step 1: Write failing renderer tests**

Test that rendered output includes heading/list/code/table text, uses monospaced font for code, and converts remote images to readable text:

```swift
let renderer = NativeAttributedStringRenderer()
let output = renderer.render([
    .heading(level: 1, text: "Title"),
    .unorderedList(["One"]),
    .image(alt: "Remote", path: "https://example.com/a.png"),
    .codeBlock(language: "swift", code: "let value = 42"),
    .table(["| A | B |", "| 1 | 2 |"])
])
XCTAssertTrue(output.string.contains("Title"))
XCTAssertTrue(output.string.contains("• One"))
XCTAssertTrue(output.string.contains("Remote image not loaded: https://example.com/a.png"))
XCTAssertTrue(output.string.contains("let value = 42"))
XCTAssertTrue(output.string.contains("| A | B |"))
```

- [ ] **Step 2: Run renderer test and verify it fails**

Run: `swift test --filter NativeAttributedStringRendererTests`

Expected: fail with missing type error for `NativeAttributedStringRenderer`.

- [ ] **Step 3: Implement native renderer**

Implement:

```swift
import AppKit

public struct NativeAttributedStringRenderer {
    public init() {}

    public func render(_ blocks: [MarkdownBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in blocks {
            switch block {
            case let .heading(level, text):
                result.append(line(text, font: .systemFont(ofSize: headingSize(level), weight: .semibold), spacing: 10))
            case let .paragraph(text):
                result.append(line(text, font: .systemFont(ofSize: 14), spacing: 8))
            case let .blockquote(text):
                result.append(line("“\(text)”", font: .systemFont(ofSize: 14), color: .secondaryLabelColor, spacing: 8))
            case let .unorderedList(items):
                for item in items { result.append(line("• \(item)", font: .systemFont(ofSize: 14), spacing: 4)) }
                result.append(NSAttributedString(string: "\n"))
            case let .orderedList(items):
                for (offset, item) in items.enumerated() { result.append(line("\(offset + 1). \(item)", font: .systemFont(ofSize: 14), spacing: 4)) }
                result.append(NSAttributedString(string: "\n"))
            case let .image(alt, path):
                let label = path.lowercased().hasPrefix("http") ? "Remote image not loaded: \(path)" : "Image: \(alt.isEmpty ? path : alt)"
                result.append(line(label, font: .systemFont(ofSize: 13), color: .secondaryLabelColor, spacing: 8))
            case let .codeBlock(_, code):
                result.append(line(code, font: .monospacedSystemFont(ofSize: 13, weight: .regular), color: .labelColor, spacing: 10))
            case let .table(lines):
                result.append(line(lines.joined(separator: "\n"), font: .monospacedSystemFont(ofSize: 13, weight: .regular), spacing: 10))
            }
        }
        return result
    }
}
```

Add these private helpers in the same file:

```swift
private extension NativeAttributedStringRenderer {
    func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 26
        case 2: return 22
        case 3: return 18
        default: return 15
        }
    }

    func line(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        spacing: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacing
        paragraph.lineSpacing = 2
        return NSAttributedString(
            string: text + "\n",
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}
```

- [ ] **Step 4: Run renderer tests**

Run: `swift test --filter NativeAttributedStringRendererTests`

Expected: renderer tests pass.

- [ ] **Step 5: Run all package tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit renderer**

```bash
git add Sources/MarkdownPreviewCore/NativeAttributedStringRenderer.swift Tests/MarkdownPreviewCoreTests/NativeAttributedStringRendererTests.swift
git commit -m "Add native attributed renderer"
```

## Task 4: Minimal macOS Container App and Quick Look Extension Source

**Files:**
- Create: `MarkdownQuickLook/MarkdownQuickLookApp.swift`
- Create: `MarkdownQuickLook/ContentView.swift`
- Create: `MarkdownQuickLookPreview/PreviewViewController.swift`
- Create: `MarkdownQuickLookPreview/Info.plist`

- [ ] **Step 1: Add container app source**

`MarkdownQuickLookApp.swift`:

```swift
import SwiftUI

@main
struct MarkdownQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 460, minHeight: 280)
        }
    }
}
```

`ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Markdown Quick Look")
                .font(.title2.weight(.semibold))
            Text("The preview extension is installed with this app.")
                .foregroundStyle(.secondary)
            Text("Select a .md or .markdown file in Finder, then press Space to preview it.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
    }
}
```

- [ ] **Step 2: Add Quick Look preview controller source**

`PreviewViewController.swift`:

```swift
import AppKit
import QuickLookUI
import MarkdownPreviewCore

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()

    override func loadView() {
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        view = scrollView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                let text = try MarkdownFileReader().readText(from: url)
                let attributed: NSAttributedString

                if PreviewLimits().shouldUseSimplifiedPreview(fileSize: fileSize) {
                    attributed = NSAttributedString(string: text)
                } else {
                    let blocks = LineMarkdownParser().parse(text)
                    attributed = NativeAttributedStringRenderer().render(blocks)
                }

                DispatchQueue.main.async {
                    self.textView.textStorage?.setAttributedString(attributed)
                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.textView.string = "This Markdown file could not be previewed."
                    handler(nil)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add extension Info.plist**

`Info.plist` must include:

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.quicklook.preview</string>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).PreviewViewController</string>
  <key>QLSupportedContentTypes</key>
  <array>
    <string>net.daringfireball.markdown</string>
    <string>public.markdown</string>
    <string>public.plain-text</string>
  </array>
</dict>
```

- [ ] **Step 4: Commit app and extension source**

```bash
git add MarkdownQuickLook MarkdownQuickLookPreview
git commit -m "Add macOS app and Quick Look extension source"
```

## Task 5: Xcode Project Wiring

**Files:**
- Create: `MarkdownQuickLook.xcodeproj/project.pbxproj`
- Modify: `README.md` after the project opens/builds

- [ ] **Step 1: Create the Xcode project file**

Create a macOS app target named `MarkdownQuickLook` and a Quick Look Preview Extension target named `MarkdownQuickLookPreview`. Add the Swift package target sources from `Sources/MarkdownPreviewCore` to the extension target or link the package product if the Xcode version supports local package products cleanly.

Required build settings:

```text
MACOSX_DEPLOYMENT_TARGET = 13.0
SWIFT_VERSION = 6.0
PRODUCT_BUNDLE_IDENTIFIER = local.markdownquicklook.app
CODE_SIGN_STYLE = Automatic
```

Extension build settings:

```text
PRODUCT_BUNDLE_IDENTIFIER = local.markdownquicklook.app.preview
WRAPPER_EXTENSION = appex
INFOPLIST_FILE = MarkdownQuickLookPreview/Info.plist
LD_RUNPATH_SEARCH_PATHS = @executable_path/../Frameworks @executable_path/../../../../Frameworks
```

- [ ] **Step 2: Verify project structure without building**

Run: `find MarkdownQuickLook.xcodeproj MarkdownQuickLook MarkdownQuickLookPreview Sources Tests -maxdepth 3 -type f | sort`

Expected: the app source, extension source, core source, tests, and `project.pbxproj` are present.

- [ ] **Step 3: Build when full Xcode is available**

Run: `xcodebuild -project MarkdownQuickLook.xcodeproj -scheme MarkdownQuickLook -configuration Debug build`

Expected with full Xcode selected: `BUILD SUCCEEDED`.

Expected on the current Command Line Tools-only setup: `xcode-select: error: tool 'xcodebuild' requires Xcode`.

- [ ] **Step 4: Commit project wiring**

```bash
git add MarkdownQuickLook.xcodeproj README.md
git commit -m "Wire macOS Quick Look project"
```

## Task 6: Samples and README

**Files:**
- Create: `Samples/basic.md`
- Create: `Samples/local-image.md`
- Create: `Samples/code-and-table.md`
- Create: `Samples/missing-image.md`
- Create: `Samples/remote-image.md`
- Create: `README.md`

- [ ] **Step 1: Add sample Markdown files**

Create sample files covering headings, paragraphs, lists, quotes, local images, missing local images, remote images, code blocks, and tables. The remote image sample must include `![Remote](https://example.com/image.png)` so manual testing confirms it does not fetch content.

- [ ] **Step 2: Add README**

README must include these commands:

```bash
swift test
xcodebuild -project MarkdownQuickLook.xcodeproj -scheme MarkdownQuickLook -configuration Debug build
qlmanage -r
qlmanage -r cache
```

It must explain:

- Open the project in Xcode after selecting full Xcode with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Build and run the container app once.
- In Finder, select a `.md` or `.markdown` file and press Space.
- Run Quick Look cache refresh commands if Finder still shows the old preview.

- [ ] **Step 3: Commit samples and docs**

```bash
git add Samples README.md
git commit -m "Add samples and usage docs"
```

## Task 7: Final Verification

**Files:**
- Modify only files needed to fix verification failures from earlier tasks.

- [ ] **Step 1: Run Swift package tests**

Run: `swift test`

Expected: all package tests pass.

- [ ] **Step 2: Run Xcode build check**

Run: `xcodebuild -project MarkdownQuickLook.xcodeproj -scheme MarkdownQuickLook -configuration Debug build`

Expected on a machine with full Xcode selected: `BUILD SUCCEEDED`.

Expected on the current machine until Xcode is selected: the known `xcode-select` Command Line Tools error. Record this clearly in the final handoff instead of claiming the app build passed.

- [ ] **Step 3: Check repository status**

Run: `git status --short`

Expected: no uncommitted changes after all task commits.

- [ ] **Step 4: Manual Finder smoke test**

Run after installing/building the app:

```bash
qlmanage -r
qlmanage -r cache
```

Then select `Samples/basic.md` in Finder and press Space. Expected: a native Quick Look panel with styled Markdown text, no WebView chrome, and no network-loaded remote images.

## Self-Review

Spec coverage:

- macOS 13+ native app and Quick Look extension: Tasks 4 and 5.
- Basic Markdown scope: Tasks 1 and 3.
- Local image-only policy and no remote fetching: Task 2 and Task 6 samples.
- Gentle degradation: Tasks 2, 3, 4, and 7.
- Large file fallback: Task 2 and Task 4.
- Automated tests: Tasks 1, 2, 3, and 7.
- Manual validation and README: Task 6 and Task 7.

Type consistency:

- Parser emits `MarkdownBlock`.
- Renderer consumes `[MarkdownBlock]`.
- Quick Look controller uses `MarkdownFileReader`, `PreviewLimits`, `LineMarkdownParser`, and `NativeAttributedStringRenderer`.
- Image policy is independent and testable; renderer still displays remote-image text safely even if no file lookup occurs.
