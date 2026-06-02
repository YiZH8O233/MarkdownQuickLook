# Markdown Quick Look

[English](README.md) | [简体中文](README.zh-CN.md)

A lightweight native macOS Quick Look preview extension for Markdown files.

Select a `.md` or `.markdown` file in Finder, press Space, and preview it without opening a full editor.

## Requirements

- macOS 13 Ventura or later
- Xcode 26.2 or another recent full Xcode installation
- Swift 6

The active command line developer directory may still point at Command Line Tools. The build commands below call Xcode directly so they do not require changing global `xcode-select` state.

## Build

Run package checks:

```bash
swift test
```

Build the macOS app and Quick Look extension with full Xcode:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MarkdownQuickLook.xcodeproj \
  -scheme MarkdownQuickLook \
  -configuration Debug \
  -derivedDataPath .build/XcodeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

If you prefer using Xcode interactively, select full Xcode first:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
open MarkdownQuickLook.xcodeproj
```

## Try In Finder

1. Build the `MarkdownQuickLook` scheme.
2. Run the container app once from Xcode.
3. In Finder, select a file from `Samples/`.
4. Press Space.

If Finder still shows the old preview, refresh Quick Look:

```bash
qlmanage -r
qlmanage -r cache
```

You can also test from Terminal after the app has been built and registered:

```bash
qlmanage -p Samples/basic.md
```

## Supported Markdown

First version supports a small, fast Markdown subset:

- Headings
- Paragraphs
- Block quotes
- Ordered, unordered, and task lists
- Bold, italic, bold italic, inline code, links, autolinks, bare URLs, and strikethrough
- Academic Ink Blue semantic color theme
- Local relative images
- Fenced code blocks with backticks or tildes
- Native table rendering
- Mermaid `xychart-beta` bar and line charts

Remote images are not loaded. URLs such as `https://example.com/image.png` render as safe text instead of making a network request. Local images are constrained by file size and display size so Finder previews stay responsive.

## Samples

- `Samples/basic.md`
- `Samples/local-image.md`
- `Samples/code-and-table.md`
- `Samples/missing-image.md`
- `Samples/remote-image.md`
