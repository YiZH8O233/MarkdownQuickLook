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
