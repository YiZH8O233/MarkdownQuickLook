# Markdown Quick Look Preview Design

Date: 2026-05-25

## Goal

Build a lightweight native macOS Markdown preview tool that works like Finder Quick Look: select a `.md` file, press Space, and see a fast, readable preview without launching a full editor.

The first version prioritizes low overhead, native macOS behavior, and reliable fallback behavior over complete GitHub-flavored Markdown support.

## Target Platform

- macOS 13 Ventura and later.
- Native macOS app bundle with a Quick Look Preview Extension.
- Swift, AppKit, and system frameworks where practical.
- No background service and no long-running helper process.

## Product Shape

The product has two parts:

1. A minimal container macOS app.
2. A Quick Look Preview Extension that renders Markdown files in Finder preview.

The container app exists mainly to install and host the extension. Its UI should be minimal: a native window that confirms the extension is available and tells the user to select a Markdown file in Finder and press Space.

The extension is the main experience. It receives the file URL from Quick Look, reads the file on demand, renders it into a native preview, and releases work when the preview closes.

## Supported File Types

First version supports:

- `.md`
- `.markdown`

The app should use system Uniform Type Identifiers where available and declare compatible document types only where needed for Quick Look registration.

## Rendering Approach

Rendering must be native-first. The extension should not use `WKWebView` for the first version.

The preview UI should use AppKit components such as `NSViewController`, `NSScrollView`, and native text/image presentation. The rendered document should feel close to Apple's native preview surfaces: quiet typography, system colors, clear spacing, and no custom chrome beyond what the Quick Look panel already provides.

The Markdown parser can start from Apple's `AttributedString(markdown:)` / Foundation Markdown behavior where it fits, with focused preprocessing or postprocessing for features that need local resource handling.

## Markdown Scope

First version supports basic Markdown:

- Headings
- Paragraphs
- Emphasis and strong emphasis where supported by the system parser
- Block quotes
- Ordered and unordered lists
- Links
- Local relative images
- Fenced code blocks
- Basic tables as readable fallback text or simple columns

First version does not support:

- Remote image loading
- Mermaid diagrams
- LaTeX rendering
- GitHub task list checkboxes
- Syntax highlighting beyond a simple monospace code style
- Full GitHub-flavored Markdown compatibility

## Image Handling

Only local images referenced relative to the Markdown file are loaded.

Rules:

- Relative image paths resolve from the Markdown file's parent directory.
- Absolute paths outside the Quick Look-provided file context are not required for the first version.
- `http://` and `https://` image URLs are not fetched.
- Missing or unsupported images render as a lightweight inline placeholder.
- Image loading must not block the whole document preview.

This keeps the extension fast and avoids unexpected network requests from Finder preview.

## Links

Links should be styled using native link color and be recognizable as links.

Remote links may be displayed and opened by the system if clicked, but rendering the preview must not fetch remote content. If link interactivity is risky or awkward inside Quick Look, the first version may display links as styled text without custom click handling.

## Large File Behavior

The extension should protect Finder preview from expensive rendering.

Recommended first-version policy:

- Normal files render with basic Markdown styling.
- Very large files use a simplified text preview.
- If rendering exceeds a reasonable internal limit, fall back to plain text instead of blocking.

The exact threshold can be finalized during implementation after testing on sample files, but the behavior must favor responsiveness over completeness.

## Error Handling

Use gentle degradation.

Failure cases:

- File cannot be read: show a concise native error placeholder.
- UTF-8 decoding fails: attempt a system text decoding fallback.
- All decoding fails: show a concise unreadable-file message.
- Markdown parsing fails: show plain text.
- Local image cannot be loaded: show an inline missing-image placeholder.
- Unsupported Markdown feature appears: preserve readable source text where possible.

The preview should avoid alarming diagnostics unless the whole file cannot be displayed.

## Security and Privacy

The extension must not make network requests in the first version.

The extension should read only:

- The Markdown file passed by Quick Look.
- Local relative resources needed by that file, such as images beside it or below its directory.

It should not scan unrelated folders, add analytics, collect telemetry, or persist document contents.

## Performance Principles

- Do work on demand when Quick Look asks for a preview.
- Avoid WebView startup cost.
- Keep parsing and rendering synchronous only for small, safe operations.
- Move file/image work off the main thread where needed.
- Prefer native system colors and fonts instead of heavy custom styling.
- Release rendered content when the preview controller is dismissed.

## Testing Plan

Automated tests should cover:

- Markdown text parsing fallback.
- Local image path resolution.
- Remote image rejection.
- Missing local image handling.
- Encoding fallback behavior.
- Large file fallback decision.

Manual validation samples should include:

- Headings and paragraphs.
- Lists.
- Block quotes.
- Links.
- Local images.
- Missing images.
- Code blocks.
- Tables.
- A very large Markdown file.
- A file with invalid or unusual encoding.

Build validation should use `xcodebuild` once a full Xcode developer directory is available. The current machine reports Command Line Tools as the active developer directory, so local Xcode project builds may require installing Xcode or switching with `xcode-select`.

## Delivery

First implementation should deliver:

- A buildable macOS app project.
- A Quick Look Preview Extension target.
- Minimal container app UI.
- Native Markdown preview for `.md` and `.markdown`.
- Sample Markdown files for manual validation.
- A short README explaining installation, Finder preview testing, and Quick Look cache refresh.

Out of scope for the first implementation:

- App Store packaging.
- Preferences window.
- Custom themes.
- Background services.
- Remote content fetching.
- Full GitHub-flavored Markdown compatibility.

## Open Implementation Notes

During implementation, verify the exact Quick Look extension template and Info.plist keys against the local Xcode project structure. Apple documentation indicates Quick Look Preview Extensions can be view-based or data-based; this design chooses a view-based native preview because it provides the most direct control over AppKit rendering while preserving a lightweight user experience.
